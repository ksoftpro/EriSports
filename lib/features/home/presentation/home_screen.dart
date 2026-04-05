import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/features/home/presentation/home_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/match_card_compact.dart';
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

  @override
  Widget build(BuildContext context) {
    final importReport = ref.watch(startupImportReportProvider);
    final homeFeed = ref.watch(homeFeedProvider);
    final days = _windowDays();
    final effectiveSelectedDay = days.any((item) => _isSameDay(item, _selectedDay))
        ? _selectedDay
        : days[1];

    return SafeArea(
      child: homeFeed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'Failed to load local match feed.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        data: (state) {
          final assetResolver = ref.read(appServicesProvider).assetResolver;
          final dayMatches = state.all
              .where((item) => _isSameDay(item.match.kickoffUtc.toLocal(), effectiveSelectedDay))
              .toList(growable: false)
            ..sort((a, b) => a.match.kickoffUtc.compareTo(b.match.kickoffUtc));
          final grouped = _groupByCompetition(
            dayMatches,
            state.competitionNamesById,
          );

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Matches',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live scores and fixtures from your offline feed',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
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
              ),
              SliverToBoxAdapter(
                child: _DateStrip(
                  days: days,
                  selectedDay: effectiveSelectedDay,
                  onSelect: (day) {
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ImportStatusPanel(report: importReport),
                ),
              ),
              if (state.followed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      'Following',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                SliverList.list(
                  children: state.followed
                      .take(4)
                      .map((item) => _buildMatchCard(context, item, assetResolver))
                      .toList(growable: false),
                ),
              ],
              if (grouped.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    child: Text(
                      'No fixtures for ${DateFormat('EEE, MMM d').format(effectiveSelectedDay)} in loaded data.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              for (final section in grouped) ...[
                SliverToBoxAdapter(
                  child: _CompetitionHeader(
                    competitionId: section.competitionId,
                    competitionName: section.competitionName,
                    resolver: assetResolver,
                  ),
                ),
                SliverList.list(
                  children: section.matches
                      .map((item) => _buildMatchCard(context, item, assetResolver))
                      .toList(growable: false),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    HomeMatchView item,
    LocalAssetResolver assetResolver,
  ) {
    final now = DateTime.now().toUtc();
    final lowerStatus = item.match.status.toLowerCase();
    final isLive = lowerStatus == 'live' ||
        lowerStatus == 'inplay' ||
        lowerStatus == 'in_play' ||
        lowerStatus == 'playing' ||
        lowerStatus == 'ht';

    final isFuture = item.match.kickoffUtc.isAfter(now);
    final timeText = isLive
        ? 'LIVE'
        : DateFormat('HH:mm').format(item.match.kickoffUtc.toLocal());
    final statusLabel = isLive
        ? item.match.status.toUpperCase()
        : (isFuture ? 'TODAY' : 'FT');

    return MatchCardCompact(
      status: statusLabel,
      timeOrMinute: timeText,
      homeTeam: item.homeTeamName,
      awayTeam: item.awayTeamName,
      homeTeamId: item.match.homeTeamId,
      awayTeamId: item.match.awayTeamId,
      assetResolver: assetResolver,
      onTap: () => context.push('/match/${item.match.id}'),
      homeScore: item.match.homeScore,
      awayScore: item.match.awayScore,
    );
  }

  List<DateTime> _windowDays() {
    final anchor = _dayKey(DateTime.now());
    return List<DateTime>.generate(
      6,
      (index) => anchor.add(Duration(days: index - 1)),
      growable: false,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime _dayKey(DateTime source) {
    return DateTime(source.year, source.month, source.day);
  }

  List<_CompetitionSection> _groupByCompetition(
    List<HomeMatchView> matches,
    Map<String, String> competitionNames,
  ) {
    final grouped = <String, List<HomeMatchView>>{};
    for (final item in matches) {
      grouped.putIfAbsent(item.match.competitionId, () => []).add(item);
    }

    final sections = grouped.entries
        .map(
          (entry) => _CompetitionSection(
            competitionId: entry.key,
            competitionName: competitionNames[entry.key] ?? 'League',
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

class _ImportStatusPanel extends StatelessWidget {
  const _ImportStatusPanel({required this.report});

  final ImportRunReport report;

  @override
  Widget build(BuildContext context) {
    final isSuccess = report.status == 'success';
    final isPartial = report.status == 'partial_success';
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.65)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess
                    ? Icons.check_circle
                    : isPartial
                        ? Icons.warning_amber
                        : Icons.error,
                size: 16,
                color: isSuccess
                  ? Colors.green
                    : isPartial
                    ? Colors.orange
                    : scheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Local data import: ${report.status}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Source: daylySport',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color:
                      Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.82),
                ),
          ),
          Text(
            'Discovered JSON files: ${report.jsonFileCount}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color:
                      Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.82),
                ),
          ),
        ],
      ),
    );
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

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.days,
    required this.selectedDay,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: days
              .map(
                (day) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${DateFormat('EEE').format(day)} ${DateFormat('d').format(day)}',
                    ),
                    selected: _HomeScreenState._isSameDay(day, selectedDay),
                    selectedColor: scheme.primary,
                    backgroundColor: Theme.of(context).cardColor,
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
                    labelStyle: TextStyle(
                      color: _HomeScreenState._isSameDay(day, selectedDay)
                          ? scheme.onPrimary
                          : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => onSelect(day),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _CompetitionHeader extends StatelessWidget {
  const _CompetitionHeader({
    required this.competitionId,
    required this.competitionName,
    required this.resolver,
  });

  final String competitionId;
  final String competitionName;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/league/$competitionId'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(
          children: [
            EntityBadge(
              entityId: competitionId,
              type: SportsAssetType.leagues,
              resolver: resolver,
              size: 20,
              isCircular: false,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                competitionName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}