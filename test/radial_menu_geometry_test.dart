import 'dart:ui' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/services/radial_menu_geometry.dart';
import 'package:caderno_infinito/widgets/stylus_radial_menu.dart';

void main() {
  test('Catálogo tem ícones únicos e dez ações padrão', () {
    final actions=radialQuickActions.map((a)=>a.key).toList();
    expect(actions.length,greaterThanOrEqualTo(10));
    expect(selectedRadialActions(null).length,RadialMenuGeometry.actionCount);
    expect(actions.toSet().length,actions.length);
    for(final name in ['pen','eraser','select','lasso','pan',
      'undo','redo','marker','colors','stroke']) {
      expect(actions,contains(name));
    }
  });
  test('Menu personalizado aceita ordem, filtra duplicados e itens inválidos', () {
    final selected=selectedRadialActions(['undo','pen','pen','text','eraser','unknown']);
    expect(selected.map((a)=>a.key).toList(),['undo','pen','text','eraser']);
    expect(selectedRadialActions(['pen']).length,10);
    expect(selectedRadialActions(['pen','eraser','undo','redo','lasso','pan','select',
      'text','line','rectangle','ellipse']).length,10);
  });
  test('Menu variável mantém a correspondência entre ícone e gesto', () {
    const center=Offset(150,150);
    for(final count in [4,6,8,10]) {
      for(var index=0;index<count;index++) {
        final position=RadialMenuGeometry.actionCenter(index,center,92,count:count);
        expect(RadialMenuGeometry.hit(position,center,92,count:count),index);
      }
    }
  });
  test('Abrir sem arrastar não escolhe ação; fora do círculo cancela', () {
    const center=Offset(150,150);
    expect(RadialMenuGeometry.hit(center,center,92),isNull);
    expect(RadialMenuGeometry.hit(const Offset(150,170),center,92),isNull);
    expect(RadialMenuGeometry.hit(const Offset(150,300),center,92),isNull);
  });
  test('Arrastar até um ícone aponta exatamente para esse ícone', () {
    const center=Offset(150,150);
    for(var i=0;i<RadialMenuGeometry.actionCount;i++) {
      final point=RadialMenuGeometry.actionCenter(i,center,92);
      expect(RadialMenuGeometry.hit(point,center,92),i);
    }
  });
  test('Centro mantém o menu dentro da tela mesmo em uma borda', () {
    const view=Size(360,640);
    final radius=RadialMenuGeometry.radiusFor(view);
    for(final anchor in [Offset.zero,const Offset(360,640),
      const Offset(180,320)]) {
      final center=RadialMenuGeometry.safeCenter(anchor,view,radius);
      expect(center.dx-radius-22,greaterThanOrEqualTo(0));
      expect(center.dy-radius-22,greaterThanOrEqualTo(0));
      expect(center.dx+radius+22,lessThanOrEqualTo(view.width));
      expect(center.dy+radius+22,lessThanOrEqualTo(view.height));
    }
  });
  test('Em modo paisagem usa um raio menor; sem dimensão usa padrão', () {
    final landscape=RadialMenuGeometry.radiusFor(const Size(500,200));
    expect(landscape,lessThan(92));
    expect(RadialMenuGeometry.radiusFor(Size.zero),88);
    final center=RadialMenuGeometry.safeCenter(const Offset(3,5),
        const Size(500,200),landscape);
    expect(center.dy,greaterThan(20));
  });
  test('Gestos curtos não interrompem a escrita; soltar no centro cancela', () {
    expect(RadialMenuGeometry.holdSlop,lessThan(RadialMenuGeometry.selectionSlop));
    expect(RadialMenuGeometry.holdDelay.inMilliseconds,inInclusiveRange(400,600));
  });
}
