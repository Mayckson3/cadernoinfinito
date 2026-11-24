import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/widgets/document_minimap.dart';

void main() {
  testWidgets('Toque no minimapa chama o callback de navegação', (tester) async {
    Offset? destination;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 220, height: 160, child: DocumentMiniMap(
        doc: Sketch(),
        visibleWorld: const Rect.fromLTWH(0, 0, 500, 300),
        onJump: (world) => destination = world,
      )),
    ))));
    await tester.tap(find.byType(DocumentMiniMap));
    expect(destination, isNotNull);
    expect(destination!.dx.isFinite, isTrue);
    expect(destination!.dy.isFinite, isTrue);
  });
}
