import 'package:eri_sports/features/bookmarks/presentation/bookmarks_providers.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/shared/providers/asset_resolver_provider.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _isEditing = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(followingDashboardProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
            child: Text(_isEditing ? 'Done' : 'Edit'),
          ),
          IconButton(
            onPressed: _showAddSheet,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Teams'),
            Tab(text: 'Players'),
          ],
        ),
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Text('Unable to load following data.'),
        ),
        data: (state) {
          final resolver = ref.watch(assetResolverProvider);

          return TabBarView(
            controller: _tabs,
            children: [
              state.teams.isEmpty
                  ? const _EmptyFollowingState(label: 'No followed teams yet.')
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      itemCount: state.teams.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.96,
                      ),
                      itemBuilder: (context, index) {
                        final item = state.teams[index];
                        final bg = _teamCardBackground(index, scheme.brightness);

                        return InkWell(
                          onTap: () => context.push('/team/${item.team.id}'),
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      EntityBadge(
                                        entityId: item.team.id,
                                        entityName: item.team.name,
                                        type: SportsAssetType.teams,
                                        resolver: resolver,
                                        size: 28,
                                      ),
                                      const Spacer(),
                                      if (_isEditing)
                                        _RemoveChip(
                                          onTap: () {
                                            ref
                                                .read(
                                                  followingSelectionProvider
                                                      .notifier,
                                                )
                                                .toggleTeam(item.team.id);
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.team.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: _cardTextColor(
                                            bg,
                                            scheme.brightness,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.competitionName ?? 'Competition',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: _cardTextColor(
                                            bg,
                                            scheme.brightness,
                                          ).withValues(alpha: 0.84),
                                        ),
                                  ),
                                  const Spacer(),
                                  if (item.nextMatch != null)
                                    Text(
                                      '${DateFormat('EEE HH:mm').format(item.nextMatch!.match.kickoffUtc.toLocal())}\nvs ${item.nextOpponentName ?? 'TBD'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: _cardTextColor(
                                              bg,
                                              scheme.brightness,
                                            ),
                                          ),
                                    )
                                  else
                                    Text(
                                      'No upcoming fixture',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: _cardTextColor(
                                              bg,
                                              scheme.brightness,
                                            ),
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              state.players.isEmpty
                  ? const _EmptyFollowingState(label: 'No followed players yet.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                      itemCount: state.players.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = state.players[index];
                        return InkWell(
                          onTap: () => context.push('/player/${item.player.id}'),
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.outline.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              children: [
                                EntityBadge(
                                  entityId: item.player.id,
                                  type: SportsAssetType.players,
                                  resolver: resolver,
                                  size: 34,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.player.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (item.team != null) ...[
                                            EntityBadge(
                                              entityId: item.team!.id,
                                              entityName: item.team!.name,
                                              type: SportsAssetType.teams,
                                              resolver: resolver,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 5),
                                          ],
                                          Expanded(
                                            child: Text(
                                              item.team?.name ?? 'No team',
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
                                if (_isEditing)
                                  _RemoveChip(
                                    onTap: () {
                                      ref
                                          .read(
                                            followingSelectionProvider.notifier,
                                          )
                                          .togglePlayer(item.player.id);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddSheet() async {
    final dashboard = await ref.read(followingDashboardProvider.future);
    if (!mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _AddFollowingSheet(
          teams: dashboard.availableTeams,
          players: dashboard.availablePlayers,
        );
      },
    );
  }

  Color _teamCardBackground(int index, Brightness brightness) {
    const lightPalette = [
      Color(0xFFE7F0FF),
      Color(0xFFEAF8EC),
      Color(0xFFFFF1E2),
      Color(0xFFF0EAFD),
    ];
    const darkPalette = [
      Color(0xFF1E355C),
      Color(0xFF1D3A2E),
      Color(0xFF4A3520),
      Color(0xFF3D2D56),
    ];

    final palette = brightness == Brightness.dark ? darkPalette : lightPalette;
    return palette[index % palette.length];
  }

  Color _cardTextColor(Color background, Brightness brightness) {
    return brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A2336);
  }
}

class _AddFollowingSheet extends ConsumerWidget {
  const _AddFollowingSheet({required this.teams, required this.players});

  final List<TeamRow> teams;
  final List<PlayerRow> players;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              const TabBar(tabs: [Tab(text: 'Teams'), Tab(text: 'Players')]),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView.builder(
                      itemCount: teams.length,
                      itemBuilder: (context, index) {
                        final team = teams[index];
                        final selected = ref
                            .watch(followingSelectionProvider)
                            .teamIds
                            .contains(team.id);
                        return ListTile(
                          dense: true,
                          title: Text(team.name),
                          trailing: Checkbox(
                            value: selected,
                            onChanged: (_) {
                              ref
                                  .read(followingSelectionProvider.notifier)
                                  .toggleTeam(team.id);
                            },
                          ),
                        );
                      },
                    ),
                    ListView.builder(
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final player = players[index];
                        final selected = ref
                            .watch(followingSelectionProvider)
                            .playerIds
                            .contains(player.id);
                        return ListTile(
                          dense: true,
                          title: Text(player.name),
                          trailing: Checkbox(
                            value: selected,
                            onChanged: (_) {
                              ref
                                  .read(followingSelectionProvider.notifier)
                                  .togglePlayer(player.id);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveChip extends StatelessWidget {
  const _RemoveChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Remove',
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
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
