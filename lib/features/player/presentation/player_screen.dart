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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Align(
                alignment: Alignment.center,
                child: EntityBadge(
                  entityId: state.player.id,
                  type: SportsAssetType.players,
                  resolver: resolver,
                  size: 92,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  state.player.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              if (state.team != null)
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.push('/team/${state.team!.id}'),
                    icon: EntityBadge(
                      entityId: state.team!.id,
                      type: SportsAssetType.teams,
                      resolver: resolver,
                      size: 20,
                    ),
                    label: Text(state.team!.name),
                  ),
                ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
            ],
          );
        },
      ),
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