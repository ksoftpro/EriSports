import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/bootstrap/startup_controller.dart';
import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/sync/daylysport_sync_coordinator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _isDiagnosingAssets = false;
  bool _isPickingJsonFolder = false;
  bool _isRunningOfflineAction = false;
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
      final result =
          await ref
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
      final result =
          await ref
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
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
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
      final result =
          await ref
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

  Future<void> _runOfflineAction(OfflineContentManualAction action) async {
    if (_isRunningOfflineAction) {
      return;
    }

    setState(() {
      _isRunningOfflineAction = true;
    });

    try {
      await ref
          .read(offlineContentRefreshControllerProvider.notifier)
          .runManualAction(action);
    } finally {
      if (mounted) {
        setState(() {
          _isRunningOfflineAction = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final startupReport = ref.watch(startupImportReportProvider);
    final startupState = ref.watch(startupControllerProvider);
    final offlineContentState = ref.watch(
      offlineContentRefreshControllerProvider,
    );
    final themeMode = ref.watch(themeModeProvider);
    final syncState = ref.watch(daylysportSyncControllerProvider);
    final services = ref.read(appServicesProvider);
    final selectedJsonFolder =
        services.daylySportLocator.readCustomDirectoryPath();
    final scheme = Theme.of(context).colorScheme;
    final effectiveBrightness = Theme.of(context).brightness;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle:
                  'Choose how EriSports follows light, dark, or system theme mode.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('System'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Light'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: <ThemeMode>{themeMode},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(selection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusBadge(
                              label: 'Mode',
                              value: _themeModeLabel(themeMode),
                            ),
                            _StatusBadge(
                              label: 'Active',
                              value: _brightnessLabel(effectiveBrightness),
                            ),
                            if (themeMode == ThemeMode.system)
                              _StatusBadge(
                                label: 'Device',
                                value: _brightnessLabel(platformBrightness),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          themeMode == ThemeMode.system
                              ? 'The app is following your device setting and is currently using ${_brightnessLabel(platformBrightness).toLowerCase()} mode.'
                              : 'The app is locked to ${_brightnessLabel(effectiveBrightness).toLowerCase()} mode until you switch it again.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.lock_outline_rounded,
              title: 'Offline Content Security',
              subtitle:
                  'Inspect encrypted content, warm caches, and clear decrypted runtime files.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    syncState.statusText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offlineContentState.statusText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.push('/secure-content'),
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Open secure content'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/sync'),
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Open sync tools'),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _isRunningOfflineAction || syncState.isBusy
                                ? null
                                : () => _runOfflineAction(
                                  OfflineContentManualAction.sync,
                                ),
                        icon: const Icon(Icons.cloud_sync_outlined),
                        label: Text(
                          _isRunningOfflineAction
                              ? 'Working...'
                              : 'Run sync now',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isRunningOfflineAction
                                ? null
                                : () => _runOfflineAction(
                                  OfflineContentManualAction.decrypt,
                                ),
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('Prewarm decryption'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isRunningOfflineAction
                                ? null
                                : () => _runOfflineAction(
                                  OfflineContentManualAction.cache,
                                ),
                        icon: const Icon(Icons.cached_rounded),
                        label: const Text('Refresh cache'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.folder_open_rounded,
              title: 'JSON Data Directory',
              subtitle:
                  'Choose where the app reads the daylySport offline dataset from.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedJsonFolder ??
                        'Using automatic daylySport discovery. Android defaults to /storage/emulated/0/daylySport when available.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _isPickingJsonFolder ? null : _pickJsonDirectory,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: Text(
                          _isPickingJsonFolder
                              ? 'Applying folder...'
                              : 'Browse data JSONs directory',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isPickingJsonFolder
                                ? null
                                : () =>
                                    _openManualPathDialog(selectedJsonFolder),
                        icon: const Icon(Icons.edit_location_alt_rounded),
                        label: const Text('Set path manually'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isPickingJsonFolder || selectedJsonFolder == null
                                ? null
                                : _clearCustomJsonDirectory,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Use default folder'),
                      ),
                    ],
                  ),
                  if (_folderSelectionMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _folderSelectionMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              _folderSelectionMessage!.toLowerCase().contains(
                                        'failed',
                                      ) ||
                                      _folderSelectionMessage!
                                          .toLowerCase()
                                          .contains('unable')
                                  ? scheme.error
                                  : scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.tune_rounded,
              title: 'Tools',
              subtitle: 'Open data utilities and run local asset validation.',
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.leaderboard_rounded,
                    title: 'Offline player leaderboards',
                    subtitle:
                        'Inspect imported player statistics by competition and category.',
                    onTap: () => context.push('/player-stats'),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    subtitle: 'Developer and business contact information.',
                    onTap: () => context.push('/about'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isDiagnosingAssets ? null : _runAssetDiagnostics,
                      icon: const Icon(Icons.image_search_rounded),
                      label: Text(
                        _isDiagnosingAssets
                            ? 'Checking local image coverage...'
                            : 'Run offline asset diagnostics',
                      ),
                    ),
                  ),
                ],
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
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String _brightnessLabel(Brightness brightness) {
    switch (brightness) {
      case Brightness.light:
        return 'Light';
      case Brightness.dark:
        return 'Dark';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
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
