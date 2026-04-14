import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/player/presentation/player_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({required this.playerId, super.key});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerDetailProvider(playerId));

    return Scaffold(
      appBar: AppBar(),
      body: playerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return _buildUnavailableState(
            context,
            requestedPlayerId: playerId,
            reason: 'Unable to load local player data. ${error.toString().trim()}',
            logs: const [],
          );
        },
        data: (state) {
          final player = state.player;
          if (player == null) {
            return _buildUnavailableState(
              context,
              requestedPlayerId: state.requestedPlayerId,
              resolvedPlayerId: state.resolvedPlayerId,
              reason:
                  'Player details unavailable in local daylysport JSON for this player id.',
              logs: state.debugLogs,
            );
          }

          final resolver = ref.read(appServicesProvider).assetResolver;
          final scheme = Theme.of(context).colorScheme;
          final infoRows = <({String label, String value})>[
            (label: 'Position', value: player.position ?? 'Unknown'),
            (label: 'Jersey', value: player.jerseyNumber?.toString() ?? '-'),
            (label: 'Player ID', value: player.id),
          ];

          if (state.team != null) {
            infoRows.add((label: 'Team', value: state.team!.name));
          }
          if (state.competition != null) {
            infoRows.add((label: 'Competition', value: state.competition!.name));
          }
          if (state.profile.nationality != null) {
            infoRows.add((label: 'Nationality', value: state.profile.nationality!));
          }
          if (state.profile.country != null) {
            infoRows.add((label: 'Country', value: state.profile.country!));
          }
          if (state.profile.birthDate != null) {
            infoRows.add((label: 'Birth date', value: state.profile.birthDate!));
          }
          if (state.profile.age != null) {
            infoRows.add((label: 'Age', value: state.profile.age!));
          }
          if (state.profile.height != null) {
            infoRows.add((label: 'Height', value: state.profile.height!));
          }
          if (state.profile.weight != null) {
            infoRows.add((label: 'Weight', value: state.profile.weight!));
          }
          if (state.profile.preferredFoot != null) {
            infoRows.add((label: 'Preferred foot', value: state.profile.preferredFoot!));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.2),
                      scheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    EntityBadge(
                      entityId: player.id,
                      entityName: player.name,
                      type: SportsAssetType.players,
                      resolver: resolver,
                      size: 96,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      player.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _metaChip(
                          context,
                          player.position ?? 'Unknown Position',
                        ),
                        _metaChip(
                          context,
                          player.jerseyNumber == null
                              ? 'No jersey'
                              : 'No. ${player.jerseyNumber}',
                        ),
                        if (state.profile.nationality != null)
                          _metaChip(context, state.profile.nationality!),
                      ],
                    ),
                    if (state.team != null) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed:
                            () => context.push('/team/${state.team!.id}'),
                        icon: TeamBadge(
                          teamId: state.team!.id,
                          teamName: state.team!.name,
                          resolver: resolver,
                          source: 'player.team-link',
                          size: 20,
                        ),
                        label: Text(state.team!.name),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Player information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...infoRows.map(
                        (row) => _metaRow(row.label, row.value),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.profile.stats.isNotEmpty) ...[
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stats summary',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...state.profile.stats.entries.map(
                          (entry) => _metaRow(entry.key, entry.value),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (state.profile.summary != null &&
                  state.profile.summary!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(state.profile.summary!),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (state.team != null)
                OutlinedButton.icon(
                  onPressed: () => context.push('/team/${state.team!.id}'),
                  icon: const Icon(Icons.shield),
                  label: const Text('Open team page'),
                ),
              if (state.team?.competitionId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.icon(
                    onPressed:
                        () => context.push(
                          '/player-stats?competitionId=${state.team!.competitionId}',
                        ),
                    icon: const Icon(Icons.leaderboard),
                    label: const Text('Open league leaderboards'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnavailableState(
    BuildContext context, {
    required String requestedPlayerId,
    String? resolvedPlayerId,
    required String reason,
    required List<String> logs,
  }) {
    final visibleLogs = logs.take(8).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player details unavailable',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(reason),
                const SizedBox(height: 10),
                _metaRow('Requested player id', requestedPlayerId),
                if (resolvedPlayerId != null)
                  _metaRow('Resolved player id', resolvedPlayerId),
              ],
            ),
          ),
        ),
        if (visibleLogs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnostic logs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final line in visibleLogs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _metaChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Expanded(child: Text(label)), Text(value)]),
    );
  }
}
