import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/gallery_bulk_actions.dart';

void main() {
  final docs = [
    Sketch(id:'desenho_0001',title:'A',folder:'Concurso'),
    Sketch(id:'desenho_0002',title:'B',folder:'Concurso'),
    Sketch(id:'desenho_0003',title:'C',folder:'Concurso/Geografia'),
    Sketch(id:'desenho_0004',title:'D',folder:'Português'),
    Sketch(id:'desenho_0005',title:'Na lixeira',folder:'Concurso',deleted:true),
  ];
  test('apagar tudo nesta pasta não inclui subpastas nem desenhos já na lixeira', () {
    final found=GalleryBulkActions.inFolder(docs, 'Concurso');
    expect(found.map((d)=>d.id), ['desenho_0001','desenho_0002']);
    expect(GalleryBulkActions.inFolder(docs,'Concurso/Geografia').single.title, 'C');
  });
  test('Todos inclui todas as pastas ativas mas não inclui a lixeira', () {
    expect(GalleryBulkActions.inFolder(docs, 'Todos').length, 4);
    expect(GalleryBulkActions.inFolder(docs, 'Lixeira',trash:true).length, 1);
  });
  test('seleção ignora identificadores fora da pasta ou já excluídos', () {
    final selected=GalleryBulkActions.selected(docs, 'Concurso',
      {'desenho_0001','desenho_0003','desenho_0005'});
    expect(selected.map((d)=>d.id), ['desenho_0001']);
  });
  test('alterar pesquisa limita seleção aos itens visíveis', () {
    final result=GalleryBulkActions.limitedToVisible(
      {'desenho_0001','desenho_0002'}, [docs[1]]);
    expect(result.length, 1);
    expect(result.contains('desenho_0002'), isTrue);
  });
}
