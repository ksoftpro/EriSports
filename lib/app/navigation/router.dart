import 'package:eri_sports/app/navigation/app_shell.dart';
import 'package:eri_sports/app/config/app_product_variant.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:eri_sports/features/admin/presentation/admin_login_screen.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouteObserverProvider = Provider<RouteObserver<ModalRoute<void>>>(
  (ref) => RouteObserver<ModalRoute<void>>(),
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final variant = ref.watch(appProductVariantProvider);
  final adminAuthService = ref.read(appServicesProvider).adminAuthService;

  return GoRouter(
    initialLocation: variant.initialLocation,
    observers: [ref.watch(appRouteObserverProvider)],
    refreshListenable:
        variant == AppProductVariant.admin ? adminAuthService : null,
    redirect: (context, state) {
      if (variant != AppProductVariant.admin) {
        return null;
      }

      final isLoginRoute = state.matchedLocation == '/admin-login';
      if (adminAuthService.requiresSetup) {
        return isLoginRoute ? null : '/admin-login';
      }
      if (!adminAuthService.isAuthenticated) {
        return isLoginRoute ? null : '/admin-login';
      }
      if (adminAuthService.isAuthenticated && isLoginRoute) {
        return '/secure-content';
      }
      return null;
    },
    routes:
        variant == AppProductVariant.admin
            ? _buildAdminRoutes()
            : _buildClientRoutes(),
  );
});

List<RouteBase> _buildClientRoutes() {
  return [
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
                      initialDateFocusToken: state.uri.queryParameters['focus'],
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
    GoRoute(path: '/', redirect: (context, state) => '/home'),
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
  ];
}

List<RouteBase> _buildAdminRoutes() {
  return [
    GoRoute(path: '/', redirect: (context, state) => '/secure-content'),
    GoRoute(
      path: '/admin-login',
      name: 'admin-login',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/secure-content',
      name: 'secure-content',
      builder: (context, state) => const SecureContentScreen(),
    ),
    GoRoute(
      path: '/sync',
      builder: (context, state) => const DaylysportSyncScreen(),
    ),
  ];
}
