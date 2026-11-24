import '../models/sketch.dart';

/// Regras da seleção em lote. Não inclui subpastas implicitamente: o usuário
/// só altera o conteúdo da pasta aberta (ou a biblioteca inteira em Todos).
class GalleryBulkActions {
  static List<Sketch> inFolder(Iterable<Sketch> docs, String folder,
      {bool trash = false}) {
    return docs.where((doc) =>
      doc.deleted == trash &&
      (folder == 'Todos' || folder == 'Lixeira' || doc.folder == folder)
    ).toList();
  }

  /// A seleção nunca pode operar sobre itens de outra pasta ou da outra aba.
  static List<Sketch> selected(Iterable<Sketch> docs, String folder,
      Set<String> ids, {bool trash = false}) {
    return inFolder(docs, folder, trash: trash)
      .where((doc) => ids.contains(doc.id)).toList();
  }

  static Set<String> limitedToVisible(Set<String> selectedIds,
      Iterable<Sketch> visible) {
    final visibleIds = visible.map((doc) => doc.id).toSet();
    return selectedIds.intersection(visibleIds);
  }
}
