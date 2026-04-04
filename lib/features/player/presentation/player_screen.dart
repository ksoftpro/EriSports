import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/player/presentation/player_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({
    required this.playerId,
    super.key,
  });

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerDetailProvider(playerId));

    return Scaffold(
      appBar: AppBar(),
      body: playerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Text('Unable to load local player data.'),
        ),
        data: (state) {
          final resolver = ref.read(appServicesProvider).assetResolver;
          final scheme = Theme.of(context).colorScheme;

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
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    EntityBadge(
                      entityId: state.player.id,
                      type: SportsAssetType.players,
                      resolver: resolver,
                      size: 96,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.player.name,
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
                          state.player.position ?? 'Unknown Position',
                        ),
                        _metaChip(
                          context,
                          state.player.jerseyNumber == null
                              ? 'No jersey'
                              : 'No. ${state.player.jerseyNumber}',
                        ),
                      ],
                    ),
                    if (state.team != null) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => context.push('/team/${state.team!.id}'),
                        icon: EntityBadge(
                          entityId: state.team!.id,
                          type: SportsAssetType.teams,
                          resolver: resolver,
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
                      _metaRow('Position', state.player.position ?? 'Unknown'),
                      _metaRow(
                        'Jersey',
                        state.player.jerseyNumber?.toString() ?? '-',
                      ),
                      _metaRow('Player ID', state.player.id),
                    ],
                  ),
                ),
              ),
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
                    onPressed: () => context.push(
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
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}