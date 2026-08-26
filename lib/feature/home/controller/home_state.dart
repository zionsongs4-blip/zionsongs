import 'package:flutter/foundation.dart';

import '../home_models.dart';

/// ===============================================================
/// HomeState
/// ---------------------------------------------------------------
///
/// Pure UI state for the Home screen.
///
/// OFFLINE FIRST
/// ---------------------------------------------------------------
/// This class never talks to:
/// • Isar
/// • Firestore
/// • Repository
/// • SyncQueue
///
/// It simply remembers the current state of the Home page.
/// ===============================================================

class HomeState extends ChangeNotifier {
  // ============================================================
  // CURRENT TAB
  // ============================================================

  HomeTab _currentTab = HomeTab.allHymns;

  HomeTab get currentTab => _currentTab;

  void setCurrentTab(HomeTab tab) {
    if (_currentTab == tab) return;

    _currentTab = tab;
    notifyListeners();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  String _searchText = '';

  String get searchText => _searchText;

  void setSearchText(String value) {
    if (_searchText == value) return;

    _searchText = value;
    notifyListeners();
  }

  void clearSearch() {
    if (_searchText.isEmpty) return;

    _searchText = '';
    notifyListeners();
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Set<String> _selectedKeys = {};
  Set<String> _selectedDedicated = {};
  Set<int> _selectedYears = {};

  int? _minTempo;
  int? _maxTempo;

  Set<String> get selectedKeys => _selectedKeys;
  Set<String> get selectedDedicated => _selectedDedicated;
  Set<int> get selectedYears => _selectedYears;

  int? get minTempo => _minTempo;
  int? get maxTempo => _maxTempo;

  void setKeys(Set<String> value) {
    _selectedKeys = value;
    notifyListeners();
  }

  void setDedicated(Set<String> value) {
    _selectedDedicated = value;
    notifyListeners();
  }

  void setYears(Set<int> value) {
    _selectedYears = value;
    notifyListeners();
  }

  void setTempoRange({
    int? min,
    int? max,
  }) {
    _minTempo = min;
    _maxTempo = max;
    notifyListeners();
  }

  void clearFilters() {
    _selectedKeys = {};
    _selectedDedicated = {};
    _selectedYears = {};

    _minTempo = null;
    _maxTempo = null;

    notifyListeners();
  }

  // ============================================================
  // A-Z INDEX
  // ============================================================

  String? _selectedLetter;

  String? get selectedLetter => _selectedLetter;

  void selectLetter(String? letter) {
    _selectedLetter = letter;
    notifyListeners();
  }

  // ============================================================
  // LOADING
  // ============================================================

  bool _loading = false;

  bool get loading => _loading;

  void setLoading(bool value) {
    if (_loading == value) return;

    _loading = value;
    notifyListeners();
  }

  // ============================================================
  // ERROR
  // ============================================================

  String? _error;

  String? get error => _error;

  void setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}