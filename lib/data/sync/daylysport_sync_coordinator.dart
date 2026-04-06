import 'dart:async';

import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/local_files/daylysport_file_discovery_service.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:eri_sports/data/local_files/json_data_version_tracker.dart';

enum DaylysportSyncStatus { synchronized, upToDate, failed }

class DaylysportSyncResult {
  const DaylysportSyncResult({
    required this.triggerType,
    required this.startedAtUtc,
    required this.finishedAtUtc,
    required this.discovery,
    required this.status,
    required this.affectedDomains,
    this.importReport,
    this.errorMessage,
  });

  final String triggerType;
  final DateTime startedAtUtc;
  final DateTime finishedAtUtc;
  final DaylysportDiscoverySnapshot discovery;
  final DaylysportSyncStatus status;
  final Set<DaylysportDataDomain> affectedDomains;
  final ImportRunReport? importReport;
  final String? errorMessage;

  bool get hasChanges => discovery.hasChanges;
}

class DaylysportSyncCoordinator {
  DaylysportSyncCoordinator({
    required DaylysportFileDiscoveryService discoveryService,
    required JsonDataVersionTracker versionTracker,
    required ImportCoordinator importCoordinator,
  }) : _discoveryService = discoveryService,
       _versionTracker = versionTracker,
       _importCoordinator = importCoordinator;

  final DaylysportFileDiscoveryService _discoveryService;
  final JsonDataVersionTracker _versionTracker;
  final ImportCoordinator _importCoordinator;

  Completer<DaylysportSyncResult>? _activeRun;

  Future<DaylysportSyncResult> synchronize({
    required String triggerType,
    bool preferTrackedPaths = false,
    bool forceImport = false,
    void Function(ImportProgressUpdate update)? onProgress,
  }) async {
    final inFlight = _activeRun;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<DaylysportSyncResult>();
    _activeRun = completer;
    final startedAtUtc = DateTime.now().toUtc();

    try {
      final discovery = await _discoveryService.discoverChanges(
        preferTrackedPaths: preferTrackedPaths,
      );
      final affectedDomains = discovery.affectedDomains;

      if (!forceImport && !discovery.hasChanges) {
        final result = DaylysportSyncResult(
          triggerType: triggerType,
          startedAtUtc: startedAtUtc,
          finishedAtUtc: DateTime.now().toUtc(),
          discovery: discovery,
          status: DaylysportSyncStatus.upToDate,
          affectedDomains: affectedDomains,
        );
        completer.complete(result);
        return result;
      }

      final importReport = await _importCoordinator.runLocalImport(
        triggerType: triggerType,
        snapshots: discovery.currentSnapshots,
        onlyRelativePaths:
            discovery.changedRelativePaths.isEmpty
                ? null
                : discovery.changedRelativePaths.toSet(),
        onProgress: onProgress,
      );

      await _versionTracker.writeTrackedVersions(
        discovery.rootPath,
        discovery.trackedVersions,
      );

      final result = DaylysportSyncResult(
        triggerType: triggerType,
        startedAtUtc: startedAtUtc,
        finishedAtUtc: DateTime.now().toUtc(),
        discovery: discovery,
        status: DaylysportSyncStatus.synchronized,
        importReport: importReport,
        affectedDomains: {
          ...affectedDomains,
          ...importReport.affectedDomains,
        },
      );
      completer.complete(result);
      return result;
    } catch (error) {
      final result = DaylysportSyncResult(
        triggerType: triggerType,
        startedAtUtc: startedAtUtc,
        finishedAtUtc: DateTime.now().toUtc(),
        discovery: DaylysportDiscoverySnapshot(
          rootPath: '',
          scannedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          currentSnapshots: [],
          trackedVersions: [],
          changes: [],
        ),
        status: DaylysportSyncStatus.failed,
        affectedDomains: const <DaylysportDataDomain>{},
        errorMessage: error.toString(),
      );
      completer.complete(result);
      return result;
    } finally {
      _activeRun = null;
    }
  }

  Future<Stream<void>?> watchJsonChanges() {
    return _discoveryService.tryWatchJsonChanges();
  }
}