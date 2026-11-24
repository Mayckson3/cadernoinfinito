import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/selection_transform.dart';

void main() {
  test('Compasso tem limites de círculo completo, não só os dois pontos', () {
    final e=InkElement(layerId:'a',tool:'compass',size:2,
      points:[InkPoint(50,50),InkPoint(80,50)]);
    expect(e.bounds,Rect.fromLTRB(19,19,81,81));
  });
  test('Bloqueio de proporções no canto preserva razão 2:1', () {
    const initial=Rect.fromLTWH(10,20,100,50);
    const pointer=Rect.fromLTWH(10,20,200,120);
    final result=SelectionTransform.keepAspect(initial,pointer,SelectionHandle.southEast);
    expect(result.left,10);
    expect(result.top,20);
    expect(result.width/result.height,closeTo(2,1e-8));
  });
  test('Bloqueio pela alça lateral mantém altura proporcional e o centro', () {
    const initial=Rect.fromLTWH(10,20,100,50);
    const pointer=Rect.fromLTWH(10,20,150,50);
    final result=SelectionTransform.keepAspect(initial,pointer,SelectionHandle.east);
    expect(result.width,150);
    expect(result.height,75);
    expect(result.center.dy,45);
  });
}
