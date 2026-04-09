import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/detail_navigation.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/team/presentation/team_providers.dart';
import 'package:eri_sports/shared/formatters/match_display_formatter.dart';
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
  bool _enableDeferredDetailLoad = false;

  @override
  void initState() {
    super.initState();
    _scheduleDeferredDetailLoad();
  }

  @override
  void didUpdateWidget(covariant TeamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId) {
      _enableDeferredDetailLoad = false;
      _scheduleDeferredDetailLoad();
    }
  }

  void _scheduleDeferredDetailLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _enableDeferredDetailLoad) {
        return;
      }
      setState(() {
        _enableDeferredDetailLoad = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final shellAsync = ref.watch(teamShellProvider(widget.teamId));
    final detailAsync =
        _enableDeferredDetailLoad
            ? ref.watch(teamDetailProvider(widget.teamId))
            : const AsyncLoading<TeamDetailState>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: shellAsync.when(
        loading: () => const _TeamShellLoadingView(),
        error:
            (error, stackTrace) =>
                const Center(child: Text('Unable to load local team data.')),
        data: (shellState) {
          final state = detailAsync.valueOrNull ?? shellState;
          final isEnhancing =
              _enableDeferredDetailLoad &&
              detailAsync.valueOrNull == null &&
              !detailAsync.hasError;
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
                        if (isEnhancing) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(minHeight: 2.2),
                        ],
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

class _TeamShellLoadingView extends StatelessWidget {
  const _TeamShellLoadingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF273248), Color(0xFF3D4B66)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  _skeletonBox(width: 38, height: 38, circular: true),
                  const SizedBox(width: 12),
                  _skeletonBox(width: 64, height: 64, radius: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonBox(width: 180, height: 20),
                        const SizedBox(height: 8),
                        _skeletonBox(width: 120, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDE1E6)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: const [
                  _TabGhost(width: 72),
                  SizedBox(width: 8),
                  _TabGhost(width: 70),
                  SizedBox(width: 8),
                  _TabGhost(width: 76),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDDE1E6)),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _skeletonBox({
    required double width,
    required double height,
    bool circular = false,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.23),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

class _TabGhost extends StatelessWidget {
  const _TabGhost({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFFDFE3E8),
        borderRadius: BorderRadius.circular(999),
      ),
    );
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
    final tableSnapshot = _findTableSnapshot(
      state.tableData,
      state.identity.teamId,
    );
    final latestTransfer =
        (List<TeamTransferItem>.from(state.transferItems)..sort(
          (a, b) => b.transferDateUtc.compareTo(a.transferDateUtc),
        )).firstOrNull;
    final latestHistory = state.historyItems.firstOrNull;
    final allTableRows =
        state.tableData == null
            ? const <TeamTableRowItem>[]
            : List<TeamTableRowItem>.from(state.tableData!.rowsForMode('all'))
              ..sort((a, b) => a.position.compareTo(b.position));
    final tablePreviewRows = _buildTablePreviewRows(
      allTableRows,
      state.identity.teamId,
    );
    final squadGroups = _buildSquadGroupCounts(state.squadItems);

    final leftSections = <Widget>[
      _SectionCard(
        title: 'Team context',
        subtitle: 'League standing snapshot and current placement',
        child:
            tablePreviewRows.isEmpty
                ? const _InlineEmptyState(
                  message: 'No table context found in this dataset.',
                )
                : Column(
                  children: [
                    for (var i = 0; i < tablePreviewRows.length; i++) ...[
                      _TeamTableContextRow(
                        row: tablePreviewRows[i],
                        resolver: resolver,
                        emphasized: tablePreviewRows[i].teamId == state.identity.teamId,
                      ),
                      if (i < tablePreviewRows.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 7),
                          child: Divider(height: 1, color: Color(0xFFE4E8ED)),
                        ),
                    ],
                  ],
                ),
      ),
      _SectionCard(
        title: 'Momentum',
        subtitle: 'Recent form and immediate fixtures',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.formTokens.isNotEmpty) ...[
              const Text(
                'Recent form',
                style: TextStyle(
                  color: Color(0xFF5E6879),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _FormStrip(tokens: state.formTokens),
              const SizedBox(height: 10),
            ],
            const Text(
              'Next fixture',
              style: TextStyle(
                color: Color(0xFF5E6879),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (upcoming.isEmpty)
              const _InlineEmptyState(message: 'No upcoming fixture available.')
            else
              _FixtureSummaryRow(fixture: upcoming.first, resolver: resolver),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE4E8ED)),
            const SizedBox(height: 10),
            const Text(
              'Latest result',
              style: TextStyle(
                color: Color(0xFF5E6879),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (recent.isEmpty)
              const _InlineEmptyState(message: 'No completed fixture available.')
            else
              _FixtureSummaryRow(fixture: recent.first, resolver: resolver),
          ],
        ),
      ),
    ];

    final rightSections = <Widget>[
      _SectionCard(
        title: 'Squad pulse',
        subtitle: 'Squad depth and latest transfer movement',
        child: Column(
          children: [
            _metaRow('Total players', '${state.squadItems.length}'),
            _metaRow('Goalkeepers', '${squadGroups['Goalkeepers'] ?? 0}'),
            _metaRow('Defenders', '${squadGroups['Defenders'] ?? 0}'),
            _metaRow('Midfielders', '${squadGroups['Midfielders'] ?? 0}'),
            _metaRow('Forwards', '${squadGroups['Forwards'] ?? 0}'),
            if (latestTransfer != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFE4E8ED)),
              const SizedBox(height: 8),
              Row(
                children: [
                  EntityBadge(
                    entityId: latestTransfer.playerId ?? latestTransfer.playerName,
                    entityName: latestTransfer.playerName,
                    type: SportsAssetType.players,
                    resolver: resolver,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latest transfer',
                          style: TextStyle(
                            color: Color(0xFF5E6879),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          latestTransfer.playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1A2230),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    latestTransfer.fee ?? '--',
                    style: const TextStyle(
                      color: Color(0xFF121925),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      if (state.statHighlights.isNotEmpty)
        _SectionCard(
          title: 'Top team stats',
          subtitle: 'Best values surfaced from the dataset',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stat in state.statHighlights.take(6))
                _StatPill(title: stat.title, value: stat.value),
            ],
          ),
        ),
      if (latestHistory != null)
        _SectionCard(
          title: 'History pulse',
          subtitle: 'Most recent history signal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                latestHistory.title,
                style: const TextStyle(
                  color: Color(0xFF1A2230),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                latestHistory.subtitle,
                style: const TextStyle(
                  color: Color(0xFF6B7381),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      _SectionCard(
        title: 'Club details',
        subtitle: 'Identity and location context',
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
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: [
        _TeamOverviewHeroCard(
          teamName: state.identity.name,
          seasonLabel: seasonLabel,
          leagueName: state.identity.primaryLeagueName,
          countryName: state.identity.country,
          tableSnapshot: tableSnapshot,
          formTokens: state.formTokens,
        ),
        const SizedBox(height: 10),
        _OverviewMetricGrid(
          children: [
            _InfoCard(
              icon: Icons.calendar_month_outlined,
              label: 'Season',
              value: seasonLabel,
              caption: 'Current context',
            ),
            _InfoCard(
              icon: Icons.emoji_events_outlined,
              label: 'League',
              value: state.identity.primaryLeagueName ?? '-',
              caption: state.identity.country ?? 'Country unknown',
            ),
            _InfoCard(
              icon: Icons.format_list_numbered_rounded,
              label: 'Position',
              value:
                  tableSnapshot != null && tableSnapshot.position > 0
                      ? '${tableSnapshot.position}'
                      : '-',
              caption: 'Table rank',
            ),
            _InfoCard(
              icon: Icons.military_tech_outlined,
              label: 'Points',
              value: tableSnapshot != null ? '${tableSnapshot.points}' : '-',
              caption: 'In standings',
            ),
            _InfoCard(
              icon: Icons.groups_2_outlined,
              label: 'Squad',
              value: '${state.squadItems.length}',
              caption: 'Registered players',
            ),
            _InfoCard(
              icon: Icons.swap_horiz_rounded,
              label: 'Transfers',
              value: '${state.transferItems.length}',
              caption:
                  latestTransfer == null
                      ? 'No transfer rows'
                      : 'Latest ${DateFormat('dd MMM').format(latestTransfer.transferDateUtc.toLocal())}',
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 940) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(children: _withSectionSpacing(leftSections)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Column(children: _withSectionSpacing(rightSections)),
                  ),
                ],
              );
            }

            return Column(
              children: [
                ..._withSectionSpacing(leftSections),
                if (leftSections.isNotEmpty && rightSections.isNotEmpty)
                  const SizedBox(height: 10),
                ..._withSectionSpacing(rightSections),
              ],
            );
          },
        ),
      ],
    );
  }

  TeamTableRowItem? _findTableSnapshot(
    TeamTableData? tableData,
    String teamId,
  ) {
    if (tableData == null) {
      return null;
    }
    final rows = tableData.rowsForMode('all');
    for (final row in rows) {
      if (row.teamId == teamId) {
        return row;
      }
    }
    return null;
  }

  List<Widget> _withSectionSpacing(List<Widget> sections) {
    final output = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      if (i > 0) {
        output.add(const SizedBox(height: 10));
      }
      output.add(sections[i]);
    }
    return output;
  }

  List<TeamTableRowItem> _buildTablePreviewRows(
    List<TeamTableRowItem> rows,
    String teamId,
  ) {
    if (rows.isEmpty) {
      return const <TeamTableRowItem>[];
    }

    final topRows = rows.take(5).toList(growable: true);
    final hasTeam = topRows.any((row) => row.teamId == teamId);
    if (hasTeam) {
      return topRows;
    }

    final teamRow = rows.where((row) => row.teamId == teamId).firstOrNull;
    if (teamRow != null) {
      topRows.add(teamRow);
    }
    return topRows;
  }

  Map<String, int> _buildSquadGroupCounts(List<TeamSquadItem> squad) {
    final counts = <String, int>{
      'Goalkeepers': 0,
      'Defenders': 0,
      'Midfielders': 0,
      'Forwards': 0,
    };

    for (final item in squad) {
      final group = _groupPosition(item.position);
      counts[group] = (counts[group] ?? 0) + 1;
    }

    return counts;
  }

  String _groupPosition(String? rawPosition) {
    final value = (rawPosition ?? '').toLowerCase();
    if (value.contains('goal')) {
      return 'Goalkeepers';
    }
    if (value.contains('def')) {
      return 'Defenders';
    }
    if (value.contains('mid')) {
      return 'Midfielders';
    }
    if (value.contains('for') || value.contains('strik') || value.contains('att')) {
      return 'Forwards';
    }
    return 'Midfielders';
  }
}

class _TeamOverviewHeroCard extends StatelessWidget {
  const _TeamOverviewHeroCard({
    required this.teamName,
    required this.seasonLabel,
    required this.leagueName,
    required this.countryName,
    required this.tableSnapshot,
    required this.formTokens,
  });

  final String teamName;
  final String seasonLabel;
  final String? leagueName;
  final String? countryName;
  final TeamTableRowItem? tableSnapshot;
  final List<String> formTokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${leagueName ?? 'League'} • ${countryName ?? 'Country'} • Season $seasonLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(
                'Position',
                tableSnapshot != null && tableSnapshot!.position > 0
                    ? '${tableSnapshot!.position}'
                    : '-',
              ),
              _heroChip(
                'Points',
                tableSnapshot != null ? '${tableSnapshot!.points}' : '-',
              ),
              _heroChip('Form', formTokens.isEmpty ? '-' : formTokens.take(5).join('')),
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OverviewMetricGrid extends StatelessWidget {
  const _OverviewMetricGrid({required this.children});

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
        final cardWidth = (maxWidth - ((columns - 1) * 8)) / columns;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}

class _TeamTableContextRow extends StatelessWidget {
  const _TeamTableContextRow({
    required this.row,
    required this.resolver,
    required this.emphasized,
  });

  final TeamTableRowItem row;
  final dynamic resolver;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            '${row.position}',
            style: TextStyle(
              color: emphasized ? const Color(0xFF111827) : const Color(0xFF525D70),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TeamBadge(
          teamId: row.teamId,
          teamName: row.teamName,
          resolver: resolver,
          source: 'team.overview.context',
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            row.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF1A2230),
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${row.points} pts',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
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
                      Builder(
                        builder: (context) {
                          final score = MatchDisplayFormatter.scoreDisplay(
                            status: fixture.status,
                            kickoffUtc: fixture.kickoffUtc,
                            homeScore: fixture.homeScore,
                            awayScore: fixture.awayScore,
                          );

                          return Row(
                            children: [
                              Expanded(
                                child: Row(
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
                              ),
                              const SizedBox(width: 8),
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
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final score = MatchDisplayFormatter.scoreDisplay(
                            status: fixture.status,
                            kickoffUtc: fixture.kickoffUtc,
                            homeScore: fixture.homeScore,
                            awayScore: fixture.awayScore,
                          );

                          return Column(
                            children: [
                              _FixtureTeamLine(
                                teamId: fixture.homeTeamId,
                                teamName: fixture.homeTeamName,
                                score: score.homeScoreLabel,
                                resolver: resolver,
                              ),
                              const SizedBox(height: 6),
                              _FixtureTeamLine(
                                teamId: fixture.awayTeamId,
                                teamName: fixture.awayTeamName,
                                score: score.awayScoreLabel,
                                resolver: resolver,
                              ),
                            ],
                          );
                        },
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
  final String? score;
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
        if (score != null)
          Text(
            score!,
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
    final score = MatchDisplayFormatter.scoreDisplay(
      status: fixture.status,
      kickoffUtc: fixture.kickoffUtc,
      homeScore: fixture.homeScore,
      awayScore: fixture.awayScore,
    );

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
              score.centerLabel,
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
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
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
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData? icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: const Color(0xFF667180)),
                const SizedBox(width: 6),
              ],
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF131A25),
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
