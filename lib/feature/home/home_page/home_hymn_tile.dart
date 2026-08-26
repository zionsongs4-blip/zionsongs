import 'package:flutter/material.dart';

import '../app_bar/home_selection_controller.dart';

/// ===============================================================
/// HomeHymnTile
/// ---------------------------------------------------------------
///
/// Displays ONE hymn in the Home page list.
///
/// OFFLINE FIRST
/// ---------------------------------------------------------------
/// UI only.
/// Never talks to:
/// • Firestore
/// • Isar
/// • Repository
/// • SyncQueue
///
/// It only reflects the data passed to it.
///
/// Layout
///
/// ✓  Sr No
/// ✓  Title
/// ✓  Favorite
/// ✓  Page No
///
/// Long Press
/// ----------
/// Select hymn.
///
/// Tap
/// ---
/// • Open Hymn when not in selection mode.
/// • Toggle selection when selection mode is active.
/// ===============================================================
class HomeHymnTile extends StatelessWidget {
  const HomeHymnTile({
    super.key,
    required this.hymnId,
    required this.serialNo,
    required this.title,
    required this.tempo,
    required this.isFavorite,
    required this.selectionController,
    this.snippet,
    this.onOpen,
    this.onToggleFavorite,
  });

  final String hymnId;
  final String serialNo;
  final String title;
  final String tempo;
  final bool isFavorite;

  final HomeSelectionController selectionController;
  final String? snippet;

  final VoidCallback? onOpen;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final selected = selectionController.isSelected(hymnId);

    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (selectionController.hasSelection) {
            selectionController.toggle(hymnId);
          } else {
            onOpen?.call();
          }
        },
        onLongPress: () {
          selectionController.select(hymnId);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              //----------------------------------------------------
              // 1. Selection Indicator & Serial Number (Extreme Left)
              //----------------------------------------------------
              SizedBox(
                width: 28,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    key: ValueKey(selected),
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),

              SizedBox(
                width: 75, // Sized safely for 6 characters like 'ZS0014'
                child: Text(serialNo, overflow: TextOverflow.ellipsis),
              ),

              //----------------------------------------------------
              // 2. Title (Gets all remaining balance space)
              //----------------------------------------------------
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (snippet != null && snippet!.isNotEmpty)
                      Text(
                        snippet!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),

              //----------------------------------------------------
              // 3. Favorite Star Icon
              //----------------------------------------------------
              SizedBox(
                width: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                  onPressed: onToggleFavorite,
                ),
              ),

              //----------------------------------------------------
              // 4. Tempo (3 digits max fixed width)
              //----------------------------------------------------
              SizedBox(
                width: 35, // Comfortably fits 3 digits
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    tempo,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              //----------------------------------------------------
              // 5. A-Z / Extra Indicator Bar (Extreme Right)
              //----------------------------------------------------

              // If you have a specific A-Z trailing element or search widget for the tile row,
              // it can sit right here on the extreme right edge with a fixed width.
            ],
          ),
        ),
      ),
    );
  }
}
