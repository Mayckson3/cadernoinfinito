import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Guias visuais são sobrepostas ao quadro em coordenadas da tela.
class SmartGuidesPainter extends CustomPainter {
  final Offset pan;
  final double zoom, rotation;
  final double? vertical, horizontal;
  const SmartGuidesPainter({required this.pan,required this.zoom,required this.rotation,
    this.vertical,this.horizontal});
  @override void paint(Canvas canvas, Size size) {
    if(vertical==null && horizontal==null)return;
    final line=Paint()..color=const Color(0xff00a9ad).withValues(alpha:.82)
      ..strokeWidth=1.6;
    Offset screen(Offset world) {
      final co=math.cos(rotation),si=math.sin(rotation);
      return pan+Offset(world.dx*co-world.dy*si,world.dx*si+world.dy*co)*zoom;
    }
    if(vertical!=null) {
      final a=screen(Offset(vertical!,-100000));
      final b=screen(Offset(vertical!,100000));
      canvas.drawLine(a,b,line);
    }
    if(horizontal!=null) {
      final a=screen(Offset(-100000,horizontal!));
      final b=screen(Offset(100000,horizontal!));
      canvas.drawLine(a,b,line);
    }
  }
  @override bool shouldRepaint(covariant SmartGuidesPainter old) =>
    old.vertical!=vertical ||old.horizontal!=horizontal ||old.pan!=pan ||
    old.zoom!=zoom ||old.rotation!=rotation;
}
