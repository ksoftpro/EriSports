import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/features/leagues/presentation/league_overview_providers.dart';
import 'package:eri_sports/features/leagues/presentation/widgets/league_overview_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LeagueOverviewScreen extends ConsumerStatefulWidget {
  const LeagueOverviewScreen({required this.competitionId, super.key});

  final String competitionId;

  @override
  ConsumerState<LeagueOverviewScreen> createState() =>
      _LeagueOverviewScreenState();
}

class _LeagueOverviewScreenState extends ConsumerState<LeagueOverviewScreen> {
  String _selectedMode = 'Short';
  String _scopeLabel = 'Overall';

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(
      leagueOverviewProvider(widget.competitionId),
    );

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFEDEFF6),
        body: overviewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, stackTrace) => const Center(
                child: Text('Unable to load league overview data.'),
              ),
          data: (state) {
            final resolver = ref.read(appServicesProvider).assetResolver;
            return Column(
              children: [
                LeagueHeader(
                  competitionId: state.competitionId,
                  resolver: resolver,
                  competitionName: state.competitionName,
                  countryLabel: state.countryLabel,
                  seasonLabel: state.seasonLabel,
                  onBack: () => context.pop(),
                  onNotify: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications coming soon'),
                      ),
                    );
                  },
                  onFollowing: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Following preferences coming soon'),
                      ),
                    );
                  },
                ),
                const LeagueTopTabs(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TableTab(
                        selectedMode: _selectedMode,
                        scopeLabel: _scopeLabel,
                        rows: state.rows,
                        resolver: resolver,
                        onModeChanged: (value) {
                          setState(() {
                            _selectedMode = value;
                          });
                        },
                        onScopeTap: _showScopeSheet,
                      ),
                      const _FeaturePlaceholder(label: 'Fixtures'),
                      const _FeaturePlaceholder(label: 'News'),
                      const _FeaturePlaceholder(label: 'Player stats'),
                      const _FeaturePlaceholder(label: 'Team stats'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showScopeSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _scopeOption('Overall'),
              _scopeOption('Home'),
              _scopeOption('Away'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _scopeLabel = selected;
    });
  }

  Widget _scopeOption(String label) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: _scopeLabel == label ? const Icon(Icons.check, size: 18) : null,
      onTap: () => Navigator.of(context).pop(label),
    );
  }
}

class _TableTab extends StatelessWidget {
  const _TableTab({
    required this.selectedMode,
    required this.scopeLabel,
    required this.rows,
    required this.resolver,
    required this.onModeChanged,
    required this.onScopeTap,
  });

  final String selectedMode;
  final String scopeLabel;
  final List<StandingsTableView> rows;
  final LocalAssetResolver resolver;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onScopeTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No standings imported for this league.',
          style: TextStyle(color: Color(0xFF4A546B)),
        ),
      );
    }

    return Column(
      children: [
        LeagueSegmentedControls(
          selectedMode: selectedMode,
          scopeLabel: scopeLabel,
          onModeChanged: onModeChanged,
          onScopeTap: onScopeTap,
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD9DEEA)),
            ),
            child: Column(
              children: [
                const LeagueStandingsHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final item = rows[index];
                      return LeagueStandingsRow(
                        position: item.row.position,
                        teamId: item.teamId,
                        teamName: item.teamName,
                        played: item.row.played,
                        goalDiff: item.row.goalDiff,
                        points: item.row.points,
                        rowCount: rows.length,
                        resolver: resolver,
                        onTap: () => context.push('/team/${item.teamId}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  const _FeaturePlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$label module is the next data hookup.',
        style: const TextStyle(
          color: Color(0xFF4A546B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
