/// Operações seguras de pastas. Desenhos continuam armazenados separadamente.
class FolderOperations {
  static bool contains(String folder, String parent) =>
      folder == parent || folder.startsWith('$parent/');

  static String normalize(String raw) => raw.trim().replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+'), '/').replaceAll(RegExp(r'^/+|/+$'), '');

  static bool isValid(String name) {
    if (name.isEmpty || name.length > 180) return false;
    if (name == 'Todos' || name == 'Lixeira') return false;
    return name.split('/').every((part) =>
      part.isNotEmpty && part != '.' && part != '..' && part.trim() == part);
  }

  static List<String> afterDelete(Iterable<String> folders, String target) =>
      folders.where((f) => !contains(f, target)).toSet().toList()..sort();

  static String moveOutOfDeleted(String folder, String target) =>
      contains(folder, target) ? 'Geral' : folder;

  static String afterRename(String folder, String from, String to) =>
      contains(folder, from) ? '$to${folder.substring(from.length)}' : folder;

  static List<String> renamed(Iterable<String> folders, String from, String to) =>
      folders.map((f) => afterRename(f, from, to)).toSet().toList()..sort();

  static bool canRename(Iterable<String> folders, String from, String to) {
    if (!isValid(to) || from == 'Geral' || from == to ||
        to.startsWith('$from/') || from.startsWith('$to/')) return false;
    final original = folders.toSet();
    if (!original.contains(from)) return false;
    final renamedTree = original.where((f) => contains(f, from))
        .map((f) => afterRename(f, from, to));
    final outside = original.where((f) => !contains(f, from)).toSet();
    return !renamedTree.any(outside.contains);
  }
}
