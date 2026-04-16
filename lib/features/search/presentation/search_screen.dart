import 'dart:async';

import 'package:eri_sports/app/navigation/detail_navigation.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/search/presentation/search_providers.dart';
import 'package:eri_sports/shared/widgets/dense_section_header.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider(_query));
    final resolver = ref.read(appServicesProvider).assetResolver;

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Container(
        color: scheme.surface,
        child: ListView(
          padding: const EdgeInsets.only(top: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 150), () {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _query = value;
                    });
                  });
                },
                style: textTheme.bodyLarge,
                cursorColor: scheme.primary,
                decoration: InputDecoration(
                  hintText: 'Search teams, players, competitions',
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: scheme.outline,
                  ),
                  prefixIcon: Icon(Icons.search, color: scheme.primary),
                  filled: true,
                  fillColor: scheme.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.primary, width: 1.25),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_query.trim().isEmpty) ...[
              const DenseSectionHeader(title: 'Search Offline Data'),
              ListTile(
                dense: true,
                title: Text(
                  'Type to search teams, players and competitions.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                tileColor: scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ] else
              resultsAsync.when(
                loading:
                    () => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(color: scheme.primary),
                      ),
                    ),
                error:
                    (error, stackTrace) => ListTile(
                      dense: true,
                      title: Text(
                        'Unable to run local search.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                      tileColor: scheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                data: (results) {
                  if (results.teams.isEmpty &&
                      results.players.isEmpty &&
                      results.competitions.isEmpty) {
                    return ListTile(
                      dense: true,
                      title: Text(
                        'No local results found.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      tileColor: scheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      if (results.teams.isNotEmpty) ...[
                        const DenseSectionHeader(title: 'Teams'),
                        ...results.teams.map(
                          (team) => ListTile(
                            dense: true,
                            // Navigation to TeamScreen is disabled
                            onTap: null,
                            leading: TeamBadge(
                              teamId: team.id,
                              teamName: team.name,
                              resolver: resolver,
                              source: 'search.team-result',
                              size: 22,
                            ),
                            title: Text(
                              team.name,
                              style: textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            trailing: Icon(Icons.block, color: scheme.error),
                            tileColor: scheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                      if (results.players.isNotEmpty) ...[
                        const DenseSectionHeader(title: 'Players'),
                        ...results.players.map(
                          (player) => ListTile(
                            dense: true,
                            onTap: () => context.openPlayerDetail(player.id),
                            leading: EntityBadge(
                              entityId: player.id,
                              entityName: player.name,
                              type: SportsAssetType.players,
                              resolver: resolver,
                              size: 22,
                            ),
                            title: Text(
                              player.name,
                              style: textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              player.position ?? '',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: scheme.outline,
                            ),
                            tileColor: scheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                      if (results.competitions.isNotEmpty) ...[
                        const DenseSectionHeader(title: 'Competitions'),
                        ...results.competitions.map(
                          (competition) => ListTile(
                            dense: true,
                            onTap:
                                () => context.push('/league/${competition.id}'),
                            leading: EntityBadge(
                              entityId: competition.id,
                              type: SportsAssetType.leagues,
                              resolver: resolver,
                              size: 22,
                            ),
                            title: Text(
                              competition.name,
                              style: textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              competition.country ?? '',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: scheme.outline,
                            ),
                            tileColor: scheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
