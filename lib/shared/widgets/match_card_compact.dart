import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/shared/formatters/team_display_name_formatter.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
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
    this.badgeSource = 'shared.match-card',
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
  final String badgeSource;
  final VoidCallback? onTap;
  final int homeScore;
  final int awayScore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.65)),
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
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeOrMinute,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _teamRow(context, homeTeam, homeScore, homeTeamId),
                    Divider(
                      height: 12,
                      color: scheme.outline.withValues(alpha: 0.45),
                    ),
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

  Widget _teamRow(
    BuildContext context,
    String name,
    int score, [
    String? teamId,
  ]) {
    final canResolveBadge = assetResolver != null;

    return Row(
      children: [
        canResolveBadge
            ? TeamBadge(
              teamId: teamId,
              teamName: name,
              resolver: assetResolver!,
              source: badgeSource,
              size: 18,
            )
            : Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            TeamDisplayNameFormatter.compactMatchName(name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text('$score', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
