import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/sketch.dart';

/// Minimapa de baixo custo: pontos e limites são calculados apenas quando
/// o caderno muda; arrastar a tela atualiza somente o retângulo visível.
class DocumentMiniMap extends StatefulWidget {
  final Sketch doc;
  final Rect visibleWorld;
  final void Function(Offset world) onJump;
  final String? onlyLayerId;
  final int revision;
  const DocumentMiniMap({super.key,required this.doc,required this.visibleWorld,
    required this.onJump,this.onlyLayerId,this.revision=0});
  @override State<DocumentMiniMap> createState()=>_DocumentMiniMapState();
}

class _MiniMark {
  final Rect bounds;
  final int color;
  final double width;
  final bool stroke;
  const _MiniMark(this.bounds,this.color,this.width,this.stroke);
}

class _DocumentMiniMapState extends State<DocumentMiniMap> {
  Sketch? _cachedDoc;
  int _cachedRevision=-1;
  String? _cachedLayer;
  Rect _contentBounds=Rect.zero;
  List<_MiniMark> _marks=const [];

  void _updateCacheIfNeeded() {
    if(identical(_cachedDoc,widget.doc) && _cachedRevision==widget.revision &&
       _cachedLayer==widget.onlyLayerId) return;
    _cachedDoc=widget.doc;
    _cachedRevision=widget.revision;
    _cachedLayer=widget.onlyLayerId;
    final visibleLayerIds={for(final l in widget.doc.layers.where((l)=>l.visible))l.id};
    final items=widget.doc.elements.where((e)=>
      visibleLayerIds.contains(e.layerId) &&
      (widget.onlyLayerId==null || e.layerId==widget.onlyLayerId)).toList();
    Rect? bounds;
    for(final e in items) {
      final itemBounds=e.bounds;
      if(itemBounds.isEmpty)continue;
      bounds=bounds==null?itemBounds:bounds.expandToInclude(itemBounds);
    }
    _contentBounds=bounds??Rect.fromLTWH(0,0,widget.doc.artboardW,widget.doc.artboardH);
    final stride=math.max(1,(items.length/1800).ceil());
    _marks=[for(var i=0;i<items.length;i+=stride)
      _MiniMark(items[i].bounds,items[i].color,items[i].size,items[i].type=='stroke')];
  }

  @override Widget build(BuildContext context) {
    _updateCacheIfNeeded();
    final domain=_contentBounds.expandToInclude(widget.visibleWorld).inflate(80);
    return ClipRRect(borderRadius:BorderRadius.circular(13),child:Material(
      color:Theme.of(context).colorScheme.surface.withValues(alpha:.96),elevation:3,
      child:LayoutBuilder(builder:(_,c)=>GestureDetector(
        behavior:HitTestBehavior.opaque,
        onTapDown:(event) {
          final width=c.maxWidth,height=c.maxHeight;
          final scale=math.min((width-16)/math.max(1,domain.width),
            (height-16)/math.max(1,domain.height));
          if(!scale.isFinite || scale<=0)return;
          final origin=Offset((width-domain.width*scale)/2,(height-domain.height*scale)/2);
          widget.onJump(domain.topLeft+(event.localPosition-origin)/scale);
        },
        child:CustomPaint(painter:_MiniMapPainter(_marks,domain,widget.visibleWorld)),
      ))));
  }
}

class _MiniMapPainter extends CustomPainter {
  final List<_MiniMark> marks;
  final Rect domain,visible;
  const _MiniMapPainter(this.marks,this.domain,this.visible);
  @override void paint(Canvas canvas, Size size) {
    final sc=math.min((size.width-16)/math.max(1,domain.width),
      (size.height-16)/math.max(1,domain.height));
    final origin=Offset((size.width-domain.width*sc)/2,(size.height-domain.height*sc)/2);
    Rect projected(Rect r)=>Rect.fromLTRB(
      origin.dx+(r.left-domain.left)*sc,origin.dy+(r.top-domain.top)*sc,
      origin.dx+(r.right-domain.left)*sc,origin.dy+(r.bottom-domain.top)*sc);
    canvas.drawRect(Offset.zero&size,Paint()..color=const Color(0xff1b2540).withValues(alpha:.1));
    for(final mark in marks) {
      if(mark.bounds.isEmpty)continue;
      final r=projected(mark.bounds);
      final paint=Paint()..color=Color(mark.color).withValues(alpha:.65)
        ..strokeWidth=math.max(1,sc*mark.width);
      if(r.width<2 && r.height<2) canvas.drawCircle(r.center,1.1,paint);
      else if(mark.stroke) canvas.drawLine(r.topLeft,r.bottomRight,paint);
      else canvas.drawRect(r,paint..style=PaintingStyle.stroke);
    }
    final view=projected(visible);
    canvas.drawRect(view,Paint()..color=const Color(0xff438bea).withValues(alpha:.13));
    canvas.drawRect(view,Paint()..color=const Color(0xff438bea)
      ..style=PaintingStyle.stroke..strokeWidth=1.6);
  }
  @override bool shouldRepaint(covariant _MiniMapPainter old)=>
    !identical(marks,old.marks) || domain!=old.domain || visible!=old.visible;
}
