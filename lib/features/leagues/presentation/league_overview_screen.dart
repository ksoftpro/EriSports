import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:eri_sports/features/leagues/presentation/league_overview_providers.dart';
import 'package:eri_sports/features/leagues/presentation/widgets/league_overview_widgets.dart'
    show LeagueHeader, LeagueTopTabs;
import 'package:eri_sports/features/player_stats/presentation/player_stats_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/match_card_compact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

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
                        standings: state.standings,
                        overallRows: state.overallStandingsRows,
                        selectedModeKey: _selectedStandingsModeKey,
                        resolver: resolver,
                        onModeChanged: (modeKey) {
                          setState(() {
                            _selectedStandingsModeKey = modeKey;
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
                        rows: state.overallStandingsRows,
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
    required this.standings,
    required this.overallRows,
    required this.selectedModeKey,
    required this.resolver,
    required this.onModeChanged,
  });

  final LeagueStandingsLeague? standings;
  final List<LeagueStandingsRow> overallRows;
  final String selectedModeKey;
  final LocalAssetResolver resolver;
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

    final hasXgColumns =
        activeModeKey.toLowerCase() == 'xg' ||
        (modeData?.hasXgColumns ?? false);
    final isFormMode = activeModeKey.toLowerCase() == 'form';
    final modeLabels = availableModeKeys
        .map((modeKey) => standingsModeLabel(modeKey))
        .toList(growable: false);
    final minTableWidth = _tableMinWidth(
      hasXgColumns: hasXgColumns,
      isFormMode: isFormMode,
    );

    return Column(
      children: [
        if (availableModeKeys.length > 1)
          _FilterChipBar(
            labels: modeLabels,
            selectedIndex: availableModeKeys.indexOf(activeModeKey),
            onSelected: (index) => onModeChanged(availableModeKeys[index]),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: _InfoStrip(
              text: 'Mode: ${standingsModeLabel(activeModeKey)}',
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.72),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(
                  minTableWidth,
                  MediaQuery.of(context).size.width - 20,
                ),
                child: Column(
                  children: [
                    _StandingsTableHeader(
                      hasXgColumns: hasXgColumns,
                      isFormMode: isFormMode,
                    ),
                    Divider(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.72),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: rows.length,
                        separatorBuilder:
                            (_, __) => Divider(
                              height: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.24),
                            ),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return _StandingsTableRow(
                            row: row,
                            resolver: resolver,
                            hasXgColumns: hasXgColumns,
                            isFormMode: isFormMode,
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
        ),
      ],
    );
  }

  double _tableMinWidth({
    required bool hasXgColumns,
    required bool isFormMode,
  }) {
    if (hasXgColumns) {
      return 820;
    }
    if (isFormMode) {
      return 780;
    }
    return 760;
  }
}

class _StandingsTableHeader extends StatelessWidget {
  const _StandingsTableHeader({
    required this.hasXgColumns,
    required this.isFormMode,
  });

  final bool hasXgColumns;
  final bool isFormMode;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
      fontWeight: FontWeight.w700,
    );

    return Container(
      height: 38,
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      alignment: Alignment.center,
      child: Row(
        children: [
          const SizedBox(width: 4),
          const SizedBox(width: 8),
          SizedBox(width: 22, child: Text('#', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('Team', style: style)),
          _headerCell('Pl', width: 34, style: style),
          _headerCell('W', width: 32, style: style),
          _headerCell('D', width: 32, style: style),
          _headerCell('L', width: 32, style: style),
          if (hasXgColumns) ...[
            _headerCell('xG', width: 54, style: style),
            _headerCell('xGA', width: 54, style: style),
            _headerCell('xPts', width: 58, style: style),
          ] else if (isFormMode) ...[
            SizedBox(
              width: 110,
              child: Text('Form', textAlign: TextAlign.center, style: style),
            ),
          ] else ...[
            _headerCell('GF-GA', width: 64, style: style),
            _headerCell('GD', width: 38, style: style),
          ],
          _headerCell('Pts', width: 40, style: style),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {required double width, TextStyle? style}) {
    return SizedBox(
      width: width,
      child: Text(text, textAlign: TextAlign.right, style: style),
    );
  }
}

class _StandingsTableRow extends StatelessWidget {
  const _StandingsTableRow({
    required this.row,
    required this.resolver,
    required this.hasXgColumns,
    required this.isFormMode,
    required this.onTap,
  });

  final LeagueStandingsRow row;
  final LocalAssetResolver resolver;
  final bool hasXgColumns;
  final bool isFormMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final qualColor = _qualColorFromHex(row.qualColor);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
        alignment: Alignment.center,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: qualColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 22,
              child: Text(
                '${row.position}',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  EntityBadge(
                    entityId: row.teamId,
                    entityName: row.teamName,
                    type: SportsAssetType.teams,
                    resolver: resolver,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.displayTeamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _metricCell('${row.played}', width: 34, color: scheme.onSurface),
            _metricCell('${row.wins}', width: 32, color: scheme.onSurface),
            _metricCell('${row.draws}', width: 32, color: scheme.onSurface),
            _metricCell('${row.losses}', width: 32, color: scheme.onSurface),
            if (hasXgColumns) ...[
              _metricCell(
                _formatDecimal(row.xg),
                width: 54,
                color: scheme.onSurface,
              ),
              _metricCell(
                _formatDecimal(row.xgConceded),
                width: 54,
                color: scheme.onSurface,
              ),
              _metricCell(
                _formatDecimal(row.xPoints),
                width: 58,
                color: scheme.onSurface,
              ),
            ] else if (isFormMode) ...[
              SizedBox(width: 110, child: _CompactFormPills(form: row.form)),
            ] else ...[
              _metricCell(row.scoresStr, width: 64, color: scheme.onSurface),
              _metricCell(
                _goalDiffLabel(row.goalConDiff),
                width: 38,
                color: scheme.onSurface,
              ),
            ],
            _metricCell(
              '${row.points}',
              width: 40,
              bold: true,
              color: scheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCell(
    String text, {
    required double width,
    required Color color,
    bool bold = false,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Color _qualColorFromHex(String? value) {
    if (value == null || value.trim().isEmpty) {
      return Colors.transparent;
    }

    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) {
      return Colors.transparent;
    }

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      return Colors.transparent;
    }
    return Color(parsed);
  }

  String _goalDiffLabel(int value) => value > 0 ? '+$value' : '$value';

  String _formatDecimal(double? value) {
    if (value == null) {
      return '-';
    }
    return value.toStringAsFixed(1);
  }
}

class _CompactFormPills extends StatelessWidget {
  const _CompactFormPills({required this.form});

  final String? form;

  @override
  Widget build(BuildContext context) {
    final tokens = (form ?? '')
        .toUpperCase()
        .replaceAll(RegExp('[^WDL]'), '')
        .split('');

    if (tokens.isEmpty || (tokens.length == 1 && tokens.first.isEmpty)) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.72),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final clipped = tokens.where((token) => token.isNotEmpty).take(5).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: clipped
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
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.72),
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
                                  entityName: item.stat.playerName,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.72),
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
                          entityName: item.teamName,
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
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.82),
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
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.72),
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
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.86),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$published • ${item.source}',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.82),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.72),
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
          color: Theme.of(
            context,
          ).textTheme.bodySmall?.color?.withValues(alpha: 0.88),
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
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.9),
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
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
