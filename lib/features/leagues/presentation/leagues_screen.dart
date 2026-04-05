import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
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
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.65)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Following',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                    ),
                    ...List.generate(filtered.length, (index) {
                      final league = filtered[index];
                      return Column(
                        children: [
                          _LeagueTile(
                            leagueId: league.id,
                            name: league.name,
                            resolver: resolver,
                          ),
                          if (index != filtered.length - 1)
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
              ),
            ],
          );
        },
      ),
    );
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
    return InkWell(
      onTap: () => context.push('/league/$leagueId'),
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
                name,
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
