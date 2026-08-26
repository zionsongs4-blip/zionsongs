import 'package:flutter/material.dart';

class HomeNavigationDrawer extends StatelessWidget {
  const HomeNavigationDrawer({
    super.key,
    required this.onHome,
    required this.onFavorites,
    required this.onViewLists,
    required this.onMedleys,
  });

  final VoidCallback onHome;
  final VoidCallback onFavorites;
  final VoidCallback onViewLists;
  final VoidCallback onMedleys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget navItem(
      String title,
      VoidCallback onTap,
    ) {
      return ListTile(
        dense: true,
        visualDensity: const VisualDensity(
          vertical: -2, // Tighter vertical spacing
          horizontal: 0,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
      );
    }

    const drawerWidth = 140.0;

    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, // Shrink-wrap the column height
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8, // Reduced top padding from 12 to 8
                  16,
                  2, // Reduced bottom padding from 4 to 2
                ),
                child: Text(
                  'Navigate',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              navItem(
                'Home',
                onHome,
              ),
              navItem(
                'Favorites',
                onFavorites,
              ),
              navItem(
                'View Lists',
                onViewLists,
              ),
              navItem(
                'Medleys',
                onMedleys,
              ),
            ],
          ),
        ),
      ),
    );
  }
}