import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/local_store.dart';

void main() {
  late Directory temp;
  late LocalStore store;
  setUp(() async {
    temp=await Directory.systemTemp.createTemp('caderno-infinito-test-');
    store=LocalStore()..root=temp;
  });
  tearDown(() async {
    if(await temp.exists())await temp.delete(recursive:true);
  });

  test('Backup de desenho apagado definitivamente restaura uma NOVA cópia', () async {
    final deleted=Sketch(title:'Recuperar do backup');
    await store.permanentlyDelete(deleted.id);
    final result=await store.restoreBackup(BackupCodec.encode([deleted]));
    expect(result.imported,1);
    expect(result.skipped,0);
    expect(store.isPermanentlyDeleted(deleted.id),isTrue);
    final recovered=await store.all();
    expect(recovered.length,1);
    expect(recovered.single.id,isNot(deleted.id));
    expect(recovered.single.title,contains('restaurado'));
  });

  test('Recuperação aceita marcadores de exclusão em lista JSON', () async {
    const id='12345678-aaaa-bbbb-cccc-000000000001';
    await store.deletionFile.writeAsString('{arquivo quebrado');
    await File('${store.deletionFile.path}.bak')
        .writeAsString(jsonEncode([id]));
    await store.recoverIncompleteWrites();
    expect(jsonDecode(await store.deletionFile.readAsString()),[id]);
    // Marcadores devem persistir mesmo depois de falha durante o salvamento.
    await store.deletionFile.delete();
    await File('${store.deletionFile.path}.tmp')
        .writeAsString(jsonEncode([id]));
    await store.recoverIncompleteWrites();
    expect(jsonDecode(await store.deletionFile.readAsString()),[id]);
  });

  test('Backup válido sobrevive a arquivo principal corrompido', () async {
    final doc=Sketch(title:'Primeira versão');
    await store.save(doc);
    doc.title='Segunda versão';
    await store.save(doc);
    final backup=File('${store.docFile(doc.id).path}.bak');
    expect((jsonDecode(await backup.readAsString()) as Map)['title'],
        'Primeira versão');
    await store.docFile(doc.id).writeAsString('{quebrado');
    doc.title='Terceira versão';
    await store.save(doc);
    expect((jsonDecode(await backup.readAsString()) as Map)['title'],
        'Primeira versão');
    expect((await store.get(doc.id))!.title,'Terceira versão');
  });

  test('Não carrega arquivo cujo ID interno difere do nome', () async {
    final original=Sketch(title:'Caderno legítimo');
    final stranger=Sketch(title:'Arquivo trocado');
    await store.docFile(original.id).writeAsString(stranger.serialize());
    expect(await store.get(original.id),isNull);
  });

  test('Recuperação de arquivos temporários não restaura JSON de outro ID', () async {
    final expected=Sketch(title:'Correto');
    final stranger=Sketch(title:'Incorreto');
    await File('${store.docFile(expected.id).path}.tmp')
        .writeAsString(stranger.serialize());
    await store.recoverIncompleteWrites();
    expect(await store.get(expected.id),isNull);
  });
}
