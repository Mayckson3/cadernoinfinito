import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/sketch.dart';

/// Escrita com arquivo temporário + rotação de backup. Um desligamento no
/// instante da troca não deve destruir a última versão íntegra.
class LocalStore {
  late Directory root;
  final Map<String, Future<void>> _writeQueue = {};
  final Set<String> _permanentlyDeleted = <String>{};
  Set<String> get permanentlyDeletedIds => Set.unmodifiable(_permanentlyDeleted);
  bool isPermanentlyDeleted(String id) => _permanentlyDeleted.contains(id);
  static final _safeId = RegExp(r'^[a-zA-Z0-9_-]{8,80}$');
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    root = Directory('${dir.path}${Platform.pathSeparator}CadernoInfinito');
    if (!await root.exists()) await root.create(recursive: true);
    await recoverIncompleteWrites();
    try {
      final value = jsonDecode(await deletionFile.readAsString());
      if (value is List) {
        _permanentlyDeleted.addAll(value.whereType<String>().where(_safeId.hasMatch));
      }
    } catch (_) { /* Nenhuma exclusão definitiva registrada ainda. */ }
  }

  File docFile(String id) {
    if (!_safeId.hasMatch(id)) throw const FormatException('Identificador de desenho inválido.');
    return File('${root.path}${Platform.pathSeparator}$id.ci.json');
  }
  File get indexFile => File('${root.path}${Platform.pathSeparator}_drive_index.json');
  File get deletionFile => File('${root.path}${Platform.pathSeparator}_permanently_deleted.json');
  Directory _historyDir(String id) {
    if (!_safeId.hasMatch(id)) throw const FormatException('ID inválido.');
    return Directory('${root.path}${Platform.pathSeparator}_history${Platform.pathSeparator}$id');
  }

  /// Salva até 12 pontos de recuperação por desenho, apenas neste aparelho.
  /// Um limite de tamanho evita cópias excessivas de PDFs importados.
  Future<bool> saveSnapshot(Sketch doc) async {
    final json=doc.serialize();
    if(json.length > 16*1024*1024 || isPermanentlyDeleted(doc.id))return false;
    final dir=_historyDir(doc.id);
    await dir.create(recursive:true);
    final stamp=DateTime.now().toUtc().microsecondsSinceEpoch;
    final file=File('${dir.path}${Platform.pathSeparator}$stamp.ci.json');
    await _atomicWrite(file,json);
    final all=await _snapshotFiles(doc.id);
    for(final old in all.skip(12)) {try {await old.delete();}catch(_) {}}
    return true;
  }
  Future<List<File>> _snapshotFiles(String id) async {
    final dir=_historyDir(id);
    if(!await dir.exists())return [];
    final files=await dir.list().where((e)=>e is File &&
      RegExp(r'^\d+\.ci\.json$').hasMatch(e.uri.pathSegments.last))
        .cast<File>().toList();
    files.sort((a,b)=>b.path.compareTo(a.path));
    return files;
  }
  Future<List<DateTime>> snapshotDates(String id) async {
    final files=await _snapshotFiles(id);
    return files.map((f)=>DateTime.fromMicrosecondsSinceEpoch(
      int.parse(f.uri.pathSegments.last.split('.').first),isUtc:true).toLocal()).toList();
  }
  Future<Sketch?> readSnapshot(String id, DateTime localDate) async {
    final stamp=localDate.toUtc().microsecondsSinceEpoch;
    final f=File('${_historyDir(id).path}${Platform.pathSeparator}$stamp.ci.json');
    if(!await f.exists())return null;
    try {
      final result=Sketch.fromJson(jsonDecode(await f.readAsString()) as Map<String,dynamic>);
      return result.id==id?result:null;
    } catch (_) {return null;}
  }

  /// Registra primeiro o bloqueio de restauração. Mesmo offline, a próxima
  /// sincronização publicará a exclusão para os demais aparelhos.
  Future<void> permanentlyDelete(String id) async {
    if (!_safeId.hasMatch(id)) throw const FormatException('Identificador inválido.');
    if (!_permanentlyDeleted.contains(id)) {
      final ids = {..._permanentlyDeleted, id}.toList()..sort();
      await _atomicWrite(deletionFile, jsonEncode(ids));
      _permanentlyDeleted.add(id);
    }
    final file = docFile(id);
    final writing = _writeQueue[file.path];
    if (writing != null) { try { await writing; } catch (_) {} }
    for (final suffix in ['', '.bak', '.tmp']) {
      final target = File('${file.path}$suffix');
      if (await target.exists()) await target.delete();
    }
    final history=_historyDir(id);
    if(await history.exists())await history.delete(recursive:true);
  }

  Future<void> _atomicWrite(File dest, String data) {
    // A mesma nota pode ser salva pelo editor e pelo sincronizador quase
    // simultaneamente. Serializar por destino evita colisões de .tmp/.bak.
    final earlier = _writeQueue[dest.path] ?? Future<void>.value();
    final write = earlier.then((_) => _writeUnlocked(dest, data),
      onError: (Object _, StackTrace __) => _writeUnlocked(dest, data));
    _writeQueue[dest.path] = write;
    write.then((_) {
      if (identical(_writeQueue[dest.path], write)) _writeQueue.remove(dest.path);
    }, onError: (Object _, StackTrace __) {
      if (identical(_writeQueue[dest.path], write)) _writeQueue.remove(dest.path);
    });
    return write;
  }

  Future<void> _writeUnlocked(File dest, String data) async {
    // Valida o JSON antes de modificar a cópia atual.
    jsonDecode(data);
    final temp = File('${dest.path}.tmp');
    final backup = File('${dest.path}.bak');
    await temp.writeAsString(data, flush:true);
    if (await dest.exists()) {
      if (await _validJson(dest)) {
        // Só substitui o backup se o arquivo principal anterior é íntegro.
        if (await backup.exists()) await backup.delete();
        await dest.rename(backup.path);
      } else if (await backup.exists() && await _validJson(backup)) {
        // Preserva o último backup BOM quando o principal está corrompido.
        await dest.delete();
      } else {
        if (await backup.exists()) await backup.delete();
        await dest.rename(backup.path);
      }
    }
    try {
      await temp.rename(dest.path);
    } catch (_) {
      if (!await dest.exists() && await backup.exists()) await backup.rename(dest.path);
      rethrow;
    }
    // Mantemos a versão anterior como .bak para recuperação manual.
  }

  Future<void> recoverIncompleteWrites() async {
    // Nunca prefere um .tmp possivelmente incompleto a uma cópia .bak válida.
    await for (final item in root.list()) {
      if (item is! File || !item.path.endsWith('.tmp')) continue;
      final primary = File(item.path.substring(0, item.path.length - 4));
      final backup = File('${primary.path}.bak');
      if (await primary.exists() && await _validJson(primary)) {
        await item.delete();
        continue;
      }
      if (await backup.exists() && await _validJson(backup)) {
        await backup.copy(primary.path);
        await item.delete();
      } else if (await _validJson(item)) {
        // Um arquivo principal corrompido pode existir após uma queda.
        // Uma cópia validada do temporário recupera o desenho.
        await item.copy(primary.path);
        await item.delete();
      } else {
        await item.delete();
      }
    }
    await for (final item in root.list()) {
      if (item is! File || !item.path.endsWith('.bak')) continue;
      final primary = File(item.path.substring(0, item.path.length - 4));
      if (!await primary.exists() || !await _validJson(primary)) {
        if (await _validJson(item)) await item.copy(primary.path);
      }
    }
  }

  Future<bool> _validJson(File f) async {
    try {
      final parsed = jsonDecode(await f.readAsString());
      // .tmp/.bak têm exatamente o mesmo formato do arquivo principal.
      final fileName = f.uri.pathSegments.last
          .replaceFirst(RegExp(r'\.(tmp|bak)$'), '');
      if (fileName == '_permanently_deleted.json') {
        // Um marcador de exclusão é uma LISTA; rejeitá-lo aqui fazia a
        // recuperação após queda do app descartar as exclusões definitivas.
        return parsed is List && parsed.every((id) =>
            id is String && _safeId.hasMatch(id));
      }
      if (fileName == '_drive_index.json') {
        return parsed is Map<String, dynamic>;
      }
      if (fileName.endsWith('.ci.json')) {
        if (parsed is! Map<String, dynamic>) return false;
        final id = fileName.substring(0, fileName.length - '.ci.json'.length);
        if (!_safeId.hasMatch(id) || parsed['id'] != id) return false;
        Sketch.fromJson(parsed);
        return true;
      }
      return false; // Não recupera arquivos desconhecidos.
    } catch (_) { return false; }
  }

  Future<void> save(Sketch doc) async {
    if (isPermanentlyDeleted(doc.id)) {
      throw StateError('Este desenho foi excluído definitivamente.');
    }
    await _atomicWrite(docFile(doc.id),doc.serialize());
  }

  Future<Sketch?> get(String id) async {
    if (isPermanentlyDeleted(id)) return null;
    // Não exibe um caderno de outro ID apenas porque seu conteúdo foi
    // copiado ou corrompido dentro do arquivo de um documento diferente.
    for (final candidate in [docFile(id), File('${docFile(id).path}.bak')]) {
      try {
        final parsed=jsonDecode(await candidate.readAsString()) as Map<String,dynamic>;
        if(parsed['id']!=id) continue;
        return Sketch.fromJson(parsed);
      } catch (_) { /* Tenta a cópia de segurança se o principal falhar. */ }
    }
    return null;
  }

  Future<List<Sketch>> all() async {
    final ids=<String>{};
    await for(final item in root.list()) {
      if(item is! File)continue;
      final name=item.uri.pathSegments.last;
      if(name.endsWith('.ci.json'))ids.add(name.substring(0,name.length-8));
      if(name.endsWith('.ci.json.bak'))ids.add(name.substring(0,name.length-12));
    }
    final docs=<Sketch>[];
    for(final id in ids){if (isPermanentlyDeleted(id)) continue; final d=await get(id);if(d!=null)docs.add(d);}
    docs.sort((a,b)=>b.updatedAt.compareTo(a.updatedAt));
    return docs;
  }

  Future<String> createBackup() async => BackupCodec.encode(await all());

  Future<({int imported, int skipped})> restoreBackup(String source) async {
    final restored = BackupCodec.decode(source);
    var imported = 0, skipped = 0;
    for (final doc in restored) {
      final existing = await get(doc.id);
      // Um documento apagado definitivamente tem existing == null.
      // Nesse caso, restaurar como CÓPIA evita Null check e não ressuscita
      // o ID tombstonado no Drive.
      if (existing != null || isPermanentlyDeleted(doc.id)) {
        if (existing != null && existing.serialize() == doc.serialize()) {
          skipped++;
          continue;
        }
        doc.id = newId();
        doc.title = '${doc.title} (restaurado)';
        doc.touch();
      }
      await save(doc);
      imported++;
    }
    return (imported: imported, skipped: skipped);
  }

  Future<Map<String,dynamic>> readIndex() async {
    for(final file in [indexFile,File('${indexFile.path}.bak')]) {
      try {return Map<String,dynamic>.from(jsonDecode(await file.readAsString()) as Map);}
      catch (_) {continue;}
    }
    return {};
  }
  Future<void> saveIndex(Map<String,dynamic> index) async =>
      _atomicWrite(indexFile,jsonEncode(index));
}

/// Backup independente do Google Drive; preserva vetores, camadas e imagens.
class BackupCodec {
  static const format = 'caderno-infinito-backup';
  static String encode(Iterable<Sketch> documents) => jsonEncode({
    'format': format,
    'version': 1,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'documents': documents.map((d) => d.toJson()).toList(),
  });

  static List<Sketch> decode(String source) {
    if (source.length > 150 * 1024 * 1024) {
      throw const FormatException('Backup maior que 150 MB; divida o arquivo antes de importar.');
    }
    final value = jsonDecode(source);
    if (value is! Map || value['format'] != format || value['version'] != 1 ||
        value['documents'] is! List) {
      throw const FormatException('Este arquivo não é um backup compatível do Caderno Infinito.');
    }
    final entries = value['documents'] as List;
    if (entries.length > 10000) {
      throw const FormatException('O backup tem mais de 10 mil documentos.');
    }
    final seen = <String>{};
    return entries.map((e) {
      if (e is! Map<String, dynamic>) throw const FormatException('Documento inválido no backup.');
      final doc = Sketch.fromJson(e);
      if (!RegExp(r'^[a-zA-Z0-9_-]{8,80}$').hasMatch(doc.id) || !seen.add(doc.id)) {
        throw const FormatException('Backup contém identificadores inválidos ou duplicados.');
      }
      return doc;
    }).toList(growable: false);
  }
}
