import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final currentShellBranchIndexProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    _syncShellIndex();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncShellIndex();
  }

  void _onDestinationSelected(int index) {
    ref.read(currentShellBranchIndexProvider.notifier).state = index;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _syncShellIndex() {
    final notifier = ref.read(currentShellBranchIndexProvider.notifier);
    if (notifier.state != widget.navigationShell.currentIndex) {
      notifier.state = widget.navigationShell.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
          ),
        ),
        child: NavigationBar(
          height: 68,
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.confirmation_num_outlined),
              label: 'Matches',
            ),
            NavigationDestination(
              icon: Icon(Icons.article_outlined),
              label: 'News',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events),
              label: 'Leagues',
            ),
            NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              label: 'Reels',
            ),
            NavigationDestination(
              icon: Icon(Icons.video_library_outlined),
              label: 'Video',
            ),
          ],
        ),
      ),
    );
  }
}
