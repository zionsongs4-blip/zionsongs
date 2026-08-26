import 'package:flutter/material.dart';

import 'hymn_detail_view.dart';

class HymnDetailPage extends StatelessWidget {
  const HymnDetailPage({
    super.key,
    required this.hymnId,
  });

  final String hymnId;

  @override
  Widget build(BuildContext context) {
    return HymnDetailView(
      hymnId: hymnId,
    );
  }
}