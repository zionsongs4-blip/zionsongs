class FolderNode {
  final String id;
  String name;
  List<String> hymnIds;
  List<FolderNode> children;

  FolderNode({required this.id, required this.name, List<String>? hymnIds, List<FolderNode>? children})
      : hymnIds = hymnIds ?? [],
        children = children ?? [];

  factory FolderNode.fromMap(String id, Map<String, dynamic> map) {
    final hymnIds = <String>[];
    if (map['hymnIds'] is Map) {
      hymnIds.addAll((map['hymnIds'] as Map).keys.map((k) => k.toString()));
    }
    final children = <FolderNode>[];
    if (map['folders'] is Map) {
      (map['folders'] as Map).forEach((k, v) {
        if (v is Map) children.add(FolderNode.fromMap(k.toString(), v.cast<String, dynamic>()));
      });
    }
    return FolderNode(id: id, name: map['name']?.toString() ?? id, hymnIds: hymnIds, children: children);
  }
}
