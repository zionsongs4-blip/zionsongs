import 'package:flutter/material.dart';

/// ===============================================================
/// HomeFilterBar
/// ---------------------------------------------------------------
///
/// Displays Home page filters.
///
/// OFFLINE FIRST
///
/// UI ONLY.
/// No Firestore.
/// No Isar.
/// No Repository.
///
/// Filters:
/// • KEY
/// • DEDICATED
/// • YEAR
/// • TEMPO RANGE
///
/// Reset always visible.
/// ===============================================================

class HomeFilterBar extends StatelessWidget {
  const HomeFilterBar({
    super.key,

    required this.keyLabel,
    required this.dedicatedLabel,
    required this.yearLabel,
    required this.tempoLabel,

    this.keySelected = 0,
    this.dedicatedSelected = 0,
    this.yearSelected = 0,
    this.tempoSelected = 0,

    this.onKeyTap,
    this.onDedicatedTap,
    this.onYearTap,
    this.onTempoTap,
    this.onReset,
    this.keyLayerLink,
    this.dedicatedLayerLink,
    this.yearLayerLink,
    this.tempoLayerLink,
    this.keyButtonKey,
    this.dedicatedButtonKey,
    this.yearButtonKey,
    this.tempoButtonKey,
  });

  final String keyLabel;
  final String dedicatedLabel;
  final String yearLabel;
  final String tempoLabel;

  final int keySelected;
  final int dedicatedSelected;
  final int yearSelected;
  final int tempoSelected;

  final VoidCallback? onKeyTap;
  final VoidCallback? onDedicatedTap;
  final VoidCallback? onYearTap;
  final VoidCallback? onTempoTap;
  final VoidCallback? onReset;
  final LayerLink? keyLayerLink;
  final LayerLink? dedicatedLayerLink;
  final LayerLink? yearLayerLink;
  final LayerLink? tempoLayerLink;
  final GlobalKey? keyButtonKey;
  final GlobalKey? dedicatedButtonKey;
  final GlobalKey? yearButtonKey;
  final GlobalKey? tempoButtonKey;


  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 4,
        ),
        child: Row(
          children: [

            Expanded(
              child: _filterButton(
                context,
                label: keyLabel,
                count: keySelected,
                onPressed: onKeyTap,
                layerLink: keyLayerLink,
                buttonKey: keyButtonKey,
              ),
            ),

            const SizedBox(width: 6),

            Expanded(
              child: _filterButton(
                context,
                label: dedicatedLabel,
                count: dedicatedSelected,
                onPressed: onDedicatedTap,
                layerLink: dedicatedLayerLink,
                buttonKey: dedicatedButtonKey,
              ),
            ),

            const SizedBox(width: 6),

            Expanded(
              child: _filterButton(
                context,
                label: yearLabel,
                count: yearSelected,
                onPressed: onYearTap,
                layerLink: yearLayerLink,
                buttonKey: yearButtonKey,
              ),
            ),

            const SizedBox(width: 6),

            Expanded(
              child: _rangeButton(
                context,
                label: tempoLabel,
                count: tempoSelected,
                onPressed: onTempoTap,
                layerLink: tempoLayerLink,
                buttonKey: tempoButtonKey,
              ),
            ),

            const SizedBox(width: 8),

            OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                minimumSize: Size.zero,
              ),
              child: const Text(
                'RESET',
                style: TextStyle(
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _filterButton(BuildContext context, {
    required String label,
    required int count,
    VoidCallback? onPressed,
    LayerLink? layerLink,
    GlobalKey? buttonKey,
  }) {
    final active = count > 0;
    final button = OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        backgroundColor: active ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
      child: Text(
        count == 0 ? label : '$label ($count)',
        style: TextStyle(
          fontSize: 11,
          color: active ? Theme.of(context).colorScheme.onPrimaryContainer : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (layerLink != null) {
      return CompositedTransformTarget(
        link: layerLink,
        child: button,
      );
    }

    return button;
  }


  Widget _rangeButton(BuildContext context, {
    required String label,
    required int count,
    VoidCallback? onPressed,
    LayerLink? layerLink,
    GlobalKey? buttonKey,
  }) {
    final active = count > 0;
    final button = OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        backgroundColor: active ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
      child: Text(
        count == 0 ? label : '$label ($count)',
        style: TextStyle(
          fontSize: 11,
          color: active ? Theme.of(context).colorScheme.onPrimaryContainer : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (layerLink != null) {
      return CompositedTransformTarget(
        link: layerLink,
        child: button,
      );
    }

    return button;
  }
}