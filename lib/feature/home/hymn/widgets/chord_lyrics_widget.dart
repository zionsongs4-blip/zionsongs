import 'package:flutter/material.dart';
import 'chord_parser_service.dart';

class ChordLyricsWidget extends StatelessWidget {
  final String lyrics;
  final bool showChords;
  final double fontSize;

  const ChordLyricsWidget({
    super.key,
    required this.lyrics,
    required this.showChords,
    this.fontSize = 16,
  });

  TextStyle get _lyricStyle => TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        height: 1.3,
      );

  TextStyle get _chordStyle => TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        color: Colors.blue,
        fontSize: fontSize - 2,
        height: 0.8,
      );

  Widget _buildSingleColumn(
    String content, {
    required bool showChordMarkup,
  }) {
    if (!showChordMarkup) {
      return SelectableText(
        ChordParserService.stripChordMarkers(content),
        style: _lyricStyle,
      );
    }

    final lines = ChordParserService.parseLyrics(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: lines.map((segments) {
        final hasChord =
            segments.any((segment) => segment.chord.isNotEmpty);

        if (!hasChord) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SelectableText(
              segments.map((e) => e.lyric).join(''),
              style: _lyricStyle,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: RichText(
            text: TextSpan(
              children: segments.map((segment) {
                return TextSpan(
                  children: [
                    if (segment.chord.isNotEmpty)
                      TextSpan(
                        text: '${segment.chord}\n',
                        style: _chordStyle,
                      ),
                    TextSpan(
                      text: segment.lyric,
                      style: _lyricStyle,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (lyrics.contains('\u001f')) {
      final split = lyrics.split('\u001f');

      final left = split.first;
      final right = split.length > 1
          ? split.sublist(1).join('\u001f')
          : '';

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 6, right: 8),
              child: _buildSingleColumn(
                left,
                showChordMarkup: showChords,
              ),
            ),
          ),
          const VerticalDivider(
            width: 20,
            thickness: 1,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildSingleColumn(
                right,
                showChordMarkup: showChords,
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: _buildSingleColumn(
        lyrics,
        showChordMarkup: showChords,
      ),
    );
  }
}