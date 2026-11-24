import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/services/drive_sync.dart';

void main() {
  group('Marcadores de exclusão permanente', () {
    test('identifica corretamente IDs e arquivos de exclusão', () {
      const id = 'abcd1234efgh';
      final name = DeletionMarkers.nameFor(id);
      expect(name, '$id.ci.deleted');
      expect(DeletionMarkers.idFromName(name), id);
    });
    test('ignora nomes de outros arquivos', () {
      expect(DeletionMarkers.idFromName('abcd1234efgh.ci.json'), isNull);
      expect(DeletionMarkers.idFromName('_drive_index.json'), isNull);
      expect(DeletionMarkers.idFromName('../../escape.ci.deleted'), isNull);
      expect(() => DeletionMarkers.nameFor('../escape'), throwsFormatException);
    });
  });
}
