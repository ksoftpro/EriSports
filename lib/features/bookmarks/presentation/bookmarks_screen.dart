import 'package:eri_sports/app/navigation/detail_navigation.dart';
import 'package:eri_sports/features/bookmarks/presentation/bookmarks_providers.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/shared/providers/asset_resolver_provider.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(followingDashboardProvider);
    final resolver = ref.watch(assetResolverProvider);
    final selection = ref.watch(followingSelectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(followingDashboardProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Teams'), Tab(text: 'Players')],
        ),
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) =>
                const Center(child: Text('Unable to load following data.')),
        data: (state) {
          final normalizedQuery = _normalizeSearchKey(_query);
          final teams = _buildTeamsResults(
            teams: state.availableTeams,
            competitionNameByTeamId: state.competitionNameByTeamId,
            followedTeamIds: selection.teamIds,
            normalizedQuery: normalizedQuery,
          );
          final players = _buildPlayersResults(
            players: state.availablePlayers,
            teamNameById: state.teamNameById,
            followedPlayerIds: selection.playerIds,
            normalizedQuery: normalizedQuery,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search clubs across all leagues or players',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Following ${selection.teamIds.length} teams',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${selection.playerIds.length} players',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    teams.isEmpty
                        ? _EmptyFollowingState(
                            label: normalizedQuery.isEmpty
                                ? 'No teams available in local data.'
                              : 'No teams match "$_query".',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                            itemCount: teams.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final team = teams[index];
                              final isFollowed = selection.teamIds.contains(team.id);
                              final competitionName =
                                  state.competitionNameByTeamId[team.id] ??
                                  'Competition';

                              return Material(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => context.push('/team/${team.id}'),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      children: [
                                        TeamBadge(
                                          teamId: team.id,
                                          teamName: team.name,
                                          resolver: resolver,
                                          source: 'following.teams-search',
                                          size: 42,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                team.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                competitionName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.tonal(
                                          onPressed: () {
                                            ref
                                                .read(
                                                  followingSelectionProvider
                                                      .notifier,
                                                )
                                                .toggleTeam(team.id);
                                          },
                                          child: Text(
                                            isFollowed ? 'Following' : 'Follow',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    players.isEmpty
                        ? _EmptyFollowingState(
                            label: normalizedQuery.isEmpty
                                ? 'No players available in local data.'
                              : 'No players match "$_query".',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                            itemCount: players.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final player = players[index];
                              final isFollowed =
                                  selection.playerIds.contains(player.id);
                              final teamName = player.teamId == null
                                  ? 'No team'
                                  : state.teamNameById[player.teamId!] ?? 'No team';

                              return Material(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => context.openPlayerDetail(player.id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      children: [
                                        EntityBadge(
                                          entityId: player.id,
                                          entityName: player.name,
                                          type: SportsAssetType.players,
                                          resolver: resolver,
                                          size: 42,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                player.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  if (player.teamId != null) ...[
                                                    TeamBadge(
                                                      teamId: player.teamId!,
                                                      teamName: teamName,
                                                      resolver: resolver,
                                                      source:
                                                          'following.players-search',
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 5),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      teamName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.tonal(
                                          onPressed: () {
                                            ref
                                                .read(
                                                  followingSelectionProvider
                                                      .notifier,
                                                )
                                                .togglePlayer(player.id);
                                          },
                                          child: Text(
                                            isFollowed ? 'Following' : 'Follow',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyFollowingState extends StatelessWidget {
  const _EmptyFollowingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

List<TeamRow> _buildTeamsResults({
  required List<TeamRow> teams,
  required Map<String, String> competitionNameByTeamId,
  required Set<String> followedTeamIds,
  required String normalizedQuery,
}) {
  final filtered = teams.where((team) {
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final teamName = _normalizeSearchKey(team.name);
    final competitionName = _normalizeSearchKey(
      competitionNameByTeamId[team.id] ?? '',
    );
    return teamName.contains(normalizedQuery) ||
        competitionName.contains(normalizedQuery);
  }).toList(growable: false);

  filtered.sort((a, b) {
    final followedRankA = followedTeamIds.contains(a.id) ? 0 : 1;
    final followedRankB = followedTeamIds.contains(b.id) ? 0 : 1;
    if (followedRankA != followedRankB) {
      return followedRankA.compareTo(followedRankB);
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return filtered;
}

List<PlayerRow> _buildPlayersResults({
  required List<PlayerRow> players,
  required Map<String, String> teamNameById,
  required Set<String> followedPlayerIds,
  required String normalizedQuery,
}) {
  final filtered = players.where((player) {
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final playerName = _normalizeSearchKey(player.name);
    final teamName = _normalizeSearchKey(
      player.teamId == null ? '' : (teamNameById[player.teamId!] ?? ''),
    );
    return playerName.contains(normalizedQuery) || teamName.contains(normalizedQuery);
  }).toList(growable: false);

  filtered.sort((a, b) {
    final followedRankA = followedPlayerIds.contains(a.id) ? 0 : 1;
    final followedRankB = followedPlayerIds.contains(b.id) ? 0 : 1;
    if (followedRankA != followedRankB) {
      return followedRankA.compareTo(followedRankB);
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return filtered;
}

String _normalizeSearchKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
