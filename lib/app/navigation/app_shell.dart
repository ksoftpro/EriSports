import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
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
    final badges = ref.watch(offlineContentBadgeCountsProvider);

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
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.confirmation_num_outlined),
              label: 'Matches',
            ),
            NavigationDestination(
              icon: _NavBadge(
                count: badges.newsImages,
                child: const Icon(Icons.article_outlined),
              ),
              label: 'News',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events),
              label: 'Leagues',
            ),
            NavigationDestination(
              icon: _NavBadge(
                count: badges.reels,
                child: const Icon(Icons.play_circle_outline),
              ),
              label: 'Reels',
            ),
            NavigationDestination(
              icon: _NavBadge(
                count: badges.videoTotal,
                child: const Icon(Icons.video_library_outlined),
              ),
              label: 'Video',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return child;
    }

    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -10,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.error,
              borderRadius: BorderRadius.circular(999),
            ),
            constraints: const BoxConstraints(minWidth: 18),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onError,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
