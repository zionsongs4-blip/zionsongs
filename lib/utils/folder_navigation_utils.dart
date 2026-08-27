String getCollectionDisplayName(String collection) {
  switch (collection) {
    case 'medleys':
      return 'Medleys';
    case 'viewlists':
    default:
      return 'View Lists';
  }
}

List<String> buildBreadcrumbLabels(
  String collection,
  List<String> path,
  Map<String, String> folderLabels,
) {
  final labels = <String>[getCollectionDisplayName(collection)];
  for (var index = 0; index < path.length; index++) {
    final prefix = path.sublist(0, index + 1);
    final pathKey = prefix.join('/');
    labels.add(folderLabels[pathKey] ?? _friendlyNameFromPath(prefix));
  }
  return labels;
}

String friendlyNameForPath(List<String> path) {
  if (path.isEmpty) return '';
  final rawValue = path.last;
  return rawValue
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _friendlyNameFromPath(List<String> path) => friendlyNameForPath(path);

bool isVisibleRelationshipUser({
  required String recordUserId,
  required String activeUserId,
}) {
  if (activeUserId.isEmpty) {
    return recordUserId == 'local-user';
  }

  // Keep records created before authentication was initialized visible.
  return recordUserId == activeUserId || recordUserId == 'local-user';
}

List<String> uniqueIdsPreservingOrder(Iterable<String> ids) {
  final seen = <String>{};
  return [
    for (final id in ids)
      if (seen.add(id)) id,
  ];
}

List<String> resolveRelationshipFolderPath({
  required String folderId,
  required String collection,
  required String docId,
  required List<String> encodedPath,
  required Map<String, String?> parentById,
}) {
  if (encodedPath.isEmpty) return const <String>[];

  final path = <String>[];
  var currentId = folderId;
  final visited = <String>{};
  while (visited.add(currentId)) {
    path.insert(0, currentId);
    final parentId = parentById[currentId];
    if (parentId == null || parentId.isEmpty) break;
    currentId = parentId;
  }

  if (path.length >= encodedPath.length) return path;
  return encodedPath
      .map((id) => '$collection::$docId::$id')
      .toList();
}
