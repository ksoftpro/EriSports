import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/leagues/presentation/league_overview_providers.dart';
import 'package:eri_sports/features/leagues/presentation/widgets/league_overview_widgets.dart';
import 'package:eri_sports/features/player_stats/presentation/player_stats_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/match_card_compact.dart';
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
  LeagueTableMode _tableMode = LeagueTableMode.short;
  LeagueScopeMode _scopeMode = LeagueScopeMode.overall;
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
      length: 5,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: overviewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const _LeagueErrorState(),
          data: (state) {
            final resolver = ref.read(appServicesProvider).assetResolver;
            final headerPref = ref.watch(
              leagueHeaderPreferenceProvider(widget.competitionId),
            );
            final seasonLabel = _resolveSeasonLabel(
              state.availableSeasonLabels,
            );

            return Column(
              children: [
                LeagueHeader(
                  competitionId: state.competitionId,
                  resolver: resolver,
                  theme: state.visualTheme,
                  competitionName: state.competitionName,
                  countryLabel: state.countryLabel,
                  seasonLabel: seasonLabel,
                  isFollowing: headerPref.isFollowing,
                  notificationsOn: headerPref.notificationsOn,
                  onBack: () => context.pop(),
                  onSeasonTap:
                      () => _showSeasonSheet(state.availableSeasonLabels),
                  onNotify: () {
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
                  onFollowing: () {
                    ref
                        .read(
                          leagueHeaderPreferenceProvider(
                            widget.competitionId,
                          ).notifier,
                        )
                        .update(
                          (pref) =>
                              pref.copyWith(isFollowing: !pref.isFollowing),
                        );
                  },
                ),
                LeagueTopTabs(theme: state.visualTheme),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TableTab(
                        mode: _tableMode,
                        scopeMode: _scopeMode,
                        rows: state.standingsRows,
                        resolver: resolver,
                        onModeChanged: (mode) {
                          setState(() {
                            _tableMode = mode;
                          });
                        },
                        onScopeChanged: (scope) {
                          setState(() {
                            _scopeMode = scope;
                          });
                        },
                      ),
                      _FixturesTab(
                        fixtures: _filterFixturesBySeason(
                          state.fixtureRows,
                          seasonLabel,
                        ),
                        filter: _fixtureFilter,
                        resolver: resolver,
                        onFilterChanged: (filter) {
                          setState(() {
                            _fixtureFilter = filter;
                          });
                        },
                      ),
                      _NewsTab(
                        newsItems: state.newsItems,
                        filter: _newsFilter,
                        onFilterChanged: (filter) {
                          setState(() {
                            _newsFilter = filter;
                          });
                        },
                      ),
                      _PlayerStatsTab(
                        competitionId: state.competitionId,
                        selectedStatType: _selectedPlayerStatType,
                        onSelectedStatType: (value) {
                          setState(() {
                            _selectedPlayerStatType = value;
                          });
                        },
                        resolver: resolver,
                      ),
                      _TeamStatsTab(
                        rows: state.standingsRows,
                        metric: _teamMetric,
                        resolver: resolver,
                        onMetricChanged: (metric) {
                          setState(() {
                            _teamMetric = metric;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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

  Future<void> _showSeasonSheet(List<String> seasons) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor:
          Theme.of(context).bottomSheetTheme.backgroundColor ??
          Theme.of(context).cardColor,
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

class _TableTab extends StatelessWidget {
  const _TableTab({
    required this.mode,
    required this.scopeMode,
    required this.rows,
    required this.resolver,
    required this.onModeChanged,
    required this.onScopeChanged,
  });

  final LeagueTableMode mode;
  final LeagueScopeMode scopeMode;
  final List<StandingsTableView> rows;
  final LocalAssetResolver resolver;
  final ValueChanged<LeagueTableMode> onModeChanged;
  final ValueChanged<LeagueScopeMode> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyTabState(
        message: 'No standings imported for this league yet.',
      );
    }

    final scopedRows = List<StandingsTableView>.from(rows);
    if (scopeMode != LeagueScopeMode.overall) {
      scopedRows.sort((a, b) {
        final pointsA = a.row.won * 3 + a.row.draw;
        final pointsB = b.row.won * 3 + b.row.draw;
        return pointsB.compareTo(pointsA);
      });
    }

    final content = Column(
      children: [
        LeagueSegmentedControls(
          selectedMode: mode,
          selectedScope: scopeMode,
          onModeChanged: onModeChanged,
          onScopeChanged: onScopeChanged,
        ),
        if (scopeMode != LeagueScopeMode.overall)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _InfoStrip(
              text:
                  'Home/Away split tables are not included in this offline data pack. Rankings are derived from available match totals.',
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.72),
              ),
            ),
            child: Column(
              children: [
                LeagueStandingsHeader(mode: mode),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: scopedRows.length,
                    itemBuilder: (context, index) {
                      final item = scopedRows[index];
                      return LeagueStandingsRow(
                        mode: mode,
                        position: item.row.position,
                        teamId: item.teamId,
                        teamName: item.teamName,
                        played: item.row.played,
                        won: item.row.won,
                        draw: item.row.draw,
                        lost: item.row.lost,
                        goalsFor: item.row.goalsFor,
                        goalsAgainst: item.row.goalsAgainst,
                        goalDiff: item.row.goalDiff,
                        points: item.row.points,
                        form: item.row.form,
                        rowCount: scopedRows.length,
                        resolver: resolver,
                        onTap: () => context.push('/team/${item.teamId}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (mode == LeagueTableMode.full) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width:
              MediaQuery.of(context).size.width < 620
                  ? 620
                  : MediaQuery.of(context).size.width,
          child: content,
        ),
      );
    }

    return content;
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
              filtered.isEmpty
                  ? const _EmptyTabState(
                    message:
                        'No fixtures match this filter in your offline league dataset.',
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      if (entry is _FixtureDateEntry) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                          child: Text(
                            entry.label,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }

                      final item = (entry as _FixtureMatchEntry).fixture;
                      return MatchCardCompact(
                        status: _fixtureStatusLabel(
                          item.match.status,
                          item.match.kickoffUtc,
                        ),
                        timeOrMinute: _fixtureTimeLabel(
                          item.match.status,
                          item.match.kickoffUtc,
                        ),
                        homeTeam: item.homeTeamName,
                        awayTeam: item.awayTeamName,
                        homeTeamId: item.match.homeTeamId,
                        awayTeamId: item.match.awayTeamId,
                        assetResolver: resolver,
                        onTap: () => context.push('/match/${item.match.id}'),
                        homeScore: item.match.homeScore,
                        awayScore: item.match.awayScore,
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
      final dateLabel = DateFormat(
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

class _NewsTab extends StatelessWidget {
  const _NewsTab({
    required this.newsItems,
    required this.filter,
    required this.onFilterChanged,
  });

  final List<LeagueNewsItem> newsItems;
  final LeagueNewsFilter filter;
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

    return Column(
      children: [
        _FilterChipBar(
          labels: const ['All', 'Updates', 'Insights'],
          selectedIndex: filter.index,
          onSelected:
              (index) => onFilterChanged(LeagueNewsFilter.values[index]),
        ),
        Expanded(
          child:
              filtered.isEmpty
                  ? const _EmptyTabState(
                    message:
                        'No offline league stories available for this filter.',
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _NewsTile(item: item);
                    },
                  ),
        ),
      ],
    );
  }
}

class _PlayerStatsTab extends ConsumerWidget {
  const _PlayerStatsTab({
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
            ),
          ),
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                      message: 'Unable to load top player rows.',
                    ),
                data: (leaders) {
                  if (leaders.isEmpty) {
                    return const _EmptyTabState(
                      message: 'No player entries found for this category.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                    itemCount: leaders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = leaders[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            () => context.push('/player/${item.stat.playerId}'),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.72),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    '${item.stat.rank}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                EntityBadge(
                                  entityId: item.stat.playerId,
                                  type: SportsAssetType.players,
                                  resolver: resolver,
                                  size: 30,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.stat.playerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.teamName ?? 'Unknown Team',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.82),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  compactNumber(item.stat.statValue),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _TeamStatsTab extends StatelessWidget {
  const _TeamStatsTab({
    required this.rows,
    required this.metric,
    required this.resolver,
    required this.onMetricChanged,
  });

  final List<StandingsTableView> rows;
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            itemCount: statRows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = statRows[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/team/${item.teamId}'),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.72),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${item.rank}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        EntityBadge(
                          entityId: item.teamId,
                          type: SportsAssetType.teams,
                          resolver: resolver,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.primary,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              item.secondary,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(alpha: 0.82),
                                fontSize: 12,
                              ),
                            ),
                          ],
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

class _NewsTile extends StatelessWidget {
  const _NewsTile({required this.item});

  final LeagueNewsItem item;

  @override
  Widget build(BuildContext context) {
    final published = DateFormat(
      'dd MMM • HH:mm',
    ).format(item.publishedAtUtc.toLocal());

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (item.matchId != null) {
          context.push('/match/${item.matchId}');
          return;
        }
        showModalBottomSheet<void>(
          context: context,
          builder: (context) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(item.excerpt),
                    const SizedBox(height: 8),
                    Text(
                      '${item.source} • $published',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.72),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      item.isInsight
                          ? const Color(0xFFD7E4FF)
                          : const Color(0xFFDDF3E7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isInsight ? Icons.insights_rounded : Icons.sports_soccer,
                  color:
                      item.isInsight
                          ? const Color(0xFF2A4F96)
                          : const Color(0xFF1C7B50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.86),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$published • ${item.source}',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.82),
                        fontSize: 12,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).cardColor,
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.72),
                  ),
                  labelStyle: TextStyle(
                    color:
                        selectedIndex == i
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
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
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.72),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context)
              .textTheme
              .bodySmall
              ?.color
              ?.withValues(alpha: 0.88),
          fontSize: 12,
        ),
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
          style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodySmall
                ?.color
                ?.withValues(alpha: 0.9),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Unable to load this league from local data. Re-scan your offline files and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodySmall
                ?.color
                ?.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
