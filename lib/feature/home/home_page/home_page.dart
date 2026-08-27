import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../app_bar/home_app_bar.dart';
import '../app_bar/home_app_bar_logic.dart';
import '../app_bar/home_repository_impl.dart';
import '../app_bar/home_selection_controller.dart';
import '../controller/home_filter.dart';
import '../hymn/app_initializer.dart';
import '../hymn/favorites_repository.dart';
import '../hymn/hymn_models.dart';
import 'workspace_manager.dart';
import 'workspace_tab_bar.dart';
import '../hymn/widgets/hymn_viewer_widget.dart';
import '../home_models.dart' as models;
import '../../../screens/folder_doc_screen.dart';
import '../../../screens/hymn_collection_page.dart';
import 'home_alphabet_bar.dart';
import 'home_filter_bar.dart';
import 'home_hymn_list.dart';
import 'home_navigation_drawer.dart';
import '../search/home_search_models.dart';

bool isEligibleOpenDestinationTab(WorkspaceTab tab) {
  // Never target Home tab
  if (tab.type == WorkspaceTabType.home || tab.id == 'home') {
    return false;
  }

  // Never target Continuous Viewer tab
  if (tab.type == WorkspaceTabType.hymn &&
      tab.arguments['viewerMode'] == 'continuous') {
    return false;
  }

  // Selection screens and valid standalone/collection hymn screens are eligible
  if (tab.type == WorkspaceTabType.selection) {
    return true;
  }

  if (tab.type == WorkspaceTabType.hymn) {
    final viewerMode = tab.arguments['viewerMode'];
    return viewerMode != 'continuous';
  }

  return false;
}

/// ===============================================================
/// HomePage
/// ---------------------------------------------------------------
/// Landing page of Zion Songs.
/// ===============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _itemHeight = 60.0;

  late final HomeSelectionController _selectionController;
  late final WorkspaceManager _workspaceManager;
  late final HomeAppBarLogic _appBarLogic;
  late final HomeRepositoryImpl _repository;
  late final FavoritesRepository _favoritesRepository;
  late Future<List<models.HomeHymn>> _hymnFuture;
  late final ScrollController _scrollController;
  // Layer links and keys for anchored filter dropdowns
  final LayerLink _keyLayerLink = LayerLink();
  final LayerLink _dedicatedLayerLink = LayerLink();
  final LayerLink _yearLayerLink = LayerLink();
  final LayerLink _tempoLayerLink = LayerLink();

  final GlobalKey _keyButtonKey = GlobalKey();
  final GlobalKey _dedicatedButtonKey = GlobalKey();
  final GlobalKey _yearButtonKey = GlobalKey();
  final GlobalKey _tempoButtonKey = GlobalKey();

  HomeFilter _filter = const HomeFilter();
  String _searchText = '';
  List<HomeSearchResult> _searchResults = const <HomeSearchResult>[];
  bool _collectionWorkspaceVisible = false;
  final GlobalKey<HymnCollectionWorkspaceState> _collectionWorkspaceKey =
      GlobalKey<HymnCollectionWorkspaceState>();

  WorkspaceTab get _activeWorkspace =>
      _workspaceManager.activeTab ?? _workspaceManager.tabs.first;

  List<WorkspaceTab> get activeTabs => _workspaceManager.tabs;

  void _onWorkspaceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _selectionController = HomeSelectionController();
    _workspaceManager = WorkspaceManager(
      initialTabs: [
        const WorkspaceTab(
          id: 'home',
          title: 'Home',
          type: WorkspaceTabType.home,
          closable: false,
        ),
      ],
    );
    _workspaceManager.addListener(_onWorkspaceChanged);
    _repository = HomeRepositoryImpl();
    _favoritesRepository = FavoritesRepository();
    _scrollController = ScrollController();

    _appBarLogic = HomeAppBarLogic(
      repository: _repository,
      selectionController: _selectionController,
      workspaceTabs: () => _workspaceManager.tabs,
      addSelectedToNewScreen: _onAddSelectedToNewScreen,
      showScreenSelectorDialog: _showScreenSelectorDialog,
      openSelectedHymnsToNewTab: _openSelectedHymnsToNewTab,
      addHymnsToExistingTab: _addHymnsToExistingTab,
    );

    _hymnFuture = _loadHymns();
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _workspaceManager.removeListener(_onWorkspaceChanged);
    _workspaceManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<models.HomeHymn>> _loadHymns() async {
    final hymns = await _repository.search(
      keyword: '',
      keys: _filter.keys,
      dedicated: _filter.dedicated,
      years: _filter.years,
      tempoRanges: _filter.tempoRanges,
      alphabet: _filter.alphabet,
      tab: models.HomeTab.allHymns,
    );

    final searchById = {
      for (final result in _searchResults) result.srNo: result,
    };
    final filteredHymns = _searchText.trim().isEmpty
        ? hymns
        : hymns.where((hymn) => searchById.containsKey(hymn.hymnId)).map((
            hymn,
          ) {
            final result = searchById[hymn.hymnId]!;
            return models.HomeHymn(
              hymnId: hymn.hymnId,
              serialNo: hymn.serialNo,
              pageNo: hymn.pageNo,
              title: hymn.title,
              favorite: hymn.favorite,
              key: hymn.key,
              dedicated: hymn.dedicated,
              year: hymn.year,
              tempo: hymn.tempo,
              snippet: result.snippet,
            );
          }).toList();

    final favoriteIds = await _favoritesRepository.getFavoriteIds();
    return filteredHymns.map((hymn) {
      final isFavorite = favoriteIds.contains(hymn.hymnId);
      return models.HomeHymn(
        hymnId: hymn.hymnId,
        serialNo: hymn.serialNo,
        pageNo: hymn.pageNo,
        title: hymn.title,
        favorite: isFavorite,
        key: hymn.key,
        dedicated: hymn.dedicated,
        year: hymn.year,
        tempo: hymn.tempo,
        snippet: hymn.snippet,
      );
    }).toList();
  }

  void _onSearchChanged(String text, List<HomeSearchResult> results) {
    setState(() {
      _searchText = text;
      _searchResults = results;
      _hymnFuture = _loadHymns();
    });
  }

  Future<void> _openCollectionTab(
    String hymnId,
    List<String> hymnIds,
    String? folderName,
  ) async {
    final title = await _lookupHymnTitle(hymnId);
    if (!mounted) return;

    setState(() {
      _collectionWorkspaceVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _collectionWorkspaceKey.currentState?.openTab(
        CollectionTab(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          folderName: folderName ?? 'Favorites',
          primaryHymnId: hymnId,
          hymnIds: hymnIds,
          displayTitle: title,
        ),
      );
    });
  }

  Future<void> _openHymnWorkspace(String hymnId) async {
    final currentHymnIds = await _loadCurrentFilteredHymnIds();
    if (currentHymnIds.length > 1) {
      if (_hasContinuousViewerTab()) {
        await _openStandaloneHymnWorkspace(hymnId);
      } else {
        await _openContinuousHymnWorkspace(hymnId, currentHymnIds);
      }
    } else {
      await _openStandaloneHymnWorkspace(hymnId);
    }
  }

  bool _hasContinuousViewerTab() {
    return _workspaceManager.tabs.any((tab) {
      return tab.type == WorkspaceTabType.hymn &&
          tab.arguments['viewerMode'] == 'continuous';
    });
  }

  Future<List<String>> _loadCurrentFilteredHymnIds() async {
    final hymns = await _repository.search(
      keyword: '',
      keys: _filter.keys,
      dedicated: _filter.dedicated,
      years: _filter.years,
      tempoRanges: _filter.tempoRanges,
      alphabet: _filter.alphabet,
      tab: models.HomeTab.allHymns,
    );

    if (_searchText.trim().isEmpty) {
      return hymns.map((hymn) => hymn.hymnId).toList();
    }

    final searchById = {
      for (final result in _searchResults) result.srNo: result,
    };

    return hymns
        .where((hymn) => searchById.containsKey(hymn.hymnId))
        .map((hymn) => hymn.hymnId)
        .toList();
  }

  Future<void> _openStandaloneHymnWorkspace(String hymnId) async {
    final title = await _lookupHymnTitle(hymnId);
    if (!mounted) return;

    _workspaceManager.openTab(
      WorkspaceTab(
        id: 'hymn_$hymnId',
        title: title.isNotEmpty ? title : hymnId,
        type: WorkspaceTabType.hymn,
        closable: true,
        arguments: {
          'hymnIds': [hymnId],
          'initialHymnId': hymnId,
          'viewerMode': 'standalone',
          'browsing': false,
        },
      ),
    );
  }

  Future<void> _openContinuousHymnWorkspace(
    String hymnId,
    List<String> hymnIds,
  ) async {
    if (!mounted) return;

    final effectiveHymnIds = hymnIds.isNotEmpty
        ? <String>[hymnId, ...hymnIds.where((id) => id != hymnId)]
        : <String>[hymnId];

    _workspaceManager.openTab(
      WorkspaceTab(
        id: 'continuous_${DateTime.now().millisecondsSinceEpoch}',
        title: 'continuous',
        type: WorkspaceTabType.hymn,
        closable: true,
        arguments: {
          'hymnIds': effectiveHymnIds,
          'initialHymnId': hymnId,
          'viewerMode': 'continuous',
          'browsing': true,
        },
      ),
    );
  }

  Future<void> _openCollectionHymnWorkspace(
    String hymnId,
    List<String> hymnIds, {
    String? folderName,
  }) async {
    final title = await _lookupHymnTitle(hymnId);
    if (!mounted) return;

    final effectiveHymnIds = hymnIds.isNotEmpty ? hymnIds : [hymnId];

    _workspaceManager.openTab(
      WorkspaceTab(
        id: 'collection_${DateTime.now().millisecondsSinceEpoch}',
        title: title.isNotEmpty ? title : hymnId,
        type: WorkspaceTabType.hymn,
        closable: true,
        arguments: {
          'hymnIds': effectiveHymnIds,
          'initialHymnId': hymnId,
          'primaryHymnId': hymnId,
          'folderName': folderName ?? 'Collection',
          'viewerMode': 'collection',
          'browsing': true,
        },
      ),
    );
  }

  Future<String> _lookupHymnTitle(String hymnId) async {
    final hymn = await AppInitializer.isar.localHymns
        .where()
        .hymnIdEqualTo(hymnId)
        .findFirst();
    return hymn?.title ?? '';
  }

  CollectionDisplayMode? _parseCollectionDisplayMode(String? value) {
    switch (value) {
      case 'displayIntro':
        return CollectionDisplayMode.displayIntro;
      case 'displayVerse':
        return CollectionDisplayMode.displayVerse;
      case 'displayAll':
        return CollectionDisplayMode.displayAll;
      case 'collapseAll':
        return CollectionDisplayMode.collapseAll;
      case 'displayChorus':
        return CollectionDisplayMode.displayChorus;
      default:
        return null;
    }
  }

  // ==========================================================
  // CUSTOMIZED SCREEN ACTIONS (OPEN FLOW)
  // ==========================================================

  void _onAddSelectedToNewScreen(List<String> hymnIds) {
    if (hymnIds.isEmpty) return;

    final newScreenId = 'selection_${DateTime.now().millisecondsSinceEpoch}';
    _workspaceManager.openTab(
      WorkspaceTab(
        id: newScreenId,
        title: 'Selection (${hymnIds.length})',
        type: WorkspaceTabType.selection,
        closable: true,
        arguments: {'hymnIds': hymnIds, 'displayMode': 'all'},
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Created new screen with selected hymns.')),
    );
  }

  Future<void> _openSelectedHymnsToNewTab(List<String> hymnIds) async {
    debugPrint('Open flow: creating new tab for ${hymnIds.length} hymns: $hymnIds');
    if (hymnIds.isEmpty) {
      debugPrint('Open flow stopped before tab creation: empty hymn list.');
      return;
    }

    final newTabId = 'standalone_${DateTime.now().millisecondsSinceEpoch}';
    _workspaceManager.openTab(
      WorkspaceTab(
        id: newTabId,
        title: 'Open (${hymnIds.length})',
        type: WorkspaceTabType.hymn,
        closable: true,
        arguments: {
          'hymnIds': hymnIds,
          'initialHymnId': hymnIds.first,
          'viewerMode': 'standalone',
          'browsing': false,
        },
      ),
    );
    debugPrint(
      'Open flow: new tab registered; active tab '
      '${_workspaceManager.activeTab?.id}, total tabs ${_workspaceManager.tabs.length}.',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opened selected hymns in a new tab.')),
    );
  }

  Future<void> _addHymnsToExistingTab(
    WorkspaceTab chosenTab,
    List<String> hymnIds,
  ) async {
    debugPrint(
      'Open flow: updating ${chosenTab.id}/${chosenTab.title} with $hymnIds.',
    );
    if (hymnIds.isEmpty) return;

    final existingIds = List<String>.from(
      chosenTab.arguments['hymnIds'] ?? <String>[],
    );
    final mergedIds = <String>[];
    final seenIds = <String>{};
    for (final hymnId in [...existingIds, ...hymnIds]) {
      if (seenIds.add(hymnId)) {
        mergedIds.add(hymnId);
      }
    }

    final index = _workspaceManager.tabs.indexWhere(
      (tab) => tab.id == chosenTab.id,
    );
    if (index != -1) {
      final updatedArguments = Map<String, dynamic>.from(chosenTab.arguments);
      final existingViewerMode = chosenTab.arguments['viewerMode'];

      updatedArguments['hymnIds'] = mergedIds;
      if (chosenTab.type == WorkspaceTabType.selection) {
        updatedArguments['displayMode'] =
            chosenTab.arguments['displayMode'] ?? 'all';
      } else {
        updatedArguments['initialHymnId'] = existingIds.isEmpty
            ? hymnIds.first
            : existingIds.first;
        updatedArguments['viewerMode'] = existingViewerMode ?? 'standalone';
        updatedArguments['browsing'] = false;
      }

      _workspaceManager.replaceTabAt(
        index,
        chosenTab.copyWith(arguments: updatedArguments),
      );
      _workspaceManager.activateTab(index);
      debugPrint(
        'Open flow: updated and activated ${chosenTab.id}; '
        'total tabs ${_workspaceManager.tabs.length}.',
      );
    } else {
      debugPrint(
        'Open flow failed: selected tab ${chosenTab.id} was removed '
        'before the update.',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Added to "${chosenTab.title}".')));
  }

  Future<void> _showScreenSelectorDialog(List<String> hymnIds) async {
    if (hymnIds.isEmpty) return;

    final existingScreens = _workspaceManager.tabs
        .where((tab) => tab.type == WorkspaceTabType.selection)
        .toList();

    if (existingScreens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No existing customized screens available. Create a new screen first.',
          ),
        ),
      );
      return;
    }

    final WorkspaceTab? chosenScreen = await showDialog<WorkspaceTab>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Existing Screen'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: existingScreens.length,
              itemBuilder: (context, index) {
                final screen = existingScreens[index];
                final hymnIds = List<String>.from(
                  screen.arguments['hymnIds'] ?? <String>[],
                );
                return ListTile(
                  title: Text(screen.title),
                  subtitle: Text('${hymnIds.length} hymns'),
                  onTap: () => Navigator.pop(context, screen),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );

    if (chosenScreen != null) {
      final updatedIds = <String>{
        ...List<String>.from(chosenScreen.arguments['hymnIds'] ?? <String>[]),
        ...hymnIds,
      }.toList();
      final index = _workspaceManager.tabs.indexWhere(
        (t) => t.id == chosenScreen.id,
      );
      if (index != -1) {
        _workspaceManager.replaceTabAt(
          index,
          chosenScreen.copyWith(
            arguments: {...chosenScreen.arguments, 'hymnIds': updatedIds},
          ),
        );
        _workspaceManager.activateTab(index);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to "${chosenScreen.title}" successfully!'),
        ),
      );
    }
  }

  void _onKeyTap() {
    _showAnchoredMultiSelect(
      title: 'Select Key',
      valuesFuture: _repository.getAvailableKeys(),
      selectedValues: _filter.keys,
      onSelected: (selected) {
        setState(() {
          _filter = _filter.copyWith(keys: Set<String>.from(selected));
        });

        _hymnFuture = _loadHymns();
      },
      layerLink: _keyLayerLink,
      buttonKey: _keyButtonKey,
    );
  }

  void _onDedicatedTap() {
    _showAnchoredMultiSelect(
      title: 'Select Dedicated',
      valuesFuture: _repository.getAvailableDedicated(),
      selectedValues: _filter.dedicated,
      onSelected: (selected) {
        setState(() {
          _filter = _filter.copyWith(dedicated: Set<String>.from(selected));
        });

        _hymnFuture = _loadHymns();
      },
      layerLink: _dedicatedLayerLink,
      buttonKey: _dedicatedButtonKey,
    );
  }

  void _onYearTap() {
    _showAnchoredMultiSelectInt(
      title: 'Select Year',
      valuesFuture: _repository.getAvailableYears(),
      selectedValues: _filter.years,
      onSelected: (selected) {
        setState(() {
          _filter = _filter.copyWith(years: Set<int>.from(selected));
        });

        _hymnFuture = _loadHymns();
      },
      layerLink: _yearLayerLink,
      buttonKey: _yearButtonKey,
    );
  }

  void _onResetFilters() {
    setState(() {
      _filter = const HomeFilter();
      _selectionController.clear();
    });

    _hymnFuture = _loadHymns();
  }

  Future<void> _toggleFavorite(String hymnId) async {
    final isFavorite = await _favoritesRepository.isFavorite(hymnId);
    if (isFavorite) {
      await _favoritesRepository.removeFavorite(hymnId);
    } else {
      await _favoritesRepository.addFavorite(hymnId);
    }

    if (!mounted) return;
    setState(() {
      _hymnFuture = _loadHymns();
    });
  }

  void _activateHomeWorkspace() {
    final homeIndex = _workspaceManager.findExistingTabIndex(
      WorkspaceTabType.home,
      uniqueId: 'home',
    );
    if (homeIndex >= 0) {
      _workspaceManager.activateTab(homeIndex);
    }
  }

  Future<void> _openFavoritesWorkspace() async {
    final favoriteIds = await _favoritesRepository.getFavoriteIds();
    _workspaceManager.openTab(
      WorkspaceTab(
        id: 'favorites',
        title: 'Favorites',
        type: WorkspaceTabType.favorites,
        closable: true,
        arguments: {'hymnIds': favoriteIds},
      ),
    );
  }

  void _openViewListWorkspace({
    required String collection,
    required String docId,
    required String title,
    String? primaryHymnId,
    List<String>? hymnIds,
  }) {
    _workspaceManager.openTab(
      WorkspaceTab(
        id: '${collection}_$docId',
        title: title,
        type: collection == 'medleys'
            ? WorkspaceTabType.medley
            : WorkspaceTabType.viewList,
        closable: true,
        arguments: {
          'collection': collection,
          'docId': docId,
          'primaryHymnId': primaryHymnId,
          'hymnIds': hymnIds ?? <String>[],
        },
      ),
    );
  }

  void _closeWorkspaceTab(int index) {
    _workspaceManager.closeTabAt(index);
  }

  void _openNewWorkspace() {
    // Placeholder for future tab creation logic.
  }

  Future<List<models.HomeHymn>> _loadHymnsByIds(List<String> hymnIds) async {
    final hymns = await _hymnFuture;
    final favoriteIds = await _favoritesRepository.getFavoriteIds();
    final map = {for (final hymn in hymns) hymn.hymnId: hymn};
    return hymnIds.where(map.containsKey).map((id) {
      final hymn = map[id]!;
      final isFavorite = favoriteIds.contains(hymn.hymnId);
      return models.HomeHymn(
        hymnId: hymn.hymnId,
        serialNo: hymn.serialNo,
        pageNo: hymn.pageNo,
        title: hymn.title,
        favorite: isFavorite,
        key: hymn.key,
        dedicated: hymn.dedicated,
        year: hymn.year,
        tempo: hymn.tempo,
        snippet: hymn.snippet,
      );
    }).toList();
  }

  Widget _buildWorkspaceContentForTab(WorkspaceTab workspace) {
    switch (workspace.type) {
      case WorkspaceTabType.home:
        return _buildHomeContent();
      case WorkspaceTabType.hymn:
        final viewerMode =
            workspace.arguments['viewerMode'] as String? ?? 'standalone';
        final hymnIds = List<String>.from(
          workspace.arguments['hymnIds'] ?? <String>[],
        );
        final initialHymnId =
            workspace.arguments['initialHymnId'] as String? ??
            (hymnIds.isNotEmpty ? hymnIds.first : '');
        if (viewerMode == 'collection') {
          final primaryHymnId =
              workspace.arguments['primaryHymnId'] as String? ?? initialHymnId;
          final folderName =
              workspace.arguments['folderName'] as String? ?? 'Collection';
          final displayMode = _parseCollectionDisplayMode(
            workspace.arguments['displayMode'] as String?,
          );
          return HymnCollectionWorkspace(
            key: ValueKey('collection_${workspace.id}'),
            onOpenHymn: (hymnId) => _appBarLogic.onOpenHymns(context, [hymnId]),
            initialTabs: [
              CollectionTab(
                id: workspace.id,
                folderName: folderName,
                primaryHymnId: primaryHymnId,
                hymnIds: hymnIds,
                displayTitle: workspace.title,
                displayMode: displayMode,
              ),
            ],
          );
        }
        return HymnViewerWidget(
          key: ValueKey(
            'hymn_${workspace.id}_${hymnIds.join('|')}_$initialHymnId',
          ),
          initialHymnId: initialHymnId,
          hymnIds: hymnIds,
          onOpenCollection: (hymnId, selectedHymnIds, folderName) {
            _openCollectionHymnWorkspace(
              hymnId,
              selectedHymnIds,
              folderName: folderName,
            );
          },
        );
      case WorkspaceTabType.selection:
        final hymnIds = List<String>.from(
          workspace.arguments['hymnIds'] ?? <String>[],
        );
        return FutureBuilder<List<models.HomeHymn>>(
          future: _loadHymnsByIds(hymnIds),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load selection.'));
            }
            final hymns = snapshot.data ?? <models.HomeHymn>[];
            if (hymns.isEmpty) {
              return const Center(child: Text('No hymns selected.'));
            }
            return HomeHymnList(
              hymns: hymns,
              selectionController: _selectionController,
              onOpen: (hymnId) => _openStandaloneHymnWorkspace(hymnId),
              onToggleFavorite: _toggleFavorite,
            );
          },
        );
      case WorkspaceTabType.favorites:
        final hymnIds = List<String>.from(
          workspace.arguments['hymnIds'] ?? <String>[],
        );
        return FutureBuilder<List<models.HomeHymn>>(
          future: _loadHymnsByIds(hymnIds),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load favorites.'));
            }
            final hymns = snapshot.data ?? <models.HomeHymn>[];
            if (hymns.isEmpty) {
              return const Center(child: Text('No favorite hymns yet.'));
            }
            return HomeHymnList(
              hymns: hymns,
              selectionController: _selectionController,
              onOpen: (hymnId) => _openCollectionHymnWorkspace(
                hymnId,
                hymnIds,
                folderName: 'Favorites',
              ),
              onToggleFavorite: _toggleFavorite,
            );
          },
        );
      case WorkspaceTabType.viewList:
      case WorkspaceTabType.medley:
        return FolderDocScreen(
          key: ValueKey('folder_${workspace.id}'),
          collection:
              workspace.arguments['collection'] as String? ?? 'viewlists',
          docId: workspace.arguments['docId'] as String? ?? 'root',
          docName: workspace.arguments['title'] as String? ?? workspace.title,
          onOpenCollection: (hymnId, hymnIds, folderName) {
            _openCollectionHymnWorkspace(
              hymnId,
              hymnIds,
              folderName: folderName,
            );
          },
          initialHighlightHymnId:
              workspace.arguments['primaryHymnId'] as String?,
        );
    }
  }

  Drawer _buildHomeDrawer() {
    return Drawer(
      child: HomeNavigationDrawer(
        onHome: _activateHomeWorkspace,
        onFavorites: _openFavoritesWorkspace,
        onViewLists: () => _openViewListWorkspace(
          collection: 'viewlists',
          docId: 'root',
          title: 'View Lists',
        ),
        onMedleys: () => _openViewListWorkspace(
          collection: 'medleys',
          docId: 'root',
          title: 'Medleys',
        ),
      ),
    );
  }

  void _onLetterSelected(String letter) {
    final nextAlphabet = _filter.alphabet == letter ? null : letter;

    setState(() {
      _filter = nextAlphabet == null
          ? _filter.copyWith(clearAlphabet: true)
          : _filter.copyWith(alphabet: nextAlphabet);
      _hymnFuture = _loadHymns();
    });
  }

  Widget _buildHomeContent() {
    return FutureBuilder<List<models.HomeHymn>>(
      future: _hymnFuture,
      builder: (context, snapshot) {
        final hymns = snapshot.data ?? [];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load hymns'));
        }

        if (hymns.isEmpty) {
          return const Center(child: Text('No hymns available.'));
        }

        return Row(
          children: [
            Expanded(
              child: HomeHymnList(
                hymns: hymns,
                selectionController: _selectionController,
                scrollController: _scrollController,
                onOpen: (hymnId) {
                  _openHymnWorkspace(hymnId);
                },
                onToggleFavorite: _toggleFavorite,
              ),
            ),
            HomeAlphabetBar(
              selectedLetter: _filter.alphabet,
              onLetterSelected: _onLetterSelected,
            ),
          ],
        );
      },
    );
  }

  void _onTempoTap() {
    _showAnchoredTempoSelect(
      layerLink: _tempoLayerLink,
      buttonKey: _tempoButtonKey,
    );
  }

  Future<void> _showAnchoredMultiSelect({
    required String title,
    required Future<List<String>> valuesFuture,
    required Set<String> selectedValues,
    required void Function(Set<String>) onSelected,
    required LayerLink layerLink,
    required GlobalKey buttonKey,
  }) async {
    final values = await valuesFuture;
    final selected = Set<String>.from(selectedValues);
    final searchController = TextEditingController();

    late OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => overlay.remove(),
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: layerLink,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 40),
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      final filtered = values.where((value) {
                        return value.toLowerCase().contains(
                          searchController.text.toLowerCase(),
                        );
                      }).toList();

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Align(
                            alignment: Alignment.topCenter,
                            child: Icon(Icons.arrow_drop_up, size: 28),
                          ),
                          Material(
                            elevation: 6,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 300,
                                maxWidth: 320,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TextField(
                                      controller: searchController,
                                      decoration: const InputDecoration(
                                        hintText: 'Search',
                                        isDense: true,
                                        prefixIcon: Icon(
                                          Icons.search,
                                          size: 18,
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  Flexible(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) {
                                        final value = filtered[index];
                                        final isSelected = selected.contains(
                                          value,
                                        );
                                        return CheckboxListTile(
                                          dense: true,
                                          title: Text(value),
                                          value: isSelected,
                                          onChanged: (checked) {
                                            setState(() {
                                              if (checked == true) {
                                                selected.add(value);
                                              } else {
                                                selected.remove(value);
                                              }
                                            });
                                            onSelected(selected);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(overlay);
  }

  Future<void> _showAnchoredMultiSelectInt({
    required String title,
    required Future<List<int>> valuesFuture,
    required Set<int> selectedValues,
    required void Function(Set<int>) onSelected,
    required LayerLink layerLink,
    required GlobalKey buttonKey,
  }) async {
    final values = await valuesFuture;
    final selected = Set<int>.from(selectedValues);
    final searchController = TextEditingController();

    late OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => overlay.remove(),
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: layerLink,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 40),
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      final filtered = values.where((value) {
                        return value.toString().contains(searchController.text);
                      }).toList();

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Align(
                            alignment: Alignment.topCenter,
                            child: Icon(Icons.arrow_drop_up, size: 28),
                          ),
                          Material(
                            elevation: 6,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 300,
                                maxWidth: 260,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TextField(
                                      controller: searchController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        hintText: 'Search Year',
                                        isDense: true,
                                        prefixIcon: Icon(
                                          Icons.search,
                                          size: 18,
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  Flexible(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) {
                                        final value = filtered[index];
                                        final isSelected = selected.contains(
                                          value,
                                        );
                                        return CheckboxListTile(
                                          dense: true,
                                          title: Text(value.toString()),
                                          value: isSelected,
                                          onChanged: (checked) {
                                            setState(() {
                                              if (checked == true) {
                                                selected.add(value);
                                              } else {
                                                selected.remove(value);
                                              }
                                            });
                                            onSelected(selected);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(overlay);
  }

  Future<void> _showAnchoredTempoSelect({
    required LayerLink layerLink,
    required GlobalKey buttonKey,
  }) async {
    final ranges = await _repository.getAvailableTempoRanges();
    final selected = Set<TempoRange>.from(_filter.tempoRanges);

    final minController = TextEditingController();
    final maxController = TextEditingController();
    final searchController = TextEditingController();

    late OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => overlay.remove(),
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: layerLink,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 40),
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      final filtered = ranges.where((range) {
                        return range.label.toLowerCase().contains(
                          searchController.text.toLowerCase(),
                        );
                      }).toList();

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Align(
                            alignment: Alignment.topCenter,
                            child: Icon(Icons.arrow_drop_up, size: 28),
                          ),
                          Material(
                            elevation: 6,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 360,
                                maxWidth: 360,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6.0,
                                      ),
                                      child: TextField(
                                        controller: searchController,
                                        decoration: const InputDecoration(
                                          hintText: 'Search Tempo',
                                          isDense: true,
                                          prefixIcon: Icon(
                                            Icons.search,
                                            size: 18,
                                          ),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    Flexible(
                                      child: ListView(
                                        shrinkWrap: true,
                                        children: [
                                          ...filtered.map((range) {
                                            final isSelected = selected
                                                .contains(range);
                                            return CheckboxListTile(
                                              dense: true,
                                              title: Text(range.label),
                                              value: isSelected,
                                              onChanged: (checked) {
                                                setState(() {
                                                  if (checked == true) {
                                                    selected.add(range);
                                                  } else {
                                                    selected.remove(range);
                                                  }
                                                });
                                                setState(() {
                                                  _filter = _filter.copyWith(
                                                    tempoRanges: selected,
                                                  );
                                                  _hymnFuture = _loadHymns();
                                                });
                                              },
                                            );
                                          }),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: minController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                      3,
                                                    ),
                                                  ],
                                                  decoration:
                                                      const InputDecoration(
                                                        hintText: 'Min',
                                                        isDense: true,
                                                      ),
                                                  onChanged: (_) {
                                                    final minText =
                                                        minController.text;
                                                    final maxText =
                                                        maxController.text;
                                                    if (minText.isNotEmpty &&
                                                        maxText.isNotEmpty) {
                                                      final min = int.tryParse(
                                                        minText,
                                                      );
                                                      final max = int.tryParse(
                                                        maxText,
                                                      );
                                                      if (min != null &&
                                                          max != null &&
                                                          min <= max) {
                                                        final custom =
                                                            TempoRange(
                                                              min: min,
                                                              max: max,
                                                            );
                                                        selected.removeWhere(
                                                          (r) => r.isCustom,
                                                        );
                                                        selected.add(custom);
                                                        setState(() {
                                                          _filter = _filter
                                                              .copyWith(
                                                                tempoRanges:
                                                                    selected,
                                                              );
                                                          _hymnFuture =
                                                              _loadHymns();
                                                        });
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller: maxController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                      3,
                                                    ),
                                                  ],
                                                  decoration:
                                                      const InputDecoration(
                                                        hintText: 'Max',
                                                        isDense: true,
                                                      ),
                                                  onChanged: (_) {
                                                    final minText =
                                                        minController.text;
                                                    final maxText =
                                                        maxController.text;
                                                    if (minText.isNotEmpty &&
                                                        maxText.isNotEmpty) {
                                                      final min = int.tryParse(
                                                        minText,
                                                      );
                                                      final max = int.tryParse(
                                                        maxText,
                                                      );
                                                      if (min != null &&
                                                          max != null &&
                                                          min <= max) {
                                                        final custom =
                                                            TempoRange(
                                                              min: min,
                                                              max: max,
                                                            );
                                                        selected.removeWhere(
                                                          (r) => r.isCustom,
                                                        );
                                                        selected.add(custom);
                                                        setState(() {
                                                          _filter = _filter
                                                              .copyWith(
                                                                tempoRanges:
                                                                    selected,
                                                              );
                                                          _hymnFuture =
                                                              _loadHymns();
                                                        });
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(overlay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildHomeDrawer(),
      appBar: HomeAppBar(
        title: _activeWorkspace.title,
        logic: _appBarLogic,
        selectionController: _selectionController,
        canShowPresentation: true,
        onSearchChanged: _onSearchChanged,
        onOpenHymn: (hymnId) {
          unawaited(_openHymnWorkspace(hymnId));
        },
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                WorkspaceTabBar(
                  tabs: _workspaceManager.tabs,
                  activeIndex: _workspaceManager.activeIndex,
                  onSelect: _workspaceManager.activateTab,
                  onClose: _closeWorkspaceTab,
                  onAddTab: _openNewWorkspace,
                  onReorder: _workspaceManager.reorderTabs,
                ),
                if (_activeWorkspace.type == WorkspaceTabType.home)
                  HomeFilterBar(
                    keyLabel: 'KEY',
                    dedicatedLabel: 'DEDICATED',
                    yearLabel: 'YEAR',
                    tempoLabel: 'TEMPO',
                    keySelected: _filter.keys.length,
                    dedicatedSelected: _filter.dedicated.length,
                    yearSelected: _filter.years.length,
                    tempoSelected: _filter.tempoRanges.length,
                    onKeyTap: _onKeyTap,
                    onDedicatedTap: _onDedicatedTap,
                    onYearTap: _onYearTap,
                    onTempoTap: _onTempoTap,
                    onReset: _onResetFilters,
                    keyLayerLink: _keyLayerLink,
                    dedicatedLayerLink: _dedicatedLayerLink,
                    yearLayerLink: _yearLayerLink,
                    tempoLayerLink: _tempoLayerLink,
                    keyButtonKey: _keyButtonKey,
                    dedicatedButtonKey: _dedicatedButtonKey,
                    yearButtonKey: _yearButtonKey,
                    tempoButtonKey: _tempoButtonKey,
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _workspaceManager.activeIndex,
                    children: _workspaceManager.tabs
                        .map(
                          (workspace) => KeyedSubtree(
                            key: ValueKey('workspace_${workspace.id}'),
                            child: _buildWorkspaceContentForTab(workspace),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
            if (_collectionWorkspaceVisible)
              Positioned.fill(
                child: HymnCollectionWorkspace(
                  key: _collectionWorkspaceKey,
                  initialTabs: const <CollectionTab>[],
                  onOpenHymn: (hymnId) => _appBarLogic.onOpenHymns(context, [hymnId]),
                  onEmpty: () {
                    setState(() {
                      _collectionWorkspaceVisible = false;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
