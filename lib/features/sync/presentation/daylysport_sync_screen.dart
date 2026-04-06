import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:eri_sports/data/sync/daylysport_sync_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DaylysportSyncScreen extends ConsumerWidget {
  const DaylysportSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(daylysportSyncControllerProvider);
    final notifier = ref.read(daylysportSyncControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final result = syncState.lastResult;
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(title: const Text('Synchronize Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'daylySport runtime synchronization',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    syncState.statusText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (syncState.isBusy) ...[
                    LinearProgressIndicator(
                      value:
                          syncState.totalFiles > 0
                              ? syncState.processedFiles / syncState.totalFiles
                              : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StatPill(
                        label: 'Watcher',
                        value: syncState.watcherSupported ? 'Active' : 'Fallback',
                      ),
                      _StatPill(
                        label: 'Changed files',
                        value: '${result?.discovery.changedJsonFiles ?? 0}',
                      ),
                      _StatPill(
                        label: 'Imported',
                        value: '${syncState.importedFiles}',
                      ),
                      _StatPill(
                        label: 'Skipped',
                        value: '${syncState.skippedFiles}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: syncState.isBusy ? null : notifier.runManualSync,
                    icon: const Icon(Icons.sync),
                    label: Text(
                      syncState.isBusy
                          ? 'Synchronizing data...'
                          : 'Synchronize daylySport data',
                    ),
                  ),
                  if (syncState.currentFile != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Current file: ${syncState.currentFile}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (syncState.lastCompletedAtUtc != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Last completed: ${formatter.format(syncState.lastCompletedAtUtc!.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (syncState.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      syncState.errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (result != null) ...[
            _SummaryCard(result: result, formatter: formatter),
            const SizedBox(height: 14),
            _ChangedFilesCard(result: result),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result, required this.formatter});

  final DaylysportSyncResult result;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    final report = result.importReport;
    final domains = result.affectedDomains
        .map(daylysportDomainLabel)
        .toList(growable: false)
      ..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last sync summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text('Trigger: ${result.triggerType}'),
            Text('Status: ${_statusLabel(result.status)}'),
            Text('Started: ${formatter.format(result.startedAtUtc.toLocal())}'),
            Text('Finished: ${formatter.format(result.finishedAtUtc.toLocal())}'),
            Text('JSON discovered: ${result.discovery.totalJsonFiles}'),
            Text('Changed files: ${result.discovery.changedJsonFiles}'),
            if (report != null) ...[
              Text('Processed files: ${report.processedFileCount}'),
              Text('Imported files: ${report.importedFileCount}'),
              Text('Skipped files: ${report.skippedFileCount}'),
              Text('Failed files: ${report.failedFileCount}'),
            ],
            Text(
              'Affected datasets: ${domains.isEmpty ? 'none' : domains.join(', ')}',
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(DaylysportSyncStatus status) {
    switch (status) {
      case DaylysportSyncStatus.synchronized:
        return 'Synchronized';
      case DaylysportSyncStatus.upToDate:
        return 'Up to date';
      case DaylysportSyncStatus.failed:
        return 'Failed';
    }
  }
}

class _ChangedFilesCard extends StatelessWidget {
  const _ChangedFilesCard({required this.result});

  final DaylysportSyncResult result;

  @override
  Widget build(BuildContext context) {
    final changes = result.discovery.changes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Changed file summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (changes.isEmpty)
              const Text('No file changes were detected in the last scan.'),
            for (final change in changes.take(12))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${daylysportFileChangeLabel(change.changeType)}  ${change.relativePath}'),
                    Text(
                      change.domains.isEmpty
                          ? 'No mapped dataset'
                          : change.domains.map(daylysportDomainLabel).join(', '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (changes.length > 12)
              Text('... and ${changes.length - 12} more file changes'),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

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
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}