import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/leagues/domain/league_ordering.dart';
import 'package:eri_sports/features/leagues/presentation/leagues_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LeaguesScreen extends ConsumerStatefulWidget {
  const LeaguesScreen({super.key});

  @override
  ConsumerState<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends ConsumerState<LeaguesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final resolver = ref.read(appServicesProvider).assetResolver;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: leaguesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) =>
                const Center(child: Text('Unable to load local competitions.')),
        data: (leagues) {
          final filtered = _applySearch(leagues);
          final grouped = _groupByCategory(filtered);

          if (filtered.isEmpty) {
            return const Center(child: Text('No competitions imported yet.'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Leagues',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Find leagues',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.7),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: scheme.primary, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final category in LeagueCategory.values)
                if ((grouped[category] ?? const []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LeagueSection(
                      title: leagueCategoryLabel(category),
                      leagues: grouped[category]!,
                      resolver: resolver,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Map<LeagueCategory, List<CompetitionRow>> _groupByCategory(
    List<CompetitionRow> leagues,
  ) {
    final grouped = {
      for (final category in LeagueCategory.values)
        category: <CompetitionRow>[],
    };

    for (final league in leagues) {
      grouped[leagueCategoryFor(league)]!.add(league);
    }

    return grouped;
  }

  List<CompetitionRow> _applySearch(List<CompetitionRow> leagues) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return leagues;
    }

    return leagues
        .where(
          (league) =>
              league.name.toLowerCase().contains(query) ||
              (league.country?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);
  }
}

class _LeagueTile extends StatelessWidget {
  const _LeagueTile({
    required this.leagueId,
    required this.name,
    required this.resolver,
  });

  final String leagueId;
  final String name;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final virtualEntry = isVirtualLeagueId(leagueId);

    return InkWell(
      onTap: () {
        if (virtualEntry) {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (sheetContext) {
              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This competition is listed, but local league detail data is not imported yet. You can sync offline files now and reopen this league.',
                        style: TextStyle(
                          color: Color(0xFF5E6572),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Close'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              context.push('/sync');
                            },
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('Open Sync'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
          return;
        }

        context.push('/league/$leagueId');
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            EntityBadge(
              entityId: leagueId,
              type: SportsAssetType.leagues,
              resolver: resolver,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                virtualEntry ? '$name (coming soon)' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueSection extends StatelessWidget {
  const _LeagueSection({
    required this.title,
    required this.leagues,
    required this.resolver,
  });

  final String title;
  final List<CompetitionRow> leagues;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.65)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          ...List.generate(leagues.length, (index) {
            final league = leagues[index];
            return Column(
              children: [
                _LeagueTile(
                  leagueId: league.id,
                  name: league.name,
                  resolver: resolver,
                ),
                if (index != leagues.length - 1)
                  Divider(
                    height: 1,
                    indent: 46,
                    endIndent: 12,
                    color: scheme.outline.withValues(alpha: 0.35),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
