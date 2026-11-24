import 'dart:math' as math;
import '../models/sketch.dart';

/// Reduz pontos redundantes sem alterar formato .ci.json ou coordenadas.
/// A otimização manual conserva as extremidades, mudanças de pressão e cantos.
class StrokeOptimizer {
  static bool shouldSample(InkPoint previous, InkPoint next,
      {required double zoom, bool fastMode = true}) {
    if (!next.x.isFinite || !next.y.isFinite || !zoom.isFinite || zoom <= 0) {
      return false;
    }
    final dx=(next.x-previous.x)*zoom,dy=(next.y-previous.y)*zoom;
    final threshold=fastMode?1.1:.4;
    final pressureChange=(next.p-previous.p).abs();
    // Comparar distância ao quadrado dispensa sqrt em cada evento de caneta.
    return dx*dx+dy*dy >= threshold*threshold || pressureChange >= .12;
  }

  static bool canSimplify(String tool) => const {
    'pen','fixed','hard pencil','soft pencil','marker','wire',
    'dynamic','fountain','watercolor','airbrush','dotted'
  }.contains(tool);

  static double _distanceSquared(InkPoint p,InkPoint a,InkPoint b,
      {double pressureWeight=12}) {
    final dx=b.x-a.x,dy=b.y-a.y;
    final denom=dx*dx+dy*dy;
    final t=denom<=1e-12?0.0:
      (((p.x-a.x)*dx+(p.y-a.y)*dy)/denom).clamp(0.0,1.0).toDouble();
    final ex=p.x-(a.x+dx*t),ey=p.y-(a.y+dy*t);
    final dp=(p.p-(a.p+(b.p-a.p)*t))*pressureWeight;
    return ex*ex+ey*ey+dp*dp;
  }

  /// Ramer-Douglas-Peucker iterativo, sem recursão; protege variações de pressão.
  /// O modo manual é conservador e nunca elimina primeiro/último ponto.
  static List<InkPoint> simplify(List<InkPoint> points,{double tolerance=.6}) {
    if(points.length<3 || !tolerance.isFinite || tolerance<=0)return List.of(points);
    // Divide traços gigantes para que a otimização nunca opere sobre
    // segmentos de centenas de milhares de pontos de uma só vez.
    if(points.length>4096) {
      final result=<InkPoint>[];
      for(var start=0;start<points.length-1;start+=4095) {
        final end=math.min(points.length,start+4096);
        final chunk=simplify(points.sublist(start,end),tolerance:tolerance);
        result.addAll(result.isEmpty?chunk:chunk.skip(1));
      }
      return result;
    }
    final keep=List<bool>.filled(points.length,false);
    keep[0]=true;keep[points.length-1]=true;
    final stack=<(int,int)>[(0,points.length-1)];
    final limit=tolerance*tolerance;
    while(stack.isNotEmpty) {
      final (start,end)=stack.removeLast();
      if(end-start<2)continue;
      var maxDistance=-1.0,index=-1;
      final a=points[start],b=points[end];
      for(var i=start+1;i<end;i++) {
        final d=_distanceSquared(points[i],a,b);
        if(d>maxDistance){maxDistance=d;index=i;}
      }
      if(maxDistance>limit && index>start && index<end) {
        keep[index]=true;
        stack.add((start,index));stack.add((index,end));
      }
    }
    return [for(var i=0;i<points.length;i++)if(keep[i]) points[i]];
  }
}
