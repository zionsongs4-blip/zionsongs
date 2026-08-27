import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feature/home/hymn/app_initializer.dart';
import '../feature/home/hymn/hymn_auth_service.dart';
import '../feature/home/hymn/hymn_models.dart';
import '../feature/home/hymn/viewlist_medley_models.dart';
import '../feature/home/search/home_search_controller.dart';
import '../feature/home/search/home_search_models.dart';
import '../feature/home/search/search_service.dart';
import '../feature/home/repositories/folder_repository.dart';
import '../services/clipboard_service.dart';
import '../utils/folder_name_utils.dart';
import '../utils/folder_navigation_utils.dart';
import '../feature/home/home_page/home_page.dart';

class FolderDocScreen extends StatefulWidget {
  final String collection;
  final String docId;
  final String? docName;
  final List<String>? initialPath;
  final String? initialHighlightHymnId;
  final void Function(String hymnId, List<String> hymnIds, String? folderName)?
  onOpenCollection;

  const FolderDocScreen({
    super.key,
    required this.collection,
    required this.docId,
    this.docName,
    this.initialPath,
    this.initialHighlightHymnId,
    this.onOpenCollection,
  });

  @override
  State<FolderDocScreen> createState() => _FolderDocScreenState();
}

class _FolderDocScreenState extends State<FolderDocScreen> {
  final _repo = FolderRepository();
  final _clipboard = ClipboardService.instance;
  final ScrollController _treeScrollController = ScrollController();
  final ScrollController _treeHorizontalScrollController = ScrollController();
  final Map<String, GlobalKey> _treeItemKeys = <String, GlobalKey>{};
  final Set<String> _expandedFolders = <String>{};
  final Map<String, String> _folderLabels = <String, String>{};
  final List<_BreadcrumbItem> _breadcrumbs = [];
  late final String collection;
  late final String docId;
  List<String> _currentPath = const <String>[];
  List<String> _selectedPath = const <String>[];
  double _treePaneWidth = 280;
  final List<_HistoryEntry> _undoStack = <_HistoryEntry>[];
  final List<_HistoryEntry> _redoStack = <_HistoryEntry>[];
  final ScrollController _contentScrollController = ScrollController();
  final Map<String, GlobalKey> _hymnItemKeys = <String, GlobalKey>{};
  String _searchText = '';
  late final TextEditingController _searchController;
  late final HomeSearchController _searchSuggestionsController;
  bool _showSearchResultList = false;
  HomeSearchResult? _selectedSearchHymn;
  HomeSearchResult? _searchResultToRestore;
  bool _returnToSearchResults = false;
  final double _minPaneWidth = 0.0;
  bool _treePaneVisible = true;
  String? _highlightedHymnId;
  Timer? _highlightTimer;

  // Scoped search state for View List/Medley hierarchy
  Set<String> _scopedHymnIds = <String>{};
  List<_ScopedSearchResult> _scopedSearchResults =
      const <_ScopedSearchResult>[];
  Timer? _scopedSearchDebounce;

  @override
  void initState() {
    super.initState();
    collection = widget.collection;
    docId = widget.docId;
    _searchController = TextEditingController();
    _searchSuggestionsController = SearchService.instance.controller
      ..addListener(_onSearchSuggestionsChanged);
    _contentScrollController.addListener(_persistNavigationState);
    _treeScrollController.addListener(_persistNavigationState);
    _treeHorizontalScrollController.addListener(_persistNavigationState);
    _breadcrumbs.add(
      _BreadcrumbItem(
        label: getCollectionDisplayName(collection),
        path: const <String>[],
      ),
    );
    if (widget.docName != null && widget.docName!.isNotEmpty) {
      _breadcrumbs.add(
        _BreadcrumbItem(label: widget.docName!, path: const <String>[]),
      );
    }

    _expandedFolders.add(_pathKey(const <String>[]));

    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      _currentPath = List<String>.from(widget.initialPath!);
      _selectedPath = List<String>.from(widget.initialPath!);
      if (widget.docName != null && widget.docName!.isNotEmpty) {
        _folderLabels[_pathKey(_currentPath)] = widget.docName!;
      }
      _breadcrumbs.clear();
      _breadcrumbs.addAll(_buildBreadcrumbs(_currentPath));
      _expandedFolders.add(_pathKey(_currentPath));
      for (var index = 0; index < _currentPath.length; index++) {
        _expandedFolders.add(_pathKey(_currentPath.sublist(0, index + 1)));
      }
    }

    unawaited(_restoreNavigationState());
    unawaited(_initializeScopedSearch());

    if (widget.initialHighlightHymnId != null &&
        widget.initialHighlightHymnId!.isNotEmpty) {
      _highlightedHymnId = widget.initialHighlightHymnId;
      _scheduleHighlightClear();
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scopedSearchDebounce?.cancel();
    _searchController.dispose();
    _searchSuggestionsController.removeListener(_onSearchSuggestionsChanged);
    _contentScrollController.removeListener(_persistNavigationState);
    _treeScrollController.removeListener(_persistNavigationState);
    _treeHorizontalScrollController.removeListener(_persistNavigationState);
    _contentScrollController.dispose();
    _treeScrollController.dispose();
    _treeHorizontalScrollController.dispose();
    super.dispose();
  }

  void _onSearchSuggestionsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPath.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _currentPath.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBack,
                )
              : null,
          title: Text(_buildCurrentTitle()),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
              onPressed: _undoStack.isEmpty ? null : _undoLastAction,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
              onPressed: _redoStack.isEmpty ? null : _redoLastAction,
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: _treePaneVisible
                  ? Builder(
                      builder: (context) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        const minContentWidth = 220.0;
                        const minPaneWidth = 120.0;
                        final maxPaneAllowed = math.max(
                          0.0,
                          screenWidth - minContentWidth,
                        );
                        final effectivePaneWidth = math.min(
                          math.max(_treePaneWidth, minPaneWidth),
                          math.max(minPaneWidth, maxPaneAllowed),
                        );

                        return Row(
                          children: [
                            SizedBox(
                              width: effectivePaneWidth,
                              child: _buildFolderTreePane(),
                            ),
                            _buildDivider(),
                            Expanded(child: _buildContentPane()),
                          ],
                        );
                      },
                    )
                  : _buildContentPane(),
            ),
            if (!_treePaneVisible)
              Positioned(
                left: 12,
                bottom: 24,
                child: FloatingActionButton.small(
                  heroTag: 'restore-explorer',
                  onPressed: _restoreExplorer,
                  child: const Icon(Icons.folder_open),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.create_new_folder),
          onPressed: () => _createFolder(_currentPath),
        ),
      ),
    );
  }

  Widget _buildFolderTreePane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Folders',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Collapse',
                icon: const Icon(Icons.close),
                onPressed: _collapseExplorer,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        Expanded(child: _buildTreeRoot()),
      ],
    );
  }

  Widget _buildTreeRoot() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getFolderCollectionRef(const <String>[]).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        return Scrollbar(
          controller: _treeHorizontalScrollController,
          thumbVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _treeHorizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _treeContentWidth,
              child: Scrollbar(
                controller: _treeScrollController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.vertical,
                child: ListView(
                  controller: _treeScrollController,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    _buildTreeNode(
                      path: const <String>[],
                      label: getCollectionDisplayName(collection),
                      depth: 0,
                      isRoot: true,
                      docs: docs,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double get _treeContentWidth {
    var longestLabelLength = getCollectionDisplayName(collection).length;
    var deepestPath = 0;

    for (final entry in _folderLabels.entries) {
      longestLabelLength = math.max(longestLabelLength, entry.value.length);
      deepestPath = math.max(deepestPath, entry.key.split('/').length);
    }

    final contentWidth = longestLabelLength * 9.0 + deepestPath * 16.0 + 100.0;
    final screenWidth = MediaQuery.of(context).size.width;
    const minPaneWidth = 120.0;
    const minReported = 320.0;
    final maxPaneAllowed = math.max(0.0, screenWidth - 220.0);
    final effectivePaneWidth = math.min(
      math.max(_treePaneWidth, minPaneWidth),
      math.max(minPaneWidth, maxPaneAllowed),
    );

    return math.max(effectivePaneWidth, math.max(minReported, contentWidth));
  }

  double get _effectivePaneWidth {
    final screenWidth = MediaQuery.of(context).size.width;
    const minContentWidth = 220.0;
    const minPaneWidth = 120.0;
    final maxPaneAllowed = math.max(0.0, screenWidth - minContentWidth);
    return math.min(
      math.max(_treePaneWidth, minPaneWidth),
      math.max(minPaneWidth, maxPaneAllowed),
    );
  }

  Widget _buildTreeNode({
    required List<String> path,
    required String label,
    required int depth,
    required bool isRoot,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  }) {
    final pathKey = _pathKey(path);
    final isExpanded = isRoot || _expandedFolders.contains(pathKey);
    final isSelected = _samePath(_selectedPath, path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: _treeItemKeys.putIfAbsent(pathKey, () => GlobalKey()),
          onTap: () => _selectFolder(path, label),
          child: Padding(
            padding: EdgeInsets.only(left: depth * 16.0, top: 4, bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: docs.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                          ),
                          onPressed: () => _toggleFolder(pathKey, path),
                          tooltip: isExpanded ? 'Collapse' : 'Expand',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 24,
                            height: 24,
                          ),
                        )
                      : null,
                ),
                Icon(
                  Icons.folder_open,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleFolderAction(value, path),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'new_folder',
                      child: Text('New Folder'),
                    ),
                    const PopupMenuItem(
                      value: 'new_subfolder',
                      child: Text('New Subfolder'),
                    ),
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(value: 'copy', child: Text('Copy')),
                    const PopupMenuItem(value: 'cut', child: Text('Cut')),
                    const PopupMenuItem(value: 'move', child: Text('Move')),
                    PopupMenuItem(
                      value: 'paste',
                      enabled: _clipboard.hasEntry(),
                      child: const Text('Paste'),
                    ),
                    const PopupMenuItem(
                      value: 'add_hymn',
                      child: Text('Add Hymn'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && docs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Column(
              children: docs.map((childDoc) {
                final childId = childDoc.id;
                final childData = childDoc.data();
                final childName = childData['name']?.toString() ?? 'Untitled';
                _folderLabels[_pathKey([...path, childId])] = childName;
                return _buildChildNode(childDoc, path, depth + 1);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildChildNode(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<String> parentPath,
    int depth,
  ) {
    final folderId = doc.id;
    final folderData = doc.data();
    final name = folderData['name']?.toString() ?? folderId;
    final hymnIds = _safeStringKeyedMap(folderData['hymnIds'], 'hymnIds');
    final countLabel = hymnIds.isNotEmpty ? ' (${hymnIds.length})' : ' (0)';
    final childPath = [...parentPath, folderId];
    final childFoldersRef = _getFolderCollectionRef(childPath);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: childFoldersRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        if (!snapshot.hasData) return const SizedBox.shrink();
        final childDocs = snapshot.data!.docs;
        _folderLabels[_pathKey(childPath)] = name;
        return _buildTreeNode(
          path: childPath,
          label: '$name$countLabel',
          depth: depth,
          isRoot: false,
          docs: childDocs,
        );
      },
    );
  }

  Widget _buildDivider() {
    final screenWidth = MediaQuery.of(context).size.width;
    const minPaneWidth = 120.0;
    const minContentWidth = 220.0;
    final maxPaneWidth = (screenWidth - minContentWidth).clamp(
      minPaneWidth,
      screenWidth,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          setState(() {
            final updatedWidth = (_treePaneWidth + details.delta.dx).clamp(
              _minPaneWidth,
              maxPaneWidth,
            );
            if (updatedWidth <= 0) {
              _treePaneVisible = false;
              _treePaneWidth = 0;
            } else {
              _treePaneWidth = updatedWidth;
            }
          });
        },
        child: Container(
          width: 10,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Future<void> _initializeScopedSearch() async {
    final collected = <String>{};
    await _collectHymnIdsRecursive(const <String>[], collected);
    if (mounted) {
      setState(() {
        _scopedHymnIds = collected;
      });
    }
  }

  Future<void> _collectHymnIdsRecursive(
    List<String> path,
    Set<String> collected,
  ) async {
    try {
      if (path.isNotEmpty) {
        final snapshot = await _getFolderDocRef(
          path,
        ).get(const GetOptions(source: Source.cache));
        final docSnap = snapshot.exists
            ? snapshot
            : await _getFolderDocRef(
                path,
              ).get(const GetOptions(source: Source.serverAndCache));
        if (docSnap.exists) {
          final data = docSnap.data()!;
          final hymnIdsMap = _safeStringKeyedMap(data['hymnIds'], 'hymnIds');
          collected.addAll(hymnIdsMap.keys);
        }
      } else {
        if (docId != 'root') {
          final docRef = FirebaseFirestore.instance
              .collection(collection)
              .doc(docId);
          var docSnap = await docRef.get(
            const GetOptions(source: Source.cache),
          );
          if (!docSnap.exists) {
            docSnap = await docRef.get(
              const GetOptions(source: Source.serverAndCache),
            );
          }
          if (docSnap.exists) {
            final data = docSnap.data()!;
            final hymnIdsMap = _safeStringKeyedMap(data['hymnIds'], 'hymnIds');
            collected.addAll(hymnIdsMap.keys);
          }
        }
      }

      final childSnapshot = await _getFolderCollectionRef(
        path,
      ).get(const GetOptions(source: Source.cache));
      final docs = childSnapshot.docs.isNotEmpty
          ? childSnapshot.docs
          : (await _getFolderCollectionRef(
              path,
            ).get(const GetOptions(source: Source.serverAndCache))).docs;

      for (final childDoc in docs) {
        final childPath = [...path, childDoc.id];
        final childData = childDoc.data();
        final childHymnIds = _safeStringKeyedMap(
          childData['hymnIds'],
          'hymnIds',
        );
        collected.addAll(childHymnIds.keys);

        await _collectHymnIdsRecursive(childPath, collected);
      }
    } catch (_) {}
  }

  Future<void> _performScopedSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _scopedSearchResults = [];
        });
      }
      return;
    }

    final normalizedQuery = query.toLowerCase().trim();
    final isar = AppInitializer.isar;

    try {
      final allHymns = await isar.localHymns.where().findAll();
      final results = <_ScopedSearchResult>[];

      for (final hymn in allHymns) {
        if (_scopedHymnIds.isNotEmpty &&
            !_scopedHymnIds.contains(hymn.hymnId)) {
          continue;
        }

        if (_matchesScopedSearch(hymn, normalizedQuery)) {
          results.add(
            _ScopedSearchResult(
              hymnId: hymn.hymnId,
              title: hymn.title,
              suggestion: _getSuggestionFromHymn(hymn, normalizedQuery),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _scopedSearchResults = results;
        });
      }
    } catch (_) {}
  }

  bool _matchesScopedSearch(LocalHymn hymn, String normalizedQuery) {
    if (hymn.title.toLowerCase().contains(normalizedQuery)) return true;
    if (hymn.originalLyrics.toLowerCase().contains(normalizedQuery))
      return true;
    if ((hymn.englishLyrics ?? '').toLowerCase().contains(normalizedQuery))
      return true;
    if ((hymn.hindiLyrics ?? '').toLowerCase().contains(normalizedQuery))
      return true;
    if ((hymn.malayalamLyrics ?? '').toLowerCase().contains(normalizedQuery))
      return true;
    if ((hymn.searchText ?? '').toLowerCase().contains(normalizedQuery))
      return true;
    return false;
  }

  String _getSuggestionFromHymn(LocalHymn hymn, String query) {
    if (hymn.title.toLowerCase().contains(query)) {
      return hymn.title;
    }

    final lyricsToSearch = [
      hymn.originalLyrics,
      hymn.englishLyrics ?? '',
      hymn.hindiLyrics ?? '',
      hymn.malayalamLyrics ?? '',
    ].join(' ').toLowerCase();

    final index = lyricsToSearch.indexOf(query);
    if (index >= 0) {
      final start = math.max(0, index - 30);
      final end = math.min(lyricsToSearch.length, index + query.length + 30);
      return lyricsToSearch.substring(start, end).trim();
    }

    return hymn.title;
  }

  Widget _buildContentPane() {
    return Column(
      children: [
        _buildBreadcrumbBar(),
        _buildSearchField(),
        Expanded(child: _buildCurrentFolderView()),
      ],
    );
  }

  Widget _buildBreadcrumbBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_breadcrumbs.length, (index) {
            final item = _breadcrumbs[index];
            final isLast = index == _breadcrumbs.length - 1;
            return Row(
              children: [
                TextButton(
                  onPressed: isLast ? null : () => _jumpToBreadcrumb(index),
                  child: Text(item.label),
                ),
                if (!isLast) const Text('>'),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final scopedSuggestions = _scopedSearchResults
        .map((r) => r.suggestion)
        .toSet()
        .toList()
        .take(8)
        .toList();
    final showSuggestions =
        _searchText.trim().isNotEmpty &&
        !_showSearchResultList &&
        _selectedSearchHymn == null &&
        scopedSuggestions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search hymns in this collection...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value;
                _selectedSearchHymn = null;
                _showSearchResultList = false;
              });
              _scopedSearchDebounce?.cancel();
              _scopedSearchDebounce = Timer(
                const Duration(milliseconds: 300),
                () => _performScopedSearch(value),
              );
            },
          ),
          if (showSuggestions)
            Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: scopedSuggestions.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final suggestion = scopedSuggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        suggestion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          _showSearchResultList = true;
                          _selectedSearchHymn = null;
                          _searchText = suggestion;
                          _searchController.text = suggestion;
                          _searchController.selection = TextSelection.collapsed(
                            offset: suggestion.length,
                          );
                        });
                        _performScopedSearch(suggestion);
                      },
                    );
                  },
                ),
              ),
            ),
          if (_showSearchResultList)
            Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _scopedSearchResults.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _scopedSearchResults[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        result.title.isNotEmpty ? result.title : result.hymnId,
                      ),
                      onTap: () => _selectScopedSearchResult(result),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectScopedSearchResult(_ScopedSearchResult result) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchText = result.title;
      _searchController.text = _searchText;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
      _showSearchResultList = false;
      _scopedSearchResults = const <_ScopedSearchResult>[];
    });

    await _showSearchLocationsForHymn(result.hymnId);
  }

  Future<void> _showSearchLocationsForHymn(String hymnId) async {
    final locations = await _searchLocationsForHymnScoped(hymnId);
    if (!mounted) return;
    setState(() {
      if (locations.isNotEmpty) {
        _selectedSearchHymn = HomeSearchResult(
          srNo: hymnId,
          title: locations[0].title,
          suggestion: locations[0].title,
        );
      }
    });
  }

  Future<List<_CollectionSearchResult>> _searchLocationsForHymnScoped(
    String hymnId,
  ) async {
    final folders = <_SearchFolderRecord>[];
    final items = <_SearchItemRecord>[];

    if (collection == 'viewlists') {
      final folderRecords = await AppInitializer.isar.viewListFolderRecords
          .where()
          .findAll();
      final itemRecords = await AppInitializer.isar.viewListItemRecords
          .where()
          .findAll();
      folders.addAll(
        folderRecords.map(
          (r) => _SearchFolderRecord(
            folderId: r.folderId,
            name: r.name,
            parentId: r.parentId,
          ),
        ),
      );
      items.addAll(
        itemRecords.map(
          (r) => _SearchItemRecord(folderId: r.folderId, hymnId: r.hymnId),
        ),
      );
    } else {
      final folderRecords = await AppInitializer.isar.medleyFolderRecords
          .where()
          .findAll();
      final itemRecords = await AppInitializer.isar.medleyItemRecords
          .where()
          .findAll();
      folders.addAll(
        folderRecords.map(
          (r) => _SearchFolderRecord(
            folderId: r.folderId,
            name: r.name,
            parentId: r.parentId,
          ),
        ),
      );
      items.addAll(
        itemRecords.map(
          (r) => _SearchItemRecord(folderId: r.folderId, hymnId: r.hymnId),
        ),
      );
    }

    final folderMap = <String, _SearchFolderRecord>{
      for (final folder in folders)
        if (_belongsToCurrentCollection(folder.folderId))
          folder.folderId: folder,
    };

    final collectionItems = items
        .where((item) => _belongsToCurrentCollection(item.folderId))
        .toList();
    final hymnIdsByFolder = <String, List<String>>{};
    for (final item in collectionItems) {
      hymnIdsByFolder.putIfAbsent(item.folderId, () => []).add(item.hymnId);
    }

    final hymn = await AppInitializer.isar.localHymns
        .filter()
        .hymnIdEqualTo(hymnId)
        .findFirst();
    if (hymn == null) return const <_CollectionSearchResult>[];

    final results = <_CollectionSearchResult>[];
    for (final item in collectionItems) {
      if (item.hymnId != hymnId) continue;
      final folder = folderMap[item.folderId];
      if (folder == null) continue;

      final path = _buildSearchFolderPath(folder, folderMap);
      results.add(
        _CollectionSearchResult(
          hymnId: hymn.hymnId,
          title: hymn.title.isNotEmpty ? hymn.title : hymn.hymnId,
          path: path,
          pathLabel: _formatCollectionPath(path, folderMap),
          folderName: folder.name,
          hymnIds: hymnIdsByFolder[item.folderId] ?? <String>[hymn.hymnId],
        ),
      );
    }
    return results;
  }

  String _formatCollectionPath(
    List<String> path,
    Map<String, _SearchFolderRecord> folderMap,
  ) {
    final names = <String>[];
    for (final folderId in path) {
      final folder = folderMap[folderId];
      if (folder == null) continue;
      names.add(folder.name.isNotEmpty ? folder.name : folder.folderId);
    }
    if (names.isEmpty) {
      return getCollectionDisplayName(collection);
    }
    return [getCollectionDisplayName(collection), ...names].join(' / ');
  }

  Widget _buildCurrentFolderView() {
    if (_selectedSearchHymn != null) {
      return _buildCollectionSearchResults();
    }

    if (_searchText.trim().isNotEmpty) {
      return const Center(
        child: Text('Select a hymn suggestion to see its locations.'),
      );
    }

    final currentPath = _currentPath;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getFolderCollectionRef(currentPath).snapshots(),
      builder: (context, folderSnapshot) {
        if (folderSnapshot.hasError || !folderSnapshot.hasData) {
          return _buildOfflineFolderContent();
        }

        final childFolders = folderSnapshot.data!.docs;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: currentPath.isEmpty
              ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
              : _getFolderDocRef(currentPath).snapshots(),
          builder: (context, folderDocSnapshot) {
            if (folderDocSnapshot.hasError ||
                (!folderDocSnapshot.hasData && currentPath.isNotEmpty)) {
              return _buildOfflineFolderContent();
            }
            if (folderDocSnapshot.hasData &&
                currentPath.isNotEmpty &&
                !folderDocSnapshot.data!.exists) {
              return const Center(child: Text('This folder no longer exists.'));
            }

            final data = currentPath.isEmpty
                ? const <String, dynamic>{}
                : (folderDocSnapshot.data?.data() ?? const <String, dynamic>{});
            final hymnIds = _safeStringKeyedMap(data['hymnIds'], 'hymnIds');
            final hymnOrder = _safeStringList(data['hymnOrder'], 'hymnOrder');
            final orderedHymns = _getOrderedHymnIds(hymnIds, hymnOrder);

            return ListView(
              controller: _contentScrollController,
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                MediaQuery.of(context).viewInsets.bottom +
                    kMinInteractiveDimension * 4,
              ),
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Hymn'),
                      onPressed: () => _addHymn(_currentPath),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.content_paste),
                      label: const Text('Paste'),
                      onPressed: _clipboard.hasEntry()
                          ? () => _pasteFolder(_currentPath)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (childFolders.isNotEmpty) ...[
                  const Text(
                    'Subfolders',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...childFolders.map((doc) => _buildRightFolderCard(doc)),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('No subfolders in this location.'),
                  ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildSongsSection(orderedHymns),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineFolderContent() {
    return FutureBuilder<List<String>>(
      future: _loadLocalFolderHymnIds(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load local folder: ${snapshot.error}'),
          );
        }

        final hymnIds = snapshot.data ?? const <String>[];
        return ListView(
          controller: _contentScrollController,
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.of(context).viewInsets.bottom +
                kMinInteractiveDimension * 4,
          ),
          children: [
            const SizedBox(height: 8),
            Text(
              '${_buildCurrentTitle()} (${hymnIds.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildSongsSection(hymnIds),
          ],
        );
      },
    );
  }

  Future<List<String>> _loadLocalFolderHymnIds() async {
    final folderId = buildRelationshipFolderKey(
      collection,
      docId,
      _currentPath,
    );
    final ids = <String>[];

    if (collection == 'medleys') {
      final records = await AppInitializer.isar.medleyItemRecords
          .where()
          .findAll();
      records.removeWhere(
        (record) =>
            record.folderId != folderId ||
            !isVisibleRelationshipUser(
              recordUserId: record.userId,
              activeUserId: AuthService.userId,
            ),
      );
      records.sort(
        (a, b) => a.sortOrder != b.sortOrder
            ? a.sortOrder.compareTo(b.sortOrder)
            : a.hymnId.compareTo(b.hymnId),
      );
      ids.addAll(records.map((record) => record.hymnId));
    } else {
      final records = await AppInitializer.isar.viewListItemRecords
          .where()
          .findAll();
      records.removeWhere(
        (record) =>
            record.folderId != folderId ||
            !isVisibleRelationshipUser(
              recordUserId: record.userId,
              activeUserId: AuthService.userId,
            ),
      );
      records.sort(
        (a, b) => a.sortOrder != b.sortOrder
            ? a.sortOrder.compareTo(b.sortOrder)
            : a.hymnId.compareTo(b.hymnId),
      );
      ids.addAll(records.map((record) => record.hymnId));
    }

    final uniqueIds = uniqueIdsPreservingOrder(ids);
    debugPrint(
      'Offline folder load: collection=$collection docId=$docId '
      'path=${_currentPath.join(' > ')} songCount=${uniqueIds.length}',
    );
    return uniqueIds;
  }

  Widget _buildSongsSection(List<String> hymnIds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const SizedBox(width: 26),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Songs (${hymnIds.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (hymnIds.isEmpty)
          const Text('No hymns in this folder.')
        else
          _buildHymnList(hymnIds),
      ],
    );
  }

  Widget _buildCollectionSearchResults() {
    return FutureBuilder<List<_CollectionSearchResult>>(
      future: _searchLocationsForHymnScoped(_selectedSearchHymn!.srNo),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Search failed: ${snapshot.error}'));
        }

        final results = snapshot.data ?? const <_CollectionSearchResult>[];
        if (results.isEmpty) {
          return const Center(child: Text('No matching hymns found.'));
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.of(context).viewInsets.bottom +
                kMinInteractiveDimension * 4,
          ),
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              title: Text(result.folderName),
              subtitle: Text(result.title),
              leading: const Icon(Icons.folder_outlined),
              onTap: () => _navigateToSearchFolder(result),
              trailing: IconButton(
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: 'Navigate to folder',
                onPressed: () => _navigateToSearchFolder(result),
              ),
            );
          },
        );
      },
    );
  }

  bool _belongsToCurrentCollection(String relationshipKey) {
    final parsed = parseRelationshipFolderKey(relationshipKey);
    return parsed.collection == collection && parsed.docId == docId;
  }

  List<String> _buildSearchFolderPath(
    _SearchFolderRecord folder,
    Map<String, _SearchFolderRecord> folderMap,
  ) {
    return parseRelationshipFolderKey(folder.folderId).path;
  }

  void _navigateToSearchFolder(_CollectionSearchResult result) {
    _searchResultToRestore = _selectedSearchHymn;
    _selectFolder(result.path, result.folderName);
    setState(() {
      _returnToSearchResults = true;
      _selectedSearchHymn = null;
      _searchText = '';
      _searchController.clear();
    });
    _searchSuggestionsController.clear();
  }

  Widget _buildHymnList(List<String> hymnIds) {
    return FutureBuilder<List<_HymnDisplayItem>>(
      future: _loadHymnDisplayItems(hymnIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final items = snapshot.data ?? const <_HymnDisplayItem>[];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final highlightedId = _highlightedHymnId;
          if (highlightedId == null || highlightedId.isEmpty) return;
          final key = _hymnItemKeys[highlightedId];
          final context = key?.currentContext;
          if (context != null) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.2,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });

        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          onReorder: (oldIndex, newIndex) async {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final updated = List<String>.from(hymnIds);
            final item = updated.removeAt(oldIndex);
            updated.insert(newIndex, item);
            await _repo.reorderHymns(collection, docId, _currentPath, updated);
          },
          itemBuilder: (context, index) {
            final item = items[index];
            final isHighlighted =
                _highlightedHymnId != null && item.id == _highlightedHymnId;
            return AnimatedContainer(
              key: ValueKey('hymn-${item.id}-$index'),
              duration: const Duration(milliseconds: 250),
              decoration: isHighlighted
                  ? BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              child: Column(
                children: [
                  ListTile(
                    key: _hymnItemKeys.putIfAbsent(item.id, () => GlobalKey()),
                    leading: SizedBox(
                      width: 48,
                      child: Text(
                        '${index + 1}.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    title: Text(
                      item.title.isNotEmpty ? item.title : 'Untitled hymn',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) =>
                              _handleHymnAction(action, item.id),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'copy',
                              child: Text('Copy'),
                            ),
                            const PopupMenuItem(
                              value: 'cut',
                              child: Text('Cut'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _openHymnInWorkspace(item.id, hymnIds),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRightFolderCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final folderId = doc.id;
    final folderData = doc.data();
    final name = folderData['name']?.toString() ?? folderId;
    final childPath = [..._currentPath, folderId];
    final isSelected = _samePath(_selectedPath, childPath);

    final entry = _clipboard.peek();
    final isCutTarget =
        entry?.kind == 'folder' &&
        entry?.isCut == true &&
        entry?.id == folderId &&
        entry != null &&
        _listsEqual(entry.path, _currentPath);
    return Draggable<List<String>>(
      data: childPath,
      feedback: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220),
          child: ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(name),
          ),
        ),
      ),
      child: DragTarget<List<String>>(
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) async {
          final destinationPath = childPath;
          final confirmed = await _confirmMove('Move folder to ${name}?');
          if (!confirmed) return;
          await _repo.moveFolder(
            collection,
            docId,
            details.data,
            destinationPath,
          );
          _clipboard.clear();
          _pushHistory(
            _HistoryEntry(
              kind: 'folder',
              action: 'move',
              fromPath: details.data,
              toPath: destinationPath,
            ),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Folder moved.')));
        },
        builder: (context, candidateData, rejectedData) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: Opacity(
            opacity: isCutTarget ? 0.55 : 1,
            child: InkWell(
              onTap: () => _selectFolder(childPath, name),
              onDoubleTap: () => _openFolder(childPath, name),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        softWrap: true,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: _effectivePaneWidth < 140 ? 12 : 14,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) =>
                          _handleFolderAction(value, childPath),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'new_folder',
                          child: Text('New Folder'),
                        ),
                        const PopupMenuItem(
                          value: 'new_subfolder',
                          child: Text('New Subfolder'),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                        const PopupMenuItem(value: 'copy', child: Text('Copy')),
                        const PopupMenuItem(value: 'cut', child: Text('Cut')),
                        const PopupMenuItem(value: 'move', child: Text('Move')),
                        PopupMenuItem(
                          value: 'paste',
                          enabled: _clipboard.hasEntry(),
                          child: const Text('Paste'),
                        ),
                        const PopupMenuItem(
                          value: 'add_hymn',
                          child: Text('Add Hymn'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openHymnInWorkspace(
    String hymnId, [
    List<String>? hymnIds,
  ]) async {
    List<String> effectiveHymnIds = hymnIds != null
        ? List<String>.from(hymnIds)
        : [];

    final localRelationshipHymnIds = await _loadLocalRelationshipHymnIds();
    if (localRelationshipHymnIds.contains(hymnId)) {
      effectiveHymnIds = localRelationshipHymnIds;
    }

    if (effectiveHymnIds.isEmpty) {
      try {
        if (_currentPath.isNotEmpty) {
          final folderDocRef = _getFolderDocRef(_currentPath);
          var folderDoc = await folderDocRef.get(
            const GetOptions(source: Source.cache),
          );
          if (!folderDoc.exists) {
            folderDoc = await folderDocRef.get(
              const GetOptions(source: Source.serverAndCache),
            );
          }
          if (folderDoc.exists) {
            final data = folderDoc.data()!;
            final hymnIdsMap = _safeStringKeyedMap(data['hymnIds'], 'hymnIds');
            final hymnOrder = _safeStringList(data['hymnOrder'], 'hymnOrder');
            effectiveHymnIds = _getOrderedHymnIds(hymnIdsMap, hymnOrder);
          }
        } else if (docId != 'root') {
          final docRef = FirebaseFirestore.instance
              .collection(collection)
              .doc(docId);
          var docSnap = await docRef.get(
            const GetOptions(source: Source.cache),
          );
          if (!docSnap.exists) {
            docSnap = await docRef.get(
              const GetOptions(source: Source.serverAndCache),
            );
          }
          if (docSnap.exists) {
            final data = docSnap.data()!;
            final hymnIdsMap = _safeStringKeyedMap(data['hymnIds'], 'hymnIds');
            final hymnOrder = _safeStringList(data['hymnOrder'], 'hymnOrder');
            effectiveHymnIds = _getOrderedHymnIds(hymnIdsMap, hymnOrder);
          }
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Collection membership fallback failed: collection=$collection '
          'docId=$docId path=${_currentPath.join(' > ')} error=$error',
        );
        debugPrint('$stackTrace');
      }
    }

    if (effectiveHymnIds.isEmpty) {
      effectiveHymnIds = [hymnId];
    } else {
      effectiveHymnIds.remove(hymnId);
      effectiveHymnIds.insert(0, hymnId);
    }

    if (widget.onOpenCollection != null) {
      widget.onOpenCollection!(hymnId, effectiveHymnIds, _buildCurrentTitle());
      return;
    }

    final homeState = context.findAncestorStateOfType<State<HomePage>>();
    if (homeState != null) {
      (homeState as dynamic)._openCollectionHymnWorkspace(
        hymnId,
        effectiveHymnIds,
        folderName: _buildCurrentTitle(),
      );
      return;
    }

    try {
      final root = WidgetsBinding.instance.renderViewElement;
      State? found;
      void visitor(Element element) {
        if (found != null) return;
        if (element is StatefulElement &&
            element.state.runtimeType.toString().contains('_HomePageState')) {
          found = element.state;
          return;
        }
        element.visitChildElements(visitor);
      }

      if (root != null) root.visitChildElements(visitor);

      if (found != null) {
        (found as dynamic)._openCollectionHymnWorkspace(
          hymnId,
          effectiveHymnIds,
          folderName: _buildCurrentTitle(),
        );
        return;
      }
    } catch (error, stackTrace) {
      debugPrint('Collection workspace lookup failed: error=$error');
      debugPrint('$stackTrace');
    }

    widget.onOpenCollection?.call(
      hymnId,
      effectiveHymnIds,
      _buildCurrentTitle(),
    );
  }

  Future<List<String>> _loadLocalRelationshipHymnIds() async {
    final folderId = buildRelationshipFolderKey(
      collection,
      docId,
      _currentPath,
    );

    if (collection == 'medleys') {
      final records = await AppInitializer.isar.medleyItemRecords
          .where()
          .findAll();
      records
        ..removeWhere(
          (record) => !isVisibleRelationshipUser(
            recordUserId: record.userId,
            activeUserId: AuthService.userId,
          ),
        )
        ..removeWhere((record) => record.folderId != folderId)
        ..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order != 0 ? order : a.hymnId.compareTo(b.hymnId);
        });
      return records.map((record) => record.hymnId).toList();
    }

    final records = await AppInitializer.isar.viewListItemRecords
        .where()
        .findAll();
    records
      ..removeWhere(
        (record) => !isVisibleRelationshipUser(
          recordUserId: record.userId,
          activeUserId: AuthService.userId,
        ),
      )
      ..removeWhere((record) => record.folderId != folderId)
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.hymnId.compareTo(b.hymnId);
      });
    return records.map((record) => record.hymnId).toList();
  }

  Future<void> _handleFolderAction(String action, List<String> path) async {
    switch (action) {
      case 'new_folder':
        await _createFolder(path);
        break;
      case 'new_subfolder':
        await _createSubfolder(path);
        break;
      case 'rename':
        await _renameFolder(path);
        break;
      case 'copy':
        _copyFolder(path);
        break;
      case 'cut':
        _cutFolder(path);
        break;
      case 'paste':
        await _pasteFolder(path);
        break;
      case 'move':
        await _moveFolder(path);
        break;
      case 'add_hymn':
        await _addHymn(path);
        break;
    }
  }

  Future<bool> _confirmMove(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move item'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _promptForText(String title) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) {
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    final trimmed = result?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : null;
  }

  Future<void> _createFolder(List<String> path) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final name = await _promptForText('Folder name');
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    try {
      final folderId = await _generateUniqueFolderId(name, path);
      await _repo.createFolder(collection, docId, path, folderId, name);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Folder created.')),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Create folder failed: $e')),
      );
    }
  }

  Future<void> _createSubfolder(List<String> path) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final name = await _promptForText('Subfolder name');
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    try {
      final folderId = await _generateUniqueFolderId(name, path);
      await _repo.createFolder(collection, docId, path, folderId, name);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Subfolder created.')),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Create subfolder failed: $e')),
      );
    }
  }

  Future<void> _renameFolder(List<String> path) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final name = await _promptForText('New name');
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    try {
      await _repo.renameFolder(collection, docId, path, name);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Folder renamed.')),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Rename failed: $e')),
      );
    }
  }

  void _copyFolder(List<String> path) {
    if (path.isEmpty) return;
    final folderId = path.last;
    final parentPath = path.sublist(0, path.length - 1);
    final name = _folderLabels[_pathKey(path)] ?? _friendlyNameForPath(path);
    _clipboard.copyFolder(collection, docId, parentPath, folderId, name);
  }

  void _cutFolder(List<String> path) {
    if (path.isEmpty) return;
    final folderId = path.last;
    final parentPath = path.sublist(0, path.length - 1);
    final name = _folderLabels[_pathKey(path)] ?? _friendlyNameForPath(path);
    _clipboard.cutFolder(collection, docId, parentPath, folderId, name);
  }

  Future<void> _pasteFolder(List<String> path) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final entry = _clipboard.peek();
    if (entry == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Nothing is copied or cut.')),
      );
      return;
    }
    if (!mounted) return;
    try {
      if (entry.kind == 'hymn_selection') {
        final selectedHymnIds = entry.hymnIds
            .where((hymnId) => hymnId.trim().isNotEmpty)
            .toList();
        if (selectedHymnIds.isEmpty) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('No hymns were selected.')),
          );
          return;
        }

        final folderDoc = await _getFolderDocRef(path).get();
        if (!folderDoc.exists) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('This folder no longer exists.')),
          );
          return;
        }

        final existingHymnIds = _safeStringKeyedMap(
          folderDoc.data()?['hymnIds'],
          'hymnIds',
        );

        for (final hymnId in selectedHymnIds) {
          if (existingHymnIds.containsKey(hymnId)) continue;
          await _repo.addHymnToFolder(collection, docId, path, hymnId);
        }

        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Hymns added to folder.')),
        );
        return;
      }

      final sourcePath = [...entry.path, entry.id];
      if (entry.kind == 'folder') {
        if (entry.docId == docId && entry.collection == collection) {
          if (entry.isCut) {
            await _repo.moveFolder(collection, docId, sourcePath, path);
            _clipboard.clear();
            _pushHistory(
              _HistoryEntry(
                kind: 'folder',
                action: 'move',
                fromPath: sourcePath,
                toPath: path,
              ),
            );
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Folder moved.')),
            );
          } else {
            await _repo.copyFolder(collection, docId, sourcePath, path);
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Folder copied.')),
            );
          }
        } else {
          if (entry.isCut) {
            await _repo.moveFolderBetweenDocs(
              entry.collection,
              entry.docId,
              sourcePath,
              collection,
              docId,
              path,
            );
            _clipboard.clear();
            _pushHistory(
              _HistoryEntry(
                kind: 'folder',
                action: 'move',
                fromPath: sourcePath,
                toPath: path,
              ),
            );
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Folder moved.')),
            );
          } else {
            await _repo.copyFolderBetweenDocs(
              entry.collection,
              entry.docId,
              sourcePath,
              collection,
              docId,
              path,
            );
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Folder copied.')),
            );
          }
        }
      } else {
        if (entry.docId == docId && entry.collection == collection) {
          if (entry.isCut) {
            await _repo.moveHymnBetweenFolders(
              collection,
              docId,
              entry.path,
              entry.id,
              path,
            );
            _clipboard.clear();
            _pushHistory(
              _HistoryEntry(
                kind: 'hymn',
                action: 'move',
                fromPath: entry.path,
                toPath: path,
                itemId: entry.id,
              ),
            );
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Hymn moved.')),
            );
          } else {
            await _repo.copyHymnBetweenFolders(
              collection,
              docId,
              entry.path,
              entry.id,
              path,
            );
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Hymn copied.')),
            );
          }
        } else {
          if (entry.isCut) {
            await _repo.moveHymnBetweenDocs(
              entry.collection,
              entry.docId,
              entry.path,
              entry.id,
              collection,
              docId,
              path,
            );
            _clipboard.clear();
            _pushHistory(
              _HistoryEntry(
                kind: 'hymn',
                action: 'move',
                fromPath: entry.path,
                toPath: path,
                itemId: entry.id,
              ),
            );
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Hymn moved.')),
            );
          } else {
            await _repo.copyHymnBetweenDocs(
              entry.collection,
              entry.docId,
              entry.path,
              entry.id,
              collection,
              docId,
              path,
            );
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Hymn copied.')),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Paste failed: $e')),
      );
    }
  }

  Future<void> _moveFolder(List<String> path) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final entry = _clipboard.peek();
    if (entry == null || !entry.isCut) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Cut a folder or hymn first to move it.')),
      );
      return;
    }
    final confirmed = await _confirmMove('Move ${entry.name} to this folder?');
    if (!confirmed) return;
    await _pasteFolder(path);
  }

  Future<void> _addHymn(List<String> path) async {
    await _showSmartHymnPicker(path);
  }

  void _handleHymnAction(String action, String hymnId) {
    switch (action) {
      case 'copy':
        _clipboard.copyHymn(collection, docId, _currentPath, hymnId, hymnId);
        break;
      case 'cut':
        _clipboard.cutHymn(collection, docId, _currentPath, hymnId, hymnId);
        break;
    }
    if (_clipboard.hasEntry()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hymn copied to clipboard.')),
      );
    }
  }

  Future<void> _showSmartHymnPicker(List<String> path) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final suggestions = <LocalHymn>[];
    String? message;

    final allHymns = await AppInitializer.isar.localHymns.where().findAll();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateSuggestions(String query) {
              final trimmed = query.trim();
              if (trimmed.isEmpty) {
                setDialogState(() {
                  suggestions.clear();
                  message = null;
                });
                return;
              }

              final lower = trimmed.toLowerCase();
              final filtered = allHymns
                  .where((hymn) => _matchesPickerQuery(hymn, lower))
                  .take(200)
                  .toList();

              setDialogState(() {
                suggestions
                  ..clear()
                  ..addAll(filtered);
                message = null;
              });
            }

            const rowHeight = 52.0;
            final maxListHeight = MediaQuery.of(context).size.height * 0.45;

            return AlertDialog(
              title: const Text('Add Hymn'),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Search hymn ID or text',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => updateSuggestions(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Add',
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final selected = suggestions.isNotEmpty
                                ? suggestions.first
                                : null;
                            if (selected == null) {
                              setDialogState(() {
                                message = 'Search for a hymn first.';
                              });
                              return;
                            }

                            final folderDoc = await _getFolderDocRef(
                              path,
                            ).get();
                            final hymnIds = _safeStringKeyedMap(
                              folderDoc.data()?['hymnIds'],
                              'hymnIds',
                            );
                            if (hymnIds.containsKey(selected.hymnId)) {
                              setDialogState(() {
                                message =
                                    'This hymn is already in this folder.';
                              });
                              return;
                            }

                            try {
                              await _repo.addHymnToFolder(
                                collection,
                                docId,
                                path,
                                selected.hymnId,
                              );
                              if (!mounted) return;
                              setDialogState(() {
                                controller.clear();
                                suggestions.clear();
                                message = 'Hymn added. Continue adding.';
                              });
                              focusNode.requestFocus();
                              setState(() {});
                            } catch (e) {
                              setDialogState(() {
                                message = 'Add hymn failed: $e';
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        message!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: rowHeight * 5,
                        maxHeight: maxListHeight,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(),
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom +
                                rowHeight * 4,
                          ),
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final hymn = suggestions[index];
                            final serial = _parseSerialFromHymn(hymn) ?? '';
                            return InkWell(
                              onTap: () async {
                                final folderDoc = await _getFolderDocRef(
                                  path,
                                ).get();
                                final hymnIds = _safeStringKeyedMap(
                                  folderDoc.data()?['hymnIds'],
                                  'hymnIds',
                                );
                                if (hymnIds.containsKey(hymn.hymnId)) {
                                  setDialogState(() {
                                    message =
                                        'This hymn is already in this folder.';
                                  });
                                  return;
                                }

                                try {
                                  await _repo.addHymnToFolder(
                                    collection,
                                    docId,
                                    path,
                                    hymn.hymnId,
                                  );
                                  if (!mounted) return;
                                  setDialogState(() {
                                    controller.clear();
                                    suggestions.clear();
                                    message = 'Hymn added. Continue adding.';
                                  });
                                  focusNode.requestFocus();
                                  setState(() {});
                                } catch (e) {
                                  setDialogState(() {
                                    message = 'Add hymn failed: $e';
                                  });
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        serial,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        hymn.title.isNotEmpty
                                            ? hymn.title
                                            : 'Untitled hymn',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _generateUniqueFolderId(String name, List<String> path) async {
    final baseId = buildFolderId(name);
    String candidateId = baseId;
    int counter = 2;
    final currentRef = _getFolderCollectionRef(path);
    while (true) {
      final doc = await currentRef.doc(candidateId).get();
      if (!doc.exists) return candidateId;
      candidateId = '${baseId}_$counter';
      counter++;
    }
  }

  CollectionReference<Map<String, dynamic>> _getFolderCollectionRef(
    List<String> path,
  ) {
    final db = FirebaseFirestore.instance;
    CollectionReference<Map<String, dynamic>> ref;

    if (docId == 'root') {
      ref = db
          .collection(collection)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => Map<String, dynamic>.from(
              snap.data() ?? const <String, dynamic>{},
            ),
            toFirestore: (data, _) => data,
          );
    } else {
      ref = db
          .collection(collection)
          .doc(docId)
          .collection('folders')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => Map<String, dynamic>.from(
              snap.data() ?? const <String, dynamic>{},
            ),
            toFirestore: (data, _) => data,
          );
    }
    for (final folderId in path) {
      ref = ref
          .doc(folderId)
          .collection('folders')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => Map<String, dynamic>.from(
              snap.data() ?? const <String, dynamic>{},
            ),
            toFirestore: (data, _) => data,
          );
    }
    return ref;
  }

  DocumentReference<Map<String, dynamic>> _getFolderDocRef(List<String> path) {
    if (path.isEmpty) throw ArgumentError('Path cannot be empty');
    final folderId = path.last;
    final parentPath = path.sublist(0, path.length - 1);
    return _getFolderCollectionRef(parentPath)
        .doc(folderId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => Map<String, dynamic>.from(
            snap.data() ?? const <String, dynamic>{},
          ),
          toFirestore: (data, _) => data,
        );
  }

  Future<List<_HymnDisplayItem>> _loadHymnDisplayItems(
    List<String> hymnIds,
  ) async {
    final items = <_HymnDisplayItem>[];
    for (final hymnId in hymnIds) {
      final hymn = await AppInitializer.isar.localHymns
          .filter()
          .hymnIdEqualTo(hymnId)
          .findFirst();
      final title = hymn?.title.isNotEmpty == true ? hymn!.title : hymnId;
      items.add(_HymnDisplayItem(id: hymnId, title: title));
    }
    return items;
  }

  List<String> _getOrderedHymnIds(
    Map<String, dynamic> hymnIds,
    List<String> hymnOrder,
  ) {
    final ordered = <String>[];
    for (final hymnId in hymnOrder) {
      if (hymnIds.containsKey(hymnId)) ordered.add(hymnId);
    }
    for (final key in hymnIds.keys) {
      if (!ordered.contains(key)) ordered.add(key.toString());
    }
    return ordered;
  }

  Map<String, dynamic> _safeStringKeyedMap(Object? value, String context) {
    if (value == null) return <String, dynamic>{};
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }

  List<String> _safeStringList(Object? value, String context) {
    if (value == null) return <String>[];
    if (value is List) {
      return value
          .map((entry) => entry.toString())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  Future<void> _restoreNavigationState() async {
    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      await _persistNavigationState();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString(_storageKey());
    if (stateJson == null || stateJson.isEmpty) {
      if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
        await _persistNavigationState();
      }
      return;
    }

    try {
      final decoded = jsonDecode(stateJson);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final savedPath = List<String>.from(decoded['path'] ?? const <String>[]);
      final savedExpanded = List<String>.from(
        decoded['expandedPaths'] ?? const <String>[],
      );
      final savedSelectedPath = List<String>.from(
        decoded['selectedPath'] ?? const <String>[],
      );
      final savedContentOffset =
          (decoded['contentOffset'] as num?)?.toDouble() ?? 0.0;
      final savedTreeOffset =
          (decoded['treeOffset'] as num?)?.toDouble() ?? 0.0;
      final savedTreeHorizontalOffset =
          (decoded['treeHorizontalOffset'] as num?)?.toDouble() ?? 0.0;

      if (savedPath.isNotEmpty) {
        final isValid = await _pathExists(savedPath);
        if (!isValid) {
          await _clearNavigationState();
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _currentPath = savedPath;
        _selectedPath = savedSelectedPath.isNotEmpty
            ? savedSelectedPath
            : savedPath;
        _expandedFolders
          ..clear()
          ..add(_pathKey(const <String>[]));
        for (final path in savedExpanded.where((item) => item.isNotEmpty)) {
          if (path.isNotEmpty) {
            _expandedFolders.add(path);
          }
        }
        if (savedPath.isNotEmpty) {
          _expandedFolders.add(_pathKey(savedPath));
          for (var index = 0; index < savedPath.length; index++) {
            _expandedFolders.add(_pathKey(savedPath.sublist(0, index + 1)));
          }
        }
        _breadcrumbs.clear();
        _breadcrumbs.addAll(_buildBreadcrumbs(_currentPath));
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_contentScrollController.hasClients) {
          _contentScrollController.jumpTo(
            savedContentOffset.clamp(
              0.0,
              _contentScrollController.position.maxScrollExtent,
            ),
          );
        }
        if (_treeScrollController.hasClients) {
          _treeScrollController.jumpTo(
            savedTreeOffset.clamp(
              0.0,
              _treeScrollController.position.maxScrollExtent,
            ),
          );
        }
        if (_treeHorizontalScrollController.hasClients) {
          _treeHorizontalScrollController.jumpTo(
            savedTreeHorizontalOffset.clamp(
              0.0,
              _treeHorizontalScrollController.position.maxScrollExtent,
            ),
          );
        }
      });
    } catch (_) {
      await _clearNavigationState();
    }
  }

  Future<bool> _pathExists(List<String> path) async {
    if (path.isEmpty) return true;
    var currentPath = <String>[];
    for (final folderId in path) {
      final snapshot = await _getFolderCollectionRef(
        currentPath,
      ).doc(folderId).get();
      if (!snapshot.exists) {
        return false;
      }
      currentPath = [...currentPath, folderId];
    }
    return true;
  }

  Future<void> _persistNavigationState() async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'path': _currentPath,
      'selectedPath': _selectedPath,
      'expandedPaths': _expandedFolders
          .where((item) => item.isNotEmpty)
          .toList(),
      'contentOffset': _contentScrollController.hasClients
          ? _contentScrollController.offset
          : 0.0,
      'treeOffset': _treeScrollController.hasClients
          ? _treeScrollController.offset
          : 0.0,
      'treeHorizontalOffset': _treeHorizontalScrollController.hasClients
          ? _treeHorizontalScrollController.offset
          : 0.0,
    };
    await prefs.setString(_storageKey(), jsonEncode(state));
  }

  Future<void> _clearNavigationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey());
  }

  String _storageKey() => 'folder_nav_${collection}_${docId}';

  void _toggleFolder(String pathKey, List<String> path) {
    setState(() {
      if (_expandedFolders.contains(pathKey)) {
        _expandedFolders.remove(pathKey);
      } else {
        _expandedFolders.add(pathKey);
      }
    });
    unawaited(_persistNavigationState());
  }

  void _collapseExplorer() {
    setState(() {
      _treePaneVisible = false;
    });
  }

  void _restoreExplorer() {
    setState(() {
      _treePaneVisible = true;
      if (_treePaneWidth <= 0) {
        _treePaneWidth = 280;
      }
    });
  }

  void _selectFolder(List<String> path, String name) {
    setState(() {
      _returnToSearchResults = false;
      _selectedPath = path;
      _currentPath = path;
      _folderLabels[_pathKey(path)] = name;
      _breadcrumbs.clear();
      _breadcrumbs.addAll(_buildBreadcrumbs(path));
      _expandedFolders.add(_pathKey(path));
      for (var index = 0; index < path.length; index++) {
        _expandedFolders.add(_pathKey(path.sublist(0, index + 1)));
      }
      if (MediaQuery.of(context).size.width < 640) {
        _treePaneVisible = false;
      }
    });
    unawaited(_persistNavigationState());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _treeItemKeys[_pathKey(path)];
      final context = key?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openFolder(List<String> path, String name) {
    _selectFolder(path, name);
  }

  List<_BreadcrumbItem> _buildBreadcrumbs(List<String> path) {
    final crumbs = <_BreadcrumbItem>[
      _BreadcrumbItem(
        label: getCollectionDisplayName(collection),
        path: const <String>[],
      ),
    ];
    if (widget.docName != null && widget.docName!.isNotEmpty) {
      crumbs.add(
        _BreadcrumbItem(label: widget.docName!, path: const <String>[]),
      );
    }
    crumbs.addAll(
      List.generate(path.length, (index) {
        final prefix = path.sublist(0, index + 1);
        final label =
            _folderLabels[_pathKey(prefix)] ?? _friendlyNameForPath(prefix);
        return _BreadcrumbItem(label: label, path: prefix);
      }),
    );
    return crumbs;
  }

  String _friendlyNameForPath(List<String> path) {
    if (path.isEmpty) return getCollectionDisplayName(collection);
    return path.last.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  }

  void _jumpToBreadcrumb(int index) {
    final targetPath = _breadcrumbs[index].path;
    final label = _breadcrumbs[index].label;
    setState(() {
      _currentPath = targetPath;
      _selectedPath = targetPath;
      _breadcrumbs.clear();
      _breadcrumbs.addAll(_buildBreadcrumbs(targetPath));
      _folderLabels[_pathKey(targetPath)] = label;
    });
    unawaited(_persistNavigationState());
  }

  void _goBack() {
    if (_returnToSearchResults && _searchResultToRestore != null) {
      final result = _searchResultToRestore!;
      setState(() {
        _returnToSearchResults = false;
        _searchResultToRestore = null;
        _selectedSearchHymn = result;
        _searchText = result.title.isNotEmpty ? result.title : result.srNo;
        _searchController.text = _searchText;
        _searchController.selection = TextSelection.collapsed(
          offset: _searchController.text.length,
        );
      });
      return;
    }

    if (_currentPath.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final parentPath = _currentPath.sublist(0, _currentPath.length - 1);
    setState(() {
      _currentPath = parentPath;
      _selectedPath = parentPath;
      _breadcrumbs.clear();
      _breadcrumbs.addAll(_buildBreadcrumbs(parentPath));
    });
    unawaited(_persistNavigationState());
  }

  String _buildCurrentTitle() {
    if (_currentPath.isEmpty) {
      return widget.docName ?? getCollectionDisplayName(collection);
    }
    final label =
        _folderLabels[_pathKey(_currentPath)] ??
        _friendlyNameForPath(_currentPath);
    return label;
  }

  void _pushHistory(_HistoryEntry entry) {
    _undoStack.add(entry);
    _redoStack.clear();
  }

  Future<void> _undoLastAction() async {
    final entry = _undoStack.removeLast();
    if (entry.kind == 'folder') {
      await _repo.moveFolder(collection, docId, entry.toPath, entry.fromPath);
    } else {
      await _repo.moveHymnBetweenFolders(
        collection,
        docId,
        entry.toPath,
        entry.itemId,
        entry.fromPath,
      );
    }
    _redoStack.add(entry);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _redoLastAction() async {
    final entry = _redoStack.removeLast();
    if (entry.kind == 'folder') {
      await _repo.moveFolder(collection, docId, entry.fromPath, entry.toPath);
    } else {
      await _repo.moveHymnBetweenFolders(
        collection,
        docId,
        entry.fromPath,
        entry.itemId,
        entry.toPath,
      );
    }
    _undoStack.add(entry);
    if (!mounted) return;
    setState(() {});
  }

  void _scheduleHighlightClear() {
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        _highlightedHymnId = null;
      });
    });
  }

  bool _matchesPickerQuery(LocalHymn hymn, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final searchText = (hymn.searchText ?? '').toLowerCase();
    if (searchText.isNotEmpty && searchText.contains(normalizedQuery)) {
      return true;
    }

    final hindi = (hymn.hindiLyrics ?? '').toLowerCase();
    if (hindi.isNotEmpty && hindi.contains(normalizedQuery)) return true;

    final malay = (hymn.malayalamLyrics ?? '').toLowerCase();
    if (malay.isNotEmpty && malay.contains(normalizedQuery)) return true;

    final english = (hymn.englishLyrics ?? '').toLowerCase();
    if (english.isNotEmpty && english.contains(normalizedQuery)) return true;

    final title = hymn.title.toLowerCase();
    if (title.isNotEmpty && title.contains(normalizedQuery)) return true;

    final serial = _parseSerialFromHymn(hymn);
    if (serial != null && serial.toLowerCase().contains(normalizedQuery)) {
      return true;
    }

    return false;
  }

  String? _parseSerialFromHymn(LocalHymn hymn) {
    final id = hymn.hymnId;
    if (id.isEmpty) return null;
    final matches = RegExp(r"\d+").allMatches(id);
    if (matches.isNotEmpty) {
      final last = matches.last.group(0);
      if (last != null) return int.tryParse(last)?.toString();
    }

    final st = hymn.searchText ?? '';
    final m = RegExp(r"\b(\d{1,4})\b").firstMatch(st);
    if (m != null) return m.group(1);
    return null;
  }

  String _pathKey(List<String> path) => path.join('/');

  bool _samePath(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class _BreadcrumbItem {
  final String label;
  final List<String> path;

  const _BreadcrumbItem({required this.label, required this.path});
}

class _HymnDisplayItem {
  final String id;
  final String title;

  const _HymnDisplayItem({required this.id, required this.title});
}

class _SearchFolderRecord {
  const _SearchFolderRecord({
    required this.folderId,
    required this.name,
    required this.parentId,
  });

  final String folderId;
  final String name;
  final String? parentId;
}

class _SearchItemRecord {
  const _SearchItemRecord({required this.folderId, required this.hymnId});

  final String folderId;
  final String hymnId;
}

class _CollectionSearchResult {
  const _CollectionSearchResult({
    required this.hymnId,
    required this.title,
    required this.path,
    required this.pathLabel,
    required this.folderName,
    required this.hymnIds,
  });

  final String hymnId;
  final String title;
  final List<String> path;
  final String pathLabel;
  final String folderName;
  final List<String> hymnIds;
}

class _ScopedSearchResult {
  const _ScopedSearchResult({
    required this.hymnId,
    required this.title,
    required this.suggestion,
  });

  final String hymnId;
  final String title;
  final String suggestion;
}

class _HistoryEntry {
  final String kind;
  final String action;
  final List<String> fromPath;
  final List<String> toPath;
  final String itemId;

  const _HistoryEntry({
    required this.kind,
    required this.action,
    required this.fromPath,
    required this.toPath,
    this.itemId = '',
  });
}

bool _listsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
