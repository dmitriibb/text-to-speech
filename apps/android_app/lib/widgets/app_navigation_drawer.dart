import 'package:flutter/material.dart';

enum AppDestination { home, models, about }

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Navigation',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _DestinationTile(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              selected: selectedDestination == AppDestination.home,
              onTap: () => onDestinationSelected(AppDestination.home),
            ),
            _DestinationTile(
              icon: Icons.library_books_outlined,
              selectedIcon: Icons.library_books,
              label: 'Models',
              selected: selectedDestination == AppDestination.models,
              onTap: () => onDestinationSelected(AppDestination.models),
            ),
            _DestinationTile(
              icon: Icons.info_outline,
              selectedIcon: Icons.info,
              label: 'About',
              selected: selectedDestination == AppDestination.about,
              onTap: () => onDestinationSelected(AppDestination.about),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(selected ? selectedIcon : icon),
      title: Text(label),
      selected: selected,
      onTap: onTap,
    );
  }
}
