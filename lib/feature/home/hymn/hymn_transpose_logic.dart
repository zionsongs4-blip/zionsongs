import 'hymn_models.dart';

class HymnTransposeLogic {
  static const List<String> _chromaticSharps = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static const List<String> _chromaticFlats = [
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  static const Map<String, String> _flatToSharp = {
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
    'Bb': 'A#',
  };

  static const Map<String, String> _sharpToFlat = {
    'C#': 'Db',
    'D#': 'Eb',
    'F#': 'Gb',
    'G#': 'Ab',
    'A#': 'Bb',
  };

  static final RegExp _chordLineRegex = RegExp(
    r'^\s*([A-G][#b]?(m|min|maj|dim|aug|sus|add)?[0-9]*(maj|min)?[0-9]?(/[A-G][#b]?)?\s*)+$',
  );

  static final RegExp _headingRegex = RegExp(
    r'^(Intro|Verse|Chorus|Bridge|Tag|Ending|Interlude|Pre-Chorus)',
    caseSensitive: false,
  );

  static final RegExp _chordRegex = RegExp(
    r'([A-G][#b]?)(m|min|maj|dim|aug|sus|add)?([0-9]*)(/[A-G][#b]?)?',
  );


  static Future<void> savePref(UserHymnPref pref) async {
    pref.modifiedOn = now();

    await pref.isar!.writeTxn(() async {
      await pref.isar!.userHymnPrefs.put(pref);
    });
  }


  static String? detectKey(String lyrics) {
    for (var line in lyrics.split('\n').skip(4)) {
      if (_headingRegex.hasMatch(line)) continue;

      if (_chordLineRegex.hasMatch(line)) {
        final match = _chordRegex.firstMatch(line);

        if (match != null) {
          return _normalize(
            match.group(1)!,
            false,
          );
        }
      }
    }

    return null;
  }


  static String _normalize(
    String key,
    bool preferFlats,
  ) {
    if (preferFlats) {
      return _sharpToFlat[key] ?? key;
    }

    return _flatToSharp[key] ?? key;
  }


  static String transpose(
    String key,
    int offset,
    bool preferFlats,
  ) {
    key = _flatToSharp[key] ?? key;

    final index = _chromaticSharps.indexOf(key);

    if (index == -1) {
      return key;
    }

    var newIndex = (index + offset) % 12;

    if (newIndex < 0) {
      newIndex += 12;
    }

    return _normalize(
      _chromaticSharps[newIndex],
      preferFlats,
    );
  }


  static String reverseTranspose(
    String displayedKey,
    int offset,
    bool preferFlats,
  ) {
    return transpose(
      displayedKey,
      -offset,
      preferFlats,
    );
  }


  static String transposeLyrics(
    String lyrics,
    int offset,
    bool preferFlats,
  ) {
    return lyrics
        .split('\n')
        .map((line) {

          if (_headingRegex.hasMatch(line)) {
            return line;
          }

          if (!_chordLineRegex.hasMatch(line)) {
            return line;
          }

          return line.replaceAllMapped(
            _chordRegex,
            (match) {

              final root = match.group(1)!;
              final quality = match.group(2) ?? '';
              final number = match.group(3) ?? '';
              final bass = match.group(4);

              String result =
                  '${transpose(root, offset, preferFlats)}'
                  '$quality'
                  '$number';

              if (bass != null && bass.isNotEmpty) {
                result +=
                    '/${transpose(
                      bass.substring(1),
                      offset,
                      preferFlats,
                    )}';
              }

              return result;
            },
          );
        })
        .join('\n');
  }


  static List<String> getScale(bool preferFlats) {
    return preferFlats
        ? _chromaticFlats
        : _chromaticSharps;
  }
}