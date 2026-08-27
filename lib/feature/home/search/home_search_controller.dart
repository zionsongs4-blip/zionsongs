import 'dart:async';
import 'package:flutter/foundation.dart';
import 'home_search_models.dart';
import 'home_search_repository.dart';

class HomeSearchController extends ChangeNotifier {
  final HomeSearchRepository repository;
  final int resultLimit;
  final bool actualSnippetForSearchText;

  HomeSearchController({
    required this.repository,
    this.resultLimit = 50,
    this.actualSnippetForSearchText = false,
  });

  HomeSearchQuery _query = const HomeSearchQuery(text: '');
  HomeSearchFilters _filters = const HomeSearchFilters();

  List<HomeSearchResult> _results = [];
  List<String> _suggestions = [];
  bool _loading = false;

  Timer? _debounce;

  List<HomeSearchResult> get results => _results;
  List<String> get suggestions => _suggestions;
  bool get loading => _loading;
  HomeSearchQuery get query => _query;

  String _sanitizeInput(String input) {
    return input.replaceAll(RegExp(r'\[.*?\]'), '').trim();
  }

  void onQueryChanged(String text) {
    _query = _query.copyWith(text: text);

    _debounce?.cancel();

    final sanitized = _sanitizeInput(text);
    if (sanitized.isEmpty) {
      _results = [];
      _suggestions = [];
      _loading = false;
      notifyListeners();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), _search);
    notifyListeners();
  }

  Future<void> searchImmediately(String text) async {
    // Sanitize the text immediately when a suggestion is clicked/selected
    final sanitizedText = _sanitizeInput(text);
    _query = _query.copyWith(text: sanitizedText);
    _debounce?.cancel();
    await _search();
  }

  Future<void> _search() async {
    final rawText = _query.text;
    final sanitizedText = _sanitizeInput(rawText);

    if (sanitizedText.isEmpty) {
      _results = [];
      _suggestions = [];
      _loading = false;
      notifyListeners();
      return;
    }

    final activeQuery = _query.copyWith(text: sanitizedText);

    _loading = true;
    notifyListeners();

    // Fetch index matches and suggestion tokens in parallel using the sanitized text
    final matchesFuture = repository.searchIndexMatches(
      activeQuery,
      filters: _filters,
      limit: resultLimit,
      actualSnippetForSearchText: actualSnippetForSearchText,
    );

    final suggestionsFuture = repository.searchSuggestions(activeQuery);

    final matches = await matchesFuture;
    _suggestions = await suggestionsFuture;

    // Convert index matches to HomeSearchResult for UI compatibility
    _results = matches
        .map((m) => HomeSearchResult(
              srNo: m.hymnId,
              title: m.title,
              suggestion: m.suggestion,
              pageNo: null,
              favorite: false,
              snippet: m.snippet,
              score: m.score,
            ))
        .toList();

    _loading = false;
    notifyListeners();
  }

  void toggleFavorites() {
    _filters = _filters.copyWith(
      onlyFavorites: !_filters.onlyFavorites,
    );

    if (_query.text.isNotEmpty) {
      _search();
    }

    notifyListeners();
  }

  void clear() {
    _debounce?.cancel();
    _query = const HomeSearchQuery(text: '');
    _results = [];
    _suggestions = [];
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}