import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/services/smart_guides.dart';

void main() {
  test('Alinha borda direita a outra borda com distância de 5 px', () {
    final m=SmartGuides.translate(const Rect.fromLTWH(0,0,40,40),
      const Offset(55,0),[const Rect.fromLTWH(100,80,30,30)],zoom:1);
    expect(m.delta.dx,60);
    expect(m.vertical,100);
    expect(m.horizontal,isNull);
  });
  test('Alinha centro horizontal de elementos de larguras diferentes', () {
    final m=SmartGuides.translate(const Rect.fromLTWH(0,0,20,20),
      const Offset(55,0),[const Rect.fromLTWH(45,200,50,20)],zoom:1);
    expect(m.delta.dx,60);
    expect(m.vertical,70);
  });
  test('Não encaixa quando longe e não modifica o movimento', () {
    final m=SmartGuides.translate(const Rect.fromLTWH(0,0,20,20),
      const Offset(10,12),[const Rect.fromLTWH(300,320,20,20)],zoom:1);
    expect(m.delta,const Offset(10,12));
    expect(m.hasGuides,false);
  });
  test('Limiar de encaixe é ajustado ao zoom', () {
    final original=const Rect.fromLTWH(0,0,20,20);
    final other=[const Rect.fromLTWH(30,300,10,10)];
    final zoom1=SmartGuides.translate(original,const Offset(3,0),other,zoom:1);
    final zoom4=SmartGuides.translate(original,const Offset(3,0),other,zoom:4);
    expect(zoom1.vertical,30);
    expect(zoom4.vertical,isNull);
  });
}
