class ChordSegment {
  final String chord;
  final String lyric;

  const ChordSegment({
    required this.chord,
    required this.lyric,
  });
}

class ChordParserService {
  static final RegExp _bracketedChordRegex = RegExp(r'(\[[^\]]+\])');

  /// Removes chord markers but keeps the original lyric spacing.
  /// Example:
  /// BE[G]FORE -> BEFORE
  static String stripChordMarkers(String text) {
    return text
        .split('\n')
        .map((line) {
          return line.replaceAll(_bracketedChordRegex, '');
        })
        .join('\n');
  }

  static List<List<ChordSegment>> parseLyrics(String lyrics) {
    return lyrics
        .split('\n')
        .map(parseLine)
        .toList();
  }

  static List<ChordSegment> parseLine(String line) {
    if (line.isEmpty) {
      return const [
        ChordSegment(
          chord: '',
          lyric: '',
        ),
      ];
    }

    final parts = line.split(_bracketedChordRegex);

    final matches = _bracketedChordRegex
        .allMatches(line)
        .toList();

    final segments = <ChordSegment>[];

    for (int i = 0; i < parts.length; i++) {
      String chord = '';

      if (i > 0 && i - 1 < matches.length) {
        chord = matches[i - 1]
            .group(0)!
            .substring(1, matches[i - 1].group(0)!.length - 1);
      }

      segments.add(
        ChordSegment(
          chord: chord,
          // IMPORTANT:
          // Do not trim.
          // Spaces are part of lyric alignment.
          lyric: parts[i],
        ),
      );
    }

    return segments;
  }
}