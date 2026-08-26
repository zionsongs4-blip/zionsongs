import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../feature/home/hymn/app_initializer.dart';
import '../feature/home/hymn/hymn_models.dart';
import '../feature/home/hymn/viewlist_medley_models.dart';
import '../feature/home/repositories/folder_repository.dart';
import 'hymn_collection_page.dart';

class ViewListScreen extends StatefulWidget {
  final String collection;

  const ViewListScreen({super.key, this.collection = 'viewlists'});

  @override
  State<ViewListScreen> createState() => _ViewListScreenState();
}

class _ViewListScreenState extends State<ViewListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search hymn ID, title, lyrics or search text...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<_FolderSearchResult>>(
            future: _buildResults(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final results = snapshot.data ?? const <_FolderSearchResult>[];

              if (results.isEmpty) {
                return const Center(
                  child: Text('No matching hymn locations found.'),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                      kMinInteractiveDimension * 4,
                ),
                itemCount: results.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = results[index];

                  return ListTile(
                    title: Text(result.title),
                    subtitle: Text(result.pathLabel),
                    leading: const Icon(Icons.folder),
                    onTap: () => _openCollectionTab(context, result),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<_FolderSearchResult>> _buildResults() async {
    final query = _normalizeCollectionSearchQuery(_searchText);

    // ---------------------------------------------------------------
    // IMPORTANT:
    // Only load folders and hymn references belonging to THIS
    // collection. View List and Medley are completely separate.
    // ---------------------------------------------------------------
    final folderRecords = await _loadFolderRecords();
    final itemRecords = await _loadItemRecords();

    final folderMap = {
      for (final folder in folderRecords) folder.folderId: folder,
    };

    final itemsByFolder = <String, List<_CollectionItemRecord>>{};

    for (final item in itemRecords) {
      itemsByFolder
          .putIfAbsent(item.folderId, () => <_CollectionItemRecord>[])
          .add(item);
    }

    for (final items in itemsByFolder.values) {
      items.sort((a, b) {
        final sortOrderDelta = a.sortOrder.compareTo(b.sortOrder);

        if (sortOrderDelta != 0) {
          return sortOrderDelta;
        }

        return a.hymnId.compareTo(b.hymnId);
      });
    }

    // ---------------------------------------------------------------
    // No search text:
    // Show the folders belonging to this collection.
    // ---------------------------------------------------------------
    if (query.isEmpty) {
      return folderRecords.map((folder) {
        final folderHymnIds = _orderedHymnIdsForFolder(
          itemsByFolder[folder.folderId] ?? const <_CollectionItemRecord>[],
        );

        final folderName = folder.name.isNotEmpty
            ? folder.name
            : folder.folderId;

        return _FolderSearchResult(
          docId: folder.folderId,
          displayName: folderName,
          title: folderName,
          pathLabel: _formatFolderPath(folder.folderId, folderMap),
          path: _buildFolderPathIds(folder.folderId, folderMap),
          hymnId: folderHymnIds.isNotEmpty ? folderHymnIds.first : '',
          folderId: folder.folderId,
          folderName: folderName,
          folderHymnIds: folderHymnIds,
        );
      }).toList();
    }

    // ---------------------------------------------------------------
    // Load ONLY the hymns that are actually referenced by this
    // View List or Medley collection.
    // ---------------------------------------------------------------
    final collectionHymnIds = itemRecords.map((item) => item.hymnId).toSet();

    final hymns = await AppInitializer.isar.localHymns.where().findAll();

    final hymnMap = {
      for (final hymn in hymns)
        if (collectionHymnIds.contains(hymn.hymnId)) hymn.hymnId: hymn,
    };

    // ---------------------------------------------------------------
    // IMPORTANT:
    // One folder = one search result.
    //
    // Several hymns can match inside the same folder, but the folder
    // must only appear once.
    // ---------------------------------------------------------------
    final folderResults = <String, _FolderSearchResult>{};

    for (final item in itemRecords) {
      final hymn = hymnMap[item.hymnId];

      if (hymn == null) {
        continue;
      }

      if (!_matchesCollectionSearchQuery(hymn, query)) {
        continue;
      }

      final folder = folderMap[item.folderId];

      if (folder == null) {
        continue;
      }

      final folderHymnIds = _orderedHymnIdsForFolder(
        itemsByFolder[item.folderId] ?? const <_CollectionItemRecord>[],
      );

      final folderName = folder.name.isNotEmpty ? folder.name : folder.folderId;

      // If this folder has already matched another hymn, don't add
      // another copy of the same folder.
      folderResults.putIfAbsent(
        folder.folderId,
        () => _FolderSearchResult(
          docId: folder.folderId,
          displayName: folderName,
          title: folderName,
          pathLabel: _formatFolderPath(folder.folderId, folderMap),
          path: _buildFolderPathIds(folder.folderId, folderMap),
          hymnId: hymn.hymnId,
          folderId: folder.folderId,
          folderName: folderName,
          folderHymnIds: folderHymnIds,
        ),
      );
    }

    final matches = folderResults.values.toList();

    matches.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    return matches;
  }

  // ===============================================================
  // COLLECTION-SPECIFIC SEARCH
  // ===============================================================

  String _normalizeCollectionSearchQuery(String value) {
    return value.trim().toLowerCase();
  }

  bool _matchesCollectionSearchQuery(LocalHymn hymn, String query) {
    if (query.isEmpty) {
      return true;
    }

    // 1. Hymn ID
    final hymnId = hymn.hymnId.toLowerCase();

    if (hymnId.contains(query)) {
      return true;
    }

    // 2. Search text
    final searchText = (hymn.searchText ?? '').toLowerCase();

    if (searchText.contains(query)) {
      return true;
    }

    // 3. Hindi lyrics
    final hindi = (hymn.hindiLyrics ?? '').toLowerCase();

    if (hindi.contains(query)) {
      return true;
    }

    // 4. Malayalam lyrics
    final malayalam = (hymn.malayalamLyrics ?? '').toLowerCase();

    if (malayalam.contains(query)) {
      return true;
    }

    // 5. English lyrics
    final english = (hymn.englishLyrics ?? '').toLowerCase();

    if (english.contains(query)) {
      return true;
    }

    // 6. Title
    final title = (hymn.title ?? '').toLowerCase();

    if (title.contains(query)) {
      return true;
    }

    return false;
  }

  // ===============================================================
  // FOLDERS
  // ===============================================================

  Future<List<_FolderRecordLike>> _loadFolderRecords() async {
    if (widget.collection == 'medleys') {
      final records = await AppInitializer.isar.medleyFolderRecords
          .where()
          .findAll();

      return records
          .map(
            (record) => _FolderRecordLike(
              folderId: record.folderId,
              name: record.name,
              parentId: record.parentId,
            ),
          )
          .toList();
    }

    final records = await AppInitializer.isar.viewListFolderRecords
        .where()
        .findAll();

    return records
        .map(
          (record) => _FolderRecordLike(
            folderId: record.folderId,
            name: record.name,
            parentId: record.parentId,
          ),
        )
        .toList();
  }

  // ===============================================================
  // SONGS BELONGING TO THIS COLLECTION
  // ===============================================================

  Future<List<_CollectionItemRecord>> _loadItemRecords() async {
    if (widget.collection == 'medleys') {
      final records = await AppInitializer.isar.medleyItemRecords
          .where()
          .findAll();

      return records
          .map(
            (record) => _CollectionItemRecord(
              folderId: record.folderId,
              hymnId: record.hymnId,
              sortOrder: record.sortOrder,
            ),
          )
          .toList();
    }

    final records = await AppInitializer.isar.viewListItemRecords
        .where()
        .findAll();

    return records
        .map(
          (record) => _CollectionItemRecord(
            folderId: record.folderId,
            hymnId: record.hymnId,
            sortOrder: record.sortOrder,
          ),
        )
        .toList();
  }

  // ===============================================================
  // ORDER HYMNS INSIDE FOLDER
  // ===============================================================

  List<String> _orderedHymnIdsForFolder(List<_CollectionItemRecord> items) {
    final ordered = List<_CollectionItemRecord>.from(items);

    ordered.sort((a, b) {
      final sortOrderDelta = a.sortOrder.compareTo(b.sortOrder);

      if (sortOrderDelta != 0) {
        return sortOrderDelta;
      }

      return a.hymnId.compareTo(b.hymnId);
    });

    return ordered.map((item) => item.hymnId).toList();
  }

  // ===============================================================
  // FOLDER PATH
  // ===============================================================

  List<String> _buildFolderPathIds(
    String folderId,
    Map<String, _FolderRecordLike> folderMap,
  ) {
    return parseRelationshipFolderKey(folderId).path;
  }

  String _formatFolderPath(
    String folderId,
    Map<String, _FolderRecordLike> folderMap,
  ) {
    final names = <String>[];
    var current = folderMap[folderId];
    final visited = <String>{};

    while (current != null && visited.add(current.folderId)) {
      final name = current.name.isNotEmpty ? current.name : current.folderId;

      names.insert(0, name);

      final parentId = current.parentId;

      current = parentId == null || parentId.isEmpty
          ? null
          : folderMap[parentId];
    }

    if (names.isEmpty) {
      return 'Root';
    }

    return ['Root', ...names].join(' / ');
  }

  // ===============================================================
  // OPEN FOLDER
  // ===============================================================

  Future<void> _openCollectionTab(
    BuildContext context,
    _FolderSearchResult result,
  ) async {
    final folderHymnIds = List<String>.from(result.folderHymnIds);

    if (folderHymnIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hymns are available in this folder yet.'),
          ),
        );
      }

      return;
    }

    // The hymn which matched the search becomes the primary hymn.
    final primaryHymnId = folderHymnIds.contains(result.hymnId)
        ? result.hymnId
        : folderHymnIds.first;

    final orderedHymnIds = List<String>.from(folderHymnIds);

    if (orderedHymnIds.contains(primaryHymnId)) {
      orderedHymnIds.remove(primaryHymnId);
      orderedHymnIds.insert(0, primaryHymnId);
    } else {
      orderedHymnIds.insert(0, primaryHymnId);
    }

    final newTab = CollectionTab(
      id: 'collection_${widget.collection}_${result.folderId}_${DateTime.now().millisecondsSinceEpoch}',
      folderName: result.folderName,
      primaryHymnId: primaryHymnId,
      hymnIds: orderedHymnIds,
      displayTitle: '${result.folderName} ($primaryHymnId)',
    );

    final workspaceState = context
        .findAncestorStateOfType<HymnCollectionWorkspaceState>();

    if (workspaceState != null) {
      workspaceState.openTab(newTab);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(result.folderName)),
            body: HymnCollectionWorkspace(initialTabs: [newTab]),
          ),
        ),
      );
    }
  }
}

// ===============================================================
// DATA CLASSES
// ===============================================================

class _FolderRecordLike {
  const _FolderRecordLike({
    required this.folderId,
    required this.name,
    required this.parentId,
  });

  final String folderId;
  final String name;
  final String? parentId;
}

class _CollectionItemRecord {
  const _CollectionItemRecord({
    required this.folderId,
    required this.hymnId,
    required this.sortOrder,
  });

  final String folderId;
  final String hymnId;
  final int sortOrder;
}

class _FolderSearchResult {
  const _FolderSearchResult({
    required this.docId,
    required this.displayName,
    required this.title,
    required this.pathLabel,
    required this.path,
    required this.hymnId,
    required this.folderId,
    required this.folderName,
    required this.folderHymnIds,
  });

  final String docId;
  final String displayName;
  final String title;
  final String pathLabel;
  final List<String> path;
  final String hymnId;
  final String folderId;
  final String folderName;
  final List<String> folderHymnIds;
}
