class HomeSearchQuery {
  final String text;

  const HomeSearchQuery({this.text = ''});

  HomeSearchQuery copyWith({String? text}) {
    return HomeSearchQuery(text: text ?? this.text);
  }
}

class HomeSearchFilters {
  final bool onlyFavorites;

  const HomeSearchFilters({this.onlyFavorites = false});

  HomeSearchFilters copyWith({bool? onlyFavorites}) {
    return HomeSearchFilters(
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
    );
  }
}

class HomeSearchResult {
  final String srNo;

  /// Actual hymn title.
  final String title;

  /// Word or short phrase shown in the autocomplete suggestions.
  final String suggestion;

  final String? pageNo;

  final bool favorite;

  /// Preview shown in the filtered hymn list (around 60 chars before/after).
  final String? snippet;

  final double score;

  const HomeSearchResult({
    required this.srNo,
    required this.title,
    required this.suggestion,
    this.pageNo,
    this.favorite = false,
    this.snippet,
    this.score = 0,
  });
}

class HomeSearchIndexMatch {
  final String hymnId;
  final String title;
  final String suggestion;
  final String snippet;
  final String field;
  final double score;

  const HomeSearchIndexMatch({
    required this.hymnId,
    required this.title,
    required this.suggestion,
    required this.snippet,
    required this.field,
    required this.score,
  });
}
