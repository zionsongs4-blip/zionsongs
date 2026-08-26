import 'package:flutter/material.dart';

import 'widgets/hymn_viewer_widget.dart';

class HymnDetailView extends StatelessWidget {
  const HymnDetailView({
    super.key,
    required this.hymnId,
    this.sourceHymnIds,
    this.initialIndex,
  });

  final String hymnId;
  final List<String>? sourceHymnIds;
  final int? initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hymn')),
      body: HymnViewerWidget(
        initialHymnId: hymnId,
        hymnIds: sourceHymnIds ?? [hymnId],
        initialHymn: null,
      ),
    );
  }
}
