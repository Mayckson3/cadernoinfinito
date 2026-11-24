import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';

void main() {
  test('salvar e abrir preserva camadas, vetores, pastas e título', () {
    final doc = Sketch(title:'Cartografia',folder:'Concurso/Geografia');
    doc.elements.add(InkElement(layerId:doc.layers.first.id,
      points:[InkPoint(12,34,.7),InkPoint(44,55,1.1)],tool:'pen'));
    final loaded = Sketch.fromJson(jsonDecode(doc.serialize()) as Map<String,dynamic>);
    expect(loaded.title,'Cartografia');
    expect(loaded.folder,'Concurso/Geografia');
    expect(loaded.elements.single.points.last.p,1.1);
    expect(loaded.elements.single.layerId,loaded.layers.first.id);
  });
  test('excluir é reversível e camadas podem estar bloqueadas', () {
    final doc=Sketch();
    doc.deleted=true;doc.layers.first.locked=true;
    final loaded=Sketch.fromJson(jsonDecode(doc.serialize()) as Map<String,dynamic>);
    expect(loaded.deleted,true);
    expect(loaded.layers.first.locked,true);
  });
}
