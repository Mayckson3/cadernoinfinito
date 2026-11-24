import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Geometria de seleção para o menu radial da caneta.
/// Nenhum cálculo é executado durante a pintura do documento.
class RadialMenuGeometry {
  static const int actionCount = 10;
  static const double holdSlop = 9;
  static const double selectionSlop = 22;
  static const Duration holdDelay = Duration(milliseconds: 480);

  /// Menu inteiro dentro da área do quadro, inclusive perto das bordas.
  static double radiusFor(Size viewport) {
    if (viewport.isEmpty || !viewport.width.isFinite ||
        !viewport.height.isFinite) return 88;
    return math.min(92.0,
        math.max(32.0, (math.min(viewport.width, viewport.height) - 22) / 2 - 22));
  }

  static Offset safeCenter(Offset anchor, Size viewport, double radius) {
    if (viewport.isEmpty) return anchor;
    final margin = radius + 22;
    double position(double v, double extent) {
      if (extent <= margin * 2) return extent / 2;
      return v.clamp(margin, extent - margin).toDouble();
    }
    return Offset(position(anchor.dx, viewport.width),
        position(anchor.dy, viewport.height));
  }

  static Offset actionCenter(int index, Offset center, double radius,
      {int count = actionCount}) {
    final angle = -math.pi / 2 + 2 * math.pi * index / count;
    return center + Offset(math.cos(angle) * radius,
        math.sin(angle) * radius);
  }

  /// Apenas arrastar para fora do centro escolhe uma ferramenta; ficar parado
  /// ou soltar no centro sempre cancela. A seleção por setor é tolerante a
  /// pequenas imprecisões, inclusive com canetas de ponta grossa.
  static int? hit(Offset pointer, Offset center, double radius,
      {int count = actionCount}) {
    if (count <= 0 || radius <= 0) return null;
    final delta = pointer - center;
    final distance = delta.distance;
    if (distance < radius * .43 || distance > radius + 34) return null;
    final angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    final normalized = ((angle % (2 * math.pi)) + 2 * math.pi) % (2 * math.pi);
    return ((normalized / (2 * math.pi) * count).round()) % count;
  }
}
