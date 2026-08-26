import '../feature/home/hymn/hymn_models.dart';

String normalizeHymnSearchQuery(String value) => value.trim().toLowerCase();

bool matchesHymnSearchQuery(LocalHymn hymn, String query) {
  final normalizedQuery = normalizeHymnSearchQuery(query);
  if (normalizedQuery.isEmpty) return true;

  final searchText = (hymn.searchText ?? '').toLowerCase();
  if (searchText.contains(normalizedQuery)) return true;

  final hindi = (hymn.hindiLyrics ?? '').toLowerCase();
  if (hindi.contains(normalizedQuery)) return true;

  final malayalam = (hymn.malayalamLyrics ?? '').toLowerCase();
  if (malayalam.contains(normalizedQuery)) return true;

  final english = (hymn.englishLyrics ?? '').toLowerCase();
  if (english.contains(normalizedQuery)) return true;

  final title = (hymn.title ?? '').toLowerCase();
  if (title.contains(normalizedQuery)) return true;

    final hymnId = hymn.hymnId.toLowerCase();
  if (hymnId.contains(normalizedQuery)) return true;

  final serial = _extractSerial(hymn);
  if (serial != null && serial.contains(normalizedQuery)) return true;

  return false;
}

String? _extractSerial(LocalHymn hymn) {
  final id = hymn.hymnId;
  if (id.isNotEmpty) {
    final matches = RegExp(r"\d+").allMatches(id);
    if (matches.isNotEmpty) {
      return matches.last.group(0);
    }
  }

  final text = (hymn.searchText ?? '').toLowerCase();
  final match = RegExp(r"\b(\d{1,4})\b").firstMatch(text);
  return match?.group(1);
}
