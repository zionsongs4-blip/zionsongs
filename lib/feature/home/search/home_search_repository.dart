import 'dart:isolate';

import 'package:isar/isar.dart';

import '../hymn/hymn_models.dart';
import '../search/home_search_models.dart';

String normalizeSearchText(String text) {
  final buffer = StringBuffer();
  var lastWasSpace = false;

  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);

    if (char.trim().isEmpty || char == '\n' || char == '\r') {
      if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
      continue;
    }

    if (char == '\t' || char == '\f' || char == '\v') {
      if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
      continue;
    }

    if (_isAsciiPunctuation(char)) {
      if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
      continue;
    }

    buffer.write(char);
    lastWasSpace = false;
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isAsciiPunctuation(String char) {
  final code = char.codeUnitAt(0);
  return code <= 0x7f && RegExp(r'[!-/:-@[-`{-~]').hasMatch(char);
}

class _SearchHymnRecord {
  const _SearchHymnRecord({
    required this.hymnId,
    required this.title,
    required this.searchText,
    required this.hindiLyrics,
    required this.malayalamLyrics,
    required this.englishLyrics,
  });

  final String hymnId;
  final String title;
  final String searchText;
  final String hindiLyrics;
  final String malayalamLyrics;
  final String englishLyrics;
}

class _SearchRequest {
  const _SearchRequest({
    required this.query,
    required this.hymns,
    required this.limit,
  });

  final String query;
  final List<_SearchHymnRecord> hymns;
  final int limit;
}

class _SuggestionsRequest {
  const _SuggestionsRequest({
    required this.query,
    required this.hymns,
    required this.limit,
  });

  final String query;
  final List<_SearchHymnRecord> hymns;
  final int limit;
}

List<HomeSearchIndexMatch> _searchIndexMatchesIsolate(_SearchRequest request) {
  final normalizedQuery = normalizeSearchText(request.query);
  if (normalizedQuery.isEmpty) {
    return const <HomeSearchIndexMatch>[];
  }

  final matches = <HomeSearchIndexMatch>[];

  for (final hymn in request.hymns) {
    final match = _evaluateHymnSnapshot(hymn, normalizedQuery);
    if (match.score == 0) continue;

    matches.add(
      HomeSearchIndexMatch(
        hymnId: hymn.hymnId,
        title: hymn.title,
        suggestion: match.suggestion,
        snippet: match.snippet,
        field: match.field,
        score: match.score.toDouble(),
      ),
    );
  }

  matches.sort((a, b) {
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    return a.title.compareTo(b.title);
  });

  return matches.take(request.limit).toList();
}

List<String> _searchSuggestionsIsolate(_SuggestionsRequest request) {
  final normalizedQuery = normalizeSearchText(request.query);
  if (normalizedQuery.isEmpty) {
    return const <String>[];
  }

  final seen = <String>{};
  final suggestions = <String>[];

  for (final hymn in request.hymns) {
    final match = _evaluateHymnSnapshot(hymn, normalizedQuery);
    if (match.score == 0 || match.suggestion.isEmpty) continue;

    final normalizedSuggestion = normalizeSearchText(match.suggestion);
    if (seen.add(normalizedSuggestion)) {
      suggestions.add(match.suggestion);
      if (suggestions.length >= request.limit) {
        return suggestions;
      }
    }
  }

  return suggestions;
}

_MatchData _evaluateHymnSnapshot(_SearchHymnRecord hymn, String query) {
  final serialNo = _extractSerialFromHymnId(hymn.hymnId);

  final fields = [
    (name: 'searchText', raw: hymn.searchText, score: 100),
    (name: 'hindi', raw: hymn.hindiLyrics, score: 90),
    (name: 'malayalam', raw: hymn.malayalamLyrics, score: 80),
    (name: 'english', raw: hymn.englishLyrics, score: 70),
    (name: 'title', raw: hymn.title, score: 60),
    (name: 'srNo', raw: serialNo, score: 50),
  ];

  for (final field in fields) {
    final raw = field.raw;
    if (raw == null || raw.trim().isEmpty) continue;

    if (normalizeSearchText(raw).contains(query)) {
      return _MatchData(
        score: field.score,
        field: field.name,
        suggestion: _extractSuggestion(raw, query),
        snippet: _extractSnippet(raw, query),
      );
    }
  }

  return const _MatchData(score: 0, field: '', suggestion: '', snippet: '');
}

String _extractSuggestion(String rawText, String query) {
  final normalizedQuery = normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return '';

  final matchData = _normalizeTextWithMap(rawText);
  final normalizedText = matchData.key;
  final positionMap = matchData.value;

  final matchIndex = normalizedText.indexOf(normalizedQuery);
  if (matchIndex == -1) return '';

  final rawStart = _findRawWordStart(rawText, positionMap[matchIndex]);
  final substring = rawText.substring(rawStart);

  final wordMatches = RegExp(r'\S+', unicode: true).allMatches(substring).toList();
  if (wordMatches.isEmpty) return '';

  final wordEnd = wordMatches.length >= 3 ? wordMatches[2].end : wordMatches.last.end;
  final phrase = substring.substring(0, wordEnd).replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  return phrase;
}

String _extractSnippet(String rawText, String query) {
  final normalizedQuery = normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return '';

  final matchData = _normalizeTextWithMap(rawText);
  final normalizedText = matchData.key;
  final positionMap = matchData.value;

  final matchIndex = normalizedText.indexOf(normalizedQuery);
  if (matchIndex == -1) return '';

  final rawStart = positionMap[matchIndex];
  final rawEnd = positionMap[matchIndex + normalizedQuery.length - 1] + 1;

  final start = rawStart > 60 ? rawStart - 60 : 0;
  final end = rawEnd + 60 < rawText.length ? rawEnd + 60 : rawText.length;

  var snippet = rawText.substring(start, end).trim();

  if (start > 0) snippet = '...$snippet';
  if (end < rawText.length) snippet = '$snippet...';

  return snippet;
}

String? _extractSerialFromHymnId(String hymnId) {
  final digits = RegExp(r'\d+').allMatches(hymnId).toList();
  if (digits.isEmpty) return null;
  return digits.last.group(0);
}

MapEntry<String, List<int>> _normalizeTextWithMap(String text) {
  final normalized = StringBuffer();
  final positions = <int>[];
  var lastWasSpace = false;

  for (var index = 0; index < text.length; index++) {
    final char = text[index];
    if (RegExp(r'[\r\n]+').hasMatch(char) || RegExp(r'\s', unicode: true).hasMatch(char)) {
      if (!lastWasSpace) {
        normalized.write(' ');
        positions.add(index);
        lastWasSpace = true;
      }
      continue;
    }

    if (_isAsciiPunctuation(char)) {
      if (!lastWasSpace) {
        normalized.write(' ');
        positions.add(index);
        lastWasSpace = true;
      }
      continue;
    }

    normalized.write(char.toLowerCase());
    positions.add(index);
    lastWasSpace = false;
  }

  return MapEntry(normalized.toString(), positions);
}

int _findRawWordStart(String rawText, int index) {
  while (index > 0 && !RegExp(r'\s', unicode: true).hasMatch(rawText[index - 1])) {
    index -= 1;
  }
  return index;
}

/// Repository used by the search UI.
///
/// RULE:
/// - suggestions = matching phrase around typed text (max 3)
/// - snippet = lyric preview only
/// - searchText is never displayed as preview
class HomeSearchRepository {
  final Isar isar;

  Future<List<LocalHymn>>? _searchIndex;

  HomeSearchRepository({
    required this.isar,
  });

  Future<List<HomeSearchResult>> searchHymns(
    HomeSearchQuery query, {
    HomeSearchFilters? filters,
    int limit = 50,
  }) async {
    final text = query.text.trim();
    if (text.isEmpty) return const <HomeSearchResult>[];

    final hymns = await (_searchIndex ??= isar.localHymns.where().findAll());
    final snapshotHymns = hymns.map((hymn) => _SearchHymnRecord(
      hymnId: hymn.hymnId,
      title: hymn.title,
      searchText: hymn.searchText ?? '',
      hindiLyrics: hymn.hindiLyrics ?? '',
      malayalamLyrics: hymn.malayalamLyrics ?? '',
      englishLyrics: hymn.englishLyrics ?? '',
    )).toList(growable: false);

    final results = await Isolate.run(() => _searchIndexMatchesIsolate(_SearchRequest(
      query: text,
      hymns: snapshotHymns,
      limit: limit,
    )));

    return results
        .map((match) => HomeSearchResult(
              srNo: match.hymnId,
              title: match.title,
              suggestion: match.suggestion,
              pageNo: null,
              favorite: false,
              snippet: match.snippet,
              score: match.score,
            ))
        .toList();
  }

  Future<List<String>> searchSuggestions(
    HomeSearchQuery query, {
    int limit = 20,
  }) async {
    final text = query.text.trim();
    if (text.isEmpty) return const <String>[];

    final hymns = await (_searchIndex ??= isar.localHymns.where().findAll());
    final snapshotHymns = hymns.map((hymn) => _SearchHymnRecord(
      hymnId: hymn.hymnId,
      title: hymn.title,
      searchText: hymn.searchText ?? '',
      hindiLyrics: hymn.hindiLyrics ?? '',
      malayalamLyrics: hymn.malayalamLyrics ?? '',
      englishLyrics: hymn.englishLyrics ?? '',
    )).toList(growable: false);

    return Isolate.run(() => _searchSuggestionsIsolate(_SuggestionsRequest(
      query: text,
      hymns: snapshotHymns,
      limit: limit,
    )));
  }

  Future<List<HomeSearchIndexMatch>> searchIndexMatches(
    HomeSearchQuery query, {
    HomeSearchFilters? filters,
    int limit = 100,
  }) async {
    final text = query.text.trim();
    if (text.isEmpty) return const <HomeSearchIndexMatch>[];

    final hymns = await (_searchIndex ??= isar.localHymns.where().findAll());
    final snapshotHymns = hymns.map((hymn) => _SearchHymnRecord(
      hymnId: hymn.hymnId,
      title: hymn.title,
      searchText: hymn.searchText ?? '',
      hindiLyrics: hymn.hindiLyrics ?? '',
      malayalamLyrics: hymn.malayalamLyrics ?? '',
      englishLyrics: hymn.englishLyrics ?? '',
    )).toList(growable: false);

    return Isolate.run(() => _searchIndexMatchesIsolate(_SearchRequest(
      query: text,
      hymns: snapshotHymns,
      limit: limit,
    )));
  }
}

class _MatchData {
  const _MatchData({
    required this.score,
    required this.field,
    required this.suggestion,
    required this.snippet,
  });

  final int score;
  final String field;
  final String suggestion;
  final String snippet;
}