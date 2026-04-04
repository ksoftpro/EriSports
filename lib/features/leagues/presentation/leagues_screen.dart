import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/leagues/presentation/leagues_providers.dart';
import 'package:eri_sports/shared/widgets/dense_section_header.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LeaguesScreen extends ConsumerWidget {
  const LeaguesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final resolver = ref.read(appServicesProvider).assetResolver;

    return SafeArea(
      child: leaguesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) =>
                const Center(child: Text('Unable to load local competitions.')),
        data: (leagues) {
          if (leagues.isEmpty) {
            return const Center(child: Text('No competitions imported yet.'));
          }

          return ListView(
            children: [
              const DenseSectionHeader(title: 'Competitions'),
              ...leagues.map(
                (league) => _LeagueTile(
                  leagueId: league.id,
                  name: league.name,
                  country: league.country,
                  resolver: resolver,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LeagueTile extends StatelessWidget {
  const _LeagueTile({
    required this.leagueId,
    required this.name,
    required this.country,
    required this.resolver,
  });

  final String leagueId;
  final String name;
  final String? country;
  final LocalAssetResolver resolver;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: () => context.push('/league/$leagueId'),
      leading: EntityBadge(
        entityId: leagueId,
        type: SportsAssetType.leagues,
        resolver: resolver,
        size: 22,
      ),
      title: Text(name, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(
        country ?? '',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
