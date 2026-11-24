import 'dart:math' as math;
import 'dart:ui';
import '../models/sketch.dart';
import 'mind_map_vectors.dart';

/// Geometria em coordenadas do documento. Não depende de pixels de tela nem
/// do nível de zoom: seleção e recorte mantêm precisão em ampliações diferentes.
class PrecisionGeometry {
  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final v = b - a;
    final length2 = v.dx * v.dx + v.dy * v.dy;
    if (length2 < 1e-12) return (p - a).distance;
    final t = (((p.dx - a.dx) * v.dx + (p.dy - a.dy) * v.dy) /
            length2).clamp(0.0, 1.0);
    return (p - (a + v * t)).distance;
  }

  static bool pointInPolygon(Offset p, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i], b = polygon[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) /
              (b.dy - a.dy) + a.dx) inside = !inside;
    }
    return inside;
  }

  static double _orientation(Offset a, Offset b, Offset c) =>
      (b.dx - a.dx) * (c.dy - a.dy) -
      (b.dy - a.dy) * (c.dx - a.dx);

  static bool _onSegment(Offset a, Offset b, Offset p) =>
      p.dx >= math.min(a.dx, b.dx) - 1e-8 &&
      p.dx <= math.max(a.dx, b.dx) + 1e-8 &&
      p.dy >= math.min(a.dy, b.dy) - 1e-8 &&
      p.dy <= math.max(a.dy, b.dy) + 1e-8;

  static bool segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
    final o1 = _orientation(a, b, c), o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a), o4 = _orientation(c, d, b);
    if ((o1 > 0 && o2 < 0 || o1 < 0 && o2 > 0) &&
        (o3 > 0 && o4 < 0 || o3 < 0 && o4 > 0)) return true;
    return (o1.abs() < 1e-8 && _onSegment(a, b, c)) ||
        (o2.abs() < 1e-8 && _onSegment(a, b, d)) ||
        (o3.abs() < 1e-8 && _onSegment(c, d, a)) ||
        (o4.abs() < 1e-8 && _onSegment(c, d, b));
  }

  static bool strokeNear(Offset point, InkElement element, double tolerance) {
    if (!element.bounds.inflate(tolerance).contains(point)) return false;
    if(MindMapVectors.newTools.contains(element.tool) && element.points.length>=2) {
      final sampled=MindMapVectors.sample(element);
      for(var i=1;i<sampled.length;i++) {
        if(distanceToSegment(point,sampled[i-1],sampled[i])<=tolerance)return true;
      }
      return sampled.length==1 && (point-sampled.first).distance<=tolerance;
    }
    final pts = element.points;
    if (pts.isEmpty) return false;
    if (pts.length == 1) return (point - pts.first.offset).distance <= tolerance;
    for (var i = 1; i < pts.length; i++) {
      if (distanceToSegment(point, pts[i-1].offset, pts[i].offset) <= tolerance) {
        return true;
      }
    }
    return false;
  }

  static bool polygonTouchesElement(List<Offset> polygon, InkElement element) {
    if (polygon.length < 3) return false;
    final e = element;
    if (e.type != 'stroke' || e.points.isEmpty) {
      final r = e.bounds;
      final corners = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
      if (corners.any((p) => pointInPolygon(p, polygon)) ||
          polygon.any(r.contains)) return true;
      for (var i = 0; i < 4; i++) {
        if (_pathIntersects(polygon, corners[i], corners[(i+1)%4])) return true;
      }
      return false;
    }
    if(MindMapVectors.newTools.contains(e.tool) && e.points.length>=2) {
      final points=MindMapVectors.sample(e);
      if(points.any((p)=>pointInPolygon(p,polygon)))return true;
      for(var i=1;i<points.length;i++) {
        if(_pathIntersects(polygon,points[i-1],points[i]))return true;
      }
      return false;
    }
    if (e.points.any((p) => pointInPolygon(p.offset, polygon))) return true;
    for (var i = 1; i < e.points.length; i++) {
      if (_pathIntersects(polygon, e.points[i-1].offset, e.points[i].offset)) {
        return true;
      }
    }
    return false;
  }

  static bool _pathIntersects(List<Offset> polygon, Offset a, Offset b) {
    for (var j = 0; j < polygon.length; j++) {
      if (segmentsIntersect(a, b, polygon[j], polygon[(j+1)%polygon.length])) {
        return true;
      }
    }
    return false;
  }

  static double distanceToPolyline(Offset at, List<InkPoint> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) return (at - polyline.first.offset).distance;
    var closest = double.infinity;
    for (var i = 1; i < polyline.length; i++) {
      closest = math.min(closest, distanceToSegment(
          at, polyline[i-1].offset, polyline[i].offset));
    }
    return closest;
  }

  static InkPoint _interpolate(InkPoint a, InkPoint b, double t) => InkPoint(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.p + (b.p - a.p) * t,
    a.tilt + (b.tilt - a.tilt) * t,
    a.angle + (b.angle - a.angle) * t,
  );

  /// Divide um traço onde a faixa da borracha atravessa sua geometria.
  /// Amostra segmentos longos para não deixar escapar cortes entre vértices.
  /// Retorna o traço original sem mutações quando não houve cruzamento.
  static List<InkElement> sliceStroke(
      InkElement stroke, List<InkPoint> eraser, double radius) {
    if (stroke.type != 'stroke' || stroke.points.isEmpty || eraser.isEmpty) {
      return [stroke];
    }
    if(MindMapVectors.newTools.contains(stroke.tool) && stroke.points.length>=2) {
      // Não cortar uma Bézier em pontos de controle sem significado.
      final points=MindMapVectors.sample(stroke);
      if(points.any((p)=>distanceToPolyline(p,eraser)<=radius+stroke.size/2))return [];
      return [stroke];
    }
    if (stroke.points.length == 1) {
      return distanceToPolyline(stroke.points.first.offset, eraser) <= radius
          ? [] : [stroke];
    }
    final chunks = <List<InkPoint>>[];
    var current = <InkPoint>[];
    var removed = false;
    final first = stroke.points.first;
    var previousInside = distanceToPolyline(first.offset, eraser) <= radius;
    if (!previousInside) current.add(_interpolate(first, first, 0));
    else removed = true;

    for (var i = 1; i < stroke.points.length; i++) {
      final a = stroke.points[i-1], b = stroke.points[i];
      final length = (b.offset - a.offset).distance;
      final count = (length / math.max(radius * 0.33, 0.8)).ceil().clamp(1, 1024);
      var previousT = 0.0;
      for (var step = 1; step <= count; step++) {
        final t = step / count;
        final next = _interpolate(a, b, t);
        final inside = distanceToPolyline(next.offset, eraser) <= radius;
        if (inside != previousInside) {
          var lo = previousT, hi = t;
          for (var iteration = 0; iteration < 9; iteration++) {
            final mid = (lo + hi) / 2;
            final middleInside = distanceToPolyline(
                _interpolate(a,b,mid).offset, eraser) <= radius;
            if (middleInside == previousInside) lo = mid;
            else hi = mid;
          }
          final boundary = _interpolate(a, b, (lo+hi)/2);
          if (!previousInside) {
            current.add(boundary);
            if (current.length >= 2) chunks.add(current);
            current = <InkPoint>[];
          } else {
            current = [boundary];
          }
        }
        if (inside) removed = true;
        else current.add(next);
        previousInside = inside;
        previousT = t;
      }
    }
    if (current.length >= 2) chunks.add(current);
    if (!removed) return [stroke];
    return chunks.map((pts) => InkElement.fromJson(stroke.toJson())
      ..id = newId()
      ..group = null
      ..points = pts).toList();
  }
}
