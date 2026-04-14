import 'dart:io';
import 'dart:math' as math;

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/detail_navigation.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:eri_sports/features/leagues/presentation/league_overview_providers.dart';
import 'package:eri_sports/features/leagues/presentation/league_theme_resolver.dart';
import 'package:eri_sports/features/player_stats/presentation/player_stats_providers.dart';
import 'package:eri_sports/shared/formatters/match_display_formatter.dart';
import 'package:eri_sports/shared/widgets/compact_standings_table.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class LeagueOverviewScreen extends ConsumerStatefulWidget {
  const LeagueOverviewScreen({required this.competitionId, super.key});

  final String competitionId;

  @override
  ConsumerState<LeagueOverviewScreen> createState() =>
      _LeagueOverviewScreenState();
}

class _LeagueOverviewScreenState extends ConsumerState<LeagueOverviewScreen> {
  String _selectedStandingsModeKey = 'all';
  LeagueFixtureFilter _fixtureFilter = LeagueFixtureFilter.all;
  LeagueNewsFilter _newsFilter = LeagueNewsFilter.all;
  LeagueTeamStatMetric _teamMetric = LeagueTeamStatMetric.points;
  String? _selectedSeason;
  String? _selectedPlayerStatType;

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(
      leagueOverviewProvider(widget.competitionId),
    );

    return DefaultTabController(
      length: 8,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: SafeArea(
          child: overviewAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => const _LeagueErrorState(),
            data: (state) {
              final resolver = ref.read(appServicesProvider).assetResolver;
              final seasonLabel = _resolveSeasonLabel(
                state.availableSeasonLabels,
              );
              final seasonFixtures = _filterFixturesBySeason(
                state.fixtureRows,
                seasonLabel,
              );
              final nextOpponents = _buildNextOpponentMap(seasonFixtures);
              final headerPref = ref.watch(
                leagueHeaderPreferenceProvider(widget.competitionId),
              );
              final visualTheme = state.visualTheme;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1260),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      children: [
                        _LeagueHeaderCard(
                          competitionId: state.competitionId,
                          competitionName: state.competitionName,
                          countryLabel: state.countryLabel,
                          seasonLabel: seasonLabel,
                          isFollowing: headerPref.isFollowing,
                          notificationsOn: headerPref.notificationsOn,
                          theme: visualTheme,
                          resolver: resolver,
                          onBack: () => context.pop(),
                          onSeasonTap:
                              () =>
                                  _showSeasonSheet(state.availableSeasonLabels),
                          onFollowTap: () {
                            ref
                                .read(
                                  leagueHeaderPreferenceProvider(
                                    widget.competitionId,
                                  ).notifier,
                                )
                                .update(
                                  (pref) => pref.copyWith(
                                    isFollowing: !pref.isFollowing,
                                  ),
                                );
                          },
                          onNotifyTap: () {
                            ref
                                .read(
                                  leagueHeaderPreferenceProvider(
                                    widget.competitionId,
                                  ).notifier,
                                )
                                .update(
                                  (pref) => pref.copyWith(
                                    notificationsOn: !pref.notificationsOn,
                                  ),
                                );
                          },
                        ),
                        const SizedBox(height: 10),
                        _LeagueTabsBar(theme: visualTheme),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFDDE1E6),
                              ),
                            ),
                            child: TabBarView(
                              children: [
                                _OverviewTab(
                                  state: state,
                                  fixtures: seasonFixtures,
                                  seasonLabel: seasonLabel,
                                  resolver: resolver,
                                ),
                                _TableTab(
                                  standings: state.standings,
                                  overallRows: state.overallStandingsRows,
                                  selectedModeKey: _selectedStandingsModeKey,
                                  resolver: resolver,
                                  nextOpponents: nextOpponents,
                                  onModeChanged: (modeKey) {
                                    setState(() {
                                      _selectedStandingsModeKey = modeKey;
                                    });
                                  },
                                ),
                                _FixturesTab(
                                  fixtures: seasonFixtures,
                                  filter: _fixtureFilter,
                                  resolver: resolver,
                                  onFilterChanged: (filter) {
                                    setState(() {
                                      _fixtureFilter = filter;
                                    });
                                  },
                                ),
                                _NewsTab(
                                  competitionId: state.competitionId,
                                  newsItems: state.newsItems,
                                  filter: _newsFilter,
                                  resolver: resolver,
                                  onFilterChanged: (filter) {
                                    setState(() {
                                      _newsFilter = filter;
                                    });
                                  },
                                ),
                                _PlayerStatsBody(
                                  competitionId: state.competitionId,
                                  selectedStatType: _selectedPlayerStatType,
                                  onSelectedStatType: (value) {
                                    setState(() {
                                      _selectedPlayerStatType = value;
                                    });
                                  },
                                  resolver: resolver,
                                ),
                                _TeamStatsBody(
                                  rows: state.overallStandingsRows,
                                  metric: _teamMetric,
                                  resolver: resolver,
                                  onMetricChanged: (metric) {
                                    setState(() {
                                      _teamMetric = metric;
                                    });
                                  },
                                ),
                                _TransfersTab(
                                  transfers: state.transferItems,
                                  resolver: resolver,
                                ),
                                _SeasonsTab(
                                  seasons: state.availableSeasonLabels,
                                  selectedSeason: seasonLabel,
                                  fixtures: state.fixtureRows,
                                  onSelectSeason: (season) {
                                    setState(() {
                                      _selectedSeason = season;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _resolveSeasonLabel(List<String> options) {
    if (options.isEmpty) {
      return '-';
    }
    if (_selectedSeason != null && options.contains(_selectedSeason)) {
      return _selectedSeason!;
    }
    return options.first;
  }

  List<HomeMatchView> _filterFixturesBySeason(
    List<HomeMatchView> fixtures,
    String seasonLabel,
  ) {
    final split = seasonLabel.split('/');
    final year = split.isNotEmpty ? int.tryParse(split.first) : null;
    if (year == null) {
      return fixtures;
    }

    return fixtures
        .where((fixture) {
          final date = fixture.match.kickoffUtc;
          final seasonStartYear = date.month >= 7 ? date.year : date.year - 1;
          return seasonStartYear == year;
        })
        .toList(growable: false);
  }

  Map<String, _NextOpponent> _buildNextOpponentMap(
    List<HomeMatchView> fixtures,
  ) {
    final map = <String, _NextOpponent>{};
    final now = DateTime.now().toUtc();
    final upcoming = fixtures
        .where((item) => item.match.kickoffUtc.isAfter(now))
        .toList(growable: false)
      ..sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));

    for (final item in upcoming) {
      map.putIfAbsent(
        item.match.homeTeamId,
        () => _NextOpponent(
          teamId: item.match.awayTeamId,
          teamName: item.awayTeamName,
        ),
      );
      map.putIfAbsent(
        item.match.awayTeamId,
        () => _NextOpponent(
          teamId: item.match.homeTeamId,
          teamName: item.homeTeamName,
        ),
      );
    }

    return map;
  }

  Future<void> _showSeasonSheet(List<String> seasons) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                dense: true,
                title: Text(
                  'Select season',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...seasons.map(
                (season) => ListTile(
                  dense: true,
                  title: Text(season),
                  trailing:
                      _selectedSeason == season
                          ? const Icon(Icons.check, size: 18)
                          : null,
                  onTap: () => Navigator.of(context).pop(season),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedSeason = selected;
    });
  }
}

class _LeagueHeaderCard extends StatelessWidget {
  const _LeagueHeaderCard({
    required this.competitionId,
    required this.competitionName,
    required this.countryLabel,
    required this.seasonLabel,
    required this.isFollowing,
    required this.notificationsOn,
    required this.theme,
    required this.resolver,
    required this.onBack,
    required this.onNotifyTap,
    required this.onSeasonTap,
    required this.onFollowTap,
  });

  final String competitionId;
  final String competitionName;
  final String countryLabel;
  final String seasonLabel;
  final bool isFollowing;
  final bool notificationsOn;
  final LeagueVisualTheme theme;
  final LocalAssetResolver resolver;
  final VoidCallback onBack;
  final VoidCallback onNotifyTap;
  final VoidCallback onSeasonTap;
  final VoidCallback onFollowTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.headerTop, theme.headerBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.onHeader.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child:
          isCompact
              ? Column(
                children: [
                  Row(
                    children: [
                      _HeaderGhostButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: onBack,
                        iconColor: theme.onHeader,
                        backgroundColor: theme.onHeader.withValues(alpha: 0.14),
                        borderColor: theme.onHeader.withValues(alpha: 0.24),
                      ),
                      const SizedBox(width: 8),
                      _NotificationButton(
                        notificationsOn: notificationsOn,
                        onTap: onNotifyTap,
                        theme: theme,
                      ),
                      const Spacer(),
                      _HeaderSeasonButton(
                        seasonLabel: seasonLabel,
                        onTap: onSeasonTap,
                        textColor: theme.onHeader,
                        backgroundColor: theme.onHeader.withValues(alpha: 0.14),
                        borderColor: theme.onHeader.withValues(alpha: 0.24),
                      ),
                      const SizedBox(width: 8),
                      _FollowButton(
                        isFollowing: isFollowing,
                        onTap: onFollowTap,
                        textColor: theme.onHeader,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _LeagueLogo(
                        competitionId: competitionId,
                        competitionName: competitionName,
                        theme: theme,
                        resolver: resolver,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LeagueNameBlock(
                          competitionName: competitionName,
                          countryLabel: countryLabel,
                          titleColor: theme.onHeader,
                          subtitleColor: theme.onHeaderMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              )
              : Row(
                children: [
                  _HeaderGhostButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack,
                    iconColor: theme.onHeader,
                    backgroundColor: theme.onHeader.withValues(alpha: 0.14),
                    borderColor: theme.onHeader.withValues(alpha: 0.24),
                  ),
                  const SizedBox(width: 8),
                  _NotificationButton(
                    notificationsOn: notificationsOn,
                    onTap: onNotifyTap,
                    theme: theme,
                  ),
                  const SizedBox(width: 12),
                  _LeagueLogo(
                    competitionId: competitionId,
                    competitionName: competitionName,
                    theme: theme,
                    resolver: resolver,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LeagueNameBlock(
                      competitionName: competitionName,
                      countryLabel: countryLabel,
                      titleColor: theme.onHeader,
                      subtitleColor: theme.onHeaderMuted,
                    ),
                  ),
                  _HeaderSeasonButton(
                    seasonLabel: seasonLabel,
                    onTap: onSeasonTap,
                    textColor: theme.onHeader,
                    backgroundColor: theme.onHeader.withValues(alpha: 0.14),
                    borderColor: theme.onHeader.withValues(alpha: 0.24),
                  ),
                  const SizedBox(width: 10),
                  _FollowButton(
                    isFollowing: isFollowing,
                    onTap: onFollowTap,
                    textColor: theme.onHeader,
                  ),
                ],
              ),
    );
  }
}

class _LeagueLogo extends StatelessWidget {
  const _LeagueLogo({
    required this.competitionId,
    required this.competitionName,
    required this.theme,
    required this.resolver,
  });

  final String competitionId;
  final String competitionName;
  final LeagueVisualTheme theme;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.onHeader.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.onHeader.withValues(alpha: 0.28)),
      ),
      child: EntityBadge(
        entityId: competitionId,
        entityName: competitionName,
        type: SportsAssetType.leagues,
        resolver: resolver,
        size: 40,
        isCircular: false,
      ),
    );
  }
}

class _LeagueNameBlock extends StatelessWidget {
  const _LeagueNameBlock({
    required this.competitionName,
    required this.countryLabel,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String competitionName;
  final String countryLabel;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          competitionName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 31,
            height: 1.05,
            color: titleColor,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          countryLabel,
          style: TextStyle(
            fontSize: 17,
            color: subtitleColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeaderGhostButton extends StatelessWidget {
  const _HeaderGhostButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

class _HeaderSeasonButton extends StatelessWidget {
  const _HeaderSeasonButton({
    required this.seasonLabel,
    required this.onTap,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String seasonLabel;
  final VoidCallback onTap;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              seasonLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textColor),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.onTap,
    required this.textColor,
  });

  final bool isFollowing;
  final VoidCallback onTap;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              isFollowing
                  ? Colors.black.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: textColor.withValues(alpha: 0.25)),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.notificationsOn,
    required this.onTap,
    required this.theme,
  });

  final bool notificationsOn;
  final VoidCallback onTap;
  final LeagueVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return _HeaderGhostButton(
      icon:
          notificationsOn
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
      onTap: onTap,
      iconColor: theme.onHeader,
      backgroundColor: theme.onHeader.withValues(alpha: 0.14),
      borderColor: theme.onHeader.withValues(alpha: 0.24),
    );
  }
}

class _LeagueTabsBar extends StatelessWidget {
  const _LeagueTabsBar({required this.theme});

  final LeagueVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.tabBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.onHeader.withValues(alpha: 0.2)),
      ),
      child: TabBar(
        isScrollable: true,
        labelColor: theme.onHeader,
        unselectedLabelColor: theme.onHeaderMuted,
        indicatorColor: theme.onHeader,
        indicatorWeight: 2.2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Color(0x00000000),
        labelPadding: EdgeInsets.only(left: 8, right: 16),
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Table'),
          Tab(text: 'Fixtures'),
          Tab(text: 'News'),
          Tab(text: 'Player stats'),
          Tab(text: 'Team stats'),
          Tab(text: 'Transfers'),
          Tab(text: 'Seasons'),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.state,
    required this.fixtures,
    required this.seasonLabel,
    required this.resolver,
  });

  final LeagueOverviewState state;
  final List<HomeMatchView> fixtures;
  final String seasonLabel;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final rows = List<LeagueStandingsRow>.from(state.overallStandingsRows)
      ..sort((a, b) => a.position.compareTo(b.position));
    final now = DateTime.now().toUtc();
    final playedMatches = fixtures
        .where((item) {
          final status = item.match.status.toLowerCase();
          final isLive = _isLiveStatus(status);
          return !isLive && item.match.kickoffUtc.isBefore(now);
        })
        .toList(growable: false);

    final totalGoals = playedMatches.fold<int>(
      0,
      (sum, item) => sum + item.match.homeScore + item.match.awayScore,
    );
    final avgGoals =
        playedMatches.isEmpty
            ? 0
            : totalGoals / math.max(playedMatches.length, 1);
    final upcomingFixtures =
        fixtures.where((item) => item.match.kickoffUtc.isAfter(now)).toList()
          ..sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));
    final recentFixtures =
        fixtures.where((item) => item.match.kickoffUtc.isBefore(now)).toList()
          ..sort((a, b) => b.match.kickoffUtc.compareTo(a.match.kickoffUtc));

    final topScorer =
        state.goalLeaders.isNotEmpty ? state.goalLeaders.first : null;
    final topAssister =
        state.assistsLeaders.isNotEmpty ? state.assistsLeaders.first : null;
    final leader = rows.firstOrNull;

    LeagueStandingsRow? bestAttack;
    LeagueStandingsRow? bestDefence;
    LeagueStandingsRow? bestFormTeam;
    var bestFormScore = -1;

    for (final row in rows) {
      if (bestAttack == null || row.goalsFor > bestAttack.goalsFor) {
        bestAttack = row;
      }
      if (row.played > 0 &&
          (bestDefence == null ||
              row.goalsAgainst < bestDefence.goalsAgainst)) {
        bestDefence = row;
      }
      final score = _formScore(row.form);
      if (score > bestFormScore) {
        bestFormScore = score;
        bestFormTeam = row;
      }
    }

    final latestTransfer =
        (List<LeagueTransferItem>.from(state.transferItems)..sort(
          (a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc),
        )).firstOrNull;
    final latestNews =
        (List<LeagueNewsItem>.from(state.newsItems)..sort(
          (a, b) => b.publishedAtUtc.compareTo(a.publishedAtUtc),
        )).firstOrNull;
    final insightCount = state.newsItems.where((item) => item.isInsight).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        _OverviewHeroBand(
          competitionName: state.competitionName,
          countryLabel: state.countryLabel,
          seasonLabel: seasonLabel,
          fixtureCount: fixtures.length,
          playedCount: playedMatches.length,
          upcomingCount: upcomingFixtures.length,
        ),
        const SizedBox(height: 12),
        _OverviewStatGrid(
          children: [
            _OverviewStatCard(
              label: 'Clubs',
              value: '${rows.length}',
              caption: 'Table teams',
              icon: Icons.groups_2_outlined,
            ),
            _OverviewStatCard(
              label: 'Matches',
              value: '${fixtures.length}',
              caption: 'Season fixtures',
              icon: Icons.sports_soccer,
            ),
            _OverviewStatCard(
              label: 'Played',
              value: '${playedMatches.length}',
              caption: 'Completed',
              icon: Icons.event_available_outlined,
            ),
            _OverviewStatCard(
              label: 'Goals',
              value: '$totalGoals',
              caption:
                  'Avg ${avgGoals == 0 ? '0.0' : avgGoals.toStringAsFixed(2)}',
              icon: Icons.adjust_rounded,
            ),
            _OverviewStatCard(
              label: 'Transfers',
              value: '${state.transferItems.length}',
              caption:
                  latestTransfer == null
                      ? 'No transfer feed'
                      : 'Latest ${DateFormat('dd MMM').format(latestTransfer.updatedAtUtc.toLocal())}',
              icon: Icons.swap_horiz_rounded,
            ),
            _OverviewStatCard(
              label: 'News',
              value: '${state.newsItems.length}',
              caption: '$insightCount insights',
              icon: Icons.newspaper_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 920) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _OverviewTableHighlight(
                      rows: rows,
                      resolver: resolver,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _OverviewTopPerformersCard(
                          scorer: topScorer,
                          assister: topAssister,
                          resolver: resolver,
                        ),
                        const SizedBox(height: 10),
                        _OverviewNextFixtureCard(
                          upcoming:
                              upcomingFixtures.isNotEmpty
                                  ? upcomingFixtures.first
                                  : null,
                          recent:
                              recentFixtures.isNotEmpty
                                  ? recentFixtures.first
                                  : null,
                          resolver: resolver,
                        ),
                        const SizedBox(height: 10),
                        _OverviewLeagueSignalsCard(
                          resolver: resolver,
                          leader: leader,
                          bestAttack: bestAttack,
                          bestDefence: bestDefence,
                          bestFormTeam: bestFormTeam,
                          bestFormScore: bestFormScore,
                        ),
                        const SizedBox(height: 10),
                        _OverviewPulseCard(
                          latestNews: latestNews,
                          latestTransfer: latestTransfer,
                          resolver: resolver,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _OverviewTableHighlight(rows: rows, resolver: resolver),
                const SizedBox(height: 10),
                _OverviewTopPerformersCard(
                  scorer: topScorer,
                  assister: topAssister,
                  resolver: resolver,
                ),
                const SizedBox(height: 10),
                _OverviewNextFixtureCard(
                  upcoming:
                      upcomingFixtures.isNotEmpty ? upcomingFixtures.first : null,
                  recent: recentFixtures.isNotEmpty ? recentFixtures.first : null,
                  resolver: resolver,
                ),
                const SizedBox(height: 10),
                _OverviewLeagueSignalsCard(
                  resolver: resolver,
                  leader: leader,
                  bestAttack: bestAttack,
                  bestDefence: bestDefence,
                  bestFormTeam: bestFormTeam,
                  bestFormScore: bestFormScore,
                ),
                const SizedBox(height: 10),
                _OverviewPulseCard(
                  latestNews: latestNews,
                  latestTransfer: latestTransfer,
                  resolver: resolver,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  int _formScore(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 0;
    }

    var score = 0;
    final tokens = value
        .toUpperCase()
        .replaceAll(RegExp('[^WDL]'), '')
        .split('');
    for (final token in tokens.take(5)) {
      if (token == 'W') {
        score += 3;
      } else if (token == 'D') {
        score += 1;
      }
    }
    return score;
  }

  bool _isLiveStatus(String status) {
    const tokens = {'live', 'inplay', 'in_play', 'playing', 'ht'};
    return tokens.contains(status);
  }
}

class _OverviewStatCard extends StatelessWidget {
  const _OverviewStatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF667180)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5F6673),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              height: 1,
              color: Color(0xFF131A25),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(
              color: Color(0xFF757C8A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStatGrid extends StatelessWidget {
  const _OverviewStatGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns =
            maxWidth > 1100
                ? 6
                : maxWidth > 760
                ? 3
                : 2;
        final tileWidth = (maxWidth - ((columns - 1) * 10)) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final child in children) SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

class _OverviewHeroBand extends StatelessWidget {
  const _OverviewHeroBand({
    required this.competitionName,
    required this.countryLabel,
    required this.seasonLabel,
    required this.fixtureCount,
    required this.playedCount,
    required this.upcomingCount,
  });

  final String competitionName;
  final String countryLabel;
  final String seasonLabel;
  final int fixtureCount;
  final int playedCount;
  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            competitionName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$countryLabel • Season $seasonLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip('Fixtures', '$fixtureCount'),
              _heroChip('Played', '$playedCount'),
              _heroChip('Upcoming', '$upcomingCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _OverviewPanelCard extends StatelessWidget {
  const _OverviewPanelCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF161D29),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Color(0xFF6A7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _OverviewTableHighlight extends StatelessWidget {
  const _OverviewTableHighlight({required this.rows, required this.resolver});

  final List<LeagueStandingsRow> rows;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final topRows = rows.take(5).toList(growable: false);

    return _OverviewPanelCard(
      title: 'League highlights',
      subtitle: 'Top of the table snapshot',
      child: Column(
        children: [
          if (topRows.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: _InlineEmptyState(
                message: 'No standings imported for this competition yet.',
              ),
            )
          else
            ...topRows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${row.position}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A2230),
                        ),
                      ),
                    ),
                    TeamBadge(
                      teamId: row.teamId,
                      teamName: row.teamName,
                      resolver: resolver,
                      source: 'league.overview.top5',
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.displayTeamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF19202D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${row.points} pts',
                      style: const TextStyle(
                        color: Color(0xFF141B27),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewTopPerformersCard extends StatelessWidget {
  const _OverviewTopPerformersCard({
    required this.scorer,
    required this.assister,
    required this.resolver,
  });

  final TopPlayerLeaderboardEntryView? scorer;
  final TopPlayerLeaderboardEntryView? assister;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    return _OverviewPanelCard(
      title: 'Top stats leaders',
      subtitle: 'Scoring and chance creation',
      child: Column(
        children: [
          _OverviewLeaderTile(
            title: 'Top scorer',
            emptyMessage: 'No top scorer data in this dataset.',
            leader: scorer,
            resolver: resolver,
            source: 'league.overview.top-scorer',
          ),
          const SizedBox(height: 8),
          _OverviewLeaderTile(
            title: 'Assists leader',
            emptyMessage: 'No assists leader data in this dataset.',
            leader: assister,
            resolver: resolver,
            source: 'league.overview.assists',
          ),
        ],
      ),
    );
  }
}

class _OverviewLeaderTile extends StatelessWidget {
  const _OverviewLeaderTile({
    required this.title,
    required this.emptyMessage,
    required this.leader,
    required this.resolver,
    required this.source,
  });

  final String title;
  final String emptyMessage;
  final TopPlayerLeaderboardEntryView? leader;
  final LocalAssetResolver resolver;
  final String source;

  @override
  Widget build(BuildContext context) {
    if (leader == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E6EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF5D6778),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            _InlineEmptyState(message: emptyMessage),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EC)),
      ),
      child: Row(
        children: [
          EntityBadge(
            entityId: leader!.stat.playerId,
            entityName: leader!.stat.playerName,
            type: SportsAssetType.players,
            resolver: resolver,
            size: 36,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF5D6778),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  leader!.stat.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1A2230),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  leader!.teamName ?? 'Unknown Team',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7381),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            compactNumber(leader!.stat.statValue),
            style: const TextStyle(
              fontSize: 21,
              height: 1,
              color: Color(0xFF101723),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewNextFixtureCard extends StatelessWidget {
  const _OverviewNextFixtureCard({
    required this.upcoming,
    required this.recent,
    required this.resolver,
  });

  final HomeMatchView? upcoming;
  final HomeMatchView? recent;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final hasAny = upcoming != null || recent != null;

    return _OverviewPanelCard(
      title: 'Fixture preview',
      subtitle: 'Next up and most recent result',
      child: Column(
        children: [
          if (!hasAny)
            const Align(
              alignment: Alignment.centerLeft,
              child: _InlineEmptyState(message: 'No fixture preview available.'),
            )
          else ...[
            if (upcoming != null)
              _LeagueFixturePreviewRow(
                label: 'Next up',
                fixture: upcoming!,
                resolver: resolver,
                source: 'league.overview.next',
              ),
            if (upcoming != null && recent != null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Color(0xFFE4E8ED)),
              ),
            if (recent != null)
              _LeagueFixturePreviewRow(
                label: 'Latest',
                fixture: recent!,
                resolver: resolver,
                source: 'league.overview.latest',
              ),
          ],
        ],
      ),
    );
  }
}

class _LeagueFixturePreviewRow extends StatelessWidget {
  const _LeagueFixturePreviewRow({
    required this.label,
    required this.fixture,
    required this.resolver,
    required this.source,
  });

  final String label;
  final HomeMatchView fixture;
  final LocalAssetResolver resolver;
  final String source;

  @override
  Widget build(BuildContext context) {
    final score = MatchDisplayFormatter.scoreDisplay(
      status: fixture.match.status,
      kickoffUtc: fixture.match.kickoffUtc,
      homeScore: fixture.match.homeScore,
      awayScore: fixture.match.awayScore,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7381),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            TeamBadge(
              teamId: fixture.match.homeTeamId,
              teamName: fixture.homeTeamName,
              resolver: resolver,
              source: source,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fixture.homeTeamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1A2230),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              score.centerLabel,
              style: const TextStyle(
                color: Color(0xFF121925),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            TeamBadge(
              teamId: fixture.match.awayTeamId,
              teamName: fixture.awayTeamName,
              resolver: resolver,
              source: source,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fixture.awayTeamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1A2230),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd MMM • HH:mm').format(fixture.match.kickoffUtc.toLocal()),
              style: const TextStyle(
                color: Color(0xFF6B7381),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewLeagueSignalsCard extends StatelessWidget {
  const _OverviewLeagueSignalsCard({
    required this.resolver,
    required this.leader,
    required this.bestAttack,
    required this.bestDefence,
    required this.bestFormTeam,
    required this.bestFormScore,
  });

  final LocalAssetResolver resolver;
  final LeagueStandingsRow? leader;
  final LeagueStandingsRow? bestAttack;
  final LeagueStandingsRow? bestDefence;
  final LeagueStandingsRow? bestFormTeam;
  final int bestFormScore;

  @override
  Widget build(BuildContext context) {
    final hasAny =
        leader != null ||
        bestAttack != null ||
        bestDefence != null ||
        bestFormTeam != null;

    return _OverviewPanelCard(
      title: 'League pulse',
      subtitle: 'Who is leading each key signal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasAny)
            const _InlineEmptyState(
              message: 'No standings signals available yet.',
            )
          else ...[
            if (leader != null)
              _signalRow(
                label: 'Leader',
                row: leader!,
                value: '${leader!.points} pts',
              ),
            if (bestAttack != null)
              _signalRow(
                label: 'Best attack',
                row: bestAttack!,
                value: '${bestAttack!.goalsFor} GF',
              ),
            if (bestDefence != null)
              _signalRow(
                label: 'Best defence',
                row: bestDefence!,
                value: '${bestDefence!.goalsAgainst} GA',
              ),
            if (bestFormTeam != null)
              _signalRow(
                label: 'Best form',
                row: bestFormTeam!,
                value: '$bestFormScore pts',
                isLast: true,
              ),
          ],
        ],
      ),
    );
  }

  Widget _signalRow({
    required String label,
    required LeagueStandingsRow row,
    required String value,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7381),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          TeamBadge(
            teamId: row.teamId,
            teamName: row.teamName,
            resolver: resolver,
            source: 'league.overview.pulse',
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              row.displayTeamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1A2230),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF141B27),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewPulseCard extends StatelessWidget {
  const _OverviewPulseCard({
    required this.latestNews,
    required this.latestTransfer,
    required this.resolver,
  });

  final LeagueNewsItem? latestNews;
  final LeagueTransferItem? latestTransfer;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final hasNews = latestNews != null;
    final hasTransfer = latestTransfer != null;

    return _OverviewPanelCard(
      title: 'Feed pulse',
      subtitle: 'Latest movement across news and transfers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasNews && !hasTransfer)
            const _InlineEmptyState(
              message: 'No news or transfer signals found in this dataset.',
            )
          else ...[
            if (hasNews) ...[
              Text(
                'Latest news',
                style: TextStyle(
                  color: Colors.blueGrey.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                latestNews!.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1A2230),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${latestNews!.source} • ${DateFormat('dd MMM • HH:mm').format(latestNews!.publishedAtUtc.toLocal())}',
                style: const TextStyle(
                  color: Color(0xFF6B7381),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
            if (hasNews && hasTransfer)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Color(0xFFE4E8ED)),
              ),
            if (hasTransfer) ...[
              Text(
                'Latest transfer',
                style: TextStyle(
                  color: Colors.blueGrey.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TeamBadge(
                    teamId: latestTransfer!.teamId,
                    teamName: latestTransfer!.teamName,
                    resolver: resolver,
                    source: 'league.overview.transfer',
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      latestTransfer!.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A2230),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat(
                      'dd MMM',
                    ).format(latestTransfer!.updatedAtUtc.toLocal()),
                    style: const TextStyle(
                      color: Color(0xFF6B7381),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                latestTransfer!.teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7381),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TableTab extends StatelessWidget {
  const _TableTab({
    required this.standings,
    required this.overallRows,
    required this.selectedModeKey,
    required this.resolver,
    required this.nextOpponents,
    required this.onModeChanged,
  });

  final LeagueStandingsLeague? standings;
  final List<LeagueStandingsRow> overallRows;
  final String selectedModeKey;
  final LocalAssetResolver resolver;
  final Map<String, _NextOpponent> nextOpponents;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final modeKeys = standings?.orderedModeKeys ?? const <String>['all'];
    final preferredModeKeys = modeKeys
        .where((modeKey) {
          final rows = standings?.mode(modeKey)?.rows;
          return rows != null && rows.isNotEmpty;
        })
        .toList(growable: false);

    final availableModeKeys =
        preferredModeKeys.isNotEmpty
            ? preferredModeKeys
            : const <String>['all'];

    final activeModeKey =
        availableModeKeys.contains(selectedModeKey)
            ? selectedModeKey
            : availableModeKeys.first;

    final modeData = standings?.mode(activeModeKey);
    final rows =
        modeData != null && modeData.rows.isNotEmpty
            ? modeData.rows
            : overallRows;

    final tableRows = rows
        .map(
          (row) => CompactStandingsTableRow(
            teamId: row.teamId,
            teamName: row.teamName,
            shortName: row.shortName,
            position: row.position,
            played: row.played,
            wins: row.wins,
            draws: row.draws,
            losses: row.losses,
            scores: row.scoresStr,
            goalDiff: row.goalConDiff,
            points: row.points,
            form: row.form,
            qualColorHex: row.qualColor,
            nextTeamId: nextOpponents[row.teamId]?.teamId,
            nextTeamName: nextOpponents[row.teamId]?.teamName,
          ),
        )
        .toList(growable: false);

    if (rows.isEmpty) {
      return const _EmptyTabState(
        message: 'No standings imported for this league yet.',
      );
    }

    return Column(
      children: [
        if (availableModeKeys.length > 1)
          _FilterChipBar(
            labels: availableModeKeys
                .map((item) => standingsModeLabel(item))
                .toList(growable: false),
            selectedIndex: availableModeKeys.indexOf(activeModeKey),
            onSelected: (index) => onModeChanged(availableModeKeys[index]),
          )
        else
          const SizedBox(height: 8),
        Expanded(
          child: CompactStandingsTable(
            rows: tableRows,
            resolver: resolver,
            showNext: true,
            tableBadgeSource: 'league.table',
            nextBadgeSource: 'league.table.next',
            fallbackStripColor: (row, rowCount) {
              if (row.position <= 4) {
                return const Color(0xFF2E7DFF);
              }
              if (row.position <= 6) {
                return const Color(0xFF2EBB75);
              }
              if (row.position >= rowCount - 2) {
                return const Color(0xFFE55368);
              }
              return Colors.transparent;
            },
            onRowTap: (row) => context.push('/team/${row.teamId}'),
          ),
        ),
      ],
    );
  }
}

class _FixturesTab extends StatefulWidget {
  const _FixturesTab({
    required this.fixtures,
    required this.filter,
    required this.resolver,
    required this.onFilterChanged,
  });

  final List<HomeMatchView> fixtures;
  final LeagueFixtureFilter filter;
  final LocalAssetResolver resolver;
  final ValueChanged<LeagueFixtureFilter> onFilterChanged;

  @override
  State<_FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends State<_FixturesTab> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dateHeaderKeys = <String, GlobalKey>{};
  String? _lastAnchoredLabel;
  bool _autoScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoScrollToRelevantSection(force: true);
  }

  @override
  void didUpdateWidget(covariant _FixturesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter ||
        oldWidget.fixtures.length != widget.fixtures.length ||
        !identical(oldWidget.fixtures, widget.fixtures)) {
      _scheduleAutoScrollToRelevantSection(force: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final filtered = _filterAndSortFixtures(now);
    final entries = _buildFixtureEntries(filtered, now.toLocal());
    _scheduleAutoScrollToRelevantSection();

    return Column(
      children: [
        _FilterChipBar(
          labels: const ['All', 'Live', 'Upcoming', 'Finished'],
          selectedIndex: widget.filter.index,
          onSelected:
              (index) =>
                  widget.onFilterChanged(LeagueFixtureFilter.values[index]),
        ),
        Expanded(
          child:
              entries.isEmpty
                  ? const _EmptyTabState(
                    message:
                        'No fixtures match this filter in your offline league dataset.',
                  )
                  : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      if (entry is _FixtureDateEntry) {
                        final key = _dateHeaderKeys.putIfAbsent(
                          entry.label,
                          GlobalKey.new,
                        );
                        return Padding(
                          key: key,
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                          child: Text(
                            entry.label,
                            style: const TextStyle(
                              color: Color(0xFF535D6B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }

                      final item = (entry as _FixtureMatchEntry).fixture;
                      final score = MatchDisplayFormatter.scoreDisplay(
                        status: item.match.status,
                        kickoffUtc: item.match.kickoffUtc,
                        homeScore: item.match.homeScore,
                        awayScore: item.match.awayScore,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => context.openMatchDetail(item.match.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E6EC),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 76,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fixtureStatusLabel(
                                          item.match.status,
                                          item.match.kickoffUtc,
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF6A7382),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _fixtureTimeLabel(
                                          item.match.status,
                                          item.match.kickoffUtc,
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF1A2230),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _FixtureTeamRow(
                                        teamId: item.match.homeTeamId,
                                        teamName: item.homeTeamName,
                                        resolver: widget.resolver,
                                      ),
                                      const SizedBox(height: 6),
                                      _FixtureTeamRow(
                                        teamId: item.match.awayTeamId,
                                        teamName: item.awayTeamName,
                                        resolver: widget.resolver,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    score.centerLabel,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Color(0xFF121925),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  List<HomeMatchView> _filterAndSortFixtures(DateTime nowUtc) {
    final filtered = widget.fixtures
        .where((fixture) {
          final lifecycle = MatchDisplayFormatter.lifecycle(
            status: fixture.match.status,
            kickoffUtc: fixture.match.kickoffUtc,
            nowUtc: nowUtc,
          );

          switch (widget.filter) {
            case LeagueFixtureFilter.all:
              return true;
            case LeagueFixtureFilter.live:
              return lifecycle == MatchLifecycle.live;
            case LeagueFixtureFilter.upcoming:
              return lifecycle == MatchLifecycle.upcoming;
            case LeagueFixtureFilter.finished:
              return lifecycle == MatchLifecycle.finished;
          }
        })
        .toList(growable: false);

    if (widget.filter == LeagueFixtureFilter.upcoming) {
      filtered.sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));
      return filtered;
    }

    if (widget.filter == LeagueFixtureFilter.finished) {
      filtered.sort((a, b) => b.match.kickoffUtc.compareTo(a.match.kickoffUtc));
      return filtered;
    }

    if (widget.filter == LeagueFixtureFilter.live) {
      filtered.sort((a, b) => b.match.kickoffUtc.compareTo(a.match.kickoffUtc));
      return filtered;
    }

    final currentAndRecent = <HomeMatchView>[];
    final upcoming = <HomeMatchView>[];

    for (final fixture in filtered) {
      final lifecycle = MatchDisplayFormatter.lifecycle(
        status: fixture.match.status,
        kickoffUtc: fixture.match.kickoffUtc,
        nowUtc: nowUtc,
      );
      if (lifecycle == MatchLifecycle.upcoming) {
        upcoming.add(fixture);
      } else {
        currentAndRecent.add(fixture);
      }
    }

    currentAndRecent.sort(
      (a, b) => b.match.kickoffUtc.compareTo(a.match.kickoffUtc),
    );
    upcoming.sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));

    return [...currentAndRecent, ...upcoming];
  }

  List<_FixtureEntry> _buildFixtureEntries(
    List<HomeMatchView> items,
    DateTime nowLocal,
  ) {
    final entries = <_FixtureEntry>[];
    String? lastDateLabel;

    for (final item in items) {
      final dateLabel = _fixtureDateLabel(item.match.kickoffUtc, nowLocal);

      if (dateLabel != lastDateLabel) {
        entries.add(_FixtureDateEntry(dateLabel));
        lastDateLabel = dateLabel;
      }

      entries.add(_FixtureMatchEntry(item));
    }

    return entries;
  }

  String _fixtureDateLabel(DateTime kickoffUtc, DateTime nowLocal) {
    final localKickoff = kickoffUtc.toLocal();
    final kickoffDate = DateTime(
      localKickoff.year,
      localKickoff.month,
      localKickoff.day,
    );
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final deltaDays = kickoffDate.difference(today).inDays;

    if (deltaDays == 0) {
      return 'Today';
    }
    if (deltaDays == -1) {
      return 'Yesterday';
    }
    if (deltaDays == 1) {
      return 'Tomorrow';
    }

    return DateFormat('EEEE, dd MMM').format(localKickoff);
  }

  String? _resolveRelevantDateLabel(List<HomeMatchView> items, DateTime nowUtc) {
    if (items.isEmpty) {
      return null;
    }

    HomeMatchView? bestMatch;
    int? bestAbsMinutes;
    int? bestSignedMinutes;

    for (final item in items) {
      final signedMinutes =
          item.match.kickoffUtc.difference(nowUtc).inMinutes;
      final absMinutes = signedMinutes.abs();

      if (bestMatch == null ||
          bestAbsMinutes == null ||
          absMinutes < bestAbsMinutes ||
          (absMinutes == bestAbsMinutes &&
              bestSignedMinutes != null &&
              signedMinutes <= 0 &&
              bestSignedMinutes > 0)) {
        bestMatch = item;
        bestAbsMinutes = absMinutes;
        bestSignedMinutes = signedMinutes;
      }
    }

    if (bestMatch == null) {
      return null;
    }

    return _fixtureDateLabel(bestMatch.match.kickoffUtc, nowUtc.toLocal());
  }

  void _scheduleAutoScrollToRelevantSection({bool force = false}) {
    if (!mounted) {
      return;
    }
    if (_autoScrollScheduled && !force) {
      return;
    }
    _autoScrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollScheduled = false;
      if (!mounted) {
        return;
      }

      final now = DateTime.now().toUtc();
      final sorted = _filterAndSortFixtures(now);
      final targetLabel = _resolveRelevantDateLabel(sorted, now);
      if (targetLabel == null) {
        return;
      }

      if (!force && _lastAnchoredLabel == targetLabel) {
        return;
      }

      final key = _dateHeaderKeys[targetLabel];
      final targetContext = key?.currentContext;
      if (targetContext == null) {
        return;
      }

      _lastAnchoredLabel = targetLabel;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: 0.04,
      );
    });
  }

  String _fixtureStatusLabel(String status, DateTime kickoffUtc) {
    final lifecycle = MatchDisplayFormatter.lifecycle(
      status: status,
      kickoffUtc: kickoffUtc,
    );
    if (lifecycle == MatchLifecycle.live) {
      return 'LIVE';
    }
    return lifecycle == MatchLifecycle.upcoming ? 'UPCOMING' : 'FT';
  }

  String _fixtureTimeLabel(String status, DateTime kickoffUtc) {
    final lifecycle = MatchDisplayFormatter.lifecycle(
      status: status,
      kickoffUtc: kickoffUtc,
    );
    if (lifecycle == MatchLifecycle.live) {
      return 'LIVE';
    }
    return DateFormat('EEE HH:mm').format(kickoffUtc.toLocal());
  }
}

class _FixtureTeamRow extends StatelessWidget {
  const _FixtureTeamRow({
    required this.teamId,
    required this.teamName,
    required this.resolver,
  });

  final String teamId;
  final String teamName;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamBadge(
          teamId: teamId,
          teamName: teamName,
          resolver: resolver,
          source: 'league.fixtures.row',
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1B2331),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

sealed class _FixtureEntry {
  const _FixtureEntry();
}

class _FixtureDateEntry extends _FixtureEntry {
  const _FixtureDateEntry(this.label);

  final String label;
}

class _FixtureMatchEntry extends _FixtureEntry {
  const _FixtureMatchEntry(this.fixture);

  final HomeMatchView fixture;
}

class _PlayerStatsBody extends ConsumerWidget {
  const _PlayerStatsBody({
    required this.competitionId,
    required this.selectedStatType,
    required this.onSelectedStatType,
    required this.resolver,
  });

  final String competitionId;
  final String? selectedStatType;
  final ValueChanged<String> onSelectedStatType;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(
      leaguePlayerStatCategoriesProvider(competitionId),
    );

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => const _EmptyTabState(
            message: 'Unable to load player stats from local data.',
          ),
      data: (categories) {
        if (categories.isEmpty) {
          return const _EmptyTabState(
            message: 'No player stats imported for this league.',
          );
        }

        final activeStat =
            selectedStatType != null &&
                    categories.any((item) => item.statType == selectedStatType)
                ? selectedStatType!
                : categories.first.statType;

        final leadersAsync = ref.watch(
          leaguePlayerLeadersProvider(
            LeaguePlayerLeadersQuery(
              competitionId: competitionId,
              statType: activeStat,
              limit: 24,
            ),
          ),
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories
                      .map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(statTypeLabel(category.statType)),
                            selected: category.statType == activeStat,
                            onSelected:
                                (_) => onSelectedStatType(category.statType),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            Expanded(
              child: leadersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, stackTrace) => const _EmptyTabState(
                      message: 'Unable to load player leaderboard rows.',
                    ),
                data: (leaders) {
                  if (leaders.isEmpty) {
                    return const _EmptyTabState(
                      message: 'No player entries found for this category.',
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 980 ? 2 : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: crossAxisCount == 2 ? 2.65 : 3.1,
                        ),
                        itemCount: leaders.length,
                        itemBuilder: (context, index) {
                          final entry = leaders[index];
                          return _PlayerStatCard(
                            entry: entry,
                            statType: activeStat,
                            resolver: resolver,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerStatCard extends StatelessWidget {
  const _PlayerStatCard({
    required this.entry,
    required this.statType,
    required this.resolver,
  });

  final TopPlayerLeaderboardEntryView entry;
  final String statType;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/player/${entry.stat.playerId}'),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E5EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 22,
                alignment: Alignment.center,
                child: Text(
                  '${entry.stat.rank}',
                  style: const TextStyle(
                    color: Color(0xFF1F2735),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              EntityBadge(
                entityId: entry.stat.playerId,
                entityName: entry.stat.playerName,
                type: SportsAssetType.players,
                resolver: resolver,
                size: 38,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.stat.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF19212E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (entry.stat.teamId != null)
                          TeamBadge(
                            teamId: entry.stat.teamId,
                            teamName: entry.teamName,
                            resolver: resolver,
                            source: 'league.stats.players',
                            size: 14,
                          ),
                        if (entry.stat.teamId != null) const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            entry.teamName ?? 'Unknown Team',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6A7382),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    compactNumber(entry.stat.statValue),
                    style: const TextStyle(
                      color: Color(0xFF121925),
                      fontSize: 18,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statTypeLabel(statType),
                    style: const TextStyle(
                      color: Color(0xFF6C7583),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Color(0xFF7A8392),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamStatsBody extends StatelessWidget {
  const _TeamStatsBody({
    required this.rows,
    required this.metric,
    required this.resolver,
    required this.onMetricChanged,
  });

  final List<LeagueStandingsRow> rows;
  final LeagueTeamStatMetric metric;
  final LocalAssetResolver resolver;
  final ValueChanged<LeagueTeamStatMetric> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyTabState(
        message: 'No standings data available for team metrics.',
      );
    }

    final statRows = buildTeamStatRows(rows, metric);

    return Column(
      children: [
        _FilterChipBar(
          labels: const [
            'Points',
            'Goals',
            'Goal Diff',
            'Defence',
            'Wins',
            'Form',
          ],
          selectedIndex: metric.index,
          onSelected:
              (index) => onMetricChanged(LeagueTeamStatMetric.values[index]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            itemCount: math.min(statRows.length, 20),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = statRows[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/team/${item.teamId}'),
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E5EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${item.rank}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TeamBadge(
                          teamId: item.teamId,
                          teamName: item.teamName,
                          resolver: resolver,
                          source: 'league.stats.teams',
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1A2230),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.primary,
                              style: const TextStyle(
                                color: Color(0xFF121925),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              item.secondary,
                              style: const TextStyle(
                                color: Color(0xFF6B7381),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Color(0xFF7A8392),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TransfersTab extends StatelessWidget {
  const _TransfersTab({required this.transfers, required this.resolver});

  final List<LeagueTransferItem> transfers;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return const _EmptyTabState(
        message:
            'No transfer updates were found in your local league data yet.',
      );
    }

    final rows = transfers.take(180).toList(growable: false);

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: _InfoStrip(
            text:
                'Showing transfer updates from imported league JSON and latest local player records.',
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(MediaQuery.of(context).size.width - 40, 1130),
              child: Column(
                children: [
                  const _TransferHeaderRow(),
                  const Divider(height: 1, color: Color(0xFFE4E8ED)),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder:
                          (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFFEEF1F5),
                          ),
                      itemBuilder: (context, index) {
                        final item = rows[index];
                        return _TransferDataRow(item: item, resolver: resolver);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransferHeaderRow extends StatelessWidget {
  const _TransferHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFF657082),
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );

    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: const Row(
        children: [
          SizedBox(width: 290, child: Text('Player', style: style)),
          SizedBox(width: 96, child: Text('Fee', style: style)),
          SizedBox(width: 214, child: Text('From', style: style)),
          SizedBox(width: 118, child: Text('Position', style: style)),
          SizedBox(width: 130, child: Text('Contract', style: style)),
          SizedBox(width: 142, child: Text('Transfer value', style: style)),
          SizedBox(width: 116, child: Text('Date', style: style)),
        ],
      ),
    );
  }
}

class _TransferDataRow extends StatelessWidget {
  const _TransferDataRow({required this.item, required this.resolver});

  final LeagueTransferItem item;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'dd MMM yyyy',
    ).format(item.updatedAtUtc.toLocal());

    return InkWell(
      onTap: () {
        if (item.playerId.trim().isNotEmpty) {
          context.push('/player/${item.playerId}');
          return;
        }
        if (item.teamId != null && item.teamId!.trim().isNotEmpty) {
          context.push('/team/${item.teamId}');
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Row(
          children: [
            SizedBox(
              width: 290,
              child: Row(
                children: [
                  EntityBadge(
                    entityId: item.playerId,
                    entityName: item.playerName,
                    type: SportsAssetType.players,
                    resolver: resolver,
                    size: 30,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A2230),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 96,
              child: Text(
                '--',
                style: TextStyle(
                  color: Color(0xFF798392),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 214,
              child: Row(
                children: [
                  TeamBadge(
                    teamId: item.teamId,
                    teamName: item.teamName,
                    resolver: resolver,
                    source: 'league.transfers',
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF273040),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 118,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.position ?? 'N/A',
                    style: const TextStyle(
                      color: Color(0xFF4B5566),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 130,
              child: Text(
                '--',
                style: TextStyle(
                  color: Color(0xFF798392),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(
              width: 142,
              child: Text(
                '--',
                style: TextStyle(
                  color: Color(0xFF798392),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 116,
              child: Text(
                dateLabel,
                style: const TextStyle(
                  color: Color(0xFF273040),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonsTab extends StatelessWidget {
  const _SeasonsTab({
    required this.seasons,
    required this.selectedSeason,
    required this.fixtures,
    required this.onSelectSeason,
  });

  final List<String> seasons;
  final String selectedSeason;
  final List<HomeMatchView> fixtures;
  final ValueChanged<String> onSelectSeason;

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) {
      return const _EmptyTabState(
        message: 'No season labels found in local matches data.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      itemCount: seasons.length,
      itemBuilder: (context, index) {
        final season = seasons[index];
        final selected = season == selectedSeason;
        final matchCount = _matchCountForSeason(season);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => onSelectSeason(season),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color:
                    selected
                        ? const Color(0xFFEAF0FA)
                        : const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      selected
                          ? const Color(0xFFCAD8EF)
                          : const Color(0xFFE1E5EB),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            season,
                            style: TextStyle(
                              color: const Color(0xFF17202E),
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                          if (index == 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B2230),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Current',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '$matchCount matches',
                      style: const TextStyle(
                        color: Color(0xFF66707F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color:
                          selected
                              ? const Color(0xFF2A6ADF)
                              : const Color(0xFF9AA3B2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _matchCountForSeason(String seasonLabel) {
    final split = seasonLabel.split('/');
    final year = split.isNotEmpty ? int.tryParse(split.first) : null;
    if (year == null) {
      return 0;
    }

    return fixtures.where((fixture) {
      final date = fixture.match.kickoffUtc;
      final seasonStart = date.month >= 7 ? date.year : date.year - 1;
      return seasonStart == year;
    }).length;
  }
}

class _NewsTab extends StatelessWidget {
  const _NewsTab({
    required this.competitionId,
    required this.newsItems,
    required this.filter,
    required this.resolver,
    required this.onFilterChanged,
  });

  final String competitionId;
  final List<LeagueNewsItem> newsItems;
  final LeagueNewsFilter filter;
  final LocalAssetResolver resolver;
  final ValueChanged<LeagueNewsFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final filtered = newsItems
        .where((item) {
          switch (filter) {
            case LeagueNewsFilter.all:
              return true;
            case LeagueNewsFilter.updates:
              return !item.isInsight;
            case LeagueNewsFilter.insights:
              return item.isInsight;
          }
        })
        .toList(growable: false);

    if (filtered.isEmpty) {
      return Column(
        children: [
          _FilterChipBar(
            labels: const ['All', 'Updates', 'Insights'],
            selectedIndex: filter.index,
            onSelected:
                (index) => onFilterChanged(LeagueNewsFilter.values[index]),
          ),
          const Expanded(
            child: _EmptyTabState(
              message: 'No offline league stories available for this filter.',
            ),
          ),
        ],
      );
    }

    final featured = filtered.first;
    final listItems = filtered.skip(1).toList(growable: false);

    return Column(
      children: [
        _FilterChipBar(
          labels: const ['All', 'Updates', 'Insights'],
          selectedIndex: filter.index,
          onSelected:
              (index) => onFilterChanged(LeagueNewsFilter.values[index]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 980) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: _FeaturedNewsCard(
                          item: featured,
                          competitionId: competitionId,
                          resolver: resolver,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: ListView.separated(
                          itemCount: listItems.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _SideNewsTile(
                              item: listItems[index],
                              competitionId: competitionId,
                              resolver: resolver,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }

                return ListView(
                  children: [
                    _FeaturedNewsCard(
                      item: featured,
                      competitionId: competitionId,
                      resolver: resolver,
                    ),
                    const SizedBox(height: 10),
                    ...listItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SideNewsTile(
                          item: item,
                          competitionId: competitionId,
                          resolver: resolver,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedNewsCard extends StatelessWidget {
  const _FeaturedNewsCard({
    required this.item,
    required this.competitionId,
    required this.resolver,
  });

  final LeagueNewsItem item;
  final String competitionId;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final published = DateFormat(
      'dd MMM • HH:mm',
    ).format(item.publishedAtUtc.toLocal());

    return InkWell(
      onTap: () => _openNewsDestination(context, item),
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E5EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: _NewsImage(
                item: item,
                competitionId: competitionId,
                resolver: resolver,
                height: 280,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Color(0xFF131A25),
                      fontSize: 33,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.excerpt,
                    style: const TextStyle(
                      color: Color(0xFF4B5566),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.source} • $published',
                    style: const TextStyle(
                      color: Color(0xFF6F7886),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNewsTile extends StatelessWidget {
  const _SideNewsTile({
    required this.item,
    required this.competitionId,
    required this.resolver,
  });

  final LeagueNewsItem item;
  final String competitionId;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final published = DateFormat(
      'dd MMM • HH:mm',
    ).format(item.publishedAtUtc.toLocal());

    return InkWell(
      onTap: () => _openNewsDestination(context, item),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E5EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _NewsImage(
                  item: item,
                  competitionId: competitionId,
                  resolver: resolver,
                  height: 86,
                  width: 112,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17202E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.source} • $published',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7381),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsImage extends StatelessWidget {
  const _NewsImage({
    required this.item,
    required this.competitionId,
    required this.resolver,
    required this.height,
    this.width,
  });

  final LeagueNewsItem item;
  final String competitionId;
  final LocalAssetResolver resolver;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedImageRef?>(
      future: _resolveImage(),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null) {
          return _fallback();
        }

        if (resolved.isFile) {
          return Image.file(
            File(resolved.path),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
          );
        }

        return Image.asset(
          resolved.path,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      },
    );
  }

  Future<ResolvedImageRef?> _resolveImage() async {
    if (item.imagePlayerId != null) {
      final player = await resolver.resolve(
        type: SportsAssetType.players,
        entityId: item.imagePlayerId!,
      );
      if (player != null) {
        return player;
      }
    }

    if (item.imageTeamId != null) {
      final team = await resolver.resolveTeamBadge(
        teamId: item.imageTeamId,
        teamName: item.imageTeamName,
        source: 'league.news.image',
      );
      if (team != null) {
        return team;
      }
    }

    return resolver.resolve(
      type: SportsAssetType.leagues,
      entityId: competitionId,
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF415A77), Color(0xFF1B263B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.sports_soccer_rounded,
        color: Color(0xFFE5E9F0),
        size: 36,
      ),
    );
  }
}

void _openNewsDestination(BuildContext context, LeagueNewsItem item) {
  if (item.matchId != null) {
    context.openMatchDetail(item.matchId!);
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      final published = DateFormat(
        'EEE, dd MMM yyyy • HH:mm',
      ).format(item.publishedAtUtc.toLocal());

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.source,
                      style: const TextStyle(
                        color: Color(0xFF5F6877),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(
                item.title,
                style: const TextStyle(
                  color: Color(0xFF151C28),
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.excerpt,
                style: const TextStyle(
                  color: Color(0xFF4B5566),
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                published,
                style: const TextStyle(
                  color: Color(0xFF6B7381),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.imageTeamId != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push('/team/${item.imageTeamId}');
                      },
                      icon: const Icon(Icons.shield_rounded, size: 16),
                      label: Text(item.imageTeamName ?? 'Open team'),
                    ),
                  if (item.imagePlayerId != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push('/player/${item.imagePlayerId}');
                      },
                      icon: const Icon(Icons.person_rounded, size: 16),
                      label: const Text('Open player'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FilterChipBar extends StatelessWidget {
  const _FilterChipBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(labels[i]),
                  selected: selectedIndex == i,
                  selectedColor: const Color(0xFF1D2432),
                  backgroundColor: const Color(0xFFF8F9FB),
                  side: const BorderSide(color: Color(0xFFDDE2E8)),
                  labelStyle: TextStyle(
                    color:
                        selectedIndex == i
                            ? Colors.white
                            : const Color(0xFF2D3646),
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        border: Border.all(color: const Color(0xFFDDE2E8)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF5F6977),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: Color(0xFF6C7583),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF677181),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LeagueErrorState extends StatelessWidget {
  const _LeagueErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Unable to load this league from local data. Re-scan your offline files and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF677181),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _NextOpponent {
  const _NextOpponent({required this.teamId, required this.teamName});

  final String teamId;
  final String teamName;
}
