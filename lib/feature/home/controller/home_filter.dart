/// ===============================================================
/// HomeFilter
/// ---------------------------------------------------------------
///
/// OFFLINE FIRST
///
/// Pure data model.
/// No UI.
/// No Isar.
/// No Firestore.
/// No Repository.
///
/// Stores currently selected filters.
///
/// Supports MULTI-SELECTION for the broader filter chips,
/// but the alphabet strip uses a single active letter.
/// ===============================================================

library;

class TempoRange {
  final int min;
  final int max;

  const TempoRange({
    required this.min,
    required this.max,
  });

  /// Custom range marker
  const TempoRange.custom()
      : min = 0,
        max = 0;

  bool get isCustom => min == 0 && max == 0;

  bool contains(int tempo) {
    if (isCustom) return true;
    return tempo >= min && tempo <= max;
  }

  String get label {
    if (isCustom) {
      return 'Custom';
    }

    return '$min - $max';
  }

  @override
  String toString() {
    return label;
  }

  @override
  bool operator ==(Object other) {
    return other is TempoRange &&
        other.min == min &&
        other.max == max;
  }

  @override
  int get hashCode => Object.hash(min, max);
}


class HomeFilter {
  const HomeFilter({
    this.keys = const <String>{},
    this.dedicated = const <String>{},
    this.years = const <int>{},
    this.tempoRanges = const <TempoRange>{},
    this.alphabet,
  });

  /// KEY
  final Set<String> keys;

  /// DEDICATED
  final Set<String> dedicated;

  /// YEAR
  final Set<int> years;

  /// TEMPO RANGE
  final Set<TempoRange> tempoRanges;

  /// A-Z FILTER (single selection)
  final String? alphabet;

  bool get isEmpty {
    return keys.isEmpty &&
        dedicated.isEmpty &&
        years.isEmpty &&
        tempoRanges.isEmpty &&
        (alphabet == null || alphabet!.isEmpty);
  }


  bool get hasFilters => !isEmpty;


  HomeFilter clear() {
    return const HomeFilter();
  }


  HomeFilter copyWith({
    Set<String>? keys,
    Set<String>? dedicated,
    Set<int>? years,
    Set<TempoRange>? tempoRanges,
    String? alphabet,
    bool clearAlphabet = false,
  }) {
    return HomeFilter(
      keys: keys ?? this.keys,
      dedicated: dedicated ?? this.dedicated,
      years: years ?? this.years,
      tempoRanges: tempoRanges ?? this.tempoRanges,
      alphabet: clearAlphabet ? null : (alphabet ?? this.alphabet),
    );
  }


  @override
  String toString() {
    return '''
HomeFilter(
  keys: $keys,
  dedicated: $dedicated,
  years: $years,
  tempoRanges: $tempoRanges,
  alphabet: $alphabet,
)
''';
  }
}