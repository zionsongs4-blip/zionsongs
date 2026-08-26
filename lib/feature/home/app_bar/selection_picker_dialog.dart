import 'package:flutter/material.dart';

/// ===============================================================
/// SelectionPickerDialog
/// ---------------------------------------------------------------
/// A universal picker dialog to select a destination screen or folder
/// ===============================================================
class SelectionPickerDialog extends StatelessWidget {
  const SelectionPickerDialog({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<SelectionItem> items;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: const Icon(Icons.folder),
              title: Text(item.name),
              onTap: () => Navigator.pop(context, item.id),
            );
          },
        ),
      ),
    );
  }
}

/// ===============================================================
/// SelectionItem
/// ---------------------------------------------------------------
/// Simple model for the picker items
/// ===============================================================
class SelectionItem {
  const SelectionItem({required this.id, required this.name});
  final String id;
  final String name;
}