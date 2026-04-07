import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/detail_navigation.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/home/presentation/home_providers.dart';
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
  DateTime _selectedDay = _dayKey(DateTime.now());
  bool _followingCollapsed = false;
  bool _hideAllCompetitions = false;
  final Set<String> _collapsedCompetitionIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final homeFeed = ref.watch(homeFeedProvider);
    final days = _windowDays();
    final effectiveDay =
        days.any((item) => _isSameDay(item, _selectedDay))
            ? _selectedDay
            : _dayKey(DateTime.now());

    return SafeArea(
      child: homeFeed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load matches.')),
        data: (state) {
          final resolver = ref.read(appServicesProvider).assetResolver;
          final dayMatches = state.all
              .where(
                (item) =>
                    _isSameDay(item.match.kickoffUtc.toLocal(), effectiveDay),
              )
              .toList(growable: false)
            ..sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));

          final sections = _groupByCompetition(
            dayMatches,
            state.competitionNamesById,
          );
          final followingMatches = state.followed
              .where(
                (item) =>
                    _isSameDay(item.match.kickoffUtc.toLocal(), effectiveDay),
              )
              .take(2)
              .toList(growable: false);

          return Column(
            children: [
              _TopBar(
                onOpenClock: () {
                  setState(() {
                    _selectedDay = _dayKey(DateTime.now());
                  });
                },
                onOpenCalendar: () => context.push('/leagues'),
                onOpenSearch: () => context.push('/search'),
                onOpenMore: () => context.push('/more'),
              ),
              _DayTabStrip(
                days: days,
                selectedDay: effectiveDay,
                onSelect: (day) {
                  setState(() {
                    _selectedDay = day;
                  });
                },
              ),
              Expanded(
                child: ListView(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 9,
                          ),
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
                          'No fixtures for ${DateFormat('EEE d MMM').format(effectiveDay)}.',
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
                            _collapsedCompetitionIds.contains(
                              section.competitionId,
                            ),
                        onToggleCollapse: () {
                          setState(() {
                            if (_collapsedCompetitionIds.contains(
                              section.competitionId,
                            )) {
                              _collapsedCompetitionIds.remove(
                                section.competitionId,
                              );
                            } else {
                              _collapsedCompetitionIds.add(
                                section.competitionId,
                              );
                            }
                          });
                        },
                        onTapHeader:
                            () => context.push(
                              '/league/${section.competitionId}',
                            ),
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<DateTime> _windowDays() {
    final now = _dayKey(DateTime.now());
    return List<DateTime>.generate(
      5,
      (index) => now.add(Duration(days: index - 2)),
      growable: false,
    );
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
      (a, b) => a.matches.first.match.kickoffUtc.compareTo(
        b.matches.first.match.kickoffUtc,
      ),
    );

    return sections;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onOpenClock,
    required this.onOpenCalendar,
    required this.onOpenSearch,
    required this.onOpenMore,
  });

  final VoidCallback onOpenClock;
  final VoidCallback onOpenCalendar;
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
            'FOTMOB',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Recents',
            onPressed: onOpenClock,
            icon: const Icon(Icons.access_time_rounded, size: 22),
          ),
          IconButton(
            tooltip: 'Calendar',
            onPressed: onOpenCalendar,
            icon: const Icon(Icons.calendar_month_outlined, size: 22),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: onOpenSearch,
            icon: const Icon(Icons.search, size: 23),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: onOpenMore,
            icon: const Icon(Icons.more_vert, size: 23),
          ),
        ],
      ),
    );
  }
}

class _DayTabStrip extends StatelessWidget {
  const _DayTabStrip({
    required this.days,
    required this.selectedDay,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: 0.66);

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: days
            .map(
              (day) => Expanded(
                child: InkWell(
                  onTap: () => onSelect(day),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _labelForDay(day),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color:
                              _isSameDay(day, selectedDay)
                                  ? Theme.of(context).colorScheme.onSurface
                                  : inactiveColor,
                          fontWeight:
                              _isSameDay(day, selectedDay)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        height: 2.4,
                        width: 54,
                        decoration: BoxDecoration(
                          color:
                              _isSameDay(day, selectedDay)
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
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
    final scoreText = '${fixture.match.homeScore} - ${fixture.match.awayScore}';

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
                      scoreText,
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
    if (lower == 'live' ||
        lower == 'inplay' ||
        lower == 'in_play' ||
        lower == 'playing') {
      return 'LIVE';
    }
    if (lower.contains('pen')) {
      return 'Pen';
    }

    final isFuture = kickoffUtc.isAfter(DateTime.now().toUtc());
    if (isFuture) {
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
