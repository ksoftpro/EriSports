import 'dart:io';
import 'dart:math' as math;

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/detail_navigation.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:eri_sports/features/leagues/presentation/league_overview_providers.dart';
import 'package:eri_sports/features/player_stats/presentation/player_stats_providers.dart';
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

enum _LeagueStatsScope { players, teams }

class _LeagueOverviewScreenState extends ConsumerState<LeagueOverviewScreen> {
  String _selectedStandingsModeKey = 'all';
  LeagueFixtureFilter _fixtureFilter = LeagueFixtureFilter.all;
  LeagueNewsFilter _newsFilter = LeagueNewsFilter.all;
  LeagueTeamStatMetric _teamMetric = LeagueTeamStatMetric.points;
  String? _selectedSeason;
  String? _selectedPlayerStatType;
  _LeagueStatsScope _statsScope = _LeagueStatsScope.players;

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(
      leagueOverviewProvider(widget.competitionId),
    );

    return DefaultTabController(
      length: 7,
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
                        ),
                        const SizedBox(height: 10),
                        const _LeagueTabsBar(),
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
                                _StatsTab(
                                  competitionId: state.competitionId,
                                  selectedStatType: _selectedPlayerStatType,
                                  onSelectedStatType: (value) {
                                    setState(() {
                                      _selectedPlayerStatType = value;
                                    });
                                  },
                                  statsScope: _statsScope,
                                  onStatsScopeChanged: (scope) {
                                    setState(() {
                                      _statsScope = scope;
                                    });
                                  },
                                  resolver: resolver,
                                  teamRows: state.overallStandingsRows,
                                  teamMetric: _teamMetric,
                                  onTeamMetricChanged: (metric) {
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
    required this.resolver,
    required this.onBack,
    required this.onSeasonTap,
    required this.onFollowTap,
  });

  final String competitionId;
  final String competitionName;
  final String countryLabel;
  final String seasonLabel;
  final bool isFollowing;
  final LocalAssetResolver resolver;
  final VoidCallback onBack;
  final VoidCallback onSeasonTap;
  final VoidCallback onFollowTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE1E6)),
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
                      ),
                      const Spacer(),
                      _HeaderSeasonButton(
                        seasonLabel: seasonLabel,
                        onTap: onSeasonTap,
                      ),
                      const SizedBox(width: 8),
                      _FollowButton(
                        isFollowing: isFollowing,
                        onTap: onFollowTap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _LeagueLogo(
                        competitionId: competitionId,
                        competitionName: competitionName,
                        resolver: resolver,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LeagueNameBlock(
                          competitionName: competitionName,
                          countryLabel: countryLabel,
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
                  ),
                  const SizedBox(width: 12),
                  _LeagueLogo(
                    competitionId: competitionId,
                    competitionName: competitionName,
                    resolver: resolver,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LeagueNameBlock(
                      competitionName: competitionName,
                      countryLabel: countryLabel,
                    ),
                  ),
                  _HeaderSeasonButton(
                    seasonLabel: seasonLabel,
                    onTap: onSeasonTap,
                  ),
                  const SizedBox(width: 10),
                  _FollowButton(isFollowing: isFollowing, onTap: onFollowTap),
                ],
              ),
    );
  }
}

class _LeagueLogo extends StatelessWidget {
  const _LeagueLogo({
    required this.competitionId,
    required this.competitionName,
    required this.resolver,
  });

  final String competitionId;
  final String competitionName;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E5EA)),
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
  });

  final String competitionName;
  final String countryLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          competitionName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 33,
            height: 1.05,
            color: Color(0xFF121721),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          countryLabel,
          style: const TextStyle(
            fontSize: 17,
            color: Color(0xFF5E6572),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeaderGhostButton extends StatelessWidget {
  const _HeaderGhostButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

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
          color: const Color(0xFFF5F6F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFDDE2E8)),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF202634)),
      ),
    );
  }
}

class _HeaderSeasonButton extends StatelessWidget {
  const _HeaderSeasonButton({required this.seasonLabel, required this.onTap});

  final String seasonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFDCE1E7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              seasonLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2130),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF2A3242),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              isFollowing ? const Color(0xFF2F3440) : const Color(0xFF191C22),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _LeagueTabsBar extends StatelessWidget {
  const _LeagueTabsBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE1E6)),
      ),
      child: const TabBar(
        isScrollable: true,
        labelColor: Color(0xFF171D28),
        unselectedLabelColor: Color(0xFF6A7280),
        indicatorColor: Color(0xFF141B26),
        indicatorWeight: 2.2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Color(0x00000000),
        labelPadding: EdgeInsets.only(left: 8, right: 16),
        tabAlignment: TabAlignment.start,
        tabs: [
          Tab(text: 'Overview'),
          Tab(text: 'Table'),
          Tab(text: 'Fixtures'),
          Tab(text: 'Stats'),
          Tab(text: 'Transfers'),
          Tab(text: 'Seasons'),
          Tab(text: 'News'),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.state,
    required this.fixtures,
    required this.resolver,
  });

  final LeagueOverviewState state;
  final List<HomeMatchView> fixtures;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final rows = state.overallStandingsRows;
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
    final upcoming =
        fixtures.where((item) => item.match.kickoffUtc.isAfter(now)).toList()
          ..sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));

    final topScorer =
        state.goalLeaders.isNotEmpty ? state.goalLeaders.first : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _OverviewStatCard(
              label: 'Clubs',
              value: '${rows.length}',
              caption: 'In current table',
            ),
            _OverviewStatCard(
              label: 'Matches',
              value: '${fixtures.length}',
              caption: 'Season fixtures loaded',
            ),
            _OverviewStatCard(
              label: 'Played',
              value: '${playedMatches.length}',
              caption: 'Completed matches',
            ),
            _OverviewStatCard(
              label: 'Goals',
              value: '$totalGoals',
              caption:
                  'Avg ${avgGoals == 0 ? '0.0' : avgGoals.toStringAsFixed(2)} / game',
            ),
          ],
        ),
        const SizedBox(height: 14),
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
                        _OverviewTopScorerCard(
                          leader: topScorer,
                          resolver: resolver,
                        ),
                        const SizedBox(height: 10),
                        _OverviewNextFixtureCard(
                          match: upcoming.isNotEmpty ? upcoming.first : null,
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
                _OverviewTopScorerCard(leader: topScorer, resolver: resolver),
                const SizedBox(height: 10),
                _OverviewNextFixtureCard(
                  match: upcoming.isNotEmpty ? upcoming.first : null,
                  resolver: resolver,
                ),
              ],
            );
          },
        ),
      ],
    );
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
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5F6673),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              height: 1,
              color: Color(0xFF131A25),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: const TextStyle(
              color: Color(0xFF757C8A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            const Text(
              'League highlights',
              style: TextStyle(
                color: Color(0xFF161D29),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Top of the table snapshot',
              style: TextStyle(
                color: Color(0xFF6A7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            if (topRows.isEmpty)
              const _InlineEmptyState(
                message: 'No standings imported for this competition yet.',
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
      ),
    );
  }
}

class _OverviewTopScorerCard extends StatelessWidget {
  const _OverviewTopScorerCard({required this.leader, required this.resolver});

  final TopPlayerLeaderboardEntryView? leader;
  final LocalAssetResolver resolver;

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
            const Text(
              'Top scorer',
              style: TextStyle(
                color: Color(0xFF161D29),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (leader == null)
              const _InlineEmptyState(
                message: 'No top scorer data in this local dataset.',
              )
            else
              Row(
                children: [
                  EntityBadge(
                    entityId: leader!.stat.playerId,
                    entityName: leader!.stat.playerName,
                    type: SportsAssetType.players,
                    resolver: resolver,
                    size: 48,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leader!.stat.playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1A2230),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          leader!.teamName ?? 'Unknown Team',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7381),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    compactNumber(leader!.stat.statValue),
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1,
                      color: Color(0xFF101723),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OverviewNextFixtureCard extends StatelessWidget {
  const _OverviewNextFixtureCard({required this.match, required this.resolver});

  final HomeMatchView? match;
  final LocalAssetResolver resolver;

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
            const Text(
              'Next fixture',
              style: TextStyle(
                color: Color(0xFF161D29),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (match == null)
              const _InlineEmptyState(message: 'No upcoming fixture in season.')
            else
              Column(
                children: [
                  Row(
                    children: [
                      TeamBadge(
                        teamId: match!.match.homeTeamId,
                        teamName: match!.homeTeamName,
                        resolver: resolver,
                        source: 'league.overview.next',
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          match!.homeTeamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TeamBadge(
                        teamId: match!.match.awayTeamId,
                        teamName: match!.awayTeamName,
                        resolver: resolver,
                        source: 'league.overview.next',
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          match!.awayTeamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      DateFormat(
                        'EEE, dd MMM • HH:mm',
                      ).format(match!.match.kickoffUtc.toLocal()),
                      style: const TextStyle(
                        color: Color(0xFF6B7381),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(MediaQuery.of(context).size.width - 40, 1120),
              child: Column(
                children: [
                  const _StandingsTableHeader(),
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
                        final row = rows[index];
                        return _StandingsTableRow(
                          row: row,
                          rowCount: rows.length,
                          resolver: resolver,
                          nextOpponent: nextOpponents[row.teamId],
                          onTap: () => context.push('/team/${row.teamId}'),
                        );
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

class _StandingsTableHeader extends StatelessWidget {
  const _StandingsTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFF657082),
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );

    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      alignment: Alignment.center,
      child: Row(
        children: [
          const SizedBox(width: 5),
          const SizedBox(width: 22, child: Text('#', style: style)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Team', style: style)),
          _headerCell('PL', width: 36),
          _headerCell('W', width: 32),
          _headerCell('D', width: 32),
          _headerCell('L', width: 32),
          _headerCell('+/-', width: 66),
          _headerCell('GD', width: 40),
          _headerCell('PTS', width: 44),
          const SizedBox(
            width: 118,
            child: Text('Form', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(
            width: 74,
            child: Text('Next', textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Color(0xFF657082),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StandingsTableRow extends StatelessWidget {
  const _StandingsTableRow({
    required this.row,
    required this.rowCount,
    required this.resolver,
    required this.nextOpponent,
    required this.onTap,
  });

  final LeagueStandingsRow row;
  final int rowCount;
  final LocalAssetResolver resolver;
  final _NextOpponent? nextOpponent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final qualColor = _qualColorFromHex(row.qualColor);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color:
                    qualColor ?? _fallbackPositionColor(row.position, rowCount),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 22,
              child: Text(
                '${row.position}',
                style: const TextStyle(
                  color: Color(0xFF1D2533),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  TeamBadge(
                    teamId: row.teamId,
                    teamName: row.teamName,
                    resolver: resolver,
                    source: 'league.table',
                    size: 20,
                  ),
                  const SizedBox(width: 8),
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
                ],
              ),
            ),
            _metricCell('${row.played}', width: 36),
            _metricCell('${row.wins}', width: 32),
            _metricCell('${row.draws}', width: 32),
            _metricCell('${row.losses}', width: 32),
            _metricCell(row.scoresStr, width: 66),
            _metricCell(_goalDiffLabel(row.goalConDiff), width: 40),
            _metricCell('${row.points}', width: 44, bold: true),
            SizedBox(width: 118, child: _FormPills(form: row.form)),
            SizedBox(
              width: 74,
              child:
                  nextOpponent == null
                      ? const Text(
                        '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF808A99)),
                      )
                      : Center(
                        child: TeamBadge(
                          teamId: nextOpponent!.teamId,
                          teamName: nextOpponent!.teamName,
                          resolver: resolver,
                          source: 'league.table.next',
                          size: 22,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCell(String text, {required double width, bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: const Color(0xFF222A38),
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12.4,
        ),
      ),
    );
  }

  Color? _qualColorFromHex(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) {
      return null;
    }

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }

  Color _fallbackPositionColor(int position, int totalRows) {
    if (position <= 4) {
      return const Color(0xFF2E7DFF);
    }
    if (position <= 6) {
      return const Color(0xFF2EBB75);
    }
    if (position >= totalRows - 2) {
      return const Color(0xFFE55368);
    }
    return Colors.transparent;
  }

  String _goalDiffLabel(int value) => value > 0 ? '+$value' : '$value';
}

class _FormPills extends StatelessWidget {
  const _FormPills({required this.form});

  final String? form;

  @override
  Widget build(BuildContext context) {
    final tokens = (form ?? '')
        .toUpperCase()
        .replaceAll(RegExp('[^WDL]'), '')
        .split('')
        .where((token) => token.trim().isNotEmpty)
        .take(5)
        .toList(growable: false);

    if (tokens.isEmpty) {
      return const Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF7D8795), fontWeight: FontWeight.w600),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: tokens
          .map(
            (token) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tokenColor(token),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  token,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Color _tokenColor(String token) {
    switch (token) {
      case 'W':
        return const Color(0xFF1FA463);
      case 'D':
        return const Color(0xFF9BA5BD);
      default:
        return const Color(0xFFE14E67);
    }
  }
}

class _FixturesTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final filtered = fixtures
        .where((fixture) {
          final lowerStatus = fixture.match.status.toLowerCase();
          final isLive = _isLiveStatus(lowerStatus);
          final isUpcoming = fixture.match.kickoffUtc.isAfter(now) && !isLive;
          final isFinished = !isLive && !isUpcoming;

          switch (filter) {
            case LeagueFixtureFilter.all:
              return true;
            case LeagueFixtureFilter.live:
              return isLive;
            case LeagueFixtureFilter.upcoming:
              return isUpcoming;
            case LeagueFixtureFilter.finished:
              return isFinished;
          }
        })
        .toList(growable: false)
      ..sort((a, b) => b.match.kickoffUtc.compareTo(a.match.kickoffUtc));

    final entries = _buildFixtureEntries(filtered);

    return Column(
      children: [
        _FilterChipBar(
          labels: const ['All', 'Live', 'Upcoming', 'Finished'],
          selectedIndex: filter.index,
          onSelected:
              (index) => onFilterChanged(LeagueFixtureFilter.values[index]),
        ),
        Expanded(
          child:
              entries.isEmpty
                  ? const _EmptyTabState(
                    message:
                        'No fixtures match this filter in your offline league dataset.',
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      if (entry is _FixtureDateEntry) {
                        return Padding(
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
                                        score: item.match.homeScore,
                                        resolver: resolver,
                                      ),
                                      const SizedBox(height: 6),
                                      _FixtureTeamRow(
                                        teamId: item.match.awayTeamId,
                                        teamName: item.awayTeamName,
                                        score: item.match.awayScore,
                                        resolver: resolver,
                                      ),
                                    ],
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

  List<_FixtureEntry> _buildFixtureEntries(List<HomeMatchView> items) {
    final entries = <_FixtureEntry>[];
    String? lastDateLabel;

    for (final item in items) {
      final dateLabel =
          item.match.roundLabel != null &&
                  item.match.roundLabel!.trim().isNotEmpty
              ? item.match.roundLabel!.trim()
              : DateFormat(
                'EEEE, dd MMM',
              ).format(item.match.kickoffUtc.toLocal());

      if (dateLabel != lastDateLabel) {
        entries.add(_FixtureDateEntry(dateLabel));
        lastDateLabel = dateLabel;
      }

      entries.add(_FixtureMatchEntry(item));
    }

    return entries;
  }

  bool _isLiveStatus(String status) {
    const tokens = {'live', 'inplay', 'in_play', 'playing', 'ht'};
    return tokens.contains(status);
  }

  String _fixtureStatusLabel(String status, DateTime kickoffUtc) {
    final lower = status.toLowerCase();
    if (_isLiveStatus(lower)) {
      return 'LIVE';
    }
    return kickoffUtc.isAfter(DateTime.now().toUtc()) ? 'UPCOMING' : 'FT';
  }

  String _fixtureTimeLabel(String status, DateTime kickoffUtc) {
    final lower = status.toLowerCase();
    if (_isLiveStatus(lower)) {
      return 'LIVE';
    }
    return DateFormat('EEE HH:mm').format(kickoffUtc.toLocal());
  }
}

class _FixtureTeamRow extends StatelessWidget {
  const _FixtureTeamRow({
    required this.teamId,
    required this.teamName,
    required this.score,
    required this.resolver,
  });

  final String teamId;
  final String teamName;
  final int score;
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
        Text(
          '$score',
          style: const TextStyle(
            color: Color(0xFF121925),
            fontSize: 16,
            fontWeight: FontWeight.w800,
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

class _StatsTab extends ConsumerWidget {
  const _StatsTab({
    required this.competitionId,
    required this.selectedStatType,
    required this.onSelectedStatType,
    required this.statsScope,
    required this.onStatsScopeChanged,
    required this.resolver,
    required this.teamRows,
    required this.teamMetric,
    required this.onTeamMetricChanged,
  });

  final String competitionId;
  final String? selectedStatType;
  final ValueChanged<String> onSelectedStatType;
  final _LeagueStatsScope statsScope;
  final ValueChanged<_LeagueStatsScope> onStatsScopeChanged;
  final LocalAssetResolver resolver;
  final List<LeagueStandingsRow> teamRows;
  final LeagueTeamStatMetric teamMetric;
  final ValueChanged<LeagueTeamStatMetric> onTeamMetricChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: _SegmentedSwitcher(
            labels: const ['Players', 'Teams'],
            selectedIndex: statsScope.index,
            onSelected: (index) {
              onStatsScopeChanged(_LeagueStatsScope.values[index]);
            },
          ),
        ),
        Expanded(
          child:
              statsScope == _LeagueStatsScope.players
                  ? _PlayerStatsBody(
                    competitionId: competitionId,
                    selectedStatType: selectedStatType,
                    onSelectedStatType: onSelectedStatType,
                    resolver: resolver,
                  )
                  : _TeamStatsBody(
                    rows: teamRows,
                    metric: teamMetric,
                    resolver: resolver,
                    onMetricChanged: onTeamMetricChanged,
                  ),
        ),
      ],
    );
  }
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

    return Container(
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
      onTap: () {
        if (item.matchId != null) {
          context.openMatchDetail(item.matchId!);
        }
      },
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
      onTap: () {
        if (item.matchId != null) {
          context.openMatchDetail(item.matchId!);
        }
      },
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

class _SegmentedSwitcher extends StatelessWidget {
  const _SegmentedSwitcher({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E7EE)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        selectedIndex == i
                            ? Colors.white
                            : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color:
                          selectedIndex == i
                              ? const Color(0xFF1A2230)
                              : const Color(0xFF6B7381),
                      fontWeight:
                          selectedIndex == i
                              ? FontWeight.w800
                              : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
