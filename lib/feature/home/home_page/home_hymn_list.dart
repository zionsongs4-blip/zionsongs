import 'package:flutter/material.dart';

import '../app_bar/home_selection_controller.dart';
import '../home_models.dart' as models;
import 'home_hymn_tile.dart';

/// ===============================================================
/// HomeHymnList
/// ---------------------------------------------------------------
///
/// Displays the hymn list.
///
/// RESPONSIBILITY
/// • Display hymns.
/// • Forward tap and long press to HomeSelectionController.
/// • No Firestore.
/// • No Isar.
/// • No Repository.
/// • No SyncQueue.
///
/// OFFLINE FIRST
/// ---------------------------------------------------------------
/// Eventually this widget will receive hymns from the Repository,
/// which itself reads from Isar first and syncs later.
/// This widget never knows where the data came from.
///
/// Columns
/// ---------------------------------------------------------------
/// ✓ Selection
/// ✓ Sr No
/// ✓ Title
/// ✓ Favorite
/// ✓ Page
/// ===============================================================
class HomeHymnList extends StatelessWidget {
  const HomeHymnList({
    super.key,
    required this.hymns,
    required this.selectionController,
    this.onOpen,
    this.scrollController,
    this.onToggleFavorite,
  });

  final List<models.HomeHymn> hymns;
  final HomeSelectionController selectionController;
  final ValueChanged<String>? onOpen;
  final ScrollController? scrollController;
  final ValueChanged<String>? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.of(context).viewInsets.bottom + kMinInteractiveDimension * 4;

    return AnimatedBuilder(
      animation: selectionController,
      builder: (context, _) {
        return ListView.separated(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
          itemCount: hymns.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final hymn = hymns[index];

            return HomeHymnTile(
              hymnId: hymn.hymnId,
              serialNo: 'ZS${hymn.serialNo.toString().padLeft(4, '0')}',
              title: hymn.title,
              tempo: hymn.tempo?.toString() ?? '',
              isFavorite: hymn.favorite,
              selectionController: selectionController,
              onOpen: () => onOpen?.call(hymn.hymnId),
              onToggleFavorite: () => onToggleFavorite?.call(hymn.hymnId),
              snippet: hymn.snippet,
            );
          },
        );
      },
    );
  }
}
