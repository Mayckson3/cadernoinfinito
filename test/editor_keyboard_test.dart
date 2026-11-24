import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/screens/editor_screen.dart';
import 'package:caderno_infinito/services/editor_keyboard.dart';
import 'package:caderno_infinito/services/local_store.dart';
import 'package:caderno_infinito/services/tool_catalog.dart';
import 'package:caderno_infinito/widgets/board_painter.dart';

void main() {
  test('Cada ferramenta tem um atalho e não há combinações duplicadas', () {
    expect(EditorKeyboard.tools.keys.toSet(),ToolCatalog.labels.keys.toSet());
    final keys=<SingleActivator>[
      for(final id in EditorKeyboard.tools.keys) EditorKeyboard.activator(id),
      for(final action in EditorKeyboard.actions.values) action.$1,
    ];
    final signatures=keys.map((k)=>(k.trigger,k.control,k.shift,k.alt,k.meta)).toSet();
    expect(signatures.length,keys.length);
    expect(EditorKeyboard.label('pen'),'B');
    expect(EditorKeyboard.label('text'),'T');
    expect(EditorKeyboard.label('rectangle'),'R');
  });

  testWidgets('Teclas ativam ferramentas do editor e modificadores não colidem', (tester) async {
    await tester.pumpWidget(MaterialApp(home:EditorScreen(initial:Sketch(),store:LocalStore())));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.text('Borracha · 100%'),findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.text('Máscara suave · 100%'),findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(find.text('Retângulo · 100%'),findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(find.text('Retângulo · 120%'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Digitar no texto não troca ferramentas do quadro', (tester) async {
    await tester.pumpWidget(MaterialApp(home:EditorScreen(initial:Sketch(),store:LocalStore())));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    final board=find.byWidgetPredicate((w)=>w is CustomPaint && w.painter is BoardPainter);
    await tester.tapAt(tester.getCenter(board));
    await tester.pump();
    final field=find.byKey(const ValueKey('inline-rich-text-field'));
    expect(field,findsOneWidget);
    await tester.enterText(field,'Texto de teste');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(field,findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(field,findsNothing);
    expect(find.text('Inserir texto · 100%'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('F2 abre a referência de atalhos', (tester) async {
    await tester.pumpWidget(MaterialApp(home:EditorScreen(initial:Sketch(),store:LocalStore())));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.text('Atalhos do teclado'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
