import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/match_detail/presentation/match_detail_providers.dart';
import 'package:eri_sports/shared/formatters/match_display_formatter.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({required this.matchId, super.key});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchDetailProvider(matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Match Detail')),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return _buildUnavailableState(
            context,
            requestedMatchId: matchId,
            reason:
                'Unable to load local match detail. ${error.toString().trim()}',
            logs: const [],
          );
        },
        data: (state) {
          final detail = state.detail;
          if (detail == null) {
            return _buildUnavailableState(
              context,
              requestedMatchId: state.requestedMatchId,
              resolvedMatchId: state.resolvedMatchId,
              reason:
                  'Match details unavailable in local daylysport JSON for this match.',
              logs: state.debugLogs,
            );
          }

          final resolver = ref.read(appServicesProvider).assetResolver;
          final kickoff = DateFormat(
            'EEE, dd MMM • HH:mm',
          ).format(detail.match.kickoffUtc.toLocal());
          final score = MatchDisplayFormatter.scoreDisplay(
            status: detail.match.status,
            kickoffUtc: detail.match.kickoffUtc,
            homeScore: detail.match.homeScore,
            awayScore: detail.match.awayScore,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              Center(
                child: Text(
                  detail.competitionName,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.82),
                  ),
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
                      onTap:
                          () =>
                              context.push('/team/${detail.match.homeTeamId}'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      score.centerLabel,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Expanded(
                    child: _teamBlock(
                      context,
                      resolver,
                      detail.match.awayTeamId,
                      detail.awayTeamName,
                      onTap:
                          () =>
                              context.push('/team/${detail.match.awayTeamId}'),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stats',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (state.stats.isEmpty)
                        const Text('No local stats available for this match.')
                      else
                        ...state.stats.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 44,
                                      child: Text(
                                        _formatStatValue(item.homeValue),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _prettifyStatKey(item.statKey),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 44,
                                      child: Text(
                                        _formatStatValue(item.awayValue),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _statBar(
                                  context,
                                  item.homeValue,
                                  item.awayValue,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Timeline',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (state.events.isEmpty)
                        const Text(
                          'No local timeline events available for this match.',
                        )
                      else
                        ...state.events.map(
                          (event) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 34,
                                  child: Text(
                                    "${event.event.minute}'",
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _prettifyEventType(
                                          event.event.eventType,
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (event.event.playerName != null ||
                                          event.event.playerId != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap:
                                                    event.event.playerId == null
                                                        ? null
                                                        : () => context.push(
                                                          '/player/${event.event.playerId}',
                                                        ),
                                                child: EntityBadge(
                                                  entityId:
                                                      event.event.playerId ??
                                                      '',
                                                  entityName:
                                                      event.event.playerName,
                                                  type: SportsAssetType.players,
                                                  resolver: resolver,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  event.event.playerName ??
                                                      'Unknown player',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (event.teamName != null ||
                                          event.event.teamId != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap:
                                                    event.event.teamId == null
                                                        ? null
                                                        : () => context.push(
                                                          '/team/${event.event.teamId}',
                                                        ),
                                                child: TeamBadge(
                                                  teamId: event.event.teamId,
                                                  teamName: event.teamName,
                                                  resolver: resolver,
                                                  source:
                                                      'match-detail.timeline',
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  event.teamName ??
                                                      'Unknown team',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      Theme.of(
                                                        context,
                                                      ).textTheme.labelMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (event.event.detail != null)
                                        Text(
                                          event.event.detail!,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
            TeamBadge(
              teamId: teamId,
              teamName: teamName,
              resolver: resolver,
              source: 'match-detail.header',
              size: 52,
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
      child: Row(children: [Expanded(child: Text(label)), Text(value)]),
    );
  }

  Widget _statBar(BuildContext context, double homeValue, double awayValue) {
    final scheme = Theme.of(context).colorScheme;
    final total = (homeValue + awayValue).abs();
    final homeRatio = total == 0 ? 0.5 : (homeValue / total);
    final awayRatio = 1 - homeRatio;

    return Row(
      children: [
        Expanded(
          flex: (homeRatio * 100).round().clamp(1, 99),
          child: Container(height: 5, color: scheme.primary),
        ),
        Expanded(
          flex: (awayRatio * 100).round().clamp(1, 99),
          child: Container(height: 5, color: scheme.secondary),
        ),
      ],
    );
  }

  String _formatStatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _prettifyStatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _prettifyEventType(String type) {
    return _prettifyStatKey(type);
  }

  Widget _buildUnavailableState(
    BuildContext context, {
    required String requestedMatchId,
    String? resolvedMatchId,
    required String reason,
    required List<String> logs,
  }) {
    final visibleLogs = logs.take(8).toList(growable: false);
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match details unavailable',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(reason, style: bodyStyle),
                const SizedBox(height: 10),
                Text('Requested match id: $requestedMatchId', style: bodyStyle),
                if (resolvedMatchId != null)
                  Text('Resolved match id: $resolvedMatchId', style: bodyStyle),
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
                      child: Text(line, style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
