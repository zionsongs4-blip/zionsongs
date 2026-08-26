import 'dart:convert';

enum HymnSectionType {
  intro,
  chorus,
  verse,
  bridge,
  ending,
  outro,
  refrain,
  unknown,
}

class HymnSection {
  HymnSection({
    required this.sectionType,
    required this.originalHeading,
    required this.lyrics,
    required this.displayOrder,
    this.verseNumber,
  });

  final HymnSectionType sectionType;
  final String originalHeading;
  final String lyrics;
  final int displayOrder;
  final int? verseNumber;

  String get headingLabel {
    switch (sectionType) {
      case HymnSectionType.intro:
        return 'Intro';
      case HymnSectionType.chorus:
        return 'CH';
      case HymnSectionType.verse:
        return verseNumber != null ? 'Verse $verseNumber' : 'Verse';
      case HymnSectionType.bridge:
        return 'Bridge';
      case HymnSectionType.ending:
        return 'Ending';
      case HymnSectionType.outro:
        return 'Outro';
      case HymnSectionType.refrain:
        return 'Refrain';
      case HymnSectionType.unknown:
        return originalHeading.trim().isNotEmpty ? originalHeading : 'Section';
    }
  }
}

class HymnSectionParser {
  static List<HymnSection> parse(String rawLyrics) {
    final text = rawLyrics.trim();
    if (text.isEmpty) {
      return const <HymnSection>[];
    }

    final sections = <HymnSection>[];
    final lines = LineSplitter.split(text).toList();
    List<String> currentLines = <String>[];
    String? currentHeading;
    HymnSectionType? currentType;
    int? currentVerseNumber;
    int displayOrder = 0;

    void flushCurrentSection() {
      if (currentHeading == null && currentLines.isEmpty) {
        return;
      }

      final lyrics = currentLines.join('\n').trim();
      sections.add(
        HymnSection(
          sectionType: currentType ?? HymnSectionType.unknown,
          originalHeading: currentHeading ?? '',
          lyrics: lyrics,
          displayOrder: displayOrder++,
          verseNumber: currentVerseNumber,
        ),
      );
    }

    for (final line in lines) {
      final trimmed = line.trim();
      final detected = _detectSection(trimmed);

      if (detected != null) {
        if (currentHeading != null || currentLines.isNotEmpty) {
          flushCurrentSection();
        }
        currentHeading = trimmed;
        currentType = detected.type;
        currentVerseNumber = detected.verseNumber;
        currentLines = <String>[];
        continue;
      }

      if (currentHeading == null && currentLines.isEmpty && trimmed.isEmpty) {
        continue;
      }

      currentLines.add(line);
    }

    if (currentHeading != null || currentLines.isNotEmpty) {
      flushCurrentSection();
    }

    if (sections.isEmpty) {
      return <HymnSection>[
        HymnSection(
          sectionType: HymnSectionType.unknown,
          originalHeading: '',
          lyrics: text,
          displayOrder: 0,
        ),
      ];
    }

    return sections;
  }

  static _DetectedHeading? _detectSection(String line) {
    final normalized = line.toLowerCase();
    if (normalized == 'intro') {
      return _DetectedHeading(HymnSectionType.intro, null);
    }
    if (normalized == 'ch' || normalized == 'chorus') {
      return _DetectedHeading(HymnSectionType.chorus, null);
    }
    if (normalized == 'bridge') {
      return _DetectedHeading(HymnSectionType.bridge, null);
    }
    if (normalized == 'ending') {
      return _DetectedHeading(HymnSectionType.ending, null);
    }
    if (normalized == 'outro') {
      return _DetectedHeading(HymnSectionType.outro, null);
    }
    if (normalized == 'refrain') {
      return _DetectedHeading(HymnSectionType.refrain, null);
    }

    final verseMatch = RegExp(r'^verse\s+(\d+)$').firstMatch(normalized);
    if (verseMatch != null) {
      return _DetectedHeading(HymnSectionType.verse, int.parse(verseMatch.group(1)!));
    }

    return null;
  }
}

class _DetectedHeading {
  const _DetectedHeading(this.type, this.verseNumber);

  final HymnSectionType type;
  final int? verseNumber;
}
