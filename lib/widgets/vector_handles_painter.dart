import 'package:flutter/material.dart';

/// As alças têm tamanho constante na tela; o Listener do editor recebe o
/// gesto e converte o movimento para coordenadas do quadro.
class VectorHandlesPainter extends CustomPainter {
  final Map<int,Offset> controls,ports;
  final bool dark;
  const VectorHandlesPainter({required this.controls,required this.ports,required this.dark});
  @override
  void paint(Canvas c,Size size) {
    const blue=Color(0xff3b82f6),orange=Color(0xffea8c32);
    final background=dark?const Color(0xff263246):Colors.white;
    final guide=Paint()..color=orange.withValues(alpha:.8)..strokeWidth=1.3;
    if(controls.length==4) {
      c.drawLine(controls[0]!,controls[1]!,guide);
      c.drawLine(controls[3]!,controls[2]!,guide);
    }
    for(final entry in controls.entries) {
      final control=controls.length==4 && (entry.key==1||entry.key==2);
      final p=entry.value;
      final paint=Paint()..color=(control?orange:blue)..style=PaintingStyle.stroke..strokeWidth=2;
      if(control) {
        final r=Rect.fromCenter(center:p,width:13,height:13);
        c.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(3)),Paint()..color=background);
        c.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(3)),paint);
      } else {
        c.drawCircle(p,8,Paint()..color=background);c.drawCircle(p,8,paint);
      }
    }
    for(final p in ports.values) {
      c.drawCircle(p,10,Paint()..color=blue);
      final plus=Paint()..color=Colors.white..strokeWidth=2..strokeCap=StrokeCap.round;
      c.drawLine(p-const Offset(4,0),p+const Offset(4,0),plus);
      c.drawLine(p-const Offset(0,4),p+const Offset(0,4),plus);
    }
  }
  @override
  bool shouldRepaint(covariant VectorHandlesPainter oldDelegate)=>true;
}
