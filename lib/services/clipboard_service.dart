class ClipboardEntry {
  final String collection;
  final String docId;
  final List<String> path;
  final String id;
  final String name;
  final bool isCut;
  final String kind;
  final List<String> hymnIds;

  ClipboardEntry({required this.collection, required this.docId, required this.path, required this.id, required this.name, required this.isCut, required this.kind, required this.hymnIds});
}

class ClipboardService {
  ClipboardEntry? _entry;

  static final ClipboardService instance = ClipboardService._();
  ClipboardService._();

  void copyFolder(String collection, String docId, List<String> parentPath, String folderId, String name) {
    _entry = ClipboardEntry(collection: collection, docId: docId, path: parentPath, id: folderId, name: name, isCut: false, kind: 'folder', hymnIds: const <String>[]);
  }

  void cutFolder(String collection, String docId, List<String> parentPath, String folderId, String name) {
    _entry = ClipboardEntry(collection: collection, docId: docId, path: parentPath, id: folderId, name: name, isCut: true, kind: 'folder', hymnIds: const <String>[]);
  }

  void copyHymn(String collection, String docId, List<String> folderPath, String hymnId, String name) {
    _entry = ClipboardEntry(collection: collection, docId: docId, path: folderPath, id: hymnId, name: name, isCut: false, kind: 'hymn', hymnIds: const <String>[]);
  }

  void cutHymn(String collection, String docId, List<String> folderPath, String hymnId, String name) {
    _entry = ClipboardEntry(collection: collection, docId: docId, path: folderPath, id: hymnId, name: name, isCut: true, kind: 'hymn', hymnIds: const <String>[]);
  }

  void copyHymnSelection({required List<String> hymnIds}) {
    _entry = ClipboardEntry(
      collection: '',
      docId: '',
      path: const <String>[],
      id: '',
      name: 'Selected hymns',
      isCut: false,
      kind: 'hymn_selection',
      hymnIds: List<String>.from(hymnIds),
    );
  }

  ClipboardEntry? peek() => _entry;

  bool hasEntry() => _entry != null;

  void clear() {
    _entry = null;
  }
}
