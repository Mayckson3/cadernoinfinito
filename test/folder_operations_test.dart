import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/services/folder_operations.dart';

void main() {
  test('apagar uma pasta remove subpastas mas preserva outros caminhos', () {
    final result = FolderOperations.afterDelete(
      ['Geral', 'Geografia', 'Geografia/Clima', 'Geografia2', 'Estudos'], 'Geografia');
    expect(result, ['Estudos', 'Geografia2', 'Geral']);
    expect(FolderOperations.moveOutOfDeleted('Geografia/Clima', 'Geografia'), 'Geral');
    expect(FolderOperations.moveOutOfDeleted('Geografia2', 'Geografia'), 'Geografia2');
  });
  test('renomear pasta afeta também subpastas sem mexer nas demais', () {
    final result = FolderOperations.renamed(
      ['Geral', 'Concurso', 'Concurso/Geografia', 'Concurso2'], 'Concurso', 'Preparação');
    expect(result, ['Concurso2', 'Geral', 'Preparação', 'Preparação/Geografia']);
    expect(FolderOperations.afterRename('Concurso/Geografia', 'Concurso', 'Preparação'),
      'Preparação/Geografia');
  });
  test('evita nomes reservados e colisões com outras pastas', () {
    expect(FolderOperations.isValid('Todos'), false);
    expect(FolderOperations.isValid('Lixeira'), false);
    expect(FolderOperations.canRename(['Geral','A','A/X','B'], 'A', 'B'), false);
    expect(FolderOperations.canRename(['Geral','A','A/X','B'], 'A', 'C'), true);
  });
}
