import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as im;
import 'package:path_provider/path_provider.dart';
import '../models/sketch.dart';
import '../widgets/board_painter.dart';
import 'rich_text.dart';
import 'mind_map_vectors.dart';

class SketchExchange {
  static Future<Uint8List?> pickFile(List<String> extensions) async {
    final res = await FilePicker.platform.pickFiles(type:FileType.custom,
      allowedExtensions:extensions, withData:true);
    if (res == null || res.files.isEmpty) return null;
    final f=res.files.single;
    if (f.bytes != null) return f.bytes!;
    if (f.path != null) return File(f.path!).readAsBytes();
    throw StateError('O seletor não disponibilizou bytes do arquivo.');
  }
  static Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try { return (await codec.getNextFrame()).image; }
    finally { codec.dispose(); }
  }
  static Future<Map<String,ui.Image>> decodeAll(Sketch doc) async {
    final decoded = <String,ui.Image>{};
    for(final e in List<InkElement>.of(doc.elements)) {
      if(e.type!='image' || e.data.isEmpty) continue;
      try { decoded[e.id] = await decode(base64Decode(e.data)); }
      catch (_) { /* Placeholder desenhado no lugar de um asset inválido. */ }
    }
    return decoded;
  }
  static Future<List<InkElement>> importImage(Sketch doc, Uint8List bytes,
      {Offset at = const Offset(50,50), double maximumSide = 920}) async {
    // PSD 8 bits RGB composto é convertido para imagem; camadas PSD não são preservadas.
    if(bytes.length>=4 && String.fromCharCodes(bytes.take(4))=='8BPS') {
      return importImage(doc, decodePsdComposite(bytes),at:at,maximumSide:maximumSide);
    }
    final image = await decode(bytes);
    final ratio = math.min(1.0, maximumSide/math.max(image.width,image.height));
    final element = InkElement(layerId:doc.layers.last.id,type:'image',
      x:at.dx,y:at.dy,w:image.width*ratio,h:image.height*ratio,
      data:base64Encode(bytes));
    image.dispose();
    return [element];
  }
  static Future<List<InkElement>> importPdf(Sketch doc, Uint8List data,
      {int maxPages=40, double maxWidth=900}) async {
    File? temporary;
    if (Platform.isWindows) {
      final dir = await getTemporaryDirectory();
      temporary = File('${dir.path}/ci_import_${DateTime.now().microsecondsSinceEpoch}.pdf');
      await temporary.writeAsBytes(data, flush:true);
    }
    final document = temporary != null
      ? await pdfx.PdfDocument.openFile(temporary.path)
      : await pdfx.PdfDocument.openData(data);
    final result = <InkElement>[];
    var y = 35.0;
    try {
      final count = math.min(document.pagesCount,maxPages);
      final pdfGroup=newId();
      for(var i=1;i<=count;i++) {
        final page = await document.getPage(i);
        try {
          final ratio = maxWidth/page.width;
          final image = await page.render(
              width:page.width*ratio,height:page.height*ratio,
              format:pdfx.PdfPageImageFormat.png);
          if(image == null) continue;
          final h=page.height*ratio;
          result.add(InkElement(layerId:doc.layers.first.id,type:'image',
            x:35,y:y,w:maxWidth,h:h,data:base64Encode(image.bytes),
            meta:{'pdfGroup':pdfGroup,'pdfPage':i,'pdfPageCount':count}));
          y += h+28;
        } finally {await page.close();}
      }
    } finally {await document.close(); if (temporary != null && await temporary.exists()) await temporary.delete();}
    return result;
  }
  static Future<Uint8List> renderPng(Sketch doc, Map<String,ui.Image> images,
      {bool transparent=false,bool grid=true,double maxDimension=3000,
      Rect? area}) async {
    final bounds = area ?? doc.contentBounds;
    final width = math.max(10.0,bounds.width), height=math.max(10.0,bounds.height);
    // A memória é limitada para evitar travamento em Android com folhas enormes.
    final ratio=math.min(maxDimension/math.max(width,height),
      math.sqrt(48000000/(width*height))).clamp(.05,7.0).toDouble();
    final pxW=math.max(1,(width*ratio).round()), pxH=math.max(1,(height*ratio).round());
    final recorder=ui.PictureRecorder();
    final canvas=Canvas(recorder);
    canvas.scale(ratio); canvas.translate(-bounds.left,-bounds.top);
    if (transparent) {
      // Exportação transparente utiliza um fundo temporário sem cor.
      BoardRenderer.paint(canvas,doc,bounds,images:images,grids:false,zoom:ratio,
        transparentBackground:true);
    } else {
      BoardRenderer.paint(canvas,doc,bounds,images:images,grids:grid,zoom:ratio);
    }
    final picture=recorder.endRecording();
    final image=await picture.toImage(pxW,pxH);
    final byteData=await image.toByteData(format:ui.ImageByteFormat.png);
    image.dispose(); picture.dispose();
    if (byteData == null) throw StateError('Falha na renderização da imagem.');
    return byteData.buffer.asUint8List();
  }
  static Future<Uint8List> exportImage(Sketch doc, Map<String,ui.Image> images,
      {bool jpeg=false,bool transparent=false,bool artboard=false,int quality=92,int ppi=144}) async {
    final png=await renderPng(doc,images,
      area:artboard ? Rect.fromLTWH(0,0,doc.artboardW,doc.artboardH) : null,
      transparent:transparent,maxDimension:math.max(600,doc.artboardW*ppi/96));
    if (!jpeg) return png;
    final decoded=im.decodePng(png);
    if (decoded == null) throw StateError('Erro ao converter PNG para JPG');
    return Uint8List.fromList(im.encodeJpg(decoded,quality:quality));
  }
  static Future<Uint8List> exportPdf(Sketch doc, Map<String,ui.Image> images,
      {bool artboard=false, bool multiPage=false}) async {
    final pdf=pw.Document(compress:true);
    final pages=doc.elements.where((e)=>e.type=='image' && e.meta['pdfPage']!=null)
      .toList()..sort((a,b)=>a.y.compareTo(b.y));
    if(multiPage && pages.isNotEmpty) {
      if(pages.length>80) throw StateError('A exportação em páginas aceita até 80 páginas por arquivo.');
      for(final page in pages) {
        final bounds=Rect.fromLTWH(page.x,page.y,page.w.abs(),page.h.abs());
        if(bounds.width<1 || bounds.height<1) continue;
        final png=await renderPng(doc,images,area:bounds,grid:false,maxDimension:2000);
        final w=PdfPageFormat.a4.width;
        final h=(w*bounds.height/bounds.width).clamp(50.0,12000.0).toDouble();
        pdf.addPage(pw.Page(pageFormat:PdfPageFormat(w,h,marginAll:0),
          build:(_)=>pw.Image(pw.MemoryImage(png),fit:pw.BoxFit.fill)));
      }
    } else {
      final png=await exportImage(doc,images,artboard:artboard);
      final bounds=artboard ? Rect.fromLTWH(0,0,doc.artboardW,doc.artboardH) : doc.contentBounds;
      final w=PdfPageFormat.a4.width;
      final h=(w*bounds.height/bounds.width).clamp(50.0,12000.0).toDouble();
      pdf.addPage(pw.Page(pageFormat:PdfPageFormat(w,h,marginAll:0),
        build:(_)=>pw.Image(pw.MemoryImage(png),fit:pw.BoxFit.fill)));
    }
    return Uint8List.fromList(await pdf.save());
  }
  /// PDF vetorial para desenhos construídos com linhas e formas simples.
  /// Em vez de achatar em uma imagem, escreve comandos gráficos no PDF.
  /// Documentos com imagens, máscaras, texto e pincéis texturizados devem
  /// usar exportPdf (rasterizado) para preservar sua aparência.
  static Future<Uint8List> exportVectorPdf(Sketch doc,{bool artboard=false}) async {
    final visible = doc.layers.where((l)=>l.visible).toList();
    final items = <InkElement>[
      for(final l in visible) ...doc.elements.where((e)=>e.layerId==l.id),
    ];
    for(final layer in visible) {
      if(layer.opacity < .999) {
        throw StateError('Há camadas transparentes. Use PDF comum para preservar a aparência.');
      }
    }
    for(final e in items) {
      if(MindMapVectors.newTools.contains(e.tool) || e.meta.keys.any((key)=>key.startsWith('vector'))) {
        throw StateError('Este mapa contém vetores avançados. Use PDF comum ou SVG para preservar o contorno.');
      }
      if(e.type!='stroke' || e.opacity<.999 ||
          const ['airbrush','watercolor','soft pencil','marker',
            'mask','soft mask','eraser'].contains(e.tool)) {
        throw StateError('O documento tem imagens, texto, máscaras ou transparências. '
          'Use PDF comum; o PDF vetorial suporta traços e formas opacos.');
      }
    }
    final bounds = artboard ? Rect.fromLTWH(0,0,doc.artboardW,doc.artboardH)
      : doc.contentBounds;
    if(bounds.width <= 0 || bounds.height <= 0) {
      throw StateError('Área de exportação inválida.');
    }
    final width = PdfPageFormat.a4.width;
    final height = width * bounds.height / bounds.width;
    if(height < 50 || height > 12000) {
      throw StateError('A proporção do desenho não cabe em uma página PDF. Delimite um artboard.');
    }
    final scale = width / bounds.width;
    double px(double x) => (x-bounds.left)*scale;
    double py(double y) => height-(y-bounds.top)*scale;
    final pdf = pw.Document(compress:true);
    pdf.addPage(pw.Page(pageFormat:PdfPageFormat(width,height,marginAll:0),
      build: (_) => pw.CustomPaint(size:PdfPoint(width,height),
        painter: (canvas,size) {
          canvas.setFillColor(PdfColor.fromHex(doc.background));
          canvas.drawRect(0,0,width,height);
          canvas.fillPath();
          for(final e in items) {
            if(e.points.isEmpty)continue;
            canvas.setStrokeColor(PdfColor.fromInt(e.color));
            canvas.setFillColor(PdfColor.fromInt(e.color));
            canvas.setLineWidth(math.max(.1,e.size*scale));
            final a=e.points.first,b=e.points.last;
            if(e.tool=='rectangle') {
              final x=math.min(px(a.x),px(b.x));
              final y=math.min(py(a.y),py(b.y));
              canvas.drawRect(x,y,(a.x-b.x).abs()*scale,(a.y-b.y).abs()*scale);
              canvas.strokePath();
            } else if(e.tool=='ellipse') {
              final centerX=(px(a.x)+px(b.x))/2;
              final centerY=(py(a.y)+py(b.y))/2;
              canvas.drawEllipse(centerX,centerY,
                (a.x-b.x).abs()*scale/2,(a.y-b.y).abs()*scale/2);
              canvas.strokePath();
            } else if(e.tool=='triangle' || e.tool=='diamond') {
              final minX=math.min(px(a.x),px(b.x));
              final maxX=math.max(px(a.x),px(b.x));
              final minY=math.min(py(a.y),py(b.y));
              final maxY=math.max(py(a.y),py(b.y));
              if(e.tool=='triangle') {
                canvas.moveTo((minX+maxX)/2,maxY);
                canvas.lineTo(maxX,minY);
                canvas.lineTo(minX,minY);
              } else {
                canvas.moveTo((minX+maxX)/2,maxY);
                canvas.lineTo(maxX,(minY+maxY)/2);
                canvas.lineTo((minX+maxX)/2,minY);
                canvas.lineTo(minX,(minY+maxY)/2);
              }
              canvas.strokePath(close:true);
            } else if (e.points.length==1) {
              canvas.drawEllipse(px(a.x),py(a.y),
                math.max(.4,e.size*scale/2),math.max(.4,e.size*scale/2));
              canvas.fillPath();
            } else {
              if(e.tool=='dotted') canvas.setLineDashPattern([1,math.max(2,e.size*scale*2)]);
              canvas.moveTo(px(a.x),py(a.y));
              for(final pt in e.points.skip(1))canvas.lineTo(px(pt.x),py(pt.y));
              if(e.tool=='fill' || e.tool=='area')canvas.fillPath();
              else canvas.strokePath();
              if(e.tool=='dotted')canvas.setLineDashPattern();
              if(e.tool=='arrow') {
                final rad=math.atan2(b.y-a.y,b.x-a.x);
                final side=math.min(22.0,e.size*5+7)*scale;
                canvas.moveTo(px(b.x),py(b.y));
                canvas.lineTo(px(b.x)-side*math.cos(rad-.53),
                  py(b.y)+side*math.sin(rad-.53));
                canvas.moveTo(px(b.x),py(b.y));
                canvas.lineTo(px(b.x)-side*math.cos(rad+.53),
                  py(b.y)+side*math.sin(rad+.53));
                canvas.strokePath();
              }
            }
          }
        })));
    return Uint8List.fromList(await pdf.save());
  }

  /// PSD composto não comprimido, RGB 8 bits, para intercâmbio com editores externos.
  /// Não promete camadas editáveis em PSD; o arquivo nativo .ci.json preserva isso.
  static Future<Uint8List> exportPsd(Sketch doc,Map<String,ui.Image> images,
      {bool artboard=false,int ppi=144}) async {
    final png=await exportImage(doc,images,artboard:artboard,ppi:ppi);
    final decoded=im.decodePng(png);
    if(decoded==null)throw const FormatException('Não foi possível codificar PSD.');
    if(decoded.width*decoded.height>24000000)throw StateError('PSD excede limite de 24 milhões de pixels.');
    final builder=BytesBuilder(copy:false);
    void word(int n)=>builder.add([(n>>8)&255,n&255]);
    void dword(int n)=>builder.add([(n>>24)&255,(n>>16)&255,(n>>8)&255,n&255]);
    builder.add(ascii.encode('8BPS'));
    word(1);builder.add(List<int>.filled(6,0));word(3);
    dword(decoded.height);dword(decoded.width);word(8);word(3);
    dword(0);dword(0);dword(0);word(0);
    for(var channel=0;channel<3;channel++){
      for(var y=0;y<decoded.height;y++){
        final row=Uint8List(decoded.width);
        for(var x=0;x<decoded.width;x++){
          final p=decoded.getPixel(x,y);
          row[x]=(channel==0?p.r:channel==1?p.g:p.b).toInt();
        }
        builder.add(row);
      }
    }
    return builder.takeBytes();
  }

  /// Importação PSD limitada ao *composite* RGB 8 bits, raw ou PackBits.
  /// PSDs CMYK, 16 bits e camadas especiais não estão cobertos.
  static Uint8List decodePsdComposite(Uint8List file) {
    final data=ByteData.sublistView(file);var at=0;
    void need(int size){if(at+size>file.length)throw const FormatException('PSD incompleto.');}
    int word(){need(2);final x=data.getUint16(at);at+=2;return x;}
    int dword(){need(4);final x=data.getUint32(at);at+=4;return x;}
    need(4);if(ascii.decode(file.sublist(0,4))!='8BPS')throw const FormatException('Assinatura PSD inválida.');
    at=4;if(word()!=1)throw const FormatException('Versão PSD não suportada.');
    at+=6;final channels=word(),height=dword(),width=dword(),depth=word(),mode=word();
    if(width<=0||height<=0||width*height>20000000||depth!=8||mode!=3||channels<3)
      throw const FormatException('Aceita PSD RGB composto, 8 bits, até 20 megapixels.');
    for(var i=0;i<3;i++){final n=dword();need(n);at+=n;}
    final compression=word();final planeCount=width*height;
    final planes=<Uint8List>[];
    if(compression==0){
      for(var c=0;c<channels;c++){need(planeCount);
        if(c<3)planes.add(Uint8List.fromList(file.sublist(at,at+planeCount)));
        at+=planeCount;
      }
    }else if(compression==1){
      final lengths=<int>[];
      for(var c=0;c<channels;c++)for(var y=0;y<height;y++)lengths.add(word());
      for(var c=0;c<channels;c++){
        final plane=Uint8List(planeCount);
        for(var y=0;y<height;y++){
          final end=at+lengths[c*height+y];need(lengths[c*height+y]);
          var x=0;
          while(at<end){
            var n=file[at++];if(n>=128)n-=256;
            if(n>=0){final count=n+1;if(x+count>width || at+count>end)throw const FormatException('Linha PSD inválida.');
              plane.setRange(y*width+x,y*width+x+count,file,at);at+=count;x+=count;
            }else if(n>=-127){final count=1-n;need(1);final v=file[at++];
              if(x+count>width)throw const FormatException('Linha PSD inválida.');
              plane.fillRange(y*width+x,y*width+x+count,v);x+=count;
            }
          }
          if(x!=width)throw const FormatException('Linha PSD truncada.');
        }
        if(c<3)planes.add(plane);
      }
    }else{throw const FormatException('Compressão PSD incompatível.');}
    final img=im.Image(width:width,height:height);
    for(var y=0;y<height;y++)for(var x=0;x<width;x++){
      final k=y*width+x;
      img.setPixelRgb(x,y,planes[0][k],planes[1][k],planes[2][k]);
    }
    return Uint8List.fromList(im.encodePng(img));
  }

  static String _escape(String s) => s.replaceAll('&','&amp;').replaceAll('<','&lt;')
      .replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&apos;');
  // SVG keeps rich text editable. Font metrics can vary in external viewers;
  // PNG/PDF use the actual Flutter renderer for a pixel-accurate result.
  static void _writeSvgText(StringBuffer out, InkElement e, String color) {
    final marks=RichTextFormat.decode(e.text,e.meta['richRuns']);
    final painter=TextPainter(text:RichTextFormat.fromRuns(e.text,e.meta['richRuns'],
      TextStyle(fontSize:e.size,height:1.25,fontWeight:FontWeight.w400,color:Color(e.color))),
      textDirection:TextDirection.ltr,textScaler:TextScaler.noScaling);
    String hex(int value)=> '#${(value & 0xffffff).toRadixString(16).padLeft(6,'0')}';
    try {
      painter.layout(maxWidth:e.w>0?e.w:1200.0);
      final center=e.bounds.center;
      out.writeln('<g opacity="${e.opacity}" transform="rotate(${e.rotation*180/math.pi} ${center.dx} ${center.dy})">');
      var start=0;
      while(start<marks.length) {
        final mark=marks[start];
        var end=start+1;
        while(end<marks.length && marks[end]==mark) {end++;}
        if(mark.highlight!=null) {
          for(final box in painter.getBoxesForSelection(TextSelection(baseOffset:start,extentOffset:end))) {
            out.writeln('<rect x="${e.x+box.left}" y="${e.y+box.top}" width="${box.right-box.left}" height="${box.bottom-box.top}" fill="${hex(mark.highlight!)}"/>');
          }
        }
        start=end;
      }
      for(final line in painter.computeLineMetrics()) {
        final position=painter.getPositionForOffset(Offset(line.left+.01,line.baseline-line.ascent/2));
        final range=painter.getLineBoundary(position);
        final from=range.start.clamp(0,e.text.length).toInt();
        final to=range.end.clamp(from,e.text.length).toInt();
        if(from==to)continue;
        out.write('<text xml:space="preserve" x="${e.x+line.left}" y="${e.y+line.baseline}" fill="$color" font-size="${e.size}">');
        var i=from;
        while(i<to) {
          final mark=marks[i];
          var end=i+1;
          while(end<to && marks[end]==mark){end++;}
          final flags=mark.flags;
          final decorations=[if((flags & RichTextFormat.underline)!=0)'underline',
            if((flags & RichTextFormat.strike)!=0)'line-through'].join(' ');
          final value=e.text.substring(i,end).replaceAll('\n','').replaceAll('\r','');
          out.write('<tspan fill="${mark.color==null?color:hex(mark.color!)}" font-size="${e.size*mark.scale}" font-weight="${(flags & RichTextFormat.bold)!=0?'bold':'normal'}" font-style="${(flags & RichTextFormat.italic)!=0?'italic':'normal'}" text-decoration="${decorations.isEmpty?'none':decorations}">${_escape(value)}</tspan>');
          i=end;
        }
        out.writeln('</text>');
      }
      out.writeln('</g>');
    } finally {painter.dispose();}
  }
  static String exportSvg(Sketch doc,{bool artboard=false}) {
    final bounds=artboard ? Rect.fromLTWH(0,0,doc.artboardW,doc.artboardH) : doc.contentBounds;
    final out=StringBuffer();
    out.writeln('<svg xmlns="http://www.w3.org/2000/svg" width="${bounds.width}" height="${bounds.height}" viewBox="${bounds.left} ${bounds.top} ${bounds.width} ${bounds.height}">');
    out.writeln('<rect x="${bounds.left}" y="${bounds.top}" width="${bounds.width}" height="${bounds.height}" fill="${doc.background}"/>');
    for (final layer in doc.layers) {
      if(!layer.visible) continue;
      out.writeln('<g opacity="${layer.opacity}">');
      for(final e in doc.elements.where((e)=>e.layerId==layer.id)) {
        final color='#${(e.color & 0xffffff).toRadixString(16).padLeft(6,'0')}';
        if(e.type=='text') {
          _writeSvgText(out,e,color);
        } else if(e.type=='image') {
          final mime=e.data.startsWith('/9j/')?'image/jpeg':'image/png';
          out.writeln('<image x="${e.x}" y="${e.y}" width="${e.w}" height="${e.h}" href="data:$mime;base64,${e.data}" opacity="${e.opacity}"/>');
        } else if(e.points.isNotEmpty) {
          final first=e.points.first;
          final second=e.points.last;
          if(MindMapVectors.isVector(e) && e.points.length>=2 &&
              (MindMapVectors.newTools.contains(e.tool) || e.meta.keys.any((key)=>key.startsWith('vector')))) {
            final node=MindMapVectors.isNode(e);
            final samples=MindMapVectors.sample(e);
            if(samples.isEmpty)continue;
            final String path;
            if(MindMapVectors.isCurve(e)) {
              final p=e.points;
              path='M ${p[0].x} ${p[0].y} C ${p[1].x} ${p[1].y} ${p[2].x} ${p[2].y} ${p[3].x} ${p[3].y}';
            } else {
              path='M ${samples.first.dx} ${samples.first.dy} ${samples.skip(1).map((p)=>'L ${p.dx} ${p.dy}').join(' ')}${node?' Z':''}';
            }
            final dash=MindMapVectors.dashLengths(MindMapVectors.pattern(e),e.size);
            final dashAttr=dash.isEmpty?'':' stroke-dasharray="${dash.join(' ')}"';
            final fill=e.meta['vectorFill'];
            final fillOpacity=node && fill is num?fill.clamp(0,1):0;
            out.writeln('<path d="$path" fill="${node?color:'none'}" fill-opacity="$fillOpacity" stroke="$color" stroke-width="${e.size}" stroke-linecap="round" stroke-linejoin="round" opacity="${e.opacity}"$dashAttr/>');
            if(!node) {
              final style=MindMapVectors.arrow(e);
              for(final metric in MindMapVectors.linePath(e).computeMetrics()) {
                void head(double at,bool reverse) {
                  final t=metric.getTangentForOffset(at);if(t==null)return;
                  final angle=math.atan2(t.vector.dy,t.vector.dx)+(reverse?math.pi:0);
                  final length=math.min(metric.length*.4,math.max(9.0,e.size*4));
                  final p=t.position;
                  final a=Offset(p.dx-length*math.cos(angle-.55),p.dy-length*math.sin(angle-.55));
                  final b=Offset(p.dx-length*math.cos(angle+.55),p.dy-length*math.sin(angle+.55));
                  out.writeln('<polyline points="${a.dx},${a.dy} ${p.dx},${p.dy} ${b.dx},${b.dy}" fill="none" stroke="$color" stroke-width="${e.size}" stroke-linecap="round" stroke-linejoin="round" opacity="${e.opacity}"/>');
                }
                if(style=='start'||style=='both')head(0,true);
                if(style=='end'||style=='both')head(metric.length,false);
              }
            }
          } else if(e.tool=='ellipse') {
            out.writeln('<ellipse cx="${(first.x+second.x)/2}" cy="${(first.y+second.y)/2}" rx="${(first.x-second.x).abs()/2}" ry="${(first.y-second.y).abs()/2}" fill="none" stroke="$color" stroke-width="${e.size}" opacity="${e.opacity}"/>');
          } else if(e.tool=='rectangle') {
            out.writeln('<rect x="${math.min(first.x,second.x)}" y="${math.min(first.y,second.y)}" width="${(first.x-second.x).abs()}" height="${(first.y-second.y).abs()}" fill="none" stroke="$color" stroke-width="${e.size}" opacity="${e.opacity}"/>');
          } else {
            final path=e.points.map((p)=>'${p.x},${p.y}').join(' ');
            out.writeln('<polyline points="$path" fill="${e.tool=='fill' ? color : 'none'}" stroke="$color" stroke-width="${e.size}" stroke-linecap="round" stroke-linejoin="round" opacity="${e.opacity}"/>');
          }
        }
      }
      out.writeln('</g>');
    }
    out.writeln('</svg>');
    return out.toString();
  }
  static String exportDxf(Sketch doc) {
    final out=StringBuffer('0\nSECTION\n2\nENTITIES\n');
    for(final e in doc.elements) {
      final layer=doc.layerById(e.layerId);
      if(layer == null || !layer.visible || e.type!='stroke') continue;
      final points=MindMapVectors.newTools.contains(e.tool) && e.points.length>=2?
        MindMapVectors.sample(e).map(MindMapVectors.point).toList():e.points;
      for(var i=1;i<points.length;i++) {
        final a=points[i-1],b=points[i];
        out.write('0\nLINE\n8\n${layer.name.replaceAll('\n',' ')}\n10\n${a.x}\n20\n${-a.y}\n30\n0\n11\n${b.x}\n21\n${-b.y}\n31\n0\n');
      }
    }
    out.write('0\nENDSEC\n0\nEOF\n');
    return out.toString();
  }
  static Future<void> saveBytes(String name, Uint8List bytes) async {
    await FilePicker.platform.saveFile(dialogTitle:'Salvar / compartilhar',fileName:name,bytes:bytes);
  }
  static Future<void> printDocument(Sketch doc,Map<String,ui.Image> images) async {
    final data=await exportPdf(doc,images,artboard:true);
    await Printing.layoutPdf(onLayout: (_) async => data);
  }
}
