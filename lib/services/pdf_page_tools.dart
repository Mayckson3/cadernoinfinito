import '../models/sketch.dart';

/// Organização não destrutiva das páginas importadas.
/// Acompanhamento das anotações é por posição: elementos cujo centro estava
/// dentro da página antes da operação se movem junto dela.
class PdfPageTools {
  static void reorder(Sketch doc, List<InkElement> pages, int from, int to) {
    if (from == to || from < 0 || to < 0 ||
        from >= pages.length || to >= pages.length) return;
    final original = List<InkElement>.from(pages);
    final pageIds = original.map((e) => e.id).toSet();
    final annotations = <String, List<InkElement>>{
      for (final page in original) page.id: [],
    };
    for (final element in doc.elements) {
      if (pageIds.contains(element.id)) continue;
      for (final page in original) {
        if (page.bounds.contains(element.bounds.center)) {
          annotations[page.id]!.add(element);
          break;
        }
      }
    }
    final firstY=original.first.y;
    final moving=pages.removeAt(from);
    pages.insert(to,moving);
    var y=firstY;
    for (final page in pages) {
      final delta=y-page.y;
      page.translate(0,delta);
      for (final annotation in annotations[page.id]!) {
        annotation.translate(0,delta);
      }
      y += page.h + 28;
    }
  }
}
