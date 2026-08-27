import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../feature/home/hymn/app_initializer.dart';
import '../feature/home/hymn/hymn_master_sync_service.dart';
import '../feature/home/hymn/hymn_models.dart';
import '../feature/home/hymn/hymn_section_parser.dart';
import '../feature/home/hymn/widgets/hymn_viewer_widget.dart';

class CollectionLanguageContent {
  final String label;
  final String lyrics;

  const CollectionLanguageContent({required this.label, required this.lyrics});
}

List<CollectionLanguageContent> buildCollectionLanguageContent(LocalHymn hymn) {
  final entries = <CollectionLanguageContent>[];

  final hindiLyrics = hymn.hindiLyrics?.trim() ?? '';
  if (hindiLyrics.isNotEmpty) {
    entries.add(CollectionLanguageContent(label: 'Hindi', lyrics: hindiLyrics));
  }

  final malayalamLyrics = hymn.malayalamLyrics?.trim() ?? '';
  if (malayalamLyrics.isNotEmpty) {
    entries.add(
      CollectionLanguageContent(label: 'Malayalam', lyrics: malayalamLyrics),
    );
  }

  final englishLyrics = hymn.englishLyrics?.trim() ?? '';
  if (englishLyrics.isNotEmpty) {
    entries.add(CollectionLanguageContent(label: 'English', lyrics: englishLyrics));
  }

  if (entries.isEmpty && hymn.originalLyrics.trim().isNotEmpty) {
    entries.add(
      CollectionLanguageContent(label: 'Original', lyrics: hymn.originalLyrics),
    );
  }

  return entries;
}

enum CollectionDisplayMode {
  displayAll,
  displayIntro,
  displayChorus,
  displayVerse,
  collapseAll,
}

extension CollectionDisplayModeLabel on CollectionDisplayMode {
  String get label {
    switch (this) {
      case CollectionDisplayMode.displayAll:
        return 'Display All';
      case CollectionDisplayMode.displayIntro:
        return 'Display Intro';
      case CollectionDisplayMode.displayChorus:
        return 'Display Chorus';
      case CollectionDisplayMode.displayVerse:
        return 'Display Verse';
      case CollectionDisplayMode.collapseAll:
        return 'Collapse All';
    }
  }
}

class CollectionTab {
  final String id;
  final String folderName;
  final String primaryHymnId;
  final List<String> hymnIds;
  final String? displayTitle;
  final CollectionDisplayMode? displayMode;

  CollectionTab({
    required this.id,
    required this.folderName,
    required this.primaryHymnId,
    required this.hymnIds,
    this.displayTitle,
    this.displayMode,
  });
}

class CollectionHymnLayout {
  final LocalHymn primaryHymn;
  final List<LocalHymn> otherHymns;

  const CollectionHymnLayout({
    required this.primaryHymn,
    required this.otherHymns,
  });
}

CollectionHymnLayout splitCollectionHymnsForDisplay({
  required List<LocalHymn> hymns,
  required String primaryHymnId,
}) {
  if (hymns.isEmpty) {
    throw StateError('Cannot split an empty hymn list.');
  }

  final primaryHymn = hymns.firstWhere(
    (hymn) => hymn.hymnId == primaryHymnId,
    orElse: () => hymns.first,
  );
  final otherHymns = hymns
      .where((hymn) => hymn.hymnId != primaryHymn.hymnId)
      .toList();

  return CollectionHymnLayout(primaryHymn: primaryHymn, otherHymns: otherHymns);
}

class HymnCollectionWorkspace extends StatefulWidget {
  final List<CollectionTab> initialTabs;
  final VoidCallback? onEmpty;
  final Future<void> Function(String hymnId)? onOpenHymn;

  const HymnCollectionWorkspace({
    super.key,
    required this.initialTabs,
    this.onEmpty,
    this.onOpenHymn,
  });

  static String titleForTab(CollectionTab tab) {
    final explicitTitle = tab.displayTitle?.trim();
    if (explicitTitle != null && explicitTitle.isNotEmpty) {
      return explicitTitle;
    }
    return tab.primaryHymnId;
  }

  @override
  HymnCollectionWorkspaceState createState() => HymnCollectionWorkspaceState();
}

class HymnCollectionWorkspaceState extends State<HymnCollectionWorkspace> {
  static CollectionDisplayMode lastDisplayMode =
      CollectionDisplayMode.displayChorus;

  late List<CollectionTab> _tabs;
  int _activeTabIndex = 0;

  // Default display mode set to Display Chorus
  CollectionDisplayMode _displayMode = CollectionDisplayMode.displayChorus;

  final ValueNotifier<double> _lyricsScaleNotifier = ValueNotifier<double>(1.0);
  final Map<String, Future<List<LocalHymn>>> _hymnFutures = {};

  // Track closed languages per hymn for dual-language layout
  final Map<String, Set<String>> _closedLanguages = {};

  @override
  void initState() {
    super.initState();
    _tabs = List<CollectionTab>.from(widget.initialTabs);
    if (_tabs.isNotEmpty) {
      _displayMode =
          _tabs.first.displayMode ?? HymnCollectionWorkspaceState.lastDisplayMode;
    }
  }

  @override
  void didUpdateWidget(covariant HymnCollectionWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabs != oldWidget.initialTabs) {
      _tabs = List<CollectionTab>.from(widget.initialTabs);
      _hymnFutures.clear(); // Clear cache to refetch updated hymn references
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = (_tabs.length - 1).clamp(0, 0);
      }
    }
  }

  void openTab(CollectionTab tab) {
    final existingIndex = _tabs.indexWhere((item) => item.id == tab.id);
    setState(() {
      if (existingIndex >= 0) {
        _activeTabIndex = existingIndex;
      } else {
        _tabs.add(tab);
        _activeTabIndex = _tabs.length - 1;
      }

      if (tab.displayMode != null) {
        _displayMode = tab.displayMode!;
      }
    });
  }

  Future<List<LocalHymn>> _fetchHymnsForTab(CollectionTab tab) async {
    final allHymns = await AppInitializer.isar.localHymns.where().findAll();
    final hymnMap = {for (final hymn in allHymns) hymn.hymnId: hymn};
    final hydrated = <String, LocalHymn>{};

    for (final rawId in tab.hymnIds) {
      final hymnId = rawId.trim();
      if (hymnId.isEmpty) continue;

      var hymn = hymnMap[hymnId];
      if (hymn == null) {
        hymn = await _fetchMissingHymn(hymnId);
      }
      if (hymn != null) {
        hydrated[hymnId] = hymn;
      }
    }

    final result = tab.hymnIds
        .map((id) => hydrated[id.trim()])
        .whereType<LocalHymn>()
        .toList();
    debugPrint(
      'Workspace opened: source=collection folder=${tab.folderName} '
      'selected=${tab.primaryHymnId} collectionSize=${tab.hymnIds.length} '
      'primary=${result.any((hymn) => hymn.hymnId == tab.primaryHymnId)} '
      'secondaryCount=${math.max(0, result.length - 1)} '
      'displayMode=${tab.displayMode?.label ?? 'Display Chorus'}',
    );
    return result;
  }

  Future<LocalHymn?> _fetchMissingHymn(String hymnId) async {
    final firestore = FirebaseFirestore.instance;
    DocumentSnapshot<Map<String, dynamic>>? snapshot;
    try {
      snapshot = await firestore.collection('hymns').doc(hymnId).get(
        const GetOptions(source: Source.cache),
      );
    } catch (_) {
      // Continue to the bounded server fallback after a cache miss.
    }

    try {
      if (snapshot == null || !snapshot.exists) {
        snapshot = await firestore.collection('hymns').doc(hymnId).get(
          const GetOptions(source: Source.serverAndCache),
        ).timeout(const Duration(seconds: 3));
      }
      if (!snapshot.exists) {
        debugPrint('Isar lookup result: missing hymn $hymnId');
        return null;
      }

      final hymn = HymnMasterSyncService.toLocalHymn(hymnId, snapshot.data());
      await AppInitializer.isar.writeTxn(
        () => AppInitializer.isar.localHymns.putByHymnId(hymn),
      );
      debugPrint('Isar lookup result: hydrated hymn $hymnId from Firestore');
      return hymn;
    } catch (error, stackTrace) {
      debugPrint('Failed to hydrate hymn $hymnId: $error');
      debugPrint('$stackTrace');
      return null;
    }
  }

  void _selectTab(int index) {
    if (_activeTabIndex == index) return;
    setState(() {
      _activeTabIndex = index;
    });
  }

  Future<void> _selectSearchedHymn(String hymnId) async {
    final hymn = await AppInitializer.isar.localHymns
        .filter()
        .hymnIdEqualTo(hymnId)
        .findFirst();
    if (hymn == null || !mounted || _tabs.isEmpty) return;

    final tab = _tabs[_activeTabIndex];
    final orderedIds = <String>[
      hymnId,
      ...tab.hymnIds.where((id) => id != hymnId),
    ];
    setState(() {
      _tabs[_activeTabIndex] = CollectionTab(
        id: tab.id,
        folderName: tab.folderName,
        primaryHymnId: hymnId,
        hymnIds: orderedIds,
        displayTitle: tab.displayTitle,
        displayMode: _displayMode,
      );
      _hymnFutures.remove(tab.id);
    });
  }

  void _reorderTabs(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() {
      final tab = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, tab);
      if (_activeTabIndex == oldIndex) {
        _activeTabIndex = newIndex;
      } else if (oldIndex < _activeTabIndex && newIndex >= _activeTabIndex) {
        _activeTabIndex -= 1;
      } else if (oldIndex > _activeTabIndex && newIndex <= _activeTabIndex) {
        _activeTabIndex += 1;
      }
    });
  }

  void _closeTabAt(int index) {
    if (_tabs.isEmpty || index < 0 || index >= _tabs.length) return;

    var becameEmpty = false;
    setState(() {
      _tabs.removeAt(index);
      _hymnFutures.removeWhere((key, _) => !_tabs.any((tab) => tab.id == key));
      if (_tabs.isEmpty) {
        becameEmpty = true;
        return;
      }

      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      } else if (index < _activeTabIndex) {
        _activeTabIndex -= 1;
      }

      _activeTabIndex = _activeTabIndex.clamp(0, _tabs.length - 1);
    });

    if (becameEmpty) widget.onEmpty?.call();
  }

  void _updateMode(CollectionDisplayMode mode) {
    setState(() {
      _displayMode = mode;
    });
    HymnCollectionWorkspaceState.lastDisplayMode = mode;
  }

  void _toggleLanguageClosed(String hymnId, String label) {
    setState(() {
      _closedLanguages.putIfAbsent(hymnId, () => <String>{});
      if (_closedLanguages[hymnId]!.contains(label)) {
        _closedLanguages[hymnId]!.remove(label);
      } else {
        _closedLanguages[hymnId]!.add(label);
      }
    });
  }

  @override
  void dispose() {
    _lyricsScaleNotifier.dispose();
    super.dispose();
  }

  List<HymnSection> _getSectionsForMode(
    List<HymnSection> sections,
    CollectionDisplayMode mode,
  ) {
    switch (mode) {
      case CollectionDisplayMode.displayAll:
        return sections;
      case CollectionDisplayMode.displayIntro:
        return sections
            .where((section) => section.sectionType == HymnSectionType.intro)
            .toList();
      case CollectionDisplayMode.displayChorus:
        return sections
            .where(
              (section) =>
                  section.sectionType == HymnSectionType.chorus ||
                  section.sectionType == HymnSectionType.refrain,
            )
            .toList();
      case CollectionDisplayMode.displayVerse:
        return sections
            .where((section) => section.sectionType == HymnSectionType.verse)
            .toList();
      case CollectionDisplayMode.collapseAll:
        return const <HymnSection>[];
    }
  }

  Widget _buildTabBar() {
    return SizedBox(
      height: 58,
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        buildDefaultDragHandles: false,
        onReorder: _reorderTabs,
        children: List<Widget>.generate(_tabs.length, (index) {
          final tab = _tabs[index];
          final title = HymnCollectionWorkspace.titleForTab(tab);
          final isActive = index == _activeTabIndex;
          return Container(
            key: ValueKey(tab.id),
            margin: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _selectTab(index),
              borderRadius: BorderRadius.circular(12),
              child: Chip(
                backgroundColor: isActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    title,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                avatar: ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle,
                    size: 18,
                    color: isActive
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _closeTabAt(index),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStickyHeader() {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            PopupMenuButton<CollectionDisplayMode>(
              initialValue: _displayMode,
              onSelected: _updateMode,
              itemBuilder: (context) => CollectionDisplayMode.values
                  .map(
                    (mode) => PopupMenuItem<CollectionDisplayMode>(
                      value: mode,
                      child: Text(mode.label),
                    ),
                  )
                  .toList(),
              child: Row(
                children: [
                  const Icon(Icons.filter_list),
                  const SizedBox(width: 8),
                  Text(
                    _displayMode.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _closeTabAt(_activeTabIndex),
              tooltip: 'Close collection',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryHymn(LocalHymn primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'PRIMARY HYMN',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.1,
              ),
            ),
          ),
          SizedBox(
            height: math.max(
              360,
              MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical,
            ),
            child: HymnViewerWidget(
              initialHymnId: primary.hymnId,
              hymnIds: [primary.hymnId],
              initialHymn: primary,
              initialHymns: [primary],
              mode: ViewerMode.displayAll,
              onSearchResultSelected: _selectSearchedHymn,
              onOpenSearchResult: widget.onOpenHymn,
              lyricsScaleNotifier: _lyricsScaleNotifier,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherHymnCard(LocalHymn hymn) {
    final languageContents = buildCollectionLanguageContent(hymn);
    final closedSet = _closedLanguages[hymn.hymnId] ?? const <String>{};

    return ValueListenableBuilder<double>(
      valueListenable: _lyricsScaleNotifier,
      builder: (context, scale, child) {
        final activeLanguages = languageContents
            .where((content) => !closedSet.contains(content.label))
            .toList();

        final bodyWidgets = <Widget>[];

        if (languageContents.isNotEmpty) {
          bodyWidgets.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: activeLanguages.map((content) {
                final langSections = HymnSectionParser.parse(content.lyrics);
                final langDisplaySections = _getSectionsForMode(
                  langSections,
                  _displayMode,
                );

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              content.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Close ${content.label}',
                              onPressed: () =>
                                  _toggleLanguageClosed(hymn.hymnId, content.label),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (langDisplaySections.isNotEmpty)
                          ..._buildSectionWidgets(langDisplaySections, scale)
                        else
                          Text(
                            _displayMode == CollectionDisplayMode.collapseAll
                                ? 'Collapsed'
                                : 'No matching section.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: math.max(14.0, 16.0 * scale),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );

          if (closedSet.isNotEmpty) {
            bodyWidgets.add(
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: closedSet.map((langLabel) {
                    return ActionChip(
                      label: Text('Show $langLabel'),
                      avatar: const Icon(Icons.add, size: 16),
                      onPressed: () =>
                          _toggleLanguageClosed(hymn.hymnId, langLabel),
                    );
                  }).toList(),
                ),
              ),
            );
          }
        } else {
          bodyWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No translations available for this hymn.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: math.max(14.0, 16.0 * scale),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hymn.title.isNotEmpty ? hymn.title : hymn.hymnId,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: math.max(14.0, 18.0 * scale),
                ),
              ),
              const SizedBox(height: 8),
              ...bodyWidgets,
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSectionWidgets(List<HymnSection> sections, double scale) {
    if (sections.isEmpty) return const <Widget>[];

    return sections.map((section) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.headingLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
                fontSize: math.max(14.0, 16.0 * scale),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              section.lyrics,
              style: TextStyle(
                height: 1.4,
                fontSize: math.max(14.0, 16.0 * scale),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildTabContent(CollectionTab tab) {
    final hymnFuture = _hymnFutures.putIfAbsent(
      tab.id,
      () => _fetchHymnsForTab(tab),
    );
    return FutureBuilder<List<LocalHymn>>(
      key: ValueKey('collection-content-${tab.id}'),
      future: hymnFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Failed to load collection: ${snapshot.error}'),
            ),
          );
        }

        final hymns = snapshot.data ?? const <LocalHymn>[];
        if (hymns.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No hymns available in this collection.'),
            ),
          );
        }

        final layout = splitCollectionHymnsForDisplay(
          hymns: hymns,
          primaryHymnId: tab.primaryHymnId,
        );
        final primaryHymn = layout.primaryHymn;
        final otherHymns = layout.otherHymns;

        return Column(
          children: [
            _buildStickyHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPrimaryHymn(primaryHymn),
                    if (otherHymns.isNotEmpty) ...[
                      const Divider(height: 1, thickness: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          'Remaining Hymns',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      ...otherHymns.map(_buildOtherHymnCard),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: IndexedStack(
              index: _activeTabIndex,
              children: _tabs.map(_buildTabContent).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
