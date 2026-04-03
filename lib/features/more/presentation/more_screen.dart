import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _isRefreshing = false;
  ImportRunReport? _manualReport;

  Future<void> _runManualImport() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    final services = ref.read(appServicesProvider);
    final report =
        await services.importCoordinator.runLocalImport(triggerType: 'manual');

    if (!mounted) {
      return;
    }

    setState(() {
      _manualReport = report;
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final startupReport = ref.watch(startupImportReportProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isRefreshing ? null : _runManualImport,
            icon: const Icon(Icons.sync),
            label: Text(_isRefreshing
                ? 'Scanning local files...'
                : 'Re-scan daylySport folder'),
          ),
          const SizedBox(height: 16),
          _ReportCard(title: 'Startup import', report: startupReport),
          if (_manualReport != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ReportCard(title: 'Manual import', report: _manualReport!),
            ),
        ],
      ),
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
            Text('Started: ${formatter.format(report.startedAtUtc.toLocal())}'),
            Text('Finished: ${formatter.format(report.finishedAtUtc.toLocal())}'),
            if (report.sourcePath.isNotEmpty) Text('Source: ${report.sourcePath}'),
            if (report.errorMessage != null)
              Text('Error: ${report.errorMessage!}'),
          ],
        ),
      ),
    );
  }
}