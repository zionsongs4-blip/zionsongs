import 'package:flutter/material.dart';

import 'hymn_detail_view.dart';

class HymnDetailScreen extends StatelessWidget {
  const HymnDetailScreen({
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
    return HymnDetailView(
      hymnId: hymnId,
      sourceHymnIds: sourceHymnIds,
      initialIndex: initialIndex,
    );
  }
}