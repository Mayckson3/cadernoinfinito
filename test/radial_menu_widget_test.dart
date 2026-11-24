import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/widgets/stylus_radial_menu.dart';

void main() {
  testWidgets('Menu radial exibe dez ícones em espaço compacto', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:SizedBox(
      width:360,height:480,child:Stack(children:[
        StylusRadialMenu(center:Offset(180,240),radius:92,
          highlighted:null,activeTool:'pen',canUndo:true,canRedo:false,
          actions:radialQuickActions,previousAction:null),
      ])))));
    expect(find.byType(StylusRadialMenu),findsOneWidget);
    expect(find.text('Arraste'),findsOneWidget);
    expect(find.descendant(of:find.byKey(const Key('radial-menu-center')),
      matching:find.byType(Icon)),findsNothing);

    expect(find.byIcon(Icons.auto_fix_off),findsOneWidget);
    expect(find.byIcon(Icons.undo),findsOneWidget);
    expect(find.byIcon(Icons.redo),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Menu personalizado apresenta quatro ícones em sua ordem', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SizedBox(
      width:360,height:480,child:Stack(children:[
        StylusRadialMenu(center:const Offset(180,240),radius:92,
          highlighted:0,activeTool:'pen',canUndo:true,canRedo:true,
          actions:selectedRadialActions(['undo','pen','eraser','text']),
          previousAction:'pen'),
      ])))));
    expect(find.text('Desfazer'),findsOneWidget);
    expect(find.byIcon(Icons.text_fields),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Nome da opção selecionada aparece no centro', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:SizedBox(
      width:360,height:480,child:Stack(children:[
        StylusRadialMenu(center:Offset(180,240),radius:92,
          highlighted:2,activeTool:'pen',canUndo:false,canRedo:false,
          actions:radialQuickActions,previousAction:null),
      ])))));
    expect(find.text('Borracha'),findsOneWidget);
    expect(find.descendant(of:find.byKey(const Key('radial-menu-center')),
      matching:find.byType(Icon)),findsNothing);
    // Os ícones das dez ações externas continuam visíveis.
    expect(find.byIcon(Icons.auto_fix_off),findsOneWidget);

    expect(tester.takeException(),isNull);
  });
}
