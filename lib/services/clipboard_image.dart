import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;

import '../models/sketch.dart';

/// Leitura sob demanda, sem monitorar a área de transferência.
/// A parte Win32 e a conversão de bitmaps rodam fora do isolate da interface.
class ClipboardImage {
  static const maxBytes = 64 * 1024 * 1024;
  static const maxPixels = 24 * 1024 * 1024;

  static bool get isSupported => Platform.isWindows;

  static Future<Uint8List?> read() async {
    if (!isSupported) return null;
    return Isolate.run(_readWindowsImage);
  }

  static void _checkDimensions(int width, int height) {
    if (width <= 0 || height <= 0 || width * height > maxPixels) {
      throw const FormatException('Imagem inválida ou muito grande (limite de 24 Mi pixels).');
    }
  }

  static Uint8List checkedPng(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 33 || bytes.length > maxBytes ||
        !List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v)) {
      throw const FormatException('PNG inválido ou muito grande.');
    }
    final header = ByteData.sublistView(bytes);
    if (header.getUint32(8) != 13 || header.getUint32(12) != 0x49484452) {
      throw const FormatException('Cabeçalho PNG inválido.');
    }
    _checkDimensions(header.getUint32(16), header.getUint32(20));
    return bytes;
  }

  /// CF_DIB e CF_DIBV5 são bitmaps sem o cabeçalho de arquivo BMP.
  /// Suporta RGB de 16/24/32 bits e BITFIELDS de 16/32 bits.
  /// O byte reservado de BI_RGB de 32 bits NÃO representa transparência.
  static Uint8List dibToPng(Uint8List bytes) {
    if (bytes.length < 40 || bytes.length > maxBytes) {
      throw const FormatException('Bitmap inválido ou muito grande.');
    }
    final d = ByteData.sublistView(bytes);
    int u32(int at) => d.getUint32(at, Endian.little);
    final header = u32(0);
    if (![40, 52, 56, 108, 124].contains(header) || header > bytes.length) {
      throw const FormatException('Cabeçalho bitmap não suportado.');
    }
    final width = d.getInt32(4, Endian.little);
    final signedHeight = d.getInt32(8, Endian.little);
    final height = signedHeight.abs();
    _checkDimensions(width, height);
    final planes = d.getUint16(12, Endian.little);
    final bpp = d.getUint16(14, Endian.little);
    final compression = u32(16);
    if (planes != 1 || ![16, 24, 32].contains(bpp) ||
        ![0, 3, 6].contains(compression) || (bpp == 24 && compression != 0)) {
      throw const FormatException('Formato bitmap não suportado.');
    }
    var offset = header;
    var red = bpp == 16 ? 0x7c00 : 0xff0000;
    var green = bpp == 16 ? 0x03e0 : 0x00ff00;
    var blue = bpp == 16 ? 0x001f : 0x0000ff;
    var alpha = 0;
    if (compression == 3 || compression == 6) {
      final maskCount = compression == 6 ? 4 : 3;
      if (header == 40) offset += maskCount * 4;
      if (bytes.length < 40 + maskCount * 4 ||
          (header != 40 && header < 40 + maskCount * 4)) {
        throw const FormatException('Máscaras de cor incompletas.');
      }
      red = u32(40); green = u32(44); blue = u32(48);
      if (compression == 6 || header >= 56) alpha = u32(52);
      final maxMask = bpp == 16 ? 0xffff : 0xffffffff;
      if (red == 0 || green == 0 || blue == 0 ||
          ((red | green | blue | alpha) & ~maxMask) != 0 ||
          (red & green) != 0 || (red & blue) != 0 || (green & blue) != 0 ||
          (alpha & (red | green | blue)) != 0) {
        throw const FormatException('Máscaras de cor inválidas.');
      }
    }
    offset += u32(32) * 4; // biClrUsed: tabela opcional de cores.
    final stride = ((width * bpp + 31) ~/ 32) * 4;
    final imageBytes = stride * height;
    if (header == 124 && u32(116) > 0 && u32(112) == offset) {
      offset += u32(116); // Perfil de cor, quando antecede os pixels.
    }
    if (offset > bytes.length || imageBytes > bytes.length - offset) {
      throw const FormatException('Bitmap incompleto.');
    }
    // Máscaras consecutivas, escaladas para 8 bits.
    int shift(int mask) {
      if (mask == 0) return 0;
      var s = 0;
      while ((mask & 1) == 0) { mask >>= 1; s++; }
      if ((mask & (mask + 1)) != 0) {
        throw const FormatException('Máscara de cor não consecutiva.');
      }
      return s;
    }
    final rs = shift(red), gs = shift(green), bs = shift(blue), alphaShift = shift(alpha);
    int channel(int pixel, int mask, int bits) =>
        (((pixel & mask) >> bits) * 255 + (mask >> bits) ~/ 2) ~/ (mask >> bits);
    final result = img.Image(width: width, height: height, numChannels: 4);
    for (var y = 0; y < height; y++) {
      final row = offset + (signedHeight < 0 ? y : height - 1 - y) * stride;
      for (var x = 0; x < width; x++) {
        final p = row + x * (bpp ~/ 8);
        if (bpp == 24) {
          result.setPixelRgba(x, y, bytes[p+2], bytes[p+1], bytes[p], 255);
        } else {
          final pixel = bpp == 16 ? d.getUint16(p, Endian.little) : u32(p);
          result.setPixelRgba(x, y, channel(pixel, red, rs), channel(pixel, green, gs),
              channel(pixel, blue, bs), alpha == 0 ? 255 : channel(pixel, alpha, alphaShift));
        }
      }
    }
    return checkedPng(img.encodePng(result, level: 3));
  }

  /// Centraliza no mundo, mantendo proporções; o arquivo original fica embutido.
  static InkElement element(Uint8List bytes, {required String layerId,
      required Offset center, required int width, required int height,
      required double maximumSide}) {
    _checkDimensions(width, height);
    if (!maximumSide.isFinite || maximumSide <= 0 || !center.isFinite) {
      throw const FormatException('Posição de inserção inválida.');
    }
    final factor = math.min(1.0, maximumSide / math.max(width, height));
    final w = width * factor, h = height * factor;
    return InkElement(layerId: layerId, type: 'image',
        x: center.dx - w / 2, y: center.dy - h / 2, w: w, h: h,
        data: base64Encode(bytes));
  }
}

Uint8List? _readWindowsImage() {
  final user = DynamicLibrary.open('user32.dll');
  final kernel = DynamicLibrary.open('kernel32.dll');
  final open = user.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('OpenClipboard');
  final close = user.lookupFunction<Int32 Function(), int Function()>('CloseClipboard');
  final available = user.lookupFunction<Int32 Function(Uint32), int Function(int)>('IsClipboardFormatAvailable');
  final get = user.lookupFunction<Pointer<Void> Function(Uint32), Pointer<Void> Function(int)>('GetClipboardData');
  final register = user.lookupFunction<Uint32 Function(Pointer<Utf16>), int Function(Pointer<Utf16>)>('RegisterClipboardFormatW');
  final size = kernel.lookupFunction<UintPtr Function(Pointer<Void>), int Function(Pointer<Void>)>('GlobalSize');
  final lock = kernel.lookupFunction<Pointer<Void> Function(Pointer<Void>), Pointer<Void> Function(Pointer<Void>)>('GlobalLock');
  final unlock = kernel.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('GlobalUnlock');
  final name = 'PNG'.toNativeUtf16(allocator: calloc);
  final int png;
  try { png = register(name); } finally { calloc.free(name); }
  final formats = [if (png != 0) png, 17, 8]; // PNG, CF_DIBV5, CF_DIB.
  if (!formats.any((f) => available(f) != 0)) return null;
  var opened = false;
  for (var i = 0; i < 6; i++) {
    if (open(nullptr) != 0) { opened = true; break; }
    sleep(const Duration(milliseconds: 15));
  }
  if (!opened) throw const FormatException('Área de transferência ocupada; tente novamente.');
  // Copiar bytes enquanto o clipboard está aberto; converter após fechar.
  final candidates = <(int, Uint8List)>[];
  var imageFound = false;
  try {
    for (final format in formats) {
      if (available(format) == 0) continue;
      imageFound = true;
      final handle = get(format);
      if (handle == nullptr) continue;
      final length = size(handle);
      if (length <= 0 || length > ClipboardImage.maxBytes) continue;
      final address = lock(handle);
      if (address == nullptr) continue;
      try {
        candidates.add((format, Uint8List.fromList(address.cast<Uint8>().asTypedList(length))));
      } finally { unlock(handle); }
      // PNG válido é preferível: evita copiar também uma imagem DIB enorme.
      if (format == png && candidates.isNotEmpty) {
        try { return ClipboardImage.checkedPng(candidates.last.$2); }
        on FormatException { candidates.removeLast(); }
      }
    }
  } finally { close(); }
  for (final candidate in candidates) {
    try { return ClipboardImage.dibToPng(candidate.$2); }
    on FormatException { /* Tentar o próximo formato oferecido. */ }
  }
  if (imageFound) throw const FormatException('Imagem da área de transferência inválida, grande demais ou em formato não suportado.');
  return null;
}
