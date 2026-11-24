import '../models/sketch.dart';

/// A exclusão do gesto de arrastar afeta só os objetos selecionados editáveis.
/// Não move o documento inteiro para a Lixeira da biblioteca.
class SelectionDeletion {
  const SelectionDeletion._();
  static int removeEditable(Sketch document,Set<String> selection) {
    final previous=document.elements.length;
    document.elements.removeWhere((e)=>selection.contains(e.id) &&
      !e.locked && !(document.layerById(e.layerId)?.locked ?? true));
    return previous-document.elements.length;
  }
}
