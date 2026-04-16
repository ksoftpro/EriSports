import 'package:eri_sports/app/navigation/app_shell.dart';
import 'package:eri_sports/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:eri_sports/features/home/presentation/calendar_screen.dart';
import 'package:eri_sports/features/home/presentation/home_screen.dart';
import 'package:eri_sports/features/leagues/presentation/league_overview_screen.dart';
import 'package:eri_sports/features/leagues/presentation/leagues_screen.dart';
import 'package:eri_sports/features/match_detail/presentation/match_detail_screen.dart';
import 'package:eri_sports/features/more/presentation/about_screen.dart';
import 'package:eri_sports/features/more/presentation/more_screen.dart';
import 'package:eri_sports/features/more/presentation/secure_content_screen.dart';
import 'package:eri_sports/features/news/presentation/offline_news_screen.dart';
import 'package:eri_sports/features/player/presentation/player_screen.dart';
import 'package:eri_sports/features/player_stats/presentation/player_stats_screen.dart';
import 'package:eri_sports/features/reels/presentation/reels_screen.dart';
import 'package:eri_sports/features/search/presentation/search_screen.dart';
import 'package:eri_sports/features/sync/presentation/daylysport_sync_screen.dart';
import 'package:eri_sports/features/team/presentation/team_screen.dart';
import 'package:eri_sports/features/video/presentation/video_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: HomeScreen(
                        initialDateIso: state.uri.queryParameters['date'],
                        initialDateFocusToken:
                            state.uri.queryParameters['focus'],
                      ),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/news',
                name: 'news',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: OfflineNewsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leagues',
                name: 'leagues',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: LeaguesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reels',
                name: 'reels',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: ReelsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/video',
                name: 'video',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: VideoScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/following',
        name: 'following',
        builder: (context, state) => const BookmarksScreen(),
      ),
      GoRoute(path: '/bookmarks', redirect: (context, state) => '/following'),
      GoRoute(path: '/more', redirect: (context, state) => '/settings'),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const MoreScreen(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/secure-content',
        name: 'secure-content',
        builder: (context, state) => const SecureContentScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/calendar',
        name: 'calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/league/:leagueId',
        builder:
            (context, state) => LeagueOverviewScreen(
              competitionId: state.pathParameters['leagueId']!,
              competitionNameHint: state.uri.queryParameters['leagueName'],
            ),
      ),
      GoRoute(
        path: '/standings/:competitionId',
        builder:
            (context, state) => LeagueOverviewScreen(
              competitionId: state.pathParameters['competitionId']!,
              competitionNameHint: state.uri.queryParameters['leagueName'],
            ),
      ),
      GoRoute(
        path: '/match/:matchId',
        builder: (context, state) {
          final rawMatchId = state.pathParameters['matchId']!;
          String resolvedMatchId;
          try {
            resolvedMatchId = Uri.decodeComponent(rawMatchId);
          } catch (_) {
            resolvedMatchId = rawMatchId;
          }

          return MatchDetailScreen(matchId: resolvedMatchId);
        },
      ),
      GoRoute(
        path: '/team/:teamId',
        builder:
            (context, state) =>
                TeamScreen(teamId: state.pathParameters['teamId']!),
      ),
      GoRoute(
        path: '/player/:playerId',
        builder: (context, state) {
          final rawPlayerId = state.pathParameters['playerId']!;
          String resolvedPlayerId;
          try {
            resolvedPlayerId = Uri.decodeComponent(rawPlayerId);
          } catch (_) {
            resolvedPlayerId = rawPlayerId;
          }

          return PlayerScreen(playerId: resolvedPlayerId);
        },
      ),
      GoRoute(
        path: '/player-stats',
        builder:
            (context, state) => PlayerStatsScreen(
              initialCompetitionId: state.uri.queryParameters['competitionId'],
              initialStatType: state.uri.queryParameters['statType'],
            ),
      ),
      GoRoute(
        path: '/sync',
        builder: (context, state) => const DaylysportSyncScreen(),
      ),
    ],
  );
});
