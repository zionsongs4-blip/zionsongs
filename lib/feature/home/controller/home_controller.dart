import 'package:flutter/material.dart';

import 'home_filter.dart';
import '../home_models.dart';
import 'home_navigation.dart';
import '../app_bar/home_repository.dart';
import 'home_state.dart';

/// ===============================================================
/// HomeController
/// ---------------------------------------------------------------
///
/// Brain of the Home Screen.
///
/// OFFLINE FIRST
/// ---------------------------------------------------------------
/// UI
///      ↓
/// HomeController
///      ↓
/// Repository
///      ↓
/// Isar (Immediate)
///      ↓
/// SyncQueue
///      ↓
/// Firestore (Later)
///
/// UI NEVER talks directly to Isar or Firestore.
/// Repository handles all data operations.
/// ===============================================================
class HomeController {
  HomeController({
    required this.context,
    required this.state,
    required this.navigation,
    required this.repository,
  });

  final BuildContext context;
  final HomeState state;
  final HomeNavigation navigation;
  final HomeRepository repository;

  HomeFilter _filter = const HomeFilter();

  HomeFilter get filter => _filter;

  List<HomeHymn> _hymns = [];

  List<HomeHymn> get hymns => List.unmodifiable(_hymns);

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    state.setLoading(true);

    try {
      _hymns = await repository.getAllHymns();

      state.clearError();
    } catch (e) {
      state.setError(e.toString());
    }

    state.setLoading(false);
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refresh() async {
    state.setLoading(true);

    try {
      _hymns = await repository.getAllHymns();

      state.clearError();
    } catch (e) {
      state.setError(e.toString());
    }

    state.setLoading(false);
  }

  // ============================================================
  // SEARCH
  // ============================================================

 Future<void> search(String text) async {
  state.setSearchText(text);

  _hymns = await repository.search(
    keyword: text,
    keys: _filter.keys,
    dedicated: _filter.dedicated,
    years: _filter.years,
    tempoRanges: _filter.tempoRanges,
    alphabet: _filter.alphabet,
    tab: state.currentTab,
  );
}

  Future<void> clearSearch() async {
  state.clearSearch();

  _hymns = await repository.search(
    keyword: '',
    keys: _filter.keys,
    dedicated: _filter.dedicated,
    years: _filter.years,
    tempoRanges: _filter.tempoRanges,
    alphabet: _filter.alphabet,
    tab: state.currentTab,
  );
}

  // ============================================================
  // FILTERS
  // ============================================================

Future<void> applyFilter(HomeFilter filter) async {
  _filter = filter;

  _hymns = await repository.search(
    keyword: state.searchText,
    keys: filter.keys,
    dedicated: filter.dedicated,
    years: filter.years,
    tempoRanges: filter.tempoRanges,
    alphabet: filter.alphabet,
    tab: state.currentTab,
  );
}

  Future<void> clearFilters() async {
    _filter = const HomeFilter();

    state.clearFilters();

    _hymns = await repository.search(
      keyword: state.searchText,
      tab: state.currentTab,
    );
  }

  // ============================================================
  // TABS
  // ============================================================

 Future<void> changeTab(HomeTab tab) async {
  state.setCurrentTab(tab);

  _hymns = await repository.search(
    keyword: state.searchText,
    keys: _filter.keys,
    dedicated: _filter.dedicated,
    years: _filter.years,
    tempoRanges: _filter.tempoRanges,
    alphabet: _filter.alphabet,
    tab: tab,
  );
}
  // ============================================================
  // A-Z
  // ============================================================

  Future<void> jumpToLetter(String letter) async {
    state.selectLetter(letter);

    _filter = _filter.copyWith(alphabet: letter);

    _hymns = await repository.search(
      keyword: state.searchText,
      keys: _filter.keys,
      dedicated: _filter.dedicated,
      years: _filter.years,
      tempoRanges: _filter.tempoRanges,
      alphabet: _filter.alphabet,
      tab: state.currentTab,
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void openSettings() {
    navigation.openSettings();
  }

  void openNotifications() {
    navigation.openNotifications();
  }

  void openPresentation() {
    navigation.openPresentation();
  }

  void openSearch() {
    navigation.openSearch();
  }

  void openHymn(String hymnId) {
    navigation.openHymn(hymnId);
  }

  void openViewLists() {
    navigation.openViewLists();
  }

  void openMedleys() {
    navigation.openMedleys();
  }

  // ============================================================
  // FAVORITES
  // ============================================================

  Future<void> addToFavorites(List<String> hymnIds) async {
    await repository.addToFavorites(hymnIds);
  }

  Future<void> removeFromFavorites(List<String> hymnIds) async {
    await repository.removeFromFavorites(hymnIds);
  }

  // ============================================================
  // VIEW LIST
  // ============================================================

  Future<void> addToViewList({
    required List<String> hymnIds,
    required String viewListId,
  }) async {
    await repository.addToViewList(
      hymnIds: hymnIds,
      viewListId: viewListId,
    );
  }

  // ============================================================
  // MEDLEY
  // ============================================================

  Future<void> addToMedley({
    required List<String> hymnIds,
    required String medleyId,
  }) async {
    await repository.addToMedley(
      hymnIds: hymnIds,
      medleyId: medleyId,
    );
  }

  // ============================================================
  // PDF
  // ============================================================

  Future<void> exportPdf(List<String> hymnIds) async {
    await repository.exportPdf(hymnIds);
  }

  // ============================================================
  // OFFLINE SYNC
  // ============================================================

  Future<void> syncNow() async {
    // SyncQueue implementation will be added later.
    // UI never communicates directly with Firestore.
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    state.dispose();
  }
}