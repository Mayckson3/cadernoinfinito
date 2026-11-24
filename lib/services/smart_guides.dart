import 'dart:math' as math;
import 'dart:ui';

/// Encaixa centros e bordas contra outros elementos, em unidades do quadro.
/// O limiar é calculado em pixels, mantendo o comportamento com qualquer zoom.
class GuideMatch {
  final Offset delta;
  final double? vertical, horizontal;
  const GuideMatch(this.delta, {this.vertical, this.horizontal});
  bool get hasGuides => vertical != null || horizontal != null;
}

class SmartGuides {
  static GuideMatch translate(Rect moving, Offset proposed,
      Iterable<Rect> others, {required double zoom, double tolerancePx=9}) {
    final target=moving.shift(proposed);
    final margin=tolerancePx / math.max(0.12,zoom);
    double? bestX,bestY;
    double dx=0,dy=0;
    double minX=margin,minY=margin;
    final xPoints=[target.left,target.center.dx,target.right];
    final yPoints=[target.top,target.center.dy,target.bottom];
    for(final r in others) {
      if(r.isEmpty)continue;
      for(final from in xPoints) {
        for(final to in [r.left,r.center.dx,r.right]) {
          final distance=(to-from).abs();
          if(distance < minX) {minX=distance;dx=to-from;bestX=to;}
        }
      }
      for(final from in yPoints) {
        for(final to in [r.top,r.center.dy,r.bottom]) {
          final distance=(to-from).abs();
          if(distance < minY) {minY=distance;dy=to-from;bestY=to;}
        }
      }
    }
    return GuideMatch(proposed+Offset(dx,dy),vertical:bestX,horizontal:bestY);
  }
}
