import 'dart:convert';
import 'dart:typed_data' as td;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/clipboard_image.dart';

// Cabeçalho de bitmap DIB, sem o cabeçalho de arquivo BMP de 14 bytes.
td.Uint8List dib(int width, int height, int bpp, {int header=40, int compression=0}) {
  final stride=((width*bpp+31)~/32)*4;
  final bytes=td.Uint8List(header+stride*height.abs());
  final d=td.ByteData.sublistView(bytes);
  d.setUint32(0,header,td.Endian.little);
  d.setInt32(4,width,td.Endian.little);
  d.setInt32(8,height,td.Endian.little);
  d.setUint16(12,1,td.Endian.little);
  d.setUint16(14,bpp,td.Endian.little);
  d.setUint32(16,compression,td.Endian.little);
  return bytes;
}
void main() {
  test('DIB 24 bits respeita padding e orientação de baixo para cima', () {
    final b=dib(1,2,24);
    b.setRange(40,44,[255,0,0,99]); // Azul, linha inferior, byte padding.
    b.setRange(44,48,[0,0,255,99]); // Vermelho, linha superior.
    final result=img.decodePng(ClipboardImage.dibToPng(b))!;
    expect(result.width,1); expect(result.height,2);
    expect(result.getPixel(0,0).r,255);expect(result.getPixel(0,0).b,0);
    expect(result.getPixel(0,1).b,255);expect(result.getPixel(0,1).r,0);
    expect(result.getPixel(0,0).a,255);
  });
  test('DIB BI_RGB de 32 bits não torna capturas transparentes', () {
    final b=dib(1,-2,32);
    b.setRange(40,44,[30,20,10,0]);
    b.setRange(44,48,[80,70,60,0]);
    final result=img.decodePng(ClipboardImage.dibToPng(b))!;
    expect(result.getPixel(0,0).r,10);
    expect(result.getPixel(0,0).g,20);
    expect(result.getPixel(0,0).b,30);
    expect(result.getPixel(0,0).a,255);
    expect(result.getPixel(0,1).r,60);
  });
  test('DIBV5 BITFIELDS preserva transparência explícita', () {
    final b=dib(1,-1,32,header:124,compression:3);
    final d=td.ByteData.sublistView(b);
    d.setUint32(40,0xff0000,td.Endian.little);
    d.setUint32(44,0xff00,td.Endian.little);
    d.setUint32(48,0xff,td.Endian.little);
    d.setUint32(52,0xff000000,td.Endian.little);
    b.setRange(124,128,[30,20,10,128]);
    final pixel=img.decodePng(ClipboardImage.dibToPng(b))!.getPixel(0,0);
    expect(pixel.r,10);expect(pixel.g,20);expect(pixel.b,30);expect(pixel.a,128);
  });
  test('PNG original é preservado e dimensões inválidas são rejeitadas', () {
    final png=img.encodePng(img.Image(width:2,height:3,numChannels:4));
    expect(identical(ClipboardImage.checkedPng(png),png),isTrue);
    final corrupt=td.Uint8List.fromList(png);
    td.ByteData.sublistView(corrupt).setUint32(16,100000000);
    expect(()=>ClipboardImage.checkedPng(corrupt),throwsFormatException);
    expect(()=>ClipboardImage.checkedPng(td.Uint8List(30)),throwsFormatException);
  });
  test('Bitmap truncado ou com dimensões abusivas é rejeitado', () {
    final b=dib(2,2,24);
    expect(()=>ClipboardImage.dibToPng(td.Uint8List.sublistView(b,0,41)),throwsFormatException);
    td.ByteData.sublistView(b).setInt32(4,100000000,td.Endian.little);
    expect(()=>ClipboardImage.dibToPng(b),throwsFormatException);
  });
  test('Imagem colada fica centrada, proporcional e embutida no documento', () {
    final png=img.encodePng(img.Image(width:8,height:4));
    final doc=Sketch();
    final e=ClipboardImage.element(png,layerId:doc.layers.first.id,
      center:const Offset(100,200),width:8,height:4,maximumSide:6);
    expect(e.bounds.center,const Offset(100,200));
    expect(e.w,6);expect(e.h,3);expect(e.type,'image');
    doc.elements.add(e);
    final restored=Sketch.fromJson(jsonDecode(doc.serialize()) as Map<String,dynamic>);
    expect(restored.elements.single.id,e.id);
    expect(base64Decode(restored.elements.single.data),orderedEquals(png));
  });
}
