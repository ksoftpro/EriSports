import 'package:eri_sports/app/theme/color_tokens.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';

class MatchCardCompact extends StatelessWidget {
  const MatchCardCompact({
    required this.status,
    required this.timeOrMinute,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamId,
    this.awayTeamId,
    this.assetResolver,
    this.onTap,
    required this.homeScore,
    required this.awayScore,
    super.key,
  });

  final String status;
  final String timeOrMinute;
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamId;
  final String? awayTeamId;
  final LocalAssetResolver? assetResolver;
  final VoidCallback? onTap;
  final int homeScore;
  final int awayScore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColorTokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColorTokens.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColorTokens.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeOrMinute,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColorTokens.textPrimary,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _teamRow(context, homeTeam, homeScore, homeTeamId),
                    const Divider(height: 12, color: AppColorTokens.border),
                    _teamRow(context, awayTeam, awayScore, awayTeamId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamRow(BuildContext context, String name, int score, [String? teamId]) {
    final canResolveBadge = assetResolver != null && teamId != null && teamId.isNotEmpty;

    return Row(
      children: [
        canResolveBadge
            ? EntityBadge(
                entityId: teamId,
                type: SportsAssetType.teams,
                resolver: assetResolver!,
                size: 18,
              )
            : Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColorTokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text(
          '$score',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}