import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/team/presentation/team_providers.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/match_card_compact.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
          final now = DateTime.now().toUtc();
          HomeMatchView? nextFixture;
          for (final item in state.matches) {
            if (item.match.kickoffUtc.isAfter(now)) {
              if (nextFixture == null ||
                  item.match.kickoffUtc.isBefore(
                    nextFixture.match.kickoffUtc,
                  )) {
                nextFixture = item;
              }
            }
          }

          final recentMatches = state.matches
              .where((item) => !item.match.kickoffUtc.isAfter(now))
              .take(6)
              .toList(growable: false);
          final groupedPlayers = _groupPlayers(state.players);
          final scheme = Theme.of(context).colorScheme;

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.22),
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
                    Row(
                      children: [
                        TeamBadge(
                          teamId: state.team.id,
                          teamName: state.team.name,
                          resolver: resolver,
                          source: 'team.header',
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.team.name,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              if (state.competition != null)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 26),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed:
                                      () => context.push(
                                        '/league/${state.competition!.id}',
                                      ),
                                  icon: EntityBadge(
                                    entityId: state.competition!.id,
                                    type: SportsAssetType.leagues,
                                    resolver: resolver,
                                    size: 16,
                                    isCircular: false,
                                  ),
                                  label: Text(state.competition!.name),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FactTile(
                            label: 'Squad',
                            value: '${state.players.length}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FactTile(
                            label: 'Matches',
                            value: '${state.matches.length}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (nextFixture != null) ...[
                Builder(
                  builder: (context) {
                    final fixture = nextFixture!;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Text(
                            'Next fixture',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        MatchCardCompact(
                          status: _statusLabel(
                            fixture.match.kickoffUtc,
                            fixture.match.status,
                          ),
                          timeOrMinute: _timeLabel(
                            fixture.match.kickoffUtc,
                            fixture.match.status,
                          ),
                          homeTeam: fixture.homeTeamName,
                          awayTeam: fixture.awayTeamName,
                          homeTeamId: fixture.match.homeTeamId,
                          awayTeamId: fixture.match.awayTeamId,
                          assetResolver: resolver,
                          badgeSource: 'team.next-fixture',
                          onTap:
                              () => context.push('/match/${fixture.match.id}'),
                          homeScore: fixture.match.homeScore,
                          awayScore: fixture.match.awayScore,
                        ),
                      ],
                    );
                  },
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'Recent matches',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (recentMatches.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text('No completed fixtures in local data.'),
                ),
              ...recentMatches.map(
                (item) => MatchCardCompact(
                  status: _statusLabel(
                    item.match.kickoffUtc,
                    item.match.status,
                  ),
                  timeOrMinute: _timeLabel(
                    item.match.kickoffUtc,
                    item.match.status,
                  ),
                  homeTeam: item.homeTeamName,
                  awayTeam: item.awayTeamName,
                  homeTeamId: item.match.homeTeamId,
                  awayTeamId: item.match.awayTeamId,
                  assetResolver: resolver,
                  badgeSource: 'team.recent-matches',
                  onTap: () => context.push('/match/${item.match.id}'),
                  homeScore: item.match.homeScore,
                  awayScore: item.match.awayScore,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  'Squad',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (state.players.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text('No player data imported for this team.'),
                ),
              for (final entry in groupedPlayers.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                for (final player in entry.value)
                  ListTile(
                    dense: true,
                    onTap: () => context.push('/player/${player.id}'),
                    leading: EntityBadge(
                      entityId: player.id,
                      entityName: player.name,
                      type: SportsAssetType.players,
                      resolver: resolver,
                      size: 26,
                    ),
                    title: Text(player.name),
                    subtitle: Text(
                      player.jerseyNumber == null
                          ? 'No jersey number'
                          : '#${player.jerseyNumber}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Map<String, List<PlayerRow>> _groupPlayers(List<PlayerRow> players) {
    const preferredOrder = [
      'Goalkeeper',
      'Defender',
      'Midfielder',
      'Forward',
      'Unknown',
    ];
    final groups = <String, List<PlayerRow>>{};
    for (final player in players) {
      final position = player.position?.trim();
      final key = (position == null || position.isEmpty) ? 'Unknown' : position;
      groups.putIfAbsent(key, () => []).add(player);
    }

    final sorted = <String, List<PlayerRow>>{};
    for (final key in preferredOrder) {
      if (groups.containsKey(key)) {
        sorted[key] = groups[key]!;
      }
    }

    for (final entry in groups.entries) {
      sorted.putIfAbsent(entry.key, () => entry.value);
    }

    return sorted;
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

class _FactTile extends StatelessWidget {
  const _FactTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
