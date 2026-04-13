import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.4))),
        ),
        child: NavigationBar(
          height: 68,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.confirmation_num_outlined),
              label: 'Matches',
            ),
            NavigationDestination(icon: Icon(Icons.article_outlined), label: 'News'),
            NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Leagues'),
            NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              label: 'Reels',
            ),
            NavigationDestination(icon: Icon(Icons.video_library_outlined), label: 'Video'),
          ],
        ),
      ),
    );
  }
}