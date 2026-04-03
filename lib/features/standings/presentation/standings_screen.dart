import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/theme/color_tokens.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/standings/presentation/standings_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StandingsScreen extends ConsumerWidget {
  const StandingsScreen({
    required this.competitionId,
    super.key,
  });

  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsProvider(competitionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Standings')),
      body: standingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Text('Unable to load local standings data.'),
        ),
        data: (state) {
          final resolver = ref.read(appServicesProvider).assetResolver;

          if (state.rows.isEmpty) {
            return const Center(
              child: Text('No standings available for this competition.'),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state.competitionName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const _StandingsHeader(),
              const Divider(height: 1, color: AppColorTokens.border),
              Expanded(
                child: ListView.separated(
                  itemCount: state.rows.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColorTokens.border),
                  itemBuilder: (context, index) {
                    final item = state.rows[index];
                    return _StandingsRow(
                      position: item.row.position,
                      teamId: item.teamId,
                      teamName: item.teamName,
                      played: item.row.played,
                      won: item.row.won,
                      draw: item.row.draw,
                      lost: item.row.lost,
                      goalDiff: item.row.goalDiff,
                      points: item.row.points,
                      resolver: resolver,
                      onTap: () => context.push('/team/${item.teamId}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StandingsHeader extends StatelessWidget {
  const _StandingsHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(color: AppColorTokens.textSecondary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('#', style: style)),
          const Expanded(child: Text('Team')),
          SizedBox(width: 30, child: Text('P', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 30, child: Text('W', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 30, child: Text('D', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 30, child: Text('L', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 36, child: Text('GD', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 36, child: Text('Pts', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _StandingsRow extends StatelessWidget {
  const _StandingsRow({
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalDiff,
    required this.points,
    required this.resolver,
    required this.onTap,
  });

  final int position;
  final String teamId;
  final String teamName;
  final int played;
  final int won;
  final int draw;
  final int lost;
  final int goalDiff;
  final int points;
  final LocalAssetResolver resolver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final teamStyle = Theme.of(context).textTheme.bodyMedium;
    final statStyle = Theme.of(context).textTheme.bodyMedium;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text('$position', style: statStyle),
            ),
            Expanded(
              child: Row(
                children: [
                  EntityBadge(
                    entityId: teamId,
                    type: SportsAssetType.teams,
                    resolver: resolver,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: teamStyle,
                    ),
                  ),
                ],
              ),
            ),
            _statCell(played, statStyle),
            _statCell(won, statStyle),
            _statCell(draw, statStyle),
            _statCell(lost, statStyle),
            _statCell(goalDiff, statStyle, width: 36),
            _statCell(
              points,
              statStyle?.copyWith(fontWeight: FontWeight.w700),
              width: 36,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(int value, TextStyle? style, {double width = 30}) {
    return SizedBox(
      width: width,
      child: Text(
        '$value',
        textAlign: TextAlign.right,
        style: style,
      ),
    );
  }
}