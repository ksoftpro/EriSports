import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/team/presentation/team_providers.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({required this.teamId, super.key});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailProvider(teamId));

    return Scaffold(
      appBar: AppBar(),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) =>
                const Center(child: Text('Unable to load local team data.')),
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
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    TeamBadge(
                      teamId: state.team.id,
                      teamName: state.team.name,
                      resolver: resolver,
                      source: 'team.header',
                      size: 96,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.team.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (state.team.shortName != null &&
                        state.team.shortName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          state.team.shortName!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _metaChip(
                          context,
                          state.competition?.name ?? 'No competition',
                        ),
                        _metaChip(context, '${state.players.length} players'),
                        _metaChip(context, '${state.matches.length} matches'),
                      ],
                    ),
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
                        'Team information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _metaRow('Team ID', state.team.id),
                      _metaRow(
                        'Competition',
                        state.competition?.name ?? 'Not linked',
                      ),
                      _metaRow('Players', state.players.length.toString()),
                      _metaRow('Matches', state.matches.length.toString()),
                    ],
                  ),
                ),
              ),
              if (state.availableSeasonLabels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available seasons',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final season in state.availableSeasonLabels)
                              Chip(label: Text(season)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (state.rawTabs.isNotEmpty) ...[
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Imported tabs',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tab in state.rawTabs)
                              Chip(label: Text(tab.toUpperCase())),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
      child: Row(children: [Expanded(child: Text(label)), Text(value)]),
    );
  }
}
