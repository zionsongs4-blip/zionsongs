String buildFolderId(String name) {
  final sanitized = name
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  return sanitized.isEmpty ? 'folder' : sanitized.toLowerCase();
}
