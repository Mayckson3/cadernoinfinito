import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/precision_geometry.dart';
import 'package:caderno_infinito/services/notebook_templates.dart';
import 'package:caderno_infinito/services/drive_sync.dart';
import 'package:caderno_infinito/services/import_export.dart';

void main() {
  test('Distância à linha não depende dos pontos intermediários', () {
    expect(PrecisionGeometry.distanceToSegment(
      const Offset(40, 7), const Offset(0, 0),const Offset(100,0)),closeTo(7,1e-9));
    expect(PrecisionGeometry.distanceToSegment(
      const Offset(120,0),const Offset(0,0),const Offset(100,0)),20);
  });

  test('Laço toca linha que cruza sem ter vértice no polígono', () {
    final e=InkElement(layerId:'layer',points:[InkPoint(-100,50),InkPoint(200,50)]);
    final polygon=[const Offset(0,0),const Offset(100,0),
      const Offset(100,100),const Offset(0,100)];
    expect(PrecisionGeometry.polygonTouchesElement(polygon,e),isTrue);
  });

  test('Recorte atinge traço de apenas dois pontos e preserva as pontas', () {
    final e=InkElement(layerId:'layer',tool:'pen',size:3,
      points:[InkPoint(0,0),InkPoint(100,0)]);
    final pieces=PrecisionGeometry.sliceStroke(e,[InkPoint(50,-15),InkPoint(50,15)],5);
    expect(pieces,hasLength(2));
    expect(pieces.first.points.first.x,closeTo(0,.5));
    expect(pieces.first.points.last.x,lessThan(50));
    expect(pieces.last.points.first.x,greaterThan(50));
    expect(pieces.last.points.last.x,closeTo(100,.5));
    expect(e.points,hasLength(2)); // a operação não modifica o original
  });

  test('Não recorta traço que não toca na borracha', () {
    final e=InkElement(layerId:'layer',points:[InkPoint(0,0),InkPoint(20,0)]);
    final pieces=PrecisionGeometry.sliceStroke(e,[InkPoint(100,100)],4);
    expect(identical(pieces.single,e),isTrue);
  });

  test('Modelos são editáveis e possuem camadas válidas', () {
    for(final name in NotebookTemplates.names) {
      final doc=NotebookTemplates.create(title:'Estudo',folder:'Concurso',template:name);
      final ids=doc.layers.map((layer)=>layer.id).toSet();
      expect(doc.title,'Estudo');
      expect(doc.elements.every((e)=>ids.contains(e.layerId)),isTrue);
      expect(Sketch.fromJson(doc.toJson()).elements.length,doc.elements.length);
    }
  });

  test('Texto longo não cria caixa de seleção mais larga que a caixa', () {
    final e=InkElement(layerId:'layer',type:'text',x:20,y:25,w:300,h:25,
      size:20,text:'Uma descrição longa de aulas e objetivos no ensino médio');
    expect(e.bounds.width,300);
    expect(e.bounds.height,greaterThanOrEqualTo(25));
  });

  test('PDF vetorial registra traços sem converter em bitmap', () async {
    final d=Sketch(title:'Linhas',grid:'nenhum');
    d.elements.add(InkElement(layerId:d.layers.first.id,tool:'line',
      points:[InkPoint(0,0),InkPoint(100,100)]));
    final pdf=await SketchExchange.exportVectorPdf(d,artboard:true);
    expect(pdf.take(4).toList(),[37,80,68,70]); // %PDF
    d.elements.add(InkElement(layerId:d.layers.first.id,type:'image',w:20,h:20));
    await expectLater(SketchExchange.exportVectorPdf(d,artboard:true),throwsStateError);
  });

  test('Nomes remotos duplicados impedem sincronização silenciosa', () {
    final files=[
      CloudFile({'id':'one','name':'id1.ci.json','md5Checksum':'x'}),
      CloudFile({'id':'two','name':'id1.ci.json','md5Checksum':'y'}),
    ];
    expect(()=>CloudManifest.validate(files),throwsA(isA<DuplicateCloudDocuments>()));
  });

  test('Checksum e nome de arquivo remoto são validados', () {
    final d=Sketch(title:'Seguro');
    expect(CloudManifest.decodeVerified(d.serialize(),d.id,'' ).id,d.id);
    expect(()=>CloudManifest.decodeVerified(d.serialize(),d.id,'invalid'),throwsFormatException);
    expect(()=>CloudManifest.decodeVerified(d.serialize(),'outro',''),throwsFormatException);
  });
}
