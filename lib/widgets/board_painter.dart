import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/sketch.dart';
import '../services/advanced_tools.dart';
import '../services/rich_text.dart';
import '../services/mind_map_vectors.dart';

Color colorFromHex(String s) {
  try { return Color(int.parse(s.replaceFirst('#',''), radix:16) | 0xff000000); }
  catch (_) { return Colors.white; }
}

/// Reutiliza o layout de textos já medidos ao mover a página.
/// Limite de entradas evita crescimento contínuo de memória.
class _TextLayoutCache {
  static final LinkedHashMap<(String,double,int,double,double,String),TextPainter>
      _items=LinkedHashMap();

  static TextPainter layout(InkElement e,Color color) {
    final maxWidth=math.max(1.0,e.w>0?e.w:1200.0);
    final runs=e.meta['richRuns'];
    final key=(e.text,e.size,e.color,e.opacity,maxWidth,runs==null?'':jsonEncode(runs));
    final cached=_items.remove(key);
    if(cached!=null) {
      _items[key]=cached;
      return cached;
    }
    final painter=TextPainter(text:RichTextFormat.fromRuns(e.text,runs,TextStyle(
      fontSize:e.size,color:color,height:1.25,fontWeight:FontWeight.w400)),
      textDirection:TextDirection.ltr,textScaler:TextScaler.noScaling);
    painter.layout(maxWidth:maxWidth);
    if(_items.length>=96) {
      final oldest=_items.keys.first;
      _items.remove(oldest)?.dispose();
    }
    _items[key]=painter;
    return painter;
  }
}

/// Caixa e caminho dos objetos estão estáveis enquanto o número de edição
/// permanece o mesmo. Panning/zoom não exigem varrer todos os pontos outra vez.
class _BoardGeometryCache {
  Sketch? _document;
  int _revision=-1;
  final Map<InkElement,Rect> _bounds=HashMap.identity();
  final LinkedHashMap<InkElement,Path> _paths=LinkedHashMap.identity();

  void begin(Sketch document,int revision) {
    if(identical(_document,document) && _revision==revision)return;
    _document=document;_revision=revision;
    _bounds.clear();_paths.clear();
  }

  Rect bounds(InkElement element) {
    final cached=_bounds[element];
    if(cached!=null)return cached;
    final result=element.bounds;
    if(_bounds.length<30000)_bounds[element]=result;
    return result;
  }

  Path path(InkElement element,Path Function() build) {
    final cached=_paths.remove(element);
    if(cached!=null) {
      _paths[element]=cached;
      return cached;
    }
    final result=build();
    if(_paths.length>=650)_paths.remove(_paths.keys.first);
    _paths[element]=result;
    return result;
  }
}

class BoardRenderer {
  static final _geometry=_BoardGeometryCache();
  static void paint(Canvas canvas, Sketch doc, Rect visible,
      {Map<String,ui.Image> images = const {}, bool grids = true,
       double zoom = 1, Set<String> selected = const {}, InkElement? inProgress,
       bool transparentBackground = false, String? onlyLayerId,
       int? cacheRevision,String? hiddenElementId}) {
    if(cacheRevision!=null)_geometry.begin(doc,cacheRevision);
    final background = colorFromHex(doc.background);
    if (!transparentBackground) canvas.drawRect(visible, Paint()..color = background);
    if (grids && !transparentBackground) _drawGrid(canvas, doc, visible, zoom);
    // Agrupa uma vez por camada. A versão anterior percorria TODOS os objetos
    // para cada camada, mesmo que estivessem fora da área visível.
    final visibleLayers={for(final l in doc.layers.where(
      (l)=>l.visible && (onlyLayerId==null || l.id==onlyLayerId)))l.id:l};
    final byLayer=<String,List<InkElement>>{};
    for(final item in doc.elements) {
      if(item.id==hiddenElementId || !visibleLayers.containsKey(item.layerId) ||
        !(cacheRevision==null?item.bounds:_geometry.bounds(item)).overlaps(visible))continue;
      (byLayer[item.layerId]??=<InkElement>[]).add(item);
    }
    for (final layer in doc.layers) {
      if (!layer.visible || (onlyLayerId!=null && layer.id!=onlyLayerId)) continue;
      // Evita uma superfície offscreen cara quando a camada é 100% opaca.
      if(layer.opacity>=.999) canvas.save();
      else canvas.saveLayer(visible, Paint()..color = Color.fromRGBO(
        255, 255, 255, layer.opacity.clamp(0,1).toDouble()));
      for (final item in byLayer[layer.id]??const <InkElement>[]) {
        drawElement(canvas, item, images: images, zoom: zoom,
          background: background, measureScale: doc.scale,unit:doc.unit,
          cachePath:cacheRevision!=null);
        if (selected.contains(item.id)) _selectionBox(canvas,
          cacheRevision==null?item.bounds:_geometry.bounds(item), zoom);
      }
      if (inProgress != null && inProgress.layerId == layer.id) {
        drawElement(canvas, inProgress, images: images, zoom: zoom,
          background: background, measureScale: doc.scale,unit:doc.unit);
      }
      canvas.restore();
    }
  }

  static void _selectionBox(Canvas c, Rect r, double zoom) {
    c.drawRect(r.inflate(4 / zoom), Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoom);
  }

  static void _drawGrid(Canvas c, Sketch d, Rect r, double zoom) {
    if (d.grid == 'nenhum') return;
    // Nas escalas distantes, uma grade de pontos pode desenhar centenas de
    // milhares de círculos a cada quadro. Exiba um nível da grade a cada
    // múltiplo de dois, com no mínimo ~8 pixels entre marcas.
    var step = d.gridSpacing.clamp(12.0, 200.0).toDouble();
    final minScreenDistance=d.grid=='pontilhado'?9.0:7.0;
    while(step*zoom < minScreenDistance && step<100000) {step*=2;}
    final ink = colorFromHex(d.background).computeLuminance() < .5
        ? Colors.white.withValues(alpha: .14) : const Color(0xffa2b5cb).withValues(alpha: .40);
    final paint = Paint()..color = ink..strokeWidth = 1 / zoom.clamp(.15,10);
    final left = (r.left / step).floor() * step;
    final top = (r.top / step).floor() * step;
    final horizontal = d.grid == 'pautado' || d.grid == 'quadriculado';
    final vertical = d.grid == 'quadriculado';
    if (horizontal || vertical || d.grid == 'pontilhado') {
      for (double y = top; y <= r.bottom && y < top + step * 600; y += step) {
        if (horizontal) c.drawLine(Offset(r.left,y), Offset(r.right,y),paint);
        for (double x = left; x <= r.right && x < left + step * 600; x += step) {
          if (d.grid == 'pontilhado') c.drawCircle(Offset(x,y), 1.3 / zoom, paint);
        }
      }
      if (vertical) {
        for (double x = left; x <= r.right && x < left + step * 600; x += step) {
          c.drawLine(Offset(x,r.top),Offset(x,r.bottom),paint);
        }
      }
      return;
    }
    if (d.grid == 'isometrico' || d.grid == 'triangular') {
      for (double y = top; y <= r.bottom + step && y < top + step * 250; y += step) {
        c.drawLine(Offset(r.left,y), Offset(r.right,y), paint);
      }
      final height = r.height;
      for (double x = r.left - height * 1.8; x < r.right + height * 1.8; x += step * 1.7) {
        c.drawLine(Offset(x,r.bottom),Offset(x + height * .58,r.top),paint);
        c.drawLine(Offset(x,r.bottom),Offset(x - height * .58,r.top),paint);
      }
      return;
    }
    if (d.grid.startsWith('perspectiva')) {
      final h=d.artboardH/2,mid=d.artboardW/2;
      final origins=d.grid=='perspectiva1'?[Offset(mid,h)]:
        d.grid=='perspectiva2'?[Offset(0,h),Offset(d.artboardW,h)]:
        [Offset(0,h),Offset(d.artboardW,h),Offset(mid,-d.artboardH*.6)];
      c.drawLine(Offset(r.left,h),Offset(r.right,h),paint);
      for(final origin in origins){
        for(var i=-25;i<=25;i++){
          final destination=Offset(r.left+i*step,r.bottom+i*step*.35);
          c.drawLine(origin,destination,paint);
          c.drawLine(origin,Offset(r.right+i*step,r.top-i*step*.35),paint);
        }
      }
    }
  }

  static Path _smoothPath(InkElement element) {
    final pts=element.points;
    final a=pts.first.offset,b=pts.last.offset;
    final path=Path()..moveTo(a.dx,a.dy);
    if(pts.length==2)path.lineTo(b.dx,b.dy);
    else {
      for(var i=1;i<pts.length-1;i++) {
        final p=pts[i].offset,q=pts[i+1].offset;
        path.quadraticBezierTo(p.dx,p.dy,(p.dx+q.dx)/2,(p.dy+q.dy)/2);
      }
      path.lineTo(b.dx,b.dy);
    }
    return path;
  }

  /// Usa os mesmos pontos médios do caminho de tinta comum, mas permite
  /// largura variável. Cada trecho começa exatamente onde o anterior termina.
  static void _smoothVariableInk(Canvas canvas, InkElement element, Paint pen,
      double Function(int index) widthAt) {
    final points=element.points;
    final path=Path();
    var start=points.first.offset;
    for(var i=0;i<points.length;i++) {
      final point=points[i].offset;
      final end=i==points.length-1 ? point : (point+points[i+1].offset)/2;
      path.reset();
      path.moveTo(start.dx,start.dy);
      if(i==0 || i==points.length-1) {
        path.lineTo(end.dx,end.dy);
      } else {
        path.quadraticBezierTo(point.dx,point.dy,end.dx,end.dy);
      }
      pen.strokeWidth=widthAt(i);
      canvas.drawPath(path,pen);
      start=end;
    }
  }

  /// Contorno contínuo com largura interpolada, desenhado em uma única
  /// operação (sem sobreposição de alfa nos encontros entre segmentos).
  /// Os pequenos discos e trapézios têm a mesma orientação de preenchimento.
  static Path polishedVariablePath(InkElement element,
      double Function(int index) widthAt) {
    final points=element.points;
    final outline=Path()..fillType=PathFillType.nonZero;
    if(points.isEmpty)return outline;
    final raw=[for(var i=0;i<points.length;i++) widthAt(i)];
    final radii=[for(var i=0;i<points.length;i++) (() {
      var sum=0.0,weight=0.0;
      for(var j=math.max(0,i-2);j<=math.min(points.length-1,i+2);j++) {
        final w=(3-(i-j).abs()).toDouble();
        sum+=raw[j]*w;weight+=w;
      }
      return math.max(.05,sum/(2*weight));
    })()];
    var previous=points.first.offset, previousRadius=radii.first;
    outline.addOval(Rect.fromCircle(center:previous,radius:previousRadius));
    void append(Offset at,double radius) {
      final delta=at-previous;
      final length=delta.distance;
      if(length>1e-9) {
        final normal=Offset(-delta.dy/length,delta.dx/length);
        final a=previous-normal*previousRadius,b=at-normal*radius;
        final c=at+normal*radius,d=previous+normal*previousRadius;
        outline.moveTo(a.dx,a.dy);outline.lineTo(b.dx,b.dy);
        outline.lineTo(c.dx,c.dy);outline.lineTo(d.dx,d.dy);outline.close();
      }
      outline.addOval(Rect.fromCircle(center:at,radius:radius));
      previous=at;previousRadius=radius;
    }
    for(var i=0;i<points.length;i++) {
      final start=previous, startRadius=previousRadius;
      final control=points[i].offset;
      final last=i==points.length-1;
      final end=last?control:(control+points[i+1].offset)/2;
      final endRadius=last?radii[i]:(radii[i]+radii[i+1])/2;
      final length=(control-start).distance+(end-control).distance;
      // Subdivisão limitada e adaptada à espessura, inclusive em traços longos.
      final count=(length/math.max(.4,math.min(startRadius,endRadius)*.6))
          .ceil().clamp(1,20).toInt();
      for(var j=1;j<=count;j++) {
        final t=j/count, u=1-t;
        final at=start*(u*u)+control*(2*u*t)+end*(t*t);
        final radius=startRadius*u*u+radii[i]*2*u*t+endRadius*t*t;
        append(at,radius);
      }
    }
    return outline;
  }

  static void _drawPolishedInk(Canvas c, InkElement e, Paint pen,
      double Function(int) widthAt,bool cachePath) {
    final path=cachePath?_geometry.path(e,()=>polishedVariablePath(e,widthAt)):
      polishedVariablePath(e,widthAt);
    c.drawPath(path,pen..style=PaintingStyle.fill);
  }

  static void drawElement(Canvas c, InkElement e,
      {Map<String,ui.Image> images = const {}, double zoom = 1,
        Color background = Colors.white, double measureScale = 1,
        String unit='mm',bool cachePath=false}) {
    final color = Color(e.color).withValues(alpha: e.opacity.clamp(0, 1).toDouble());
    if (e.type == 'image') {
      final image = images[e.id];
      if (image != null) {
        c.save();
        final center = Offset(e.x + e.w/2, e.y + e.h/2);
        c.translate(center.dx,center.dy); c.rotate(e.rotation);
        if(e.skewX!=0 || e.skewY!=0) c.transform(Float64List.fromList([1,e.skewY,0,0,e.skewX,1,0,0,0,0,1,0,0,0,0,1]));
        c.translate(-center.dx,-center.dy);
        c.drawImageRect(image, Rect.fromLTWH(0,0,image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(e.x,e.y,e.w,e.h), Paint()..filterQuality =
            (zoom<.8 ? FilterQuality.low : FilterQuality.medium)
          ..color = Colors.white.withValues(alpha: e.opacity.clamp(0,1).toDouble()));
        c.restore();
      } else {
        c.drawRect(Rect.fromLTWH(e.x,e.y,e.w,e.h), Paint()..color = Colors.grey.shade300);
      }
      return;
    }
    if (e.type == 'text') {
      final painter = _TextLayoutCache.layout(e,color);
      c.save();
      final center=e.bounds.center; c.translate(center.dx,center.dy);
      c.rotate(e.rotation);
      if(e.skewX!=0 || e.skewY!=0) c.transform(Float64List.fromList([1,e.skewY,0,0,e.skewX,1,0,0,0,0,1,0,0,0,0,1]));
      c.translate(-center.dx,-center.dy);
      painter.paint(c, Offset(e.x,e.y)); c.restore();
      return;
    }
    if (e.points.isEmpty) return;
    final rotatedShape=e.rotation != 0 &&
      const ['rectangle','ellipse','triangle','diamond','rounded rectangle','cloud','balloon','capsule','hexagon'].contains(e.tool);
    if(rotatedShape) {
      final minX=e.points.map((p)=>p.x).reduce(math.min);
      final maxX=e.points.map((p)=>p.x).reduce(math.max);
      final minY=e.points.map((p)=>p.y).reduce(math.min);
      final maxY=e.points.map((p)=>p.y).reduce(math.max);
      final pivot=Offset((minX+maxX)/2,(minY+maxY)/2);
      c.save();c.translate(pivot.dx,pivot.dy);c.rotate(e.rotation);
      c.translate(-pivot.dx,-pivot.dy);
    }
    final skewed = e.skewX != 0 || e.skewY != 0;
    if (skewed) {
      final center=e.bounds.center;
      c.save(); c.translate(center.dx,center.dy);
      c.transform(Float64List.fromList([1,e.skewY,0,0,e.skewX,1,0,0,0,0,1,0,0,0,0,1]));
      c.translate(-center.dx,-center.dy);
    }
    try {
    final pen = Paint()..color = color..strokeWidth = e.size
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (e.tool == 'wire') pen.strokeWidth = e.size / zoom.clamp(.15,10);
    if (e.tool == 'marker') pen.color = color.withValues(alpha: (e.opacity * .35).clamp(0,1).toDouble());
    if (e.tool == 'watercolor') pen.color = color.withValues(alpha: (e.opacity * .45).clamp(0,1).toDouble());
    if (e.tool == 'soft pencil') pen.color = color.withValues(alpha: (e.opacity * .6).clamp(0,1).toDouble());
    if (e.tool == 'airbrush' || e.tool == 'soft mask') {
      pen.maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, e.size * .9);
      pen.strokeWidth = e.size * 3;
      pen.color = e.tool == 'soft mask' ? Colors.black.withValues(alpha:e.opacity.clamp(0,1).toDouble()) : color.withValues(alpha: (e.opacity * .23).clamp(0,1).toDouble());
    }
    if (e.tool == 'mask' || e.tool == 'soft mask') {
      pen.color = Colors.black.withValues(alpha:e.opacity.clamp(0,1).toDouble());
      pen.blendMode = BlendMode.dstOut;
    }
    if (e.tool == 'mask' || e.tool == 'eraser') pen.strokeWidth = e.size * 3;
    final a = e.points.first.offset;
    final b = e.points.last.offset;
    if (MindMapVectors.newTools.contains(e.tool) ||
        (MindMapVectors.isVector(e) && e.meta.keys.any((key)=>key.startsWith('vector')))) {
      final isNode=MindMapVectors.isNode(e);
      if(e.points.length<2)return;
      final path=isNode?MindMapVectors.nodePath(e.tool,MindMapVectors.localBounds(e)):
        MindMapVectors.linePath(e);
      final fill=e.meta['vectorFill'];
      if(isNode && fill is num && fill>0) {
        c.drawPath(path,Paint()..color=color.withValues(alpha:(color.a*fill).clamp(0.0,1.0).toDouble()));
      }
      Path outline()=>MindMapVectors.patterned(path,MindMapVectors.pattern(e),e.size);
      c.drawPath(cachePath?_geometry.path(e,outline):outline(),pen);
      if(!isNode) {
        final style=MindMapVectors.arrow(e);
        for(final metric in path.computeMetrics()) {
          void head(double at,bool reverse) {
            final t=metric.getTangentForOffset(at);
            if(t==null)return;
            final angle=math.atan2(t.vector.dy,t.vector.dx)+(reverse?math.pi:0);
            final len=math.min(metric.length*.4,math.max(9.0,e.size*4));
            final pos=t.position;
            c.drawPath(Path()..moveTo(pos.dx-len*math.cos(angle-.55),pos.dy-len*math.sin(angle-.55))
              ..lineTo(pos.dx,pos.dy)..lineTo(pos.dx-len*math.cos(angle+.55),pos.dy-len*math.sin(angle+.55)),pen);
          }
          if(style=='start'||style=='both')head(0,true);
          if(style=='end'||style=='both')head(metric.length,false);
        }
      }
      return;
    }
    if (e.tool == 'line' || e.tool == 'measure' || e.tool == 'angle') {
      c.drawLine(a,b,pen);
      if (e.tool == 'measure' || e.tool == 'angle') {
        final dist = (b-a).distance;
        final info=e.tool=='measure'?'${(dist*measureScale).toStringAsFixed(1)} $unit':
          '${((math.atan2(b.dy-a.dy,b.dx-a.dx)*180/math.pi+360)%360).toStringAsFixed(1)}°';
        final painter = TextPainter(text:TextSpan(text:info,
            style:TextStyle(fontSize:12/zoom.clamp(.5,5), color: color)),textDirection:TextDirection.ltr);
        painter.layout(); painter.paint(c, Offset((a.dx+b.dx)/2,(a.dy+b.dy)/2-20/zoom)); painter.dispose();
      }
      return;
    }
    if(e.tool=='compass' && e.points.length>=2) {
      c.drawCircle(a,(b-a).distance,pen);
      return;
    }
    if(e.tool=='bezier' && e.points.length>=4) {
      final start=e.points.first.offset;
      final control1=e.points[(e.points.length/3).floor()].offset;
      final control2=e.points[(2*e.points.length/3).floor()].offset;
      c.drawPath(Path()..moveTo(start.dx,start.dy)
        ..cubicTo(control1.dx,control1.dy,control2.dx,control2.dy,b.dx,b.dy),pen);
      return;
    }
    if (e.tool == 'rectangle' || e.tool == 'ellipse' || e.tool == 'triangle' || e.tool == 'diamond') {
      final r = Rect.fromPoints(a,b);
      if (e.tool == 'rectangle') c.drawRect(r,pen);
      if (e.tool == 'ellipse') c.drawOval(r,pen);
      if (e.tool == 'diamond') {
        c.drawPath(Path()..moveTo(r.center.dx,r.top)..lineTo(r.right,r.center.dy)
          ..lineTo(r.center.dx,r.bottom)..lineTo(r.left,r.center.dy)..close(),pen);
      }
      if (e.tool == 'triangle') {
        if(e.points.length>=3) {
          final shape=Path()..moveTo(e.points[0].x,e.points[0].y);
          for(final p in e.points.skip(1).take(2)){shape.lineTo(p.x,p.y);}
          c.drawPath(shape..close(),pen);
        } else {
          c.drawPath(Path()..moveTo((a.dx+b.dx)/2,a.dy)..lineTo(b.dx,b.dy)
            ..lineTo(a.dx,b.dy)..close(),pen);
        }
      }
      return;
    }
    if (e.tool == 'arrow') {
      c.drawLine(a,b,pen);
      final angle = math.atan2(b.dy-a.dy,b.dx-a.dx);
      final len = math.min(22.0,e.size*5+7);
      c.drawLine(b, Offset(b.dx-len*math.cos(angle-.53),b.dy-len*math.sin(angle-.53)),pen);
      c.drawLine(b, Offset(b.dx-len*math.cos(angle+.53),b.dy-len*math.sin(angle+.53)),pen);
      return;
    }
    if (e.tool == 'fill' || e.tool == 'area') {
      final path = Path()..moveTo(a.dx,a.dy);
      for (final p in e.points.skip(1)) { path.lineTo(p.x,p.y); }
      path.close();
      c.drawPath(path, Paint()..color=color.withValues(alpha:e.tool == 'area' ? 0.10 : color.a)..style=PaintingStyle.fill);
      if(e.tool=='area') {
        c.drawPath(path,pen);
        final value=AdvancedTools.area(e.points)*measureScale*measureScale;
        final painter=TextPainter(text:TextSpan(text:'${value.toStringAsFixed(1)} $unit²',
          style:TextStyle(color:color,fontSize:12/zoom.clamp(.5,5))),textDirection:TextDirection.ltr);
        painter.layout();painter.paint(c,e.bounds.center);painter.dispose();
      }
      return;
    }
    if (e.points.length == 1) {
      // Uma batida de caneta (pingo de i, ponto final) precisa aparecer
      // mesmo com pressão ou pincel dinâmico, sem depender de segmentos.
      var width=pen.strokeWidth;
      final point=e.points.first;
      if(e.tool=='pen' && e.meta['pressureInk']==true && (point.p-1).abs()>.04) {
        width=e.size*(.32+.76*point.p.clamp(.1,1.5).toDouble());
      } else if(e.tool=='dynamic') {
        width=e.size*(.45+point.p*1.35)*(1+point.tilt*.25);
      } else if(e.tool=='fountain') {
        width=e.size*1.5;
      }
      pen.style=PaintingStyle.fill;
      c.drawCircle(a,math.max(.75,width/2),pen);
      return;
    }
    if (e.tool == 'dotted') {
      final interval = math.max(3.0,e.size*2.5);
      for (int i=1;i<e.points.length;i++) {
        final p=e.points[i-1].offset, q=e.points[i].offset;
        final len=(q-p).distance;
        if (len == 0) continue;
        for (double t=0;t<len;t+=interval) { c.drawCircle(Offset.lerp(p,q,t/len)!,e.size*.53,pen..style=PaintingStyle.fill); }
      }
      return;
    }
    if (e.tool == 'pen' && e.meta['pressureInk']==true &&
        e.points.any((point)=>(point.p-1).abs()>.04)) {
      if(e.meta['polishedInk']==true && e.points.length>=2) {
        _drawPolishedInk(c,e,pen,(i)=>e.size*(.32+.76*e.points[i].p.clamp(.1,1.5).toDouble()),cachePath);
        return;
      }
      if(e.meta['stabilizedInk']==true && e.points.length>=3) {
        _smoothVariableInk(c,e,pen,(i)=>e.size*(.32+.76*e.points[i].p.clamp(.1,1.5).toDouble()));
        return;
      }
      for(var i=1;i<e.points.length;i++) {
        final start=e.points[i-1],end=e.points[i];
        final pressure=((start.p+end.p)/2).clamp(.1,1.5).toDouble();
        pen.strokeWidth=e.size*(.32+.76*pressure);
        c.drawLine(start.offset,end.offset,pen);
      }
      return;
    }
    if (e.tool == 'dynamic' || e.tool == 'fountain') {
      if(e.meta['stabilizedInk']==true && e.points.length>=2) {
        double widthAt(int i){
          final p=e.points[i];
          if(e.tool=='dynamic') return e.size*(.45+p.p*1.35)*(1+p.tilt*.25);
          final previous=e.points[math.max(0,i-1)].offset;
          final next=e.points[math.min(e.points.length-1,i+1)].offset;
          final count=(i==0 || i==e.points.length-1)?1:2;
          final distance=((p.offset-previous).distance+(next-p.offset).distance)/count;
          return e.size*(1.5/(1+distance*.04)).clamp(.45,1.8).toDouble();
        }
        if(e.meta['polishedInk']==true) {
          _drawPolishedInk(c,e,pen,widthAt,cachePath);
        } else {
          _smoothVariableInk(c,e,pen,widthAt);
        }
        return;
      }
      for(int i=1;i<e.points.length;i++) {
        final p=e.points[i-1],q=e.points[i];
        final dist=(q.offset-p.offset).distance;
        final dynamicWidth = (.45+q.p*1.35)*(1+q.tilt*.25);
        final fountainWidth = (1.5/(1+dist*.04)).clamp(.45,1.8);
        pen.strokeWidth=e.size*(e.tool=='fountain'?fountainWidth:dynamicWidth);
        c.drawLine(p.offset,q.offset,pen);
      }
      return;
    }
    final path=cachePath?_geometry.path(e,()=>_smoothPath(e)):_smoothPath(e);
    c.drawPath(path,pen);
    } finally {
      // Antes, um retorno antecipado deixava a transformação de um traço
      // inclinado aplicada aos objetos seguintes, deslocando o desenho.
      if(skewed) c.restore();
      if(rotatedShape) c.restore();
    }
  }
}

class BoardPainter extends CustomPainter {
  final Sketch doc;
  final Offset pan;
  final double zoom;
  final double rotation;
  final InkElement? pending;
  final Set<String> selected;
  final Map<String,ui.Image> images;
  final String? onlyLayerId,hiddenElementId;
  final int revision,strokeFrame,imageFrame;
  const BoardPainter({required this.doc, required this.pan, required this.zoom,
    this.rotation = 0, this.pending, this.selected = const {}, this.images = const {},
    this.onlyLayerId, this.hiddenElementId, this.revision=0, this.strokeFrame=0, this.imageFrame=0});
  @override
  void paint(Canvas canvas, Size size) {
    Offset inverse(Offset p) {
      final v=p-pan, co=math.cos(rotation), si=math.sin(rotation);
      return Offset((v.dx*co+v.dy*si)/zoom,(-v.dx*si+v.dy*co)/zoom);
    }
    final corners=[inverse(Offset.zero),inverse(Offset(size.width,0)),
      inverse(Offset(0,size.height)),inverse(Offset(size.width,size.height))];
    final minX=corners.map((e)=>e.dx).reduce(math.min);
    final maxX=corners.map((e)=>e.dx).reduce(math.max);
    final minY=corners.map((e)=>e.dy).reduce(math.min);
    final maxY=corners.map((e)=>e.dy).reduce(math.max);
    final world = Rect.fromLTRB(minX,minY,maxX,maxY);
    canvas.save(); canvas.translate(pan.dx,pan.dy); canvas.rotate(rotation);canvas.scale(zoom);
    BoardRenderer.paint(canvas,doc,world.inflate(10/zoom),
      zoom: zoom, selected:selected,images:images,inProgress:pending,
      onlyLayerId:onlyLayerId,cacheRevision:revision,hiddenElementId:hiddenElementId);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant BoardPainter old) =>
      !identical(doc,old.doc) || revision!=old.revision ||
      strokeFrame!=old.strokeFrame || imageFrame!=old.imageFrame ||
      !identical(pending,old.pending) || !identical(images,old.images) ||
      !identical(selected,old.selected) || onlyLayerId!=old.onlyLayerId || hiddenElementId!=old.hiddenElementId ||
      pan!=old.pan || zoom!=old.zoom || rotation!=old.rotation;
}
