import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/theme/app_theme.dart';

void main() {
  testWidgets('Tema do Caderno Infinito renderiza uma tela de exemplo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme:AppTheme.light(),
      home:const Scaffold(body:Center(child:Text('Caderno Infinito'))),
    ));
    expect(find.text('Caderno Infinito'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
