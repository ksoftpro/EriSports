import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/navigation/detail_navigation.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/home/presentation/home_providers.dart';
import 'package:eri_sports/shared/formatters/match_display_formatter.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final homeFeed = ref.watch(homeFeedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: homeFeed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load calendar data.')),
        data: (state) {
          final allDays = _allMatchDays(state.all);
          final selected = _resolveSelectedDay(allDays);
          final dayMatches = state.all
              .where((item) => _isSameDay(item.match.kickoffUtc.toLocal(), selected))
              .toList(growable: false)
            ..sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));

          final firstDate =
              allDays.isNotEmpty ? allDays.first : _dayKey(DateTime.now().subtract(const Duration(days: 365)));
          final lastDate =
              allDays.isNotEmpty ? allDays.last : _dayKey(DateTime.now().add(const Duration(days: 365)));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: selected,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    currentDate: DateTime.now(),
                    onDateChanged: (value) {
                      final picked = _dayKey(value);
                      final dateParam = DateFormat('yyyy-MM-dd').format(picked);
                      final focusParam =
                          DateTime.now().microsecondsSinceEpoch.toString();
                      context.go('/home?date=$dateParam&focus=$focusParam');
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                child: Row(
                  children: [
                    Text(
                      DateFormat('EEEE, d MMM y').format(selected),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        final target = _todayOrClosest(allDays);
                        setState(() {
                          _selectedDay = target;
                        });
                      },
                      icon: const Icon(Icons.today_outlined, size: 18),
                      label: const Text('Today'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: dayMatches.isEmpty
                    ? const Center(
                        child: Text('No matches on the selected date.'),
                      )
                    : _CalendarMatchList(
                        matches: dayMatches,
                        competitionNamesById: state.competitionNamesById,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime _resolveSelectedDay(List<DateTime> allDays) {
    final existing = _selectedDay;
    if (existing != null) {
      return existing;
    }
    final selected = _todayOrClosest(allDays);
    _selectedDay = selected;
    return selected;
  }

  DateTime _todayOrClosest(List<DateTime> allDays) {
    final today = _dayKey(DateTime.now());
    if (allDays.isEmpty) {
      return today;
    }

    for (final day in allDays) {
      if (_isSameDay(day, today)) {
        return day;
      }
    }

    for (final day in allDays) {
      if (!day.isBefore(today)) {
        return day;
      }
    }

    return allDays.last;
  }

  List<DateTime> _allMatchDays(List<HomeMatchView> matches) {
    final unique = <DateTime>{
      for (final item in matches) _dayKey(item.match.kickoffUtc.toLocal()),
    };
    final days = unique.toList(growable: false)..sort((a, b) => a.compareTo(b));
    return days;
  }

  DateTime _dayKey(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CalendarMatchList extends ConsumerWidget {
  const _CalendarMatchList({
    required this.matches,
    required this.competitionNamesById,
  });

  final List<HomeMatchView> matches;
  final Map<String, String> competitionNamesById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.read(appServicesProvider).assetResolver;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final fixture = matches[index];
        final score = MatchDisplayFormatter.scoreDisplay(
          status: fixture.match.status,
          kickoffUtc: fixture.match.kickoffUtc,
          homeScore: fixture.match.homeScore,
          awayScore: fixture.match.awayScore,
        );

        return InkWell(
          onTap: () => context.openMatchDetail(fixture.match.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  competitionNamesById[fixture.match.competitionId] ??
                      'Competition',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          TeamBadge(
                            teamId: fixture.match.homeTeamId,
                            teamName: fixture.homeTeamName,
                            resolver: resolver,
                            source: 'calendar.match',
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fixture.homeTeamName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      score.centerLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              fixture.awayTeamName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TeamBadge(
                            teamId: fixture.match.awayTeamId,
                            teamName: fixture.awayTeamName,
                            resolver: resolver,
                            source: 'calendar.match',
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEE HH:mm').format(fixture.match.kickoffUtc.toLocal()),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
