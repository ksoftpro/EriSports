import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/theme/color_tokens.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/features/home/presentation/home_providers.dart';
import 'package:eri_sports/shared/widgets/dense_section_header.dart';
import 'package:eri_sports/shared/widgets/match_card_compact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importReport = ref.watch(startupImportReportProvider);
    final homeFeed = ref.watch(homeFeedProvider);

    return SafeArea(
      child: homeFeed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'Failed to load local match feed.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        data: (state) {
          final assetResolver = ref.read(appServicesProvider).assetResolver;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text(
                    'Matches',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ImportStatusPanel(report: importReport),
                ),
              ),
              _buildMatchSection(
                title: 'Live Now',
                actionLabel: 'All',
                matches: state.live,
                emptyLabel: 'No live matches in local dataset.',
                assetResolver: assetResolver,
              ),
              _buildMatchSection(
                title: 'Upcoming',
                actionLabel: 'Calendar',
                matches: state.upcoming,
                emptyLabel: 'No upcoming fixtures in loaded range.',
                assetResolver: assetResolver,
              ),
              _buildMatchSection(
                title: 'Recent',
                actionLabel: 'Results',
                matches: state.recent,
                emptyLabel: 'No recent matches in loaded range.',
                assetResolver: assetResolver,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchSection({
    required String title,
    required String actionLabel,
    required List<HomeMatchView> matches,
    required String emptyLabel,
    required LocalAssetResolver assetResolver,
  }) {
    if (matches.isEmpty) {
      return SliverList.list(
        children: [
          DenseSectionHeader(
            title: title,
            actionLabel: actionLabel,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              emptyLabel,
              style: const TextStyle(color: AppColorTokens.textSecondary),
            ),
          ),
        ],
      );
    }

    return SliverList.list(
      children: [
        DenseSectionHeader(
          title: title,
          actionLabel: actionLabel,
        ),
        ...matches.take(6).map((item) => _buildMatchCard(item, assetResolver)),
      ],
    );
  }

  Widget _buildMatchCard(HomeMatchView item, LocalAssetResolver assetResolver) {
    final now = DateTime.now().toUtc();
    final lowerStatus = item.match.status.toLowerCase();
    final isLive = lowerStatus == 'live' ||
        lowerStatus == 'inplay' ||
        lowerStatus == 'in_play' ||
        lowerStatus == 'playing' ||
        lowerStatus == 'ht';

    final isFuture = item.match.kickoffUtc.isAfter(now);
    final timeText = isLive
        ? 'LIVE'
        : DateFormat('HH:mm').format(item.match.kickoffUtc.toLocal());
    final statusLabel = isLive
        ? item.match.status.toUpperCase()
        : (isFuture ? 'TODAY' : 'FT');

    return MatchCardCompact(
      status: statusLabel,
      timeOrMinute: timeText,
      homeTeam: item.homeTeamName,
      awayTeam: item.awayTeamName,
      homeTeamId: item.match.homeTeamId,
      awayTeamId: item.match.awayTeamId,
      assetResolver: assetResolver,
      homeScore: item.match.homeScore,
      awayScore: item.match.awayScore,
    );
  }
}

class _ImportStatusPanel extends StatelessWidget {
  const _ImportStatusPanel({required this.report});

  final ImportRunReport report;

  @override
  Widget build(BuildContext context) {
    final isSuccess = report.status == 'success';
    final isPartial = report.status == 'partial_success';

    return Container(
      decoration: BoxDecoration(
        color: AppColorTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColorTokens.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess
                    ? Icons.check_circle
                    : isPartial
                        ? Icons.warning_amber
                        : Icons.error,
                size: 16,
                color: isSuccess
                    ? AppColorTokens.success
                    : isPartial
                        ? AppColorTokens.warning
                        : AppColorTokens.danger,
              ),
              const SizedBox(width: 8),
              Text(
                'Local data import: ${report.status}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Source: daylySport',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColorTokens.textSecondary),
          ),
          Text(
            'Discovered JSON files: ${report.jsonFileCount}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColorTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}