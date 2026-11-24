import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/services/tool_catalog.dart';
import 'package:caderno_infinito/screens/editor_screen.dart' show tools;

void main() {
  test('Todas as ferramentas aparecem no seletor com nomes precisos', () {
    final listed=ToolCatalog.sections.values.expand((group)=>group).toList();
    expect(listed.toSet().length,listed.length,reason:'Não repetir ferramentas em categorias');
    expect(listed.toSet(),tools.keys.toSet());
    for(final key in tools.keys) {
      final label=ToolCatalog.nameOf(key);
      expect(label.trim(),isNotEmpty);
      expect(label,isNot(equals(key)),reason:'Não deixar ID técnico na interface: $key');
    }
  });

  test('Ferramentas fundamentais são encontradas por nome', () {
    expect(ToolCatalog.nameOf('pen'),'Caneta');
    expect(ToolCatalog.nameOf('select'),'Selecionar');
    expect(ToolCatalog.nameOf('pan'),'Mover tela');
    expect(ToolCatalog.nameOf('eraser'),'Borracha');
    expect(ToolCatalog.nameOf('text'),'Inserir texto');
  });
}
