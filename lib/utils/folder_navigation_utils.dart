String getCollectionDisplayName(String collection) {
  switch (collection) {
    case 'medleys':
      return 'Medleys';
    case 'viewlists':
    default:
      return 'View Lists';
  }
}

List<String> buildBreadcrumbLabels(String collection, List<String> path, Map<String, String> folderLabels) {
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
