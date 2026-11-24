import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/sketch.dart';
import 'board_painter.dart';

/// Prévia real, pequena e independente por camada, incluindo textos e bitmaps.
class LayerPreview extends StatelessWidget {
  final Sketch doc;
  final String layerId;
  final Map<String,ui.Image> images;
  const LayerPreview({super.key,required this.doc,required this.layerId,
    this.images=const {}});
  @override Widget build(BuildContext context) {
    return ClipRRect(borderRadius:BorderRadius.circular(5),
      child:CustomPaint(painter:_LayerPreviewPainter(doc,layerId,images),
        child:const SizedBox.expand()));
  }
}

class _LayerPreviewPainter extends CustomPainter {
  final Sketch doc;
  final String layerId;
  final Map<String,ui.Image> images;
  const _LayerPreviewPainter(this.doc,this.layerId,this.images);
  @override void paint(Canvas c,Size size) {
    c.drawRect(Offset.zero&size,Paint()..color=colorFromHex(doc.background));
    final items=doc.elements.where((e)=>e.layerId==layerId).toList();
    if(items.isEmpty)return;
    var area=items.first.bounds;
    for(final item in items.skip(1)){area=area.expandToInclude(item.bounds);}
    final scale=math.min((size.width-8)/math.max(1,area.width),
      (size.height-8)/math.max(1,area.height));
    c.save(); c.clipRect(Offset.zero&size);
    c.translate(size.width/2-area.center.dx*scale,
      size.height/2-area.center.dy*scale);
    c.scale(scale);
    for(final item in items){BoardRenderer.drawElement(c,item,images:images,zoom:scale,
      background:colorFromHex(doc.background),measureScale:doc.scale,unit:doc.unit);}
    c.restore();
  }
  @override bool shouldRepaint(covariant _LayerPreviewPainter old)=>true;
}
