import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/detail_navigation.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/team/presentation/team_providers.dart';
import 'package:eri_sports/shared/widgets/compact_standings_table.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({required this.teamId, super.key});

  final String teamId;

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  String _selectedTableMode = 'all';
  String? _selectedSeason;

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamDetailProvider(widget.teamId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) =>
                const Center(child: Text('Unable to load local team data.')),
        data: (state) {
          final resolver = ref.read(appServicesProvider).assetResolver;
          final tabs =
              state.tabs.isNotEmpty
                  ? state.tabs
                  : const [TeamTabSpec(key: 'overview', label: 'Overview')];
          final followEnabled = ref.watch(
            teamHeaderFollowingProvider(state.team.id),
          );
          final seasonLabel = _resolveSeasonLabel(state.availableSeasonLabels);

          return SafeArea(
            child: DefaultTabController(
              key: ValueKey(
                'team-tabs-${tabs.map((tab) => tab.key).join('|')}',
              ),
              length: tabs.length,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1260),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      children: [
                        _TeamHeaderCard(
                          state: state,
                          seasonLabel: seasonLabel,
                          isFollowing: followEnabled,
                          resolver: resolver,
                          onBack: () => context.pop(),
                          onFollowTap: () {
                            ref
                                .read(
                                  teamHeaderFollowingProvider(
                                    state.team.id,
                                  ).notifier,
                                )
                                .update((value) => !value);
                          },
                          onSeasonTap:
                              state.availableSeasonLabels.isEmpty
                                  ? null
                                  : () => _showSeasonSheet(
                                    state.availableSeasonLabels,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        _TeamTabsBar(tabs: tabs),
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
                                for (final tab in tabs)
                                  _buildTab(
                                    tabKey: tab.key,
                                    state: state,
                                    resolver: resolver,
                                    seasonLabel: seasonLabel,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab({
    required String tabKey,
    required TeamDetailState state,
    required dynamic resolver,
    required String seasonLabel,
  }) {
    switch (tabKey) {
      case 'overview':
        return _OverviewTab(
          state: state,
          seasonLabel: seasonLabel,
          resolver: resolver,
        );
      case 'table':
        return _TableTab(
          state: state,
          selectedMode: _selectedTableMode,
          onSelectMode: (mode) {
            setState(() {
              _selectedTableMode = mode;
            });
          },
          resolver: resolver,
        );
      case 'fixtures':
        return _FixturesTab(state: state, resolver: resolver);
      case 'squad':
        return _SquadTab(state: state, resolver: resolver);
      case 'stats':
        return _StatsTab(state: state, resolver: resolver);
      case 'history':
        return _HistoryTab(state: state);
      case 'transfers':
        return _TransfersTab(state: state, resolver: resolver);
      default:
        return _EmptyTabState(
          message: 'No renderer available for "$tabKey" tab.',
        );
    }
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

class _TeamHeaderCard extends StatelessWidget {
  const _TeamHeaderCard({
    required this.state,
    required this.seasonLabel,
    required this.isFollowing,
    required this.resolver,
    required this.onBack,
    required this.onFollowTap,
    required this.onSeasonTap,
  });

  final TeamDetailState state;
  final String seasonLabel;
  final bool isFollowing;
  final dynamic resolver;
  final VoidCallback onBack;
  final VoidCallback onFollowTap;
  final VoidCallback? onSeasonTap;

  @override
  Widget build(BuildContext context) {
    final colorA =
        _parseHexColor(state.teamColors?.darkMode) ?? const Color(0xFF222B3A);
    final colorB =
        _parseHexColor(state.teamColors?.lightMode) ?? const Color(0xFF3A4A62);
    final textColor =
        _parseHexColor(state.teamColors?.fontDarkMode) ?? Colors.white;
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [colorA, colorB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child:
          isCompact
              ? Column(
                children: [
                  Row(
                    children: [
                      _headerIconButton(
                        Icons.arrow_back_rounded,
                        onBack,
                        textColor,
                      ),
                      const Spacer(),
                      if (onSeasonTap != null)
                        _seasonButton(
                          seasonLabel: seasonLabel,
                          onTap: onSeasonTap!,
                          textColor: textColor,
                        ),
                      const SizedBox(width: 8),
                      _followButton(isFollowing, onFollowTap, textColor),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _headerMainRow(textColor, resolver),
                ],
              )
              : Row(
                children: [
                  _headerIconButton(
                    Icons.arrow_back_rounded,
                    onBack,
                    textColor,
                  ),
                  const SizedBox(width: 12),
                  _headerMainRow(textColor, resolver),
                  if (onSeasonTap != null) ...[
                    const SizedBox(width: 12),
                    _seasonButton(
                      seasonLabel: seasonLabel,
                      onTap: onSeasonTap!,
                      textColor: textColor,
                    ),
                  ],
                  const SizedBox(width: 10),
                  _followButton(isFollowing, onFollowTap, textColor),
                ],
              ),
    );
  }

  Widget _headerMainRow(Color textColor, dynamic resolver) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            alignment: Alignment.center,
            child: TeamBadge(
              teamId: state.team.id,
              teamName: state.identity.name,
              resolver: resolver,
              source: 'team.header',
              size: 44,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.identity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitleLabel(state.identity),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (state.formTokens.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _FormStrip(tokens: state.formTokens, compact: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, VoidCallback onTap, Color iconColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Widget _seasonButton({
    required String seasonLabel,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              seasonLabel,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _followButton(bool following, VoidCallback onTap, Color textColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Text(
          following ? 'Following' : 'Follow',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _subtitleLabel(TeamIdentityInfo identity) {
    final parts = <String>[];
    if (identity.primaryLeagueName != null &&
        identity.primaryLeagueName!.isNotEmpty) {
      parts.add(identity.primaryLeagueName!);
    }
    if (identity.country != null && identity.country!.isNotEmpty) {
      parts.add(identity.country!);
    }
    return parts.isEmpty ? 'Club profile' : parts.join(' • ');
  }
}

class _TeamTabsBar extends StatelessWidget {
  const _TeamTabsBar({required this.tabs});

  final List<TeamTabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE1E6)),
      ),
      child: TabBar(
        isScrollable: true,
        labelColor: const Color(0xFF171D28),
        unselectedLabelColor: const Color(0xFF6A7280),
        indicatorColor: const Color(0xFF141B26),
        indicatorWeight: 2.2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: const Color(0x00000000),
        labelPadding: const EdgeInsets.only(left: 8, right: 16),
        tabAlignment: TabAlignment.start,
        tabs: [for (final tab in tabs) Tab(text: tab.label)],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.state,
    required this.seasonLabel,
    required this.resolver,
  });

  final TeamDetailState state;
  final String seasonLabel;
  final dynamic resolver;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final fixtures = state.fixtureItems;
    final upcoming = fixtures
        .where((item) => item.kickoffUtc.isAfter(now))
        .toList(growable: false)
      ..sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));
    final recent = fixtures
        .where((item) => item.kickoffUtc.isBefore(now))
        .toList(growable: false)
      ..sort((a, b) => b.kickoffUtc.compareTo(a.kickoffUtc));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoCard(
              label: 'Season',
              value: seasonLabel,
              caption: 'Current context',
            ),
            _InfoCard(
              label: 'League',
              value: state.identity.primaryLeagueName ?? '-',
              caption: state.identity.country ?? 'Country unknown',
            ),
            _InfoCard(
              label: 'Squad',
              value: '${state.squadItems.length}',
              caption: 'Players',
            ),
            _InfoCard(
              label: 'Fixtures',
              value: '${fixtures.length}',
              caption: 'Loaded for team',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.formTokens.isNotEmpty)
          _SectionCard(
            title: 'Recent form',
            child: _FormStrip(tokens: state.formTokens),
          ),
        if (state.formTokens.isNotEmpty) const SizedBox(height: 10),
        _SectionCard(
          title: 'Club details',
          child: Column(
            children: [
              _metaRow('Team ID', state.identity.teamId),
              _metaRow('Short name', state.identity.shortName ?? '-'),
              _metaRow('Country', state.identity.country ?? '-'),
              _metaRow('League', state.identity.primaryLeagueName ?? '-'),
              _metaRow('Venue', state.identity.venue ?? '-'),
              _metaRow('City', state.identity.city ?? '-'),
              _metaRow('Latest season', state.identity.latestSeason ?? '-'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Next fixture',
          child:
              upcoming.isEmpty
                  ? const _InlineEmptyState(
                    message: 'No upcoming fixture available.',
                  )
                  : _FixtureSummaryRow(
                    fixture: upcoming.first,
                    resolver: resolver,
                  ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Latest result',
          child:
              recent.isEmpty
                  ? const _InlineEmptyState(
                    message: 'No completed fixture available.',
                  )
                  : _FixtureSummaryRow(
                    fixture: recent.first,
                    resolver: resolver,
                  ),
        ),
        if (state.statHighlights.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Top team stats',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final stat in state.statHighlights.take(4))
                  _StatPill(title: stat.title, value: stat.value),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TableTab extends StatelessWidget {
  const _TableTab({
    required this.state,
    required this.selectedMode,
    required this.onSelectMode,
    required this.resolver,
  });

  final TeamDetailState state;
  final String selectedMode;
  final ValueChanged<String> onSelectMode;
  final dynamic resolver;

  @override
  Widget build(BuildContext context) {
    final table = state.tableData;
    if (table == null || !table.hasRows) {
      return const _EmptyTabState(
        message: 'No table context found in team JSON.',
      );
    }

    final modeKeys = table.orderedModeKeys;
    final activeMode =
        modeKeys.contains(selectedMode) ? selectedMode : modeKeys.first;
    final rows = table.rowsForMode(activeMode);
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
            goalDiff: row.goalDiff,
            points: row.points,
            form: row.form,
            qualColorHex: row.qualColor,
            isHighlighted: row.teamId == table.highlightedTeamId,
          ),
        )
        .toList(growable: false);

    return Column(
      children: [
        if (modeKeys.length > 1)
          _FilterChipBar(
            labels: [for (final mode in modeKeys) _humanizeMode(mode)],
            selectedIndex: modeKeys.indexOf(activeMode),
            onSelected: (index) => onSelectMode(modeKeys[index]),
          )
        else
          const SizedBox(height: 10),
        if (table.legend.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in table.legend)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE2E6EC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                _parseHexColor(item.colorHex) ??
                                const Color(0xFF7D8797),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Color(0xFF30384A),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: CompactStandingsTable(
            rows: tableRows,
            resolver: resolver,
            tableBadgeSource: 'team.table',
            onRowTap: (row) => context.push('/team/${row.teamId}'),
          ),
        ),
      ],
    );
  }
}

class _FixturesTab extends StatelessWidget {
  const _FixturesTab({required this.state, required this.resolver});

  final TeamDetailState state;
  final dynamic resolver;

  @override
  Widget build(BuildContext context) {
    final fixtures = List<TeamFixtureItem>.from(state.fixtureItems)
      ..sort((a, b) => b.kickoffUtc.compareTo(a.kickoffUtc));

    if (fixtures.isEmpty) {
      return const _EmptyTabState(
        message: 'No fixtures available for this team.',
      );
    }

    final grouped = <String, List<TeamFixtureItem>>{};
    for (final fixture in fixtures) {
      final key = DateFormat(
        'EEEE, dd MMM yyyy',
      ).format(fixture.kickoffUtc.toLocal());
      grouped.putIfAbsent(key, () => []).add(fixture);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
            child: Text(
              entry.key,
              style: const TextStyle(
                color: Color(0xFF535D6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final fixture in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap:
                    fixture.matchId == null
                        ? null
                        : () => context.openMatchDetail(fixture.matchId!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E6EC)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fixture.roundLabel ?? fixture.status,
                              style: const TextStyle(
                                color: Color(0xFF6A7382),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat(
                              'HH:mm',
                            ).format(fixture.kickoffUtc.toLocal()),
                            style: const TextStyle(
                              color: Color(0xFF1A2230),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _FixtureTeamLine(
                        teamId: fixture.homeTeamId,
                        teamName: fixture.homeTeamName,
                        score: fixture.homeScore,
                        resolver: resolver,
                      ),
                      const SizedBox(height: 6),
                      _FixtureTeamLine(
                        teamId: fixture.awayTeamId,
                        teamName: fixture.awayTeamName,
                        score: fixture.awayScore,
                        resolver: resolver,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _FixtureTeamLine extends StatelessWidget {
  const _FixtureTeamLine({
    required this.teamId,
    required this.teamName,
    required this.score,
    required this.resolver,
  });

  final String? teamId;
  final String teamName;
  final int? score;
  final dynamic resolver;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamBadge(
          teamId: teamId,
          teamName: teamName,
          resolver: resolver,
          source: 'team.fixtures',
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
          score?.toString() ?? '-',
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

class _SquadTab extends StatelessWidget {
  const _SquadTab({required this.state, required this.resolver});

  final TeamDetailState state;
  final dynamic resolver;

  @override
  Widget build(BuildContext context) {
    if (state.squadItems.isEmpty) {
      return const _EmptyTabState(message: 'No squad data in this team JSON.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 940 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 3 ? 2.7 : 2.45,
          ),
          itemCount: state.squadItems.length,
          itemBuilder: (context, index) {
            final item = state.squadItems[index];
            return InkWell(
              onTap:
                  item.playerId == null
                      ? null
                      : () => context.push('/player/${item.playerId}'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE1E5EB)),
                ),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  children: [
                    EntityBadge(
                      entityId: item.playerId ?? item.playerName,
                      entityName: item.playerName,
                      type: SportsAssetType.players,
                      resolver: resolver,
                      size: 40,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1A2230),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.position ?? 'Unknown position',
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
                    const SizedBox(width: 4),
                    Text(
                      item.shirtNumber?.toString() ?? '--',
                      style: const TextStyle(
                        color: Color(0xFF131B28),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.state, required this.resolver});

  final TeamDetailState state;
  final dynamic resolver;

  @override
  Widget build(BuildContext context) {
    if (state.statHighlights.isEmpty) {
      return const _EmptyTabState(
        message: 'No stats data available for this team.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      itemCount: state.statHighlights.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = state.statHighlights[index];
        return InkWell(
          onTap:
              item.playerId == null
                  ? null
                  : () => context.push('/player/${item.playerId}'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E5EB)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                if (item.playerId != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: EntityBadge(
                      entityId: item.playerId!,
                      entityName: item.subtitle,
                      type: SportsAssetType.players,
                      resolver: resolver,
                      size: 30,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Color(0xFF1A2230),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.subtitle != null &&
                          item.subtitle!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            item.subtitle!,
                            style: const TextStyle(
                              color: Color(0xFF6B7381),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.value,
                  style: const TextStyle(
                    color: Color(0xFF121925),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.state});

  final TeamDetailState state;

  @override
  Widget build(BuildContext context) {
    if (state.historyItems.isEmpty) {
      return const _EmptyTabState(
        message: 'No history timeline data found for this team.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      itemCount: state.historyItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = state.historyItems[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1E5EB)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: Color(0xFF707B8E),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF1A2230),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7381),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TransfersTab extends StatelessWidget {
  const _TransfersTab({required this.state, required this.resolver});

  final TeamDetailState state;
  final dynamic resolver;

  @override
  Widget build(BuildContext context) {
    if (state.transferItems.isEmpty) {
      return const _EmptyTabState(
        message: 'No transfer entries found in this team JSON.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      itemCount: state.transferItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = state.transferItems[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1E5EB)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EntityBadge(
                entityId: item.playerId ?? item.playerName,
                entityName: item.playerName,
                type: SportsAssetType.players,
                resolver: resolver,
                size: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A2230),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.fromTeamName ?? '-'} -> ${item.toTeamName ?? '-'}',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.fee ?? '--',
                    style: const TextStyle(
                      color: Color(0xFF121925),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat(
                      'dd MMM yyyy',
                    ).format(item.transferDateUtc.toLocal()),
                    style: const TextStyle(
                      color: Color(0xFF6B7381),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(labels[index]),
            selected: selected,
            onSelected: (_) => onSelected(index),
          );
        },
      ),
    );
  }
}

class _FormStrip extends StatelessWidget {
  const _FormStrip({required this.tokens, this.compact = false});

  final List<String> tokens;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (tokens.isEmpty) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          color:
              compact
                  ? Colors.white.withValues(alpha: 0.9)
                  : const Color(0xFF7D8795),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final size = compact ? 16.0 : 22.0;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final token in tokens.take(5))
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _formTokenColor(token),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              token,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Color _formTokenColor(String token) {
    switch (token.toUpperCase()) {
      case 'W':
        return const Color(0xFF1FA463);
      case 'D':
        return const Color(0xFF9BA5BD);
      default:
        return const Color(0xFFE14E67);
    }
  }
}

class _FixtureSummaryRow extends StatelessWidget {
  const _FixtureSummaryRow({required this.fixture, required this.resolver});

  final TeamFixtureItem fixture;
  final dynamic resolver;

  @override
  Widget build(BuildContext context) {
    final homeScore = fixture.homeScore?.toString() ?? '-';
    final awayScore = fixture.awayScore?.toString() ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat(
            'EEE, dd MMM • HH:mm',
          ).format(fixture.kickoffUtc.toLocal()),
          style: const TextStyle(
            color: Color(0xFF6A7382),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  TeamBadge(
                    teamId: fixture.homeTeamId,
                    teamName: fixture.homeTeamName,
                    resolver: resolver,
                    source: 'team.overview.fixture',
                    size: 18,
                  ),
                  const SizedBox(width: 8),
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
                ],
              ),
            ),
            Text(
              '$homeScore - $awayScore',
              style: const TextStyle(
                color: Color(0xFF121925),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  TeamBadge(
                    teamId: fixture.awayTeamId,
                    teamName: fixture.awayTeamName,
                    resolver: resolver,
                    source: 'team.overview.fixture',
                    size: 18,
                  ),
                  const SizedBox(width: 8),
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
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7EC)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF131A25),
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _StatPill extends StatelessWidget {
  const _StatPill({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(
              color: Color(0xFF697181),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A2230),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
        color: Color(0xFF6D7583),
        fontWeight: FontWeight.w500,
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6D7583),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

Widget _metaRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6A7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1A2230),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

String _humanizeMode(String value) {
  final key = value.trim().toLowerCase();
  switch (key) {
    case 'all':
      return 'Overall';
    case 'home':
      return 'Home';
    case 'away':
      return 'Away';
    case 'form':
      return 'Form';
    case 'xg':
      return 'XG';
    default:
      final words = key.split('_').where((part) => part.isNotEmpty);
      return words
          .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
  }
}

Color? _parseHexColor(String? value) {
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
