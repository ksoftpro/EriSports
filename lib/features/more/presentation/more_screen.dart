import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/bootstrap/startup_controller.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/sync/daylysport_sync_coordinator.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _isPickingJsonFolder = false;
  String? _folderSelectionMessage;
  AssetDiagnosticsReport? _assetDiagnostics;

  Future<void> _pickJsonDirectory() async {
    if (_isPickingJsonFolder) {
      return;
    }

    setState(() {
      _isPickingJsonFolder = true;
      _folderSelectionMessage = null;
    });

    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select JSON data folder',
      );

      if (selectedPath == null || selectedPath.trim().isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _folderSelectionMessage = 'Folder selection canceled.';
          _isPickingJsonFolder = false;
        });
        return;
      }

      final services = ref.read(appServicesProvider);
      await services.daylySportLocator.setCustomDirectoryPath(selectedPath);
      final result = await ref
          .read(daylysportSyncControllerProvider.notifier)
          .runManualSync();

      if (!mounted) {
        return;
      }

      setState(() {
        _folderSelectionMessage =
            result.status == DaylysportSyncStatus.failed
                ? 'Folder updated, but synchronization failed: ${result.errorMessage ?? 'unknown error'}'
                : 'JSON folder updated successfully.';
        _isPickingJsonFolder = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _folderSelectionMessage = 'Unable to set folder: $error';
        _isPickingJsonFolder = false;
      });
    }
  }

  Future<void> _clearCustomJsonDirectory() async {
    if (_isPickingJsonFolder) {
      return;
    }

    setState(() {
      _isPickingJsonFolder = true;
      _folderSelectionMessage = null;
    });

    try {
      final services = ref.read(appServicesProvider);
      await services.daylySportLocator.setCustomDirectoryPath(null);
      final result = await ref
          .read(daylysportSyncControllerProvider.notifier)
          .runManualSync();

      if (!mounted) {
        return;
      }

      setState(() {
        _folderSelectionMessage =
            result.status == DaylysportSyncStatus.failed
                ? 'Reset to default folder, but sync failed: ${result.errorMessage ?? 'unknown error'}'
                : 'Using default daylySport folder again.';
        _isPickingJsonFolder = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _folderSelectionMessage = 'Unable to reset folder: $error';
        _isPickingJsonFolder = false;
      });
    }
  }

  Future<void> _openManualPathDialog(String? currentPath) async {
    final controller = TextEditingController(text: currentPath ?? '');
    final nextPath = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set JSON folder path'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Directory path',
              hintText: '/storage/emulated/0/daylySport',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (nextPath == null) {
      return;
    }

    if (nextPath.isEmpty) {
      await _clearCustomJsonDirectory();
      return;
    }

    if (_isPickingJsonFolder) {
      return;
    }

    setState(() {
      _isPickingJsonFolder = true;
      _folderSelectionMessage = null;
    });

    try {
      final services = ref.read(appServicesProvider);
      await services.daylySportLocator.setCustomDirectoryPath(nextPath);
      final result = await ref
          .read(daylysportSyncControllerProvider.notifier)
          .runManualSync();

      if (!mounted) {
        return;
      }

      setState(() {
        _folderSelectionMessage =
            result.status == DaylysportSyncStatus.failed
                ? 'Path saved, but sync failed: ${result.errorMessage ?? 'unknown error'}'
                : 'JSON folder path saved.';
        _isPickingJsonFolder = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _folderSelectionMessage = 'Unable to save path: $error';
        _isPickingJsonFolder = false;
      });
    }
  }

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
    final services = ref.read(appServicesProvider);
    final selectedJsonFolder = services.daylySportLocator.readCustomDirectoryPath();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
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
                        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                      ),
                      _themeChip(
                        context: context,
                        label: 'Light',
                        selected: themeMode == ThemeMode.light,
                        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                      ),
                      _themeChip(
                        context: context,
                        label: 'Dark',
                        selected: themeMode == ThemeMode.dark,
                        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
              leading: Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(
                'About',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Developer and business contact information',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
              onTap: () => context.push('/about'),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.push('/player-stats'),
            icon: Icon(Icons.leaderboard, color: Theme.of(context).colorScheme.onPrimary),
            label: Text('Open offline player leaderboards', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.push('/sync'),
            icon: Icon(Icons.sync, color: Theme.of(context).colorScheme.onPrimary),
            label: Text('Open Synchronize Data', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
          ),
          const SizedBox(height: 10),
          Card(
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JSON data directory',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedJsonFolder ??
                        'Default: /storage/emulated/0/daylySport (or platform fallback)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _isPickingJsonFolder ? null : _pickJsonDirectory,
                        icon: Icon(Icons.folder_open, color: Theme.of(context).colorScheme.onPrimary),
                        label: Text(
                          _isPickingJsonFolder
                              ? 'Applying folder...'
                              : 'Browse data JSONs directory',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isPickingJsonFolder
                                ? null
                                : () => _openManualPathDialog(selectedJsonFolder),
                        icon: Icon(Icons.edit_location_alt, color: Theme.of(context).colorScheme.primary),
                        label: Text('Set path manually', style: Theme.of(context).textTheme.labelLarge),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isPickingJsonFolder || selectedJsonFolder == null
                                ? null
                                : _clearCustomJsonDirectory,
                        icon: Icon(Icons.restart_alt, color: Theme.of(context).colorScheme.primary),
                        label: Text('Use default folder', style: Theme.of(context).textTheme.labelLarge),
                      ),
                    ],
                  ),
                  if (_folderSelectionMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_folderSelectionMessage!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isDiagnosingAssets ? null : _runAssetDiagnostics,
            icon: Icon(Icons.image_search, color: Theme.of(context).colorScheme.primary),
            label: Text(
              _isDiagnosingAssets
                  ? 'Checking local image coverage...'
                  : 'Run offline asset diagnostics',
              style: Theme.of(context).textTheme.labelLarge,
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
