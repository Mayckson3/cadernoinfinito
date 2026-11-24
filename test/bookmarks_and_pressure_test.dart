import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';

void main() {
  test('Índice com marcador sobrevive exportação JSON e mantém os dados anteriores', () {
    final doc=Sketch(title:'Meu quadro',bookmarks:[
      {'id':'marco1','label':'Resumo 1','x':125.5,'y':-30.25,'zoom':1.7}
    ]);
    final imported=Sketch.fromJson(doc.toJson());
    expect(imported.title,'Meu quadro');
    expect(imported.bookmarks.single['label'],'Resumo 1');
    expect(imported.bookmarks.single['x'],125.5);
    expect(imported.bookmarks.single['zoom'],1.7);
  });
  test('Arquivos antigos sem bookmarks abrem com índice vazio', () {
    final original=Sketch(title:'Anterior');
    final source=original.toJson()..remove('bookmarks');
    final decoded=Sketch.fromJson(source);
    expect(decoded.bookmarks,isEmpty);
    expect(decoded.title,'Anterior');
  });
  test('Atributo de pressão da caneta fica salvo no elemento editável', () {
    final pen=InkElement(layerId:'main',tool:'pen',points:[
      InkPoint(0,0,.2),InkPoint(15,10,1.3),
    ],meta:{'pressureInk':true});
    final loaded=InkElement.fromJson(pen.toJson());
    expect(loaded.meta['pressureInk'],true);
    expect(loaded.points.first.p,.2);
    expect(loaded.points.last.offset,const Offset(15,10));
  });
  test('Objeto pode ter vínculo para marcador interno', () {
    final item=InkElement(layerId:'main',tool:'rectangle',
      meta:{'targetBookmark':'marca-1'});
    expect(InkElement.fromJson(item.toJson()).meta['targetBookmark'],'marca-1');
  });
}
