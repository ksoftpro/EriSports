import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/player_stats/presentation/player_stats_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlayerStatsScreen extends ConsumerStatefulWidget {
  const PlayerStatsScreen({
    this.initialCompetitionId,
    this.initialStatType,
    super.key,
  });

  final String? initialCompetitionId;
  final String? initialStatType;

  @override
  ConsumerState<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends ConsumerState<PlayerStatsScreen> {
  String? _selectedCompetitionId;
  String? _selectedStatType;

  @override
  Widget build(BuildContext context) {
    final competitionsAsync = ref.watch(topStatsCompetitionsProvider);
    final resolver = ref.read(appServicesProvider).assetResolver;

    return Scaffold(
      appBar: AppBar(title: const Text('Player Statistics')),
      body: competitionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) => const Center(
              child: Text('Unable to load local player statistics.'),
            ),
        data: (competitions) {
          if (competitions.isEmpty) {
            return _EmptyStatsState(
              message:
                  'No player leaderboard data found. Import local stats files and try again.',
            );
          }

          final competitionId = _resolveCompetitionId(competitions);
          if (competitionId == null) {
            return const _EmptyStatsState(
              message: 'No competition selection available.',
            );
          }

          final selectedCompetition = competitions.firstWhere(
            (item) => item.competitionId == competitionId,
          );
          final categoriesAsync = ref.watch(
            topStatCategoriesProvider(competitionId),
          );

          return Column(
            children: [
              _TopPanel(
                title: selectedCompetition.competitionName,
                competitions: competitions,
                selectedCompetitionId: competitionId,
                onSelectCompetition: (value) {
                  setState(() {
                    _selectedCompetitionId = value;
                    _selectedStatType = null;
                  });
                },
              ),
              Expanded(
                child: categoriesAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, stackTrace) => const Center(
                        child: Text('Unable to load stat categories.'),
                      ),
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const _EmptyStatsState(
                        message:
                            'No statistic categories available for this league.',
                      );
                    }

                    final statType = _resolveStatType(categories);
                    if (statType == null) {
                      return const _EmptyStatsState(
                        message:
                            'Select a category to show leaderboard entries.',
                      );
                    }

                    final leaderboardAsync = ref.watch(
                      topPlayersLeaderboardProvider(
                        TopPlayersQuery(
                          competitionId: competitionId,
                          statType: statType,
                        ),
                      ),
                    );

                    return Column(
                      children: [
                        _CategoryStrip(
                          categories: categories,
                          selectedStatType: statType,
                          onSelectCategory: (value) {
                            setState(() {
                              _selectedStatType = value;
                            });
                          },
                        ),
                        Expanded(
                          child: leaderboardAsync.when(
                            loading:
                                () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            error:
                                (error, stackTrace) => const Center(
                                  child: Text(
                                    'Unable to load leaderboard rows.',
                                  ),
                                ),
                            data: (rows) {
                              if (rows.isEmpty) {
                                return const _EmptyStatsState(
                                  message:
                                      'No player entries for this category in local data.',
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  14,
                                ),
                                itemCount: rows.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = rows[index];
                                  return _LeaderboardRow(
                                    entry: item,
                                    resolver: resolver,
                                    statType: statType,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
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

  String? _resolveCompetitionId(List<TopStatsCompetitionView> competitions) {
    final available = competitions.map((item) => item.competitionId).toSet();
    if (_selectedCompetitionId != null &&
        available.contains(_selectedCompetitionId)) {
      return _selectedCompetitionId;
    }

    if (widget.initialCompetitionId != null &&
        available.contains(widget.initialCompetitionId)) {
      return widget.initialCompetitionId;
    }

    return competitions.first.competitionId;
  }

  String? _resolveStatType(List<TopStatCategoryView> categories) {
    final available = categories.map((item) => item.statType).toSet();
    if (_selectedStatType != null && available.contains(_selectedStatType)) {
      return _selectedStatType;
    }

    if (widget.initialStatType != null &&
        available.contains(widget.initialStatType)) {
      return widget.initialStatType;
    }

    return categories.first.statType;
  }
}

class _TopPanel extends StatelessWidget {
  const _TopPanel({
    required this.title,
    required this.competitions,
    required this.selectedCompetitionId,
    required this.onSelectCompetition,
  });

  final String title;
  final List<TopStatsCompetitionView> competitions;
  final String selectedCompetitionId;
  final ValueChanged<String> onSelectCompetition;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      constraints: const BoxConstraints(minHeight: 104),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.65),
        ),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Players', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: competitions
                  .map((competition) {
                    final isSelected =
                        competition.competitionId == selectedCompetitionId;
                    final scheme = Theme.of(context).colorScheme;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(competition.competitionName),
                        selected: isSelected,
                        selectedColor: scheme.primary,
                        backgroundColor: Theme.of(context).cardColor,
                        side: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.72),
                        ),
                        labelStyle: TextStyle(
                          color:
                              isSelected ? scheme.onPrimary : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected:
                            (_) =>
                                onSelectCompetition(competition.competitionId),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedStatType,
    required this.onSelectCategory,
  });

  final List<TopStatCategoryView> categories;
  final String selectedStatType;
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Categories',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.82),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories
                  .map((category) {
                    final isSelected = category.statType == selectedStatType;
                    final scheme = Theme.of(context).colorScheme;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          '${statTypeLabel(category.statType)} (${category.entryCount})',
                        ),
                        selected: isSelected,
                        selectedColor: scheme.primary,
                        backgroundColor: Theme.of(context).cardColor,
                        side: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.72),
                        ),
                        labelStyle: TextStyle(
                          color:
                              isSelected ? scheme.onPrimary : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => onSelectCategory(category.statType),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.resolver,
    required this.statType,
  });

  final TopPlayerLeaderboardEntryView entry;
  final LocalAssetResolver resolver;
  final String statType;

  @override
  Widget build(BuildContext context) {
    final teamId = entry.stat.teamId;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/player/${entry.stat.playerId}'),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.65),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              _RankPill(rank: entry.stat.rank),
              const SizedBox(width: 10),
              EntityBadge(
                entityId: entry.stat.playerId,
                type: SportsAssetType.players,
                resolver: resolver,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.stat.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (teamId != null) ...[
                          GestureDetector(
                            onTap: () => context.push('/team/$teamId'),
                            child: EntityBadge(
                              entityId: teamId,
                              entityName: entry.teamName,
                              type: SportsAssetType.teams,
                              resolver: resolver,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            entry.teamName ?? 'Unknown Team',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    compactNumber(entry.stat.statValue),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    statTypeLabel(statType),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.82),
                    ),
                  ),
                  if (entry.stat.subStatValue != null)
                    Text(
                      '+${compactNumber(entry.stat.subStatValue!)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (rank) {
      1 => const Color(0xFFF5B93D),
      2 => const Color(0xFFA8B0BB),
      3 => const Color(0xFFBD7F44),
      _ => scheme.secondary,
    };

    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: rank <= 3 ? Colors.black : scheme.onSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyStatsState extends StatelessWidget {
  const _EmptyStatsState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.82),
          ),
        ),
      ),
    );
  }
}
