import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../../../screens/folder_doc_screen.dart';
import '../../../services/clipboard_service.dart';
import '../hymn/app_initializer.dart';
import '../hymn/favorites_repository.dart';
import '../search/home_search_dialog.dart';
import 'home_repository.dart';
import 'home_selection_controller.dart';
import '../search/search_service.dart';
import '../hymn/edit_lyrics_page.dart';
import '../hymn/hymn_models.dart';
import '../home_page/home_page.dart';
import 'theme_service.dart';

/// ===============================================================
/// HomeAppBarLogic
/// ===============================================================
class HomeAppBarLogic {
  HomeAppBarLogic({
    required this.repository,
    required this.selectionController,
  });

  final HomeRepository repository;
  final HomeSelectionController selectionController;

  List<String> get _selectedIds => selectionController.selectedHymnIds.toList();

  // ============================================================
  // NORMAL MODE
  // ============================================================

  void onSearch(BuildContext context) {
    () async {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => HomeSearchDialog(
          isar: AppInitializer.isar,
        ),
      );

      if (result == null || result.isEmpty) return;

      if (!context.mounted) return;

      final homeState = context.findAncestorStateOfType<State<HomePage>>();
      if (homeState != null) {
        final controller = SearchService.instance.controller;
        (homeState as dynamic)._onSearchChanged(result, controller.results);
      }
    }();
  }

  void onTheme() {
    ThemeService.changeTheme();
  }

  void onInvertTheme() {
    ThemeService.invertTheme();
  }

  void onPresentation() {
    repository.presentationMode();
  }

  void onNotifications() {
    repository.openNotifications();
  }

  void onSettings() {
    repository.openSettings();
  }

  // ============================================================
  // SINGLE SELECTION
  // ============================================================

  Future<void> onEdit(BuildContext context) async {
    if (_selectedIds.length != 1) return;

    final hymn = await AppInitializer.isar.localHymns
        .where()
        .hymnIdEqualTo(_selectedIds.first)
        .findFirst();

    if (hymn == null) return;
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditLyricsPage(
          isar: AppInitializer.isar,
          hymnId: hymn.hymnId,
          originalLyrics: hymn.originalLyrics,
          hindiLyrics: hymn.hindiLyrics,
          malayalamLyrics: hymn.malayalamLyrics,
        ),
      ),
    );

    selectionController.clear();
  }

  // ============================================================
  // MULTIPLE SELECTION
  // ============================================================

  Future<void> onAddToFavorites(BuildContext context) async {
    final favoritesRepository = FavoritesRepository();
    for (final hymnId in _selectedIds) {
      await favoritesRepository.addFavorite(hymnId);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to Favorites')),
    );
    selectionController.clear();
  }

  Future<void> onAddToViewList(BuildContext context) async {
    ClipboardService.instance.copyHymnSelection(hymnIds: _selectedIds);
    selectionController.clear();

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FolderDocScreen(
          collection: 'viewlists',
          docId: 'root',
          docName: 'View Lists',
        ),
      ),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a folder and tap Paste.')),
    );
  }

  Future<void> onAddToMedley(BuildContext context) async {
    ClipboardService.instance.copyHymnSelection(hymnIds: _selectedIds);
    selectionController.clear();

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FolderDocScreen(
          collection: 'medleys',
          docId: 'root',
          docName: 'Medleys',
        ),
      ),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a folder and tap Paste.')),
    );
  }

  Future<void> onAddSelectedToNewScreen(BuildContext context) async {
    final ids = List<String>.from(_selectedIds);

    try {
      final homeState = context.findAncestorStateOfType<State<HomePage>>();
      if (homeState != null) {
        (homeState as dynamic)._onAddSelectedToNewScreen(ids);
      }
    } finally {
      if (selectionController.selectedCount > 0) {
        selectionController.clear();
      }
    }
  }

  Future<void> onAddSelectedToExistingScreen(BuildContext context) async {
    final ids = List<String>.from(_selectedIds);

    try {
      final homeState = context.findAncestorStateOfType<State<HomePage>>();
      if (homeState != null) {
        await (homeState as dynamic)._showScreenSelectorDialog(ids);
      }
    } finally {
      if (selectionController.selectedCount > 0) {
        selectionController.clear();
      }
    }
  }

  Future<void> onOpenSelection(BuildContext context) async {
    final ids = List<String>.from(_selectedIds);
    if (ids.isEmpty) return;

    try {
      final homeState = context.findAncestorStateOfType<State<HomePage>>();
      if (homeState == null) return;

      final allTabs = (homeState as dynamic).activeTabs ?? [];
      final eligibleTabs = allTabs.where(isEligibleOpenDestinationTab).toList();

      String? choice;
      if (eligibleTabs.isEmpty) {
        choice = 'new';
      } else {
        choice = await showDialog<String>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Open Hymns'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: const Text('Add to Existing Screen'),
                    onTap: () => Navigator.of(dialogContext).pop('existing'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('Open on New Screen'),
                    onTap: () => Navigator.of(dialogContext).pop('new'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('CANCEL'),
                ),
              ],
            );
          },
        );
      }

      if (!context.mounted || choice == null) return;

      if (choice == 'new') {
        await (homeState as dynamic)._openSelectedHymnsToNewTab(ids);
      } else if (choice == 'existing') {
        final selectedTab = await showDialog<dynamic>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Select Existing Screen'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: eligibleTabs.length,
                  itemBuilder: (context, index) {
                    final tab = eligibleTabs[index];
                    final existingHymnIds = List<String>.from(tab.arguments['hymnIds'] ?? <String>[]);
                    return ListTile(
                      title: Text(tab.title),
                      subtitle: Text('${existingHymnIds.length} hymns'),
                      onTap: () => Navigator.of(dialogContext).pop(tab),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('CANCEL'),
                ),
              ],
            );
          },
        );

        if (selectedTab != null) {
          await (homeState as dynamic)._addHymnsToExistingTab(selectedTab, ids);
        }
      }
    } finally {
      if (selectionController.selectedCount > 0) {
        selectionController.clear();
      }
    }
  }

  Future<void> onExportPdf(BuildContext context) async {
    if (_selectedIds.isEmpty) return;

    try {
      await repository.exportPdf(_selectedIds);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF Saved Successfully')),
      );
    } catch (error, stackTrace) {
      if (!context.mounted) return;

      final err = error.toString();
      debugPrint('PDF export failed: $err');
      debugPrint('$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: ${err.isEmpty ? 'unknown' : err}')),
      );
    }
  }

  Future<void> onShareSelection(BuildContext context) async {
    if (_selectedIds.isEmpty) return;

    try {
      await repository.sharePdf(_selectedIds);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing PDF')),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error sharing PDF.')));
    }
  }

  // ============================================================
  // CANCEL SELECTION
  // ============================================================

  void onCancelSelection(BuildContext context) {
    selectionController.clear();
  }

  // ============================================================
  // POPUP MENU
  // ============================================================

  void onImportExcel() {
    repository.importExcel();
  }

  void onExportExcel() {
    repository.exportExcel();
  }

  void onStatistics() {
    repository.openStatistics();
  }

  void onHelp() {
    repository.openHelp();
  }

  void onFeedback() {
    repository.sendFeedback();
  }

  void onAbout() {
    repository.openAbout();
  }
}