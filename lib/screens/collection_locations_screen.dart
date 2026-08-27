import 'package:flutter/material.dart';

import 'folder_doc_screen.dart';

class CollectionLocation {
  const CollectionLocation({
    required this.collection,
    required this.docId,
    required this.path,
    required this.folderName,
  });

  final String collection;
  final String docId;
  final List<String> path;
  final String folderName;
}

class CollectionLocationsScreen extends StatelessWidget {
  const CollectionLocationsScreen({
    super.key,
    required this.collection,
    required this.hymnId,
    required this.locations,
  });

  final String collection;
  final String hymnId;
  final List<CollectionLocation> locations;

  String get _title =>
      collection == 'medleys' ? 'Medley Locations' : 'View List Locations';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: locations.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final location = locations[index];
          return ListTile(
            title: Text(location.folderName),
            leading: const Icon(Icons.folder_outlined),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FolderDocScreen(
                  collection: location.collection,
                  docId: location.docId,
                  docName: location.folderName,
                  initialPath: location.path,
                  initialHighlightHymnId: hymnId,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
