import 'dart:math' as math;
import 'dart:ui';
import '../models/sketch.dart';

/// Geometria vetorial de mapas mentais. Os quatro pontos de uma curva são
/// âncoras e controles cúbicos (não são amostras de um traço à mão livre).
class MindMapVectors {
  static const nodeTools = {'rectangle','ellipse','triangle','diamond',
    'rounded rectangle','cloud','balloon','capsule','hexagon'};
  static const newNodes = {'rounded rectangle','cloud','balloon','capsule','hexagon'};
  static const connectorTools = {'connector','elbow connector','straight connector'};
  static const curveTools = {'vector curve','connector'};
  static const lineTools = {'line','arrow','dashed line','vector curve',
    'connector','elbow connector','straight connector'};
  static const newTools = {...newNodes,...connectorTools,'dashed line','vector curve'};
  static bool isNode(InkElement e) => e.type=='stroke' && nodeTools.contains(e.tool) && e.points.length>=2;
  static bool isCurve(InkElement e) => e.type=='stroke' && curveTools.contains(e.tool) && e.points.length==4;
  static bool isConnector(InkElement e) => e.type=='stroke' && connectorTools.contains(e.tool) && e.points.length>=2;
  static bool isVector(InkElement e) => e.type=='stroke' && (nodeTools.contains(e.tool)||lineTools.contains(e.tool));
  static InkPoint point(Offset p)=>InkPoint(p.dx,p.dy);
  static Rect localBounds(InkElement e) => Rect.fromLTRB(
    e.points.map((p)=>p.x).reduce(math.min),e.points.map((p)=>p.y).reduce(math.min),
    e.points.map((p)=>p.x).reduce(math.max),e.points.map((p)=>p.y).reduce(math.max));

  static Path nodePath(String tool,Rect r) {
    final p=Path();
    final a=r.topLeft,b=r.bottomRight;
    if(tool=='ellipse') return p..addOval(r);
    if(tool=='rounded rectangle' || tool=='capsule') {
      final radius = math.min(r.width, r.height) *
          (tool == 'capsule' ? 0.5 : 0.16);
      return p..addRRect(RRect.fromRectAndRadius(r,Radius.circular(radius)));
    }
    if(tool=='diamond') return p..moveTo(r.center.dx,r.top)..lineTo(r.right,r.center.dy)
      ..lineTo(r.center.dx,r.bottom)..lineTo(r.left,r.center.dy)..close();
    if(tool=='triangle') return p..moveTo(r.center.dx,r.top)..lineTo(b.dx,b.dy)..lineTo(a.dx,b.dy)..close();
    double x(double v)=>r.left+r.width*v;
    double y(double v)=>r.top+r.height*v;
    void move(double u,double v)=>p.moveTo(x(u),y(v));
    void line(double u,double v)=>p.lineTo(x(u),y(v));
    void cubic(double a,double b,double c,double d,double e,double f)=>
      p.cubicTo(x(a),y(b),x(c),y(d),x(e),y(f));
    if(tool=='hexagon') {
      move(.16,0);line(.84,0);line(1,.5);line(.84,1);line(.16,1);line(0,.5);return p..close();
    }
    if(tool=='balloon') {
      move(.14,0);line(.86,0);cubic(.96,0,1,.07,1,.16);
      line(1,.66);cubic(1,.76,.96,.82,.86,.82);
      line(.44,.82);line(.22,1);line(.25,.82);line(.14,.82);
      cubic(.04,.82,0,.76,0,.66);line(0,.16);cubic(0,.07,.04,0,.14,0);return p..close();
    }
    if(tool=='cloud') {
      // Nuvem de lóbulos contínuos, editável, semelhante ao contorno do exemplo.
      move(.12,.19);cubic(.11,.02,.29,0,.36,.12);
      cubic(.43,0,.60,0,.66,.12);cubic(.76,.015,.90,.03,.91,.20);
      cubic(1,.20,1,.38,.94,.47);cubic(1,.54,1,.69,.94,.73);
      cubic(.99,.87,.85,1,.76,.88);cubic(.72,1,.58,1,.53,.91);
      cubic(.45,1,.32,1,.26,.90);cubic(.15,1,.03,.94,.07,.78);
      cubic(0,.72,0,.58,.055,.50);cubic(0,.40,0,.24,.12,.19);
      return p..close();
    }
    return p..addRect(r);
  }

  static List<InkPoint> initialPoints(String tool,Offset a,Offset b) {
    if(!curveTools.contains(tool))return [point(a),point(b)];
    final d=b-a;
    // Uma curva S com tangentes horizontais (ou verticais, conforme o eixo).
    final horizontal=d.dx.abs()>=d.dy.abs();
    final c1=horizontal?Offset(a.dx+d.dx*.52,a.dy):Offset(a.dx,a.dy+d.dy*.52);
    final c2=horizontal?Offset(b.dx-d.dx*.52,b.dy):Offset(b.dx,b.dy-d.dy*.52);
    // Para curvas avulsas inicialmente retas, dê uma curvatura visível.
    if(tool=='vector curve') {
      final normal=Offset(-d.dy,d.dx)*.25;
      return [point(a),point(a+d/3+normal),point(a+d*2/3+normal),point(b)];
    }
    return [point(a),point(c1),point(c2),point(b)];
  }

  static Path linePath(InkElement e) {
    final a=e.points.first.offset,b=e.points.last.offset;
    final p=Path()..moveTo(a.dx,a.dy);
    if(isCurve(e)) {
      final c=e.points[1],d=e.points[2];
      return p..cubicTo(c.x,c.y,d.x,d.y,b.dx,b.dy);
    }
    if(e.tool=='elbow connector') {
      if((b.dx-a.dx).abs()>=(b.dy-a.dy).abs()) {
        final mid=(a.dx+b.dx)/2;
        p.lineTo(mid,a.dy);p.lineTo(mid,b.dy);
      } else {
        final mid=(a.dy+b.dy)/2;
        p.lineTo(a.dx,mid);p.lineTo(b.dx,mid);
      }
    }
    return p..lineTo(b.dx,b.dy);
  }

  static String pattern(InkElement e) => e.meta['vectorPattern'] is String?
      e.meta['vectorPattern'] as String:(e.tool=='dashed line'?'dash':'solid');
  static String arrow(InkElement e) => e.meta['vectorArrow'] is String?
      e.meta['vectorArrow'] as String:(isConnector(e)||e.tool=='arrow'?'end':'none');
  static List<double> dashLengths(String style,double width) {
    final unit=math.max(1.0,width);
    if(style=='dot')return [unit*.15,unit*2.5];
    if(style=='dashdot')return [unit*4,unit*2,unit*.15,unit*2];
    if(style=='dash')return [unit*4,unit*2.4];
    return [];
  }
  static Path patterned(Path path,String style,double width) {
    if(style!='dash' && style!='dot' && style!='dashdot') return path;
    final lengths=dashLengths(style,width);
    final out=Path();
    for(final metric in path.computeMetrics()) {
      // Limita segmentos em mapas enormes com linhas muito finas.
      final scale=math.max(1.0,metric.length/(lengths.reduce((a,b)=>a+b)*5000));
      double pos=0;int i=0;
      while(pos<metric.length) {
        final end=math.min(metric.length,pos+lengths[i%lengths.length]*scale);
        if(i.isEven)out.addPath(metric.extractPath(pos,end),Offset.zero);
        pos=end;i++;
      }
    }
    return out;
  }

  static Offset _rotate(Offset p,double a)=>Offset(p.dx*math.cos(a)-p.dy*math.sin(a),
      p.dx*math.sin(a)+p.dy*math.cos(a));
  /// Interseção com o contorno real, inclusive formas arredondadas e giradas.
  static Offset anchor(InkElement node,Offset toward) {
    final r=localBounds(node),center=r.center;
    if(r.isEmpty)return center;
    var direction=_rotate(toward-center,-node.rotation);
    if(direction.distance<.001)direction=const Offset(1,0);
    direction=direction/direction.distance;
    final path=nodePath(node.tool,r);
    var lo=0.0,hi=r.longestSide*2;
    for(var i=0;i<25;i++) {
      final mid=(lo+hi)/2;
      if(path.contains(center+direction*mid))lo=mid;else hi=mid;
    }
    return center+_rotate(direction*((lo+hi)/2+node.size/2),node.rotation);
  }
  static InkElement? nodeAt(Sketch doc,Offset p,{double tolerance=10,String? exclude,String? layerId}) {
    for(final n in doc.elements.reversed) {
      if(n.id==exclude || !isNode(n) || doc.layerById(n.layerId)?.visible!=true ||
          (layerId!=null && n.layerId!=layerId))continue;
      if(n.bounds.inflate(tolerance).contains(p))return n;
    }
    return null;
  }
  static void endpoint(InkElement e,int index,Offset position) {
    final delta=position-e.points[index].offset;
    e.points[index]=point(position);
    if(isCurve(e) && (index==0 || index==3)) {
      final control=index==0?1:2;
      e.points[control]=point(e.points[control].offset+delta);
    }
  }
  static void refreshOne(InkElement e,Map<String,InkElement> nodes,{bool detachMissing=true}) {
    if(!isConnector(e))return;
    final source=nodes[e.meta['sourceNode']],target=nodes[e.meta['targetNode']];
    if(detachMissing) {
      if(source==null)e.meta.remove('sourceNode');
      if(target==null)e.meta.remove('targetNode');
    }
    final start=source==null?e.points.first.offset:
        anchor(source,target?.bounds.center??e.points.last.offset);
    final end=target==null?e.points.last.offset:
        anchor(target,source?.bounds.center??e.points.first.offset);
    if((e.points.first.offset-start).distance>.00001)endpoint(e,0,start);
    if((e.points.last.offset-end).distance>.00001)endpoint(e,e.points.length-1,end);
  }
  static void refresh(Sketch doc) {
    if(!doc.elements.any(isConnector))return;
    final nodes={for(final e in doc.elements.where(isNode))e.id:e};
    for(final e in doc.elements.where(isConnector)) {refreshOne(e,nodes);}
  }
  static void remapLinks(InkElement e,Map<String,String> ids) {
    for(final key in ['sourceNode','targetNode']) {
      final id=ids[e.meta[key]];
      if(id==null)e.meta.remove(key);else e.meta[key]=id;
    }
  }
  /// Modelo radial vazio, pronto para escrita livre ou texto digitado.
  static List<InkElement> radialTemplate(String layerId,Offset center,int color,double width) {
    InkElement node(String tool,Offset at,double w,double h) => InkElement(
      layerId:layerId,tool:tool,color:color,size:width,
      points:[point(at-Offset(w/2,h/2)),point(at+Offset(w/2,h/2))]);
    final middle=node('cloud',center,250,150);
    final branches=[for(final delta in const [Offset(-340,-150),Offset(340,-150),
      Offset(-340,150),Offset(340,150)])node('rounded rectangle',center+delta,205,110)];
    final edges=<InkElement>[];
    for(final branch in branches) {
      final a=anchor(middle,branch.bounds.center),b=anchor(branch,center);
      edges.add(InkElement(layerId:layerId,tool:'connector',color:color,size:width,
        points:initialPoints('connector',a,b),meta:{'sourceNode':middle.id,'targetNode':branch.id}));
    }
    return [...edges,...branches,middle];
  }
  static List<Offset> sample(InkElement e) {
    if(e.points.isEmpty)return [];
    final Path path;
    if(isNode(e)) {
      path=nodePath(e.tool,localBounds(e));
    } else {path=linePath(e);}
    final center=isNode(e)?localBounds(e).center:Offset.zero;
    final out=<Offset>[];
    for(final metric in path.computeMetrics()) {
      final n=(metric.length/3).ceil().clamp(1,1024).toInt();
      for(var i=0;i<=n;i++) {
        final p=metric.getTangentForOffset(metric.length*i/n)?.position;
        if(p!=null)out.add(isNode(e)?center+_rotate(p-center,e.rotation):p);
      }
    }
    return out.isEmpty?e.points.map((p)=>p.offset).toList():out;
  }
}
