import 'package:flutter/material.dart';

/// ===============================================================
/// HomeAlphabetBar
/// ---------------------------------------------------------------
///
/// A-Z quick navigation.
///
/// RESPONSIBILITY
/// • Display A-Z vertically.
/// • Notify parent when a letter is selected.
/// • UI only.
///
/// OFFLINE FIRST
/// ---------------------------------------------------------------
/// No Firestore.
/// No Isar.
/// No Repository.
/// No SyncQueue.
///
/// The parent decides how to scroll the hymn list.
///
/// Future
/// ---------------------------------------------------------------
/// When connected to HomeHymnList:
///
/// A tapped
///     ↓
/// HomePage
///     ↓
/// HomeHymnList
///     ↓
/// Scroll to first hymn beginning with A
///
/// ===============================================================
class HomeAlphabetBar extends StatelessWidget {
  const HomeAlphabetBar({
    super.key,
    this.onLetterSelected,
    this.selectedLetter,
  });

  final ValueChanged<String>? onLetterSelected;
  final String? selectedLetter;

  static const List<String> _letters = [
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: _letters.length,
        itemBuilder: (context, index) {
          final letter = _letters[index];
          final isSelected = selectedLetter != null &&
              letter.toUpperCase() == selectedLetter!.toUpperCase();
          final colorScheme = Theme.of(context).colorScheme;

          return InkWell(
            onTap: () => onLetterSelected?.call(letter),
            child: Container(
              height: 22,
              margin: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primaryContainer : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}