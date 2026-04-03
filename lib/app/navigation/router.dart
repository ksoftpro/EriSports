import 'package:eri_sports/app/navigation/app_shell.dart';
import 'package:eri_sports/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:eri_sports/features/home/presentation/home_screen.dart';
import 'package:eri_sports/features/leagues/presentation/leagues_screen.dart';
import 'package:eri_sports/features/more/presentation/more_screen.dart';
import 'package:eri_sports/features/search/presentation/search_screen.dart';
import 'package:eri_sports/features/standings/presentation/standings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leagues',
                name: 'leagues',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: LeaguesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SearchScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookmarks',
                name: 'bookmarks',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: BookmarksScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                name: 'more',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: MoreScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/league/:leagueId',
        builder: (context, state) => _DetailPlaceholder(
          title: 'League ${state.pathParameters['leagueId']}',
        ),
      ),
      GoRoute(
        path: '/standings/:competitionId',
        builder: (context, state) => StandingsScreen(
          competitionId: state.pathParameters['competitionId']!,
        ),
      ),
      GoRoute(
        path: '/match/:matchId',
        builder: (context, state) => _DetailPlaceholder(
          title: 'Match ${state.pathParameters['matchId']}',
        ),
      ),
      GoRoute(
        path: '/team/:teamId',
        builder: (context, state) => _DetailPlaceholder(
          title: 'Team ${state.pathParameters['teamId']}',
        ),
      ),
      GoRoute(
        path: '/player/:playerId',
        builder: (context, state) => _DetailPlaceholder(
          title: 'Player ${state.pathParameters['playerId']}',
        ),
      ),
    ],
  );
});

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title page is ready for data-bound implementation.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}