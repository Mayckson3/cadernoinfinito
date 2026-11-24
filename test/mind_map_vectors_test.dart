import 'dart:math' as math;
import 'dart:ui' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/mind_map_vectors.dart';
import 'package:caderno_infinito/services/selection_transform.dart';
import 'package:caderno_infinito/services/advanced_tools.dart';
import 'package:caderno_infinito/services/precision_geometry.dart';
import 'package:caderno_infinito/services/import_export.dart';

void main() {
  InkElement node(String tool,double x,double y) => InkElement(layerId:'l',tool:tool,
      points:[InkPoint(x,y),InkPoint(x+100,y+60)],size:2);
  test('Nuvens, balões e caixas são caminhos fechados dentro de seus limites', () {
    for(final kind in MindMapVectors.newNodes) {
      final n=node(kind,10,20);
      final p=MindMapVectors.nodePath(kind,MindMapVectors.localBounds(n));
      expect(p.computeMetrics().single.isClosed,isTrue);
      expect(p.contains(n.bounds.center),isTrue);
      expect(p.getBounds().left,greaterThanOrEqualTo(9.99));
      expect(p.getBounds().right,lessThanOrEqualTo(110.01));
    }
  });
  test('Cápsula e caixa arredondada usam raios distintos', () {
    const rect = Rect.fromLTWH(0, 0, 100, 60);
    final capsule = MindMapVectors.nodePath('capsule', rect);
    final rounded = MindMapVectors.nodePath('rounded rectangle', rect);
    // O raio da cápsula é 30; o da caixa é 9.6.
    expect(capsule.contains(const Offset(5, 5)), isFalse);
    expect(rounded.contains(const Offset(5, 5)), isTrue);
    expect(capsule.contains(rect.center), isTrue);
    expect(rounded.contains(rect.center), isTrue);
  });
  test('Conector acompanha duas formas e preserva controle relativo', () {
    final a=node('cloud',0,0),b=node('rounded rectangle',300,80);
    final e=InkElement(layerId:'l',tool:'connector',points:MindMapVectors.initialPoints('connector',a.bounds.center,b.bounds.center),
      meta:{'sourceNode':a.id,'targetNode':b.id});
    final doc=Sketch(layers:[InkLayer(id:'l')],elements:[a,b,e]);
    MindMapVectors.refresh(doc);
    final relative=e.points[2].offset-e.points.last.offset;
    final before=e.points.last.offset;
    b.translate(45,90);MindMapVectors.refresh(doc);
    expect((e.points.last.offset-before).distance,greaterThan(30));
    expect((e.points[2].offset-e.points.last.offset-relative).distance,lessThan(.001));
    expect((e.points.last.offset-MindMapVectors.anchor(b,a.bounds.center)).distance,lessThan(.001));
    doc.elements.remove(a);MindMapVectors.refresh(doc);
    expect(e.meta.containsKey('sourceNode'),isFalse);
    expect(e.meta['targetNode'],b.id);
  });
  test('Curva tem quatro pontos, giro livre e seleção no caminho real', () {
    final e=InkElement(layerId:'l',tool:'vector curve',points:[InkPoint(0,0),InkPoint(0,100),InkPoint(100,100),InkPoint(100,0)]);
    expect(PrecisionGeometry.strokeNear(const Offset(50,75),e,2),isTrue);
    expect(PrecisionGeometry.strokeNear(const Offset(50,100),e,2),isFalse);
    final copy=SelectionTransform.rotate([e],Offset.zero,math.pi/2).single;
    expect(copy.points[1].x,closeTo(-100,.00001));
    expect(e.points[1].x,0);
    expect(copy.points.length,4);
  });
  test('Tracejado mantém lacunas e pode ser aplicado em caminho curvo', () {
    final e=InkElement(layerId:'l',tool:'vector curve',points:MindMapVectors.initialPoints('vector curve',Offset.zero,const Offset(200,0)),size:3);
    final path=MindMapVectors.linePath(e);
    final metrics=MindMapVectors.patterned(path,'dash',e.size).computeMetrics().toList();
    expect(metrics.length,greaterThan(3));
    expect(metrics.fold<double>(0,(n,m)=>n+m.length),lessThan(path.computeMetrics().single.length));
  });
  test('Copiar mapa remapeia vínculos; copiar somente conector desvincula', () {
    final objects=MindMapVectors.radialTemplate('l',Offset.zero,0xff123456,3);
    expect(objects.length,9);
    final copies=AdvancedTools.instantiateObject('l',objects.map((e)=>e.toJson()).toList(),const Offset(10,20));
    final ids=copies.map((e)=>e.id).toSet();
    for(final edge in copies.where(MindMapVectors.isConnector)) {
      expect(ids,contains(edge.meta['sourceNode']));
      expect(ids,contains(edge.meta['targetNode']));
      expect(edge.meta['sourceNode'],isNot(objects.last.id));
    }
    final only=AdvancedTools.instantiateObject('l',[objects.first.toJson()],Offset.zero).single;
    expect(only.meta.containsKey('sourceNode'),isFalse);
    expect(only.meta.containsKey('targetNode'),isFalse);
  });
  test('SVG contém curva cúbica, contorno tracejado e pontas de seta', () {
    final e=InkElement(layerId:'l',tool:'vector curve',points:MindMapVectors.initialPoints('vector curve',Offset.zero,const Offset(200,0)),
      meta:{'vectorPattern':'dash','vectorArrow':'both'});
    final doc=Sketch(layers:[InkLayer(id:'l')],elements:[e]);
    final svg=SketchExchange.exportSvg(doc);
    expect(svg,contains(' C '));
    expect(svg,contains('stroke-dasharray='));
    expect(svg,contains('<polyline'));
  });
}
