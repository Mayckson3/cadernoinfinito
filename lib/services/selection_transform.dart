import 'dart:math' as math;
import 'dart:ui';

import '../models/sketch.dart';

/// Alças da caixa de transformação. As coordenadas do desenho permanecem
/// no espaço mundial, independentemente de zoom e rotação da câmera.
enum SelectionHandle {
  northWest, north, northEast,
  east, southEast, south, southWest, west,
  rotate, move,
}

class SelectionTransform {
  const SelectionTransform._();

  static Rect? selectedBounds(Iterable<InkElement> elements,
      {double minWidth = 10, double minHeight = 10}) {
    final iterator = elements.iterator;
    if (!iterator.moveNext()) return null;
    var result = iterator.current.bounds;
    while (iterator.moveNext()) {
      result = result.expandToInclude(iterator.current.bounds);
    }
    final width = math.max(minWidth, result.width);
    final height = math.max(minHeight, result.height);
    return Rect.fromCenter(center: result.center, width: width, height: height);
  }

  static Offset toScreen(Offset world, Offset pan, double zoom, double viewRotation) {
    final x = world.dx * zoom, y = world.dy * zoom;
    final c = math.cos(viewRotation), s = math.sin(viewRotation);
    return pan + Offset(x * c - y * s, x * s + y * c);
  }

  static Offset toWorld(Offset screen, Offset pan, double zoom, double viewRotation) {
    final translated = screen - pan;
    final c = math.cos(viewRotation), s = math.sin(viewRotation);
    return Offset((translated.dx * c + translated.dy * s) / zoom,
        (-translated.dx * s + translated.dy * c) / zoom);
  }

  static Map<SelectionHandle, Offset> handlePositions(Rect bounds,
      {required Offset pan, required double zoom, required double viewRotation}) {
    final world = <SelectionHandle, Offset>{
      SelectionHandle.northWest: bounds.topLeft,
      SelectionHandle.north: bounds.topCenter,
      SelectionHandle.northEast: bounds.topRight,
      SelectionHandle.east: bounds.centerRight,
      SelectionHandle.southEast: bounds.bottomRight,
      SelectionHandle.south: bounds.bottomCenter,
      SelectionHandle.southWest: bounds.bottomLeft,
      SelectionHandle.west: bounds.centerLeft,
      SelectionHandle.move: bounds.center,
    };
    final screen = <SelectionHandle, Offset>{
      for (final entry in world.entries)
        entry.key: toScreen(entry.value, pan, zoom, viewRotation),
    };
    final top = screen[SelectionHandle.north]!;
    final center = screen[SelectionHandle.move]!;
    final vector = top - center;
    final unit = vector.distance > .0001
        ? vector / vector.distance
        : Offset(-math.sin(viewRotation), -math.cos(viewRotation));
    screen[SelectionHandle.rotate] = top + unit * 34;
    return screen;
  }

  /// Prioriza a alça de rotação e os cantos. Retorna [move] quando o toque
  /// está dentro do quadrilátero da seleção (mesmo com o quadro girado).
  static SelectionHandle? hitTest(Offset position, Rect bounds,
      {required Offset pan, required double zoom, required double viewRotation,
      double radius = 15}) {
    final positions = handlePositions(bounds,
        pan: pan, zoom: zoom, viewRotation: viewRotation);
    const priority = <SelectionHandle>[
      SelectionHandle.rotate,
      SelectionHandle.northWest, SelectionHandle.northEast,
      SelectionHandle.southEast, SelectionHandle.southWest,
      SelectionHandle.north, SelectionHandle.east,
      SelectionHandle.south, SelectionHandle.west,
    ];
    for (final handle in priority) {
      if ((positions[handle]! - position).distance <= radius) return handle;
    }
    final world = toWorld(position, pan, zoom, viewRotation);
    return bounds.contains(world) ? SelectionHandle.move : null;
  }

  static Offset handleWorldPosition(SelectionHandle handle, Rect bounds) {
    switch (handle) {
      case SelectionHandle.northWest: return bounds.topLeft;
      case SelectionHandle.north: return bounds.topCenter;
      case SelectionHandle.northEast: return bounds.topRight;
      case SelectionHandle.east: return bounds.centerRight;
      case SelectionHandle.southEast: return bounds.bottomRight;
      case SelectionHandle.south: return bounds.bottomCenter;
      case SelectionHandle.southWest: return bounds.bottomLeft;
      case SelectionHandle.west: return bounds.centerLeft;
      case SelectionHandle.rotate: return bounds.topCenter;
      case SelectionHandle.move: return bounds.center;
    }
  }

  static Rect resizedBounds(Rect original, SelectionHandle handle, Offset pointer,
      {double minDimension = 4}) {
    var left = original.left, top = original.top;
    var right = original.right, bottom = original.bottom;
    switch (handle) {
      case SelectionHandle.northWest:
      case SelectionHandle.west:
      case SelectionHandle.southWest:
        left = math.min(pointer.dx, right - minDimension);
        break;
      case SelectionHandle.northEast:
      case SelectionHandle.east:
      case SelectionHandle.southEast:
        right = math.max(pointer.dx, left + minDimension);
        break;
      default: break;
    }
    switch (handle) {
      case SelectionHandle.northWest:
      case SelectionHandle.north:
      case SelectionHandle.northEast:
        top = math.min(pointer.dy, bottom - minDimension);
        break;
      case SelectionHandle.southWest:
      case SelectionHandle.south:
      case SelectionHandle.southEast:
        bottom = math.max(pointer.dy, top + minDimension);
        break;
      default: break;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Shift + arraste: mantém a proporção original ao redimensionar.
  static Rect keepAspect(Rect original, Rect target, SelectionHandle handle) {
    if(original.width<=0 || original.height<=0)return target;
    final sx=target.width/original.width;
    final sy=target.height/original.height;
    final isSide=const [SelectionHandle.east,SelectionHandle.west,
      SelectionHandle.north,SelectionHandle.south].contains(handle);
    final horizontal=const [SelectionHandle.east,SelectionHandle.west].contains(handle);
    final scale=isSide ? (horizontal?sx:sy) :
      ((sx-1).abs()>=(sy-1).abs()?sx:sy);
    final width=original.width*scale;
    final height=original.height*scale;
    if(isSide) {
      if(horizontal) {
        final left=handle==SelectionHandle.west?original.right-width:original.left;
        return Rect.fromLTWH(left,original.center.dy-height/2,width,height);
      }
      final top=handle==SelectionHandle.north?original.bottom-height:original.top;
      return Rect.fromLTWH(original.center.dx-width/2,top,width,height);
    }
    final left=const [SelectionHandle.northWest,SelectionHandle.southWest]
      .contains(handle)?original.right-width:original.left;
    final top=const [SelectionHandle.northWest,SelectionHandle.northEast]
      .contains(handle)?original.bottom-height:original.top;
    return Rect.fromLTWH(left,top,width,height);
  }

  /// Redimensiona sem modificar os objetos originais, prevenindo acúmulo de
  /// arredondamentos durante o arrasto. Mantém IDs, camadas e agrupamentos.
  static List<InkElement> resize(List<InkElement> originals, Rect initial,
      Rect target, {double maxScale = 40}) {
    final sx = (target.width / math.max(1e-6, initial.width)).clamp(.02, maxScale).toDouble();
    final sy = (target.height / math.max(1e-6, initial.height)).clamp(.02, maxScale).toDouble();
    final sizeFactor = math.sqrt(sx * sy);
    return originals.map((original) {
      final copy = InkElement.fromJson(original.toJson());
      copy.x = target.left + (original.x - initial.left) * sx;
      copy.y = target.top + (original.y - initial.top) * sy;
      copy.w = original.w * sx;
      copy.h = original.h * sy;
      copy.size = (original.size * sizeFactor).clamp(.2, 500).toDouble();
      for (var i = 0; i < copy.points.length; i++) {
        copy.points[i].x = target.left + (original.points[i].x - initial.left) * sx;
        copy.points[i].y = target.top + (original.points[i].y - initial.top) * sy;
      }
      return copy;
    }).toList();
  }

  static List<InkElement> translate(List<InkElement> originals, Offset delta) =>
      originals.map((e) => InkElement.fromJson(e.toJson())
        ..translate(delta.dx, delta.dy)).toList();

  static Offset _rotated(Offset v, double radians) {
    final c = math.cos(radians), s = math.sin(radians);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  static List<InkElement> rotate(List<InkElement> originals,
      Offset pivot, double radians) {
    return originals.map((original) {
      final copy = InkElement.fromJson(original.toJson());
      if (original.type == 'stroke' &&
          const ['rectangle','ellipse','triangle','diamond','rounded rectangle','cloud','balloon','capsule','hexagon'].contains(original.tool)) {
        // Estas formas são descritas por 2 cantos. Girar os 2 pontos
        // transformaria uma figura inclinada novamente numa caixa reta.
        // Portanto giramos o centro e guardamos a orientação separada.
        // Os dois pontos mantêm os limites locais; testes de grupo devem
        // conferir o centro visual/ângulo, não a inversão dos pontos internos.
        if (original.points.isNotEmpty) {
          final minX=original.points.map((p)=>p.x).reduce(math.min);
          final maxX=original.points.map((p)=>p.x).reduce(math.max);
          final minY=original.points.map((p)=>p.y).reduce(math.min);
          final maxY=original.points.map((p)=>p.y).reduce(math.max);
          final center=Offset((minX+maxX)/2,(minY+maxY)/2);
          final newCenter=pivot+_rotated(center-pivot,radians);
          final delta=newCenter-center;
          for (final p in copy.points) {p.x+=delta.dx;p.y+=delta.dy;}
        }
        copy.rotation = original.rotation + radians;
      } else if (original.type == 'stroke') {
        for (var i = 0; i < copy.points.length; i++) {
          final next = pivot + _rotated(original.points[i].offset - pivot, radians);
          copy.points[i].x = next.dx;
          copy.points[i].y = next.dy;
        }
      } else {
        final previousCenter = Offset(original.x + original.w / 2,
            original.y + original.h / 2);
        final newCenter = pivot + _rotated(previousCenter - pivot, radians);
        copy.x = newCenter.dx - original.w / 2;
        copy.y = newCenter.dy - original.h / 2;
        copy.rotation = original.rotation + radians;
      }
      return copy;
    }).toList();
  }

  static double angleBetween(Offset start, Offset current, Offset pivot) {
    final a = start - pivot;
    final b = current - pivot;
    if (a.distance < .0001 || b.distance < .0001) return 0;
    final first = math.atan2(a.dy, a.dx);
    final second = math.atan2(b.dy, b.dx);
    return math.atan2(math.sin(second - first), math.cos(second - first));
  }
}
