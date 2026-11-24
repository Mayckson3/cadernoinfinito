import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/local_store.dart';
import 'package:caderno_infinito/services/pdf_page_tools.dart';
import 'package:caderno_infinito/services/drive_sync.dart';

void main() {
  test('Trocar a pasta do Drive sem consentimento é bloqueado', () {
    final index=<String,dynamic>{'_remoteFolderId':'pasta-conta-a'};
    expect(()=>DriveBinding.verify(index,'pasta-conta-b',[]),
      throwsA(isA<DriveFolderChanged>()));
    expect(index['_remoteFolderId'],'pasta-conta-a');
  });
  test('Migração do índice anterior exige encontrar o arquivo esperado', () {
    final index=<String,dynamic>{'desenho1':{'fileId':'remote-id-1'}};
    expect(()=>DriveBinding.verify(index,'pasta-b',[]),
      throwsA(isA<DriveFolderChanged>()));
    DriveBinding.verify(index,'pasta-a',['remote-id-1']);
    expect(index['_remoteFolderId'],'pasta-a');
  });

  test('Backup preserva desenho, camadas e escrita sem perder IDs', () {
    final doc=Sketch(title:'Concurso',folder:'Geografia');
    doc.elements.add(InkElement(layerId:doc.layers.first.id,
      tool:'pen',points:[InkPoint(10,12),InkPoint(18,20)]));
    final json=BackupCodec.encode([doc]);
    final restored=BackupCodec.decode(json);
    expect(restored.single.serialize(),doc.serialize());
  });
  test('Backup rejeita estrutura incompatível', () {
    expect(()=>BackupCodec.decode('{"version":1,"documents":[]}'),throwsFormatException);
  });
  test('Página de PDF move anotações ao trocar a ordem', () {
    final doc=Sketch();
    final a=InkElement(layerId:doc.layers.first.id,type:'image',
      x:10,y:0,w:80,h:100,meta:{'pdfPage':1});
    final b=InkElement(layerId:doc.layers.first.id,type:'image',
      x:10,y:128,w:80,h:100,meta:{'pdfPage':2});
    final note=InkElement(layerId:doc.layers.first.id,tool:'pen',
      points:[InkPoint(20,15),InkPoint(30,25)]);
    doc.elements.addAll([a,b,note]);
    final order=[a,b];
    PdfPageTools.reorder(doc,order,0,1);
    expect(order.first.id,b.id);
    expect(b.y,0);
    expect(a.y,128);
    expect(note.points.first.y,143);
  });
}
