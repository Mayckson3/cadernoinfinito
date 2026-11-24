import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'rich_text.dart';

/// Mede o texto com as MESMAS configurações do renderizador do quadro.
/// O ponto de inserção é o canto superior esquerdo real da área pintada.
class TextGeometry {
  const TextGeometry._();
  static Size measure(String value,double fontSize,{double? maxWidth,Object? runs}) {
    final painter=TextPainter(text:RichTextFormat.fromRuns(value,runs,
      TextStyle(fontSize:fontSize,height:1.25,fontWeight:FontWeight.w400)),
      textDirection:TextDirection.ltr,textScaler:TextScaler.noScaling);
    try {
      painter.layout(maxWidth:maxWidth==null?double.infinity:math.max(1.0,maxWidth));
      final lines=painter.computeLineMetrics();
      var visibleWidth=0.0;
      for(final line in lines) {
        visibleWidth=math.max(visibleWidth,line.left+line.width);
      }
      // Folga subpixel impede quebrar uma palavra quando o renderizador
      // mede novamente a mesma linha após armazenamento no JSON.
      var width=math.max(1.0,visibleWidth+1.5);
      final height=math.max(fontSize*1.25,painter.height);
      if(maxWidth!=null) {
        final limit=math.max(1.0,maxWidth);
        width=math.min(width,limit);
        // A caixa justa não pode introduzir uma quebra nova ao salvar.
        if(width<limit) {
          painter.layout(maxWidth:width);
          final resized=painter.computeLineMetrics();
          if(resized.length!=lines.length || (painter.height-height).abs()>1 ||
            List.generate(lines.length,(i)=>i).any((i)=>
              (resized[i].width-lines[i].width).abs()>1))width=limit;
        }
      }
      return Size(width,height);
    } finally {painter.dispose();}
  }
}
