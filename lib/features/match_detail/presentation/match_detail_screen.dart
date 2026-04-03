import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/theme/color_tokens.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/match_detail/presentation/match_detail_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({
    required this.matchId,
    super.key,
  });

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchDetailProvider(matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Match Detail')),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Text('Unable to load local match detail.'),
        ),
        data: (detail) {
          final resolver = ref.read(appServicesProvider).assetResolver;
          final kickoff = DateFormat(
            'EEE, dd MMM • HH:mm',
          ).format(detail.match.kickoffUtc.toLocal());

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              Center(
                child: Text(
                  detail.competitionName,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: AppColorTokens.textSecondary),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  kickoff,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _teamBlock(
                      context,
                      resolver,
                      detail.match.homeTeamId,
                      detail.homeTeamName,
                      onTap: () => context.push('/team/${detail.match.homeTeamId}'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '${detail.match.homeScore} - ${detail.match.awayScore}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Expanded(
                    child: _teamBlock(
                      context,
                      resolver,
                      detail.match.awayTeamId,
                      detail.awayTeamName,
                      onTap: () => context.push('/team/${detail.match.awayTeamId}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _meta('Status', detail.match.status.toUpperCase()),
                      _meta('Round', detail.match.roundLabel ?? '-'),
                      _meta('Match ID', detail.match.id),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'This match center is fully offline and rendered from local database content only.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _teamBlock(
    BuildContext context,
    LocalAssetResolver resolver,
    String teamId,
    String teamName, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          children: [
            EntityBadge(
              entityId: teamId,
              type: SportsAssetType.teams,
              resolver: resolver,
              size: 44,
            ),
            const SizedBox(height: 8),
            Text(
              teamName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}