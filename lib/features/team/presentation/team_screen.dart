import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/team/presentation/team_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/match_card_compact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({
    required this.teamId,
    super.key,
  });

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailProvider(teamId));

    return Scaffold(
      appBar: AppBar(),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Text('Unable to load local team data.'),
        ),
        data: (state) {
          final resolver = ref.read(appServicesProvider).assetResolver;
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    EntityBadge(
                      entityId: state.team.id,
                      type: SportsAssetType.teams,
                      resolver: resolver,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.team.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          if (state.competition != null)
                            Text(
                              state.competition!.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Text('Recent Matches'),
              ),
              ...state.matches.take(8).map(
                    (item) => MatchCardCompact(
                      status: _statusLabel(item.match.kickoffUtc, item.match.status),
                      timeOrMinute: _timeLabel(item.match.kickoffUtc, item.match.status),
                      homeTeam: item.homeTeamName,
                      awayTeam: item.awayTeamName,
                      homeTeamId: item.match.homeTeamId,
                      awayTeamId: item.match.awayTeamId,
                      assetResolver: resolver,
                      onTap: () => context.push('/match/${item.match.id}'),
                      homeScore: item.match.homeScore,
                      awayScore: item.match.awayScore,
                    ),
                  ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Text('Squad'),
              ),
              if (state.players.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text('No player data imported for this team.'),
                ),
              ...state.players.map(
                (player) => ListTile(
                  dense: true,
                  onTap: () => context.push('/player/${player.id}'),
                  leading: EntityBadge(
                    entityId: player.id,
                    type: SportsAssetType.players,
                    resolver: resolver,
                    size: 24,
                  ),
                  title: Text(player.name),
                  subtitle: Text(
                    [
                      if (player.position != null) player.position!,
                      if (player.jerseyNumber != null) '#${player.jerseyNumber}',
                    ].join(' • '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _statusLabel(DateTime kickoffUtc, String rawStatus) {
    final status = rawStatus.toLowerCase();
    if (status == 'live' || status == 'inplay' || status == 'in_play') {
      return rawStatus.toUpperCase();
    }

    final now = DateTime.now().toUtc();
    return kickoffUtc.isAfter(now) ? 'UPCOMING' : 'FT';
  }

  static String _timeLabel(DateTime kickoffUtc, String rawStatus) {
    final status = rawStatus.toLowerCase();
    if (status == 'live' || status == 'inplay' || status == 'in_play') {
      return 'LIVE';
    }

    return DateFormat('HH:mm').format(kickoffUtc.toLocal());
  }
}