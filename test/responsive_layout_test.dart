import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/theme/responsive_layout.dart';

void main() {
  test('Celular: uma coluna, menus compactos, barra horizontal', () {
    expect(ResponsiveLayout.libraryHasSidebar(390),isFalse);
    expect(ResponsiveLayout.editorHasSidebar(390),isFalse);
    expect(ResponsiveLayout.galleryHeaderIsStacked(310),isTrue);
    expect(ResponsiveLayout.galleryUsesSingleColumn(390),isTrue);
    expect(ResponsiveLayout.galleryCardMaxWidth(390),480);
  });

  test('Tablet: cards distribuídos e editor lateral quando há espaço', () {
    expect(ResponsiveLayout.galleryUsesSingleColumn(600),isFalse);
    expect(ResponsiveLayout.editorHasSidebar(800),isTrue);
    expect(ResponsiveLayout.libraryHasSidebar(800),isFalse);
  });

  test('PC: lateral permanente e cartões menores', () {
    expect(ResponsiveLayout.libraryHasSidebar(1200),isTrue);
    expect(ResponsiveLayout.editorHasSidebar(1200),isTrue);
    expect(ResponsiveLayout.galleryCardMaxWidth(1200),310);
    expect(ResponsiveLayout.galleryCardHeight(1200),256);
  });
}
