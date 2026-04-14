import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/detail_navigation.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/home/presentation/home_providers.dart';
import 'package:eri_sports/features/leagues/domain/league_ordering.dart';
import 'package:eri_sports/shared/formatters/match_display_formatter.dart';
import 'package:eri_sports/shared/formatters/team_display_name_formatter.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _selectedDay;
  PageController? _dayPageController;
  List<DateTime> _controllerDays = const <DateTime>[];
  int _dayTabScrollRequest = 0;
  bool _followingCollapsed = false;
  bool _hideAllCompetitions = false;
  final Set<String> _collapsedCompetitionIds = <String>{};

  @override
  void dispose() {
    _dayPageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeFeed = ref.watch(homeFeedProvider);

    return SafeArea(
      child: homeFeed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load matches.')),
        data: (state) {
          final days = _allMatchDays(state.all);
          final selectedDay = _resolvePreferredDay(days);
          final selectedIndex = _indexForDay(days, selectedDay);
          _ensurePageController(days, selectedIndex);

          final resolver = ref.read(appServicesProvider).assetResolver;

          return Column(
            children: [
              _TopBar(
                onJumpToToday: () {
                  _selectDay(
                    days,
                    _todayOrClosest(days),
                    forceTabStripSync: true,
                  );
                },
                onOpenCalendar: () => context.push('/leagues'),
                onOpenFollowing: () => context.push('/following'),
                onOpenSearch: () => context.push('/search'),
                onOpenMore: () => context.push('/video'),
              ),
              _DayTabStrip(
                days: days,
                selectedDay: selectedDay,
                scrollRequestId: _dayTabScrollRequest,
                onSelect:
                    (day) =>
                        _selectDay(days, day, forceTabStripSync: true),
              ),
              Expanded(
                child:
                    days.isEmpty || _dayPageController == null
                        ? _buildDayMatchesList(
                          context,
                          day: selectedDay,
                          state: state,
                          resolver: resolver,
                        )
                        : PageView.builder(
                          controller: _dayPageController,
                          itemCount: days.length,
                          onPageChanged: (index) {
                            final day = days[index];
                            if (_selectedDay != null &&
                                _isSameDay(_selectedDay!, day)) {
                              return;
                            }
                            setState(() {
                              _selectedDay = day;
                            });
                          },
                          itemBuilder: (context, index) {
                            final day = days[index];
                            return _buildDayMatchesList(
                              context,
                              day: day,
                              state: state,
                              resolver: resolver,
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayMatchesList(
    BuildContext context, {
    required DateTime day,
    required HomeFeedState state,
    required LocalAssetResolver resolver,
  }) {
    final dayMatches = state.all
        .where((item) => _isSameDay(item.match.kickoffUtc.toLocal(), day))
        .toList(growable: false)
      ..sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));

    final sections = _groupByCompetition(dayMatches, state.competitionNamesById);
    final followingMatches = state.followed
        .where((item) => _isSameDay(item.match.kickoffUtc.toLocal(), day))
        .take(2)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      children: [
        if (followingMatches.isNotEmpty)
          _FixtureGroupCard(
            title: 'Following',
            leadingIcon: Icons.star,
            collapsed: _followingCollapsed,
            onToggleCollapse: () {
              setState(() {
                _followingCollapsed = !_followingCollapsed;
              });
            },
            children: followingMatches
                .map(
                  (fixture) => _FixtureRow(
                    fixture: fixture,
                    resolver: resolver,
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: 18),
        Center(
          child: InkWell(
            onTap: () {
              setState(() {
                _hideAllCompetitions = !_hideAllCompetitions;
              });
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _hideAllCompetitions ? 'Show all' : 'Hide all',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _hideAllCompetitions
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (sections.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Text(
              'No fixtures for ${DateFormat('EEE d MMM').format(day)}.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        for (final section in sections) ...[
          _FixtureGroupCard(
            title: section.competitionName,
            badge: EntityBadge(
              entityId: section.competitionId,
              entityName: section.competitionName,
              type: SportsAssetType.leagues,
              resolver: resolver,
              size: 16,
              isCircular: false,
            ),
            collapsed:
                _hideAllCompetitions ||
                _collapsedCompetitionIds.contains(section.competitionId),
            onToggleCollapse: () {
              setState(() {
                if (_collapsedCompetitionIds.contains(section.competitionId)) {
                  _collapsedCompetitionIds.remove(section.competitionId);
                } else {
                  _collapsedCompetitionIds.add(section.competitionId);
                }
              });
            },
            onTapHeader: () => context.push('/league/${section.competitionId}'),
            children: section.matches
                .map(
                  (fixture) => _FixtureRow(
                    fixture: fixture,
                    resolver: resolver,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  DateTime _resolvePreferredDay(List<DateTime> days) {
    if (days.isEmpty) {
      return _dayKey(DateTime.now());
    }

    final current = _selectedDay;
    if (current != null && days.any((item) => _isSameDay(item, current))) {
      return current;
    }

    final preferred = _todayOrClosest(days);
    _selectedDay = preferred;
    return preferred;
  }

  DateTime _todayOrClosest(List<DateTime> days) {
    if (days.isEmpty) {
      return _dayKey(DateTime.now());
    }

    final today = _dayKey(DateTime.now());
    final todayMatch = days.where((day) => _isSameDay(day, today));
    if (todayMatch.isNotEmpty) {
      return todayMatch.first;
    }

    // When today has no fixtures, prefer the nearest upcoming day.
    // If all fixtures are in the past, use the latest available day.
    return _closestMatchDay(days);
  }

  int _indexForDay(List<DateTime> days, DateTime day) {
    if (days.isEmpty) {
      return 0;
    }
    final index = days.indexWhere((item) => _isSameDay(item, day));
    return index < 0 ? 0 : index;
  }

  void _ensurePageController(List<DateTime> days, int selectedIndex) {
    if (days.isEmpty) {
      _dayPageController?.dispose();
      _dayPageController = null;
      _controllerDays = const <DateTime>[];
      return;
    }

    final shouldRecreate =
        _dayPageController == null || !_sameDayList(_controllerDays, days);

    if (shouldRecreate) {
      _dayPageController?.dispose();
      _controllerDays = List<DateTime>.from(days, growable: false);
      _dayPageController = PageController(initialPage: selectedIndex);
    }
  }

  bool _sameDayList(List<DateTime> a, List<DateTime> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (!_isSameDay(a[index], b[index])) {
        return false;
      }
    }
    return true;
  }

  void _selectDay(
    List<DateTime> days,
    DateTime day, {
    bool forceTabStripSync = false,
  }) {
    if (days.isEmpty) {
      setState(() {
        _selectedDay = day;
        if (forceTabStripSync) {
          _dayTabScrollRequest++;
        }
      });
      return;
    }

    final index = _indexForDay(days, day);
    final selected = days[index];
    final sameSelection =
        _selectedDay != null && _isSameDay(_selectedDay!, selected);
    if (!sameSelection || forceTabStripSync) {
      setState(() {
        _selectedDay = selected;
        if (forceTabStripSync) {
          _dayTabScrollRequest++;
        }
      });
    }

    final controller = _dayPageController;
    if (controller != null && controller.hasClients) {
      final currentPage = controller.page?.round() ?? controller.initialPage;
      if (currentPage != index) {
        controller.animateToPage(
          index,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  List<DateTime> _allMatchDays(List<HomeMatchView> matches) {
    final unique = <DateTime>{
      for (final item in matches) _dayKey(item.match.kickoffUtc.toLocal()),
    };

    final output = unique.toList(growable: false)
      ..sort((a, b) => a.compareTo(b));
    return output;
  }

  DateTime _closestMatchDay(List<DateTime> days) {
    if (days.isEmpty) {
      return _dayKey(DateTime.now());
    }

    final today = _dayKey(DateTime.now());
    for (final day in days) {
      if (!day.isBefore(today)) {
        return day;
      }
    }

    return days.last;
  }

  static DateTime _dayKey(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<_CompetitionSection> _groupByCompetition(
    List<HomeMatchView> matches,
    Map<String, String> competitionNames,
  ) {
    final grouped = <String, List<HomeMatchView>>{};
    for (final match in matches) {
      grouped.putIfAbsent(match.match.competitionId, () => []).add(match);
    }

    final sections = grouped.entries
        .map(
          (entry) => _CompetitionSection(
            competitionId: entry.key,
            competitionName: competitionNames[entry.key] ?? 'Competition',
            matches: entry.value,
          ),
        )
        .toList(growable: false);

    sections.sort(
      (a, b) {
        final rankA = referenceLeagueRank(a.competitionName);
        final rankB = referenceLeagueRank(b.competitionName);
        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }

        final firstKickoffCompare = a.matches.first.match.kickoffUtc.compareTo(
          b.matches.first.match.kickoffUtc,
        );
        if (firstKickoffCompare != 0) {
          return firstKickoffCompare;
        }

        final nameCompare =
            a.competitionName.toLowerCase().compareTo(
              b.competitionName.toLowerCase(),
            );
        if (nameCompare != 0) {
          return nameCompare;
        }

        return a.competitionId.compareTo(b.competitionId);
      },
    );

    return sections;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onJumpToToday,
    required this.onOpenCalendar,
    required this.onOpenFollowing,
    required this.onOpenSearch,
    required this.onOpenMore,
  });

  final VoidCallback onJumpToToday;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenFollowing;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
      child: Row(
        children: [
          const Icon(Icons.stacked_line_chart_rounded, size: 22),
          const SizedBox(width: 3),
          Text(
            'ERISPORT',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          PopupMenuButton<_HeaderMenuAction>(
            tooltip: 'Menu',
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            onSelected: (action) {
              switch (action) {
                case _HeaderMenuAction.today:
                  onJumpToToday();
                case _HeaderMenuAction.calendar:
                  onOpenCalendar();
                case _HeaderMenuAction.following:
                  onOpenFollowing();
                case _HeaderMenuAction.search:
                  onOpenSearch();
                case _HeaderMenuAction.video:
                  onOpenMore();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.today,
                  child: _HeaderMenuRow(icon: Icons.today_outlined, label: 'Today'),
                ),
                PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.calendar,
                  child: _HeaderMenuRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendar',
                  ),
                ),
                PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.following,
                  child: _HeaderMenuRow(
                    icon: Icons.people_alt_outlined,
                    label: 'Following',
                  ),
                ),
                PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.search,
                  child: _HeaderMenuRow(icon: Icons.search, label: 'Search'),
                ),
                PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.video,
                  child: _HeaderMenuRow(
                    icon: Icons.video_library_outlined,
                    label: 'Video',
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

enum _HeaderMenuAction {
  today,
  calendar,
  following,
  search,
  video,
}

class _HeaderMenuRow extends StatelessWidget {
  const _HeaderMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class _DayTabStrip extends StatefulWidget {
  const _DayTabStrip({
    required this.days,
    required this.selectedDay,
    required this.scrollRequestId,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final int scrollRequestId;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_DayTabStrip> createState() => _DayTabStripState();
}

class _DayTabStripState extends State<_DayTabStrip> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dayKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollSelectedIntoView(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant _DayTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedChanged = !_isSameDay(oldWidget.selectedDay, widget.selectedDay);
    final daysChanged = !_sameDayList(oldWidget.days, widget.days);
    final requestChanged = oldWidget.scrollRequestId != widget.scrollRequestId;

    if (selectedChanged || daysChanged || requestChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollSelectedIntoView();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) {
      return const SizedBox(height: 46);
    }

    final inactiveColor = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: 0.66);

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: widget.days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final day = widget.days[index];
          final isSelected = _isSameDay(day, widget.selectedDay);
          final key = _keyForDay(day);
          return InkWell(
            key: key,
            onTap: () => widget.onSelect(day),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minWidth: 78),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _labelForDay(day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : inactiveColor,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: 2.2,
                    width: 52,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _scrollSelectedIntoView({bool animate = true}) {
    if (!mounted || widget.days.isEmpty || !_scrollController.hasClients) {
      return;
    }

    final selectedKey = _dayKeys[_dayId(widget.selectedDay)];
    final selectedContext = selectedKey?.currentContext;
    if (selectedContext == null) {
      return;
    }

    Scrollable.ensureVisible(
      selectedContext,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 230) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  GlobalKey _keyForDay(DateTime day) {
    final id = _dayId(day);
    return _dayKeys.putIfAbsent(id, () => GlobalKey());
  }

  String _dayId(DateTime day) {
    return '${day.year}-${day.month}-${day.day}';
  }

  bool _sameDayList(List<DateTime> a, List<DateTime> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (!_isSameDay(a[index], b[index])) {
        return false;
      }
    }
    return true;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _labelForDay(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(day.year, day.month, day.day);
    final delta = target.difference(today).inDays;

    if (delta == 0) {
      return 'Today';
    }
    if (delta == -1) {
      return 'Yesterday';
    }
    if (delta == 1) {
      return 'Tomorrow';
    }

    return DateFormat('EEE d MMM').format(day);
  }
}

class _CompetitionSection {
  const _CompetitionSection({
    required this.competitionId,
    required this.competitionName,
    required this.matches,
  });

  final String competitionId;
  final String competitionName;
  final List<HomeMatchView> matches;
}

class _FixtureGroupCard extends StatelessWidget {
  const _FixtureGroupCard({
    required this.title,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.children,
    this.badge,
    this.leadingIcon,
    this.onTapHeader,
  });

  final String title;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final List<Widget> children;
  final Widget? badge;
  final IconData? leadingIcon;
  final VoidCallback? onTapHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTapHeader,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  if (badge != null) ...[
                    badge!,
                    const SizedBox(width: 8),
                  ] else if (leadingIcon != null) ...[
                    Icon(leadingIcon, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleCollapse,
                    icon: Icon(
                      collapsed
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed) ...[
            const Divider(height: 1),
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                Divider(
                  height: 1,
                  indent: 40,
                  endIndent: 12,
                  color: scheme.outline.withValues(alpha: 0.35),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FixtureRow extends StatelessWidget {
  const _FixtureRow({required this.fixture, required this.resolver});

  final HomeMatchView fixture;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final score = MatchDisplayFormatter.scoreDisplay(
      status: fixture.match.status,
      kickoffUtc: fixture.match.kickoffUtc,
      homeScore: fixture.match.homeScore,
      awayScore: fixture.match.awayScore,
    );

    return InkWell(
      onTap: () => context.openMatchDetail(fixture.match.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            _StatusChip(
              label: _statusLabel(
                fixture.match.status,
                fixture.match.kickoffUtc,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _TeamInline(
                      teamId: fixture.match.homeTeamId,
                      teamName: fixture.homeTeamName,
                      resolver: resolver,
                      alignEnd: true,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      score.centerLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TeamInline(
                      teamId: fixture.match.awayTeamId,
                      teamName: fixture.awayTeamName,
                      resolver: resolver,
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

  String _statusLabel(String status, DateTime kickoffUtc) {
    final lower = status.toLowerCase();
    final lifecycle = MatchDisplayFormatter.lifecycle(
      status: status,
      kickoffUtc: kickoffUtc,
    );
    if (lower.contains('pen')) {
      return 'Pen';
    }
    if (lifecycle == MatchLifecycle.live) {
      return 'LIVE';
    }
    if (lifecycle == MatchLifecycle.upcoming) {
      return DateFormat('HH:mm').format(kickoffUtc.toLocal());
    }
    return 'FT';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 9.5,
        ),
      ),
    );
  }
}

class _TeamInline extends StatelessWidget {
  const _TeamInline({
    required this.teamId,
    required this.teamName,
    required this.resolver,
    this.alignEnd = false,
  });

  final String teamId;
  final String teamName;
  final LocalAssetResolver resolver;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final teamBadge = TeamBadge(
      teamId: teamId,
      teamName: teamName,
      resolver: resolver,
      source: 'home.fixture-row',
      size: 20,
    );
    final name = Expanded(
      child: Text(
        TeamDisplayNameFormatter.compactMatchName(teamName),
        maxLines: 2,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );

    if (alignEnd) {
      return Row(children: [name, const SizedBox(width: 6), teamBadge]);
    }

    return Row(children: [teamBadge, const SizedBox(width: 6), name]);
  }
}
