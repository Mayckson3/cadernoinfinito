import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/services/stylus_shortcuts.dart';
import 'package:caderno_infinito/models/sketch.dart';

void main() {
  test('Preferências de escrita por caderno sobrevivem ao salvar e reabrir', () {
    final doc=Sketch();
    doc.gestures['fingerPanOnly']=true;
    doc.gestures['stylusQuickEraser']=false;
    doc.gestures['quickInkBar']=true;
    final read=doc.clone();
    expect(read.gestures['fingerPanOnly'],true);
    expect(read.gestures['stylusQuickEraser'],false);
    expect(read.gestures['quickInkBar'],true);
  });
  test('A ponta invertida usa borracha sem trocar a ferramenta escolhida', () {
    expect(StylusShortcuts.temporaryTool(PointerDeviceKind.invertedStylus, 1), 'eraser');
    expect(StylusShortcuts.temporaryTool(PointerDeviceKind.invertedStylus, 1,
      useEraser:false),isNull);
  });
  test('Botões físicos da caneta alternam borracha e laço temporários', () {
    expect(StylusShortcuts.temporaryTool(PointerDeviceKind.stylus,
      kPrimaryButton | kPrimaryStylusButton),'eraser');
    expect(StylusShortcuts.temporaryTool(PointerDeviceKind.stylus,
      kPrimaryButton | kSecondaryStylusButton),'lasso');
    expect(StylusShortcuts.temporaryTool(PointerDeviceKind.stylus,kPrimaryButton),isNull);
    expect(StylusShortcuts.temporaryTool(PointerDeviceKind.touch,
      kPrimaryButton | kPrimaryStylusButton),isNull);
  });
  test('Toque breve com dois dedos é reconhecido só ao fim do gesto', () {
    final clock=DateTime(2026,11,23);
    final g=MultiTouchQuickGestures();
    g.down(1,Offset.zero,at:clock);
    g.down(2,const Offset(60,0),at:clock);
    expect(g.up(1,Offset.zero,at:clock.add(const Duration(milliseconds:100))),isNull);
    expect(g.up(2,const Offset(60,0),at:clock.add(const Duration(milliseconds:140))),2);
  });
  test('Pinça de zoom não aciona atalhos de toque', () {
    final clock=DateTime(2026,11,23);
    final g=MultiTouchQuickGestures();
    g.down(1,Offset.zero,at:clock);
    g.down(2,const Offset(60,0),at:clock);
    g.move(2,const Offset(100,0));
    g.up(1,Offset.zero,at:clock.add(const Duration(milliseconds:100)));
    expect(g.up(2,const Offset(100,0),at:clock.add(const Duration(milliseconds:120))),isNull);
  });
  test('Três dedos e quatro dedos são reconhecidos sem movimento', () {
    final clock=DateTime(2026,11,23);
    for(final fingerCount in [3,4]) {
      final g=MultiTouchQuickGestures();
      for(var i=0;i<fingerCount;i++) {
        g.down(i,Offset(i*35.0,0),at:clock);
      }
      for(var i=0;i<fingerCount-1;i++) {
        expect(g.up(i,Offset(i*35.0,0),
          at:clock.add(const Duration(milliseconds:130))),isNull);
      }
      expect(g.up(fingerCount-1,Offset((fingerCount-1)*35.0,0),
        at:clock.add(const Duration(milliseconds:170))),fingerCount);
    }
  });
  test('Toque demorado/cancelado não altera histórico', () {
    final clock=DateTime(2026,11,23);
    final g=MultiTouchQuickGestures();
    g.down(1,Offset.zero,at:clock);
    g.down(2,const Offset(50,0),at:clock);
    g.up(1,Offset.zero,at:clock.add(const Duration(milliseconds:200)));
    expect(g.up(2,const Offset(50,0),at:clock.add(const Duration(seconds:2))),isNull);
    g.down(1,Offset.zero,at:clock);
    g.down(2,const Offset(50,0),at:clock);
    g.up(1,Offset.zero,at:clock.add(const Duration(milliseconds:100)),cancelled:true);
    expect(g.up(2,const Offset(50,0),at:clock.add(const Duration(milliseconds:110))),isNull);
  });
}
