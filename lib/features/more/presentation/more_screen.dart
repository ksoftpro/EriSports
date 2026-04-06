import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/bootstrap/startup_controller.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _isDiagnosingAssets = false;
  AssetDiagnosticsReport? _assetDiagnostics;

  Future<void> _runAssetDiagnostics() async {
    if (_isDiagnosingAssets) {
      return;
    }

    setState(() {
      _isDiagnosingAssets = true;
    });

    final services = ref.read(appServicesProvider);
    services.assetResolver.invalidateCache(clearPersistent: true);

    final teams = await services.database.readTeamsSorted();
    final teamIds = teams.map((team) => team.id).toList(growable: false);
    final playerIds = await services.database.readAllPlayerIds();
    final competitionIds = await services.database.readAllCompetitionIds();

    final missingTeamIds = <String>[];
    for (final team in teams) {
      final resolved = await services.assetResolver.resolveTeamBadge(
        teamId: team.id,
        teamName: team.shortName ?? team.name,
        source: 'more.asset-diagnostics',
      );
      if (resolved == null) {
        missingTeamIds.add(team.id);
      }
    }

    Future<List<String>> findMissing(
      List<String> ids,
      SportsAssetType type,
    ) async {
      final missing = <String>[];
      for (final id in ids) {
        final resolved = await services.assetResolver.resolveByEntityId(
          type: type,
          entityId: id,
        );
        if (resolved == null) {
          missing.add(id);
        }
      }
      return missing;
    }

    final missingPlayerIds = await findMissing(
      playerIds,
      SportsAssetType.players,
    );
    final missingCompetitionIds = await findMissing(
      competitionIds,
      SportsAssetType.leagues,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _assetDiagnostics = AssetDiagnosticsReport(
        totalTeams: teamIds.length,
        totalPlayers: playerIds.length,
        totalCompetitions: competitionIds.length,
        missingTeamIds: missingTeamIds,
        missingPlayerIds: missingPlayerIds,
        missingCompetitionIds: missingCompetitionIds,
      );
      _isDiagnosingAssets = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final startupReport = ref.watch(startupImportReportProvider);
    final startupState = ref.watch(startupControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final syncState = ref.watch(daylysportSyncControllerProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _themeChip(
                        context: context,
                        label: 'System',
                        selected: themeMode == ThemeMode.system,
                        onTap:
                            () => ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.system),
                      ),
                      _themeChip(
                        context: context,
                        label: 'Light',
                        selected: themeMode == ThemeMode.light,
                        onTap:
                            () => ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.light),
                      ),
                      _themeChip(
                        context: context,
                        label: 'Dark',
                        selected: themeMode == ThemeMode.dark,
                        onTap:
                            () => ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.push('/player-stats'),
            icon: const Icon(Icons.leaderboard),
            label: const Text('Open offline player leaderboards'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.push('/sync'),
            icon: const Icon(Icons.sync),
            label: const Text('Open Synchronize Data'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isDiagnosingAssets ? null : _runAssetDiagnostics,
            icon: const Icon(Icons.image_search),
            label: Text(
              _isDiagnosingAssets
                  ? 'Checking local image coverage...'
                  : 'Run offline asset diagnostics',
            ),
          ),
          const SizedBox(height: 16),
          if (startupReport != null)
            _ReportCard(title: 'Startup import', report: startupReport),
          if (startupState.isBackgroundRefreshing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(startupState.statusText),
                ),
              ),
            ),
          if (syncState.lastResult?.importReport != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ReportCard(
                title: 'Latest synchronization',
                report: syncState.lastResult!.importReport!,
              ),
            ),
          if (_assetDiagnostics != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _AssetDiagnosticsCard(report: _assetDiagnostics!),
            ),
        ],
      ),
    );
  }

  Widget _themeChip({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.onPrimary : scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      selectedColor: scheme.primary,
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.72)),
      onSelected: (_) => onTap(),
    );
  }
}

class AssetDiagnosticsReport {
  const AssetDiagnosticsReport({
    required this.totalTeams,
    required this.totalPlayers,
    required this.totalCompetitions,
    required this.missingTeamIds,
    required this.missingPlayerIds,
    required this.missingCompetitionIds,
  });

  final int totalTeams;
  final int totalPlayers;
  final int totalCompetitions;
  final List<String> missingTeamIds;
  final List<String> missingPlayerIds;
  final List<String> missingCompetitionIds;
}

class _AssetDiagnosticsCard extends StatelessWidget {
  const _AssetDiagnosticsCard({required this.report});

  final AssetDiagnosticsReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asset diagnostics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Teams: ${report.totalTeams - report.missingTeamIds.length}/${report.totalTeams} mapped',
            ),
            Text(
              'Players: ${report.totalPlayers - report.missingPlayerIds.length}/${report.totalPlayers} mapped',
            ),
            Text(
              'Competitions: ${report.totalCompetitions - report.missingCompetitionIds.length}/${report.totalCompetitions} mapped',
            ),
            const SizedBox(height: 10),
            _missingPreview('Missing team IDs', report.missingTeamIds),
            _missingPreview('Missing player IDs', report.missingPlayerIds),
            _missingPreview(
              'Missing competition IDs',
              report.missingCompetitionIds,
            ),
          ],
        ),
      ),
    );
  }

  Widget _missingPreview(String title, List<String> ids) {
    if (ids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$title: none'),
      );
    }

    final preview = ids.take(8).join(', ');
    final suffix = ids.length > 8 ? ' ... (+${ids.length - 8} more)' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$title: $preview$suffix'),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.report});

  final String title;
  final ImportRunReport report;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Status: ${report.status}'),
            Text('Run ID: ${report.runId}'),
            Text('JSON files discovered: ${report.jsonFileCount}'),
            Text('Changed files processed: ${report.processedFileCount}'),
            Text('Imported files: ${report.importedFileCount}'),
            Text('Skipped files: ${report.skippedFileCount}'),
            Text('Failed files: ${report.failedFileCount}'),
            Text('Started: ${formatter.format(report.startedAtUtc.toLocal())}'),
            Text(
              'Finished: ${formatter.format(report.finishedAtUtc.toLocal())}',
            ),
            if (report.sourcePath.isNotEmpty)
              Text('Source: ${report.sourcePath}'),
            if (report.sourcePath.isEmpty)
              const Text(
                'Source path unresolved. On Android, grant "All files access" and ensure folder exists at /storage/emulated/0/daylySport.',
              ),
            if (report.errorMessage != null)
              Text('Error: ${report.errorMessage!}'),
          ],
        ),
      ),
    );
  }
}
