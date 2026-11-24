import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/selection_transform.dart';

/// Interface limpa sobreposta ao quadro. Os controles permanecem com tamanho
/// fixo em pixels mesmo quando o desenho está ampliado ou afastado.
class SelectionHandlesPainter extends CustomPainter {
  final Rect bounds;
  final Offset pan;
  final double zoom;
  final double rotation;
  final bool dark;
  final SelectionHandle? activeHandle;

  const SelectionHandlesPainter({required this.bounds, required this.pan,
      required this.zoom, required this.rotation, required this.dark,
      this.activeHandle});

  @override
  void paint(Canvas canvas, Size size) {
    final handles = SelectionTransform.handlePositions(bounds,
        pan: pan, zoom: zoom, viewRotation: rotation);
    const accent = Color(0xff819cf8);
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke;
    final corners = <Offset>[
      handles[SelectionHandle.northWest]!,
      handles[SelectionHandle.northEast]!,
      handles[SelectionHandle.southEast]!,
      handles[SelectionHandle.southWest]!,
    ];
    final path = Path()..moveTo(corners.first.dx, corners.first.dy);
    for (final corner in corners.skip(1)) {
      path.lineTo(corner.dx, corner.dy);
    }
    path.close();
    canvas.drawPath(path, linePaint);
    canvas.drawLine(handles[SelectionHandle.north]!,
        handles[SelectionHandle.rotate]!, linePaint);
    const drawOrder = <SelectionHandle>[
      SelectionHandle.northWest, SelectionHandle.north,
      SelectionHandle.northEast, SelectionHandle.east,
      SelectionHandle.southEast, SelectionHandle.south,
      SelectionHandle.southWest, SelectionHandle.west,
    ];
    for (final item in drawOrder) {
      final p = handles[item]!;
      final active = item == activeHandle;
      canvas.drawCircle(p, active ? 7.7 : 6.2,
          Paint()..color = dark ? const Color(0xff222d47) : Colors.white);
      canvas.drawCircle(p, active ? 7.7 : 6.2, Paint()
        ..color = accent
        ..strokeWidth = active ? 2.8 : 2.0
        ..style = PaintingStyle.stroke);
    }
    // Ícone discreto de rotação, exterior à seleção.
    final center = handles[SelectionHandle.rotate]!;
    canvas.drawCircle(center, 12.5, Paint()
      ..color = dark ? const Color(0xff202a45) : Colors.white);
    canvas.drawCircle(center, 12.5, Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);
    final arc = Rect.fromCircle(center: center, radius: 6);
    canvas.drawArc(arc, -.65 * math.pi, 1.5 * math.pi, false,
        Paint()..color = accent..style = PaintingStyle.stroke
          ..strokeWidth = 1.8..strokeCap = StrokeCap.round);
    final arrow = Path()
      ..moveTo(center.dx + 6.6, center.dy - 4.2)
      ..lineTo(center.dx + 7.2, center.dy + 0.1)
      ..lineTo(center.dx + 3.3, center.dy - 1.6);
    canvas.drawPath(arrow, Paint()..color = accent
        ..style = PaintingStyle.stroke..strokeWidth = 1.6);
    // Marca sutil no centro indica que a seleção pode ser arrastada.
    final mid = handles[SelectionHandle.move]!;
    canvas.drawCircle(mid, 3, Paint()..color = accent.withValues(alpha: .85));
  }

  @override
  bool shouldRepaint(covariant SelectionHandlesPainter old) => true;
}
