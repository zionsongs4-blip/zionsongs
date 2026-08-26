import 'package:flutter/material.dart';
import 'viewlist_screen.dart';

class MedleysScreen extends StatelessWidget {
  const MedleysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ViewListScreen(collection: 'medleys');
  }
}