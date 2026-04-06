import 'dart:async';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:eri_sports/data/sync/daylysport_sync_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DaylysportSyncPhase { idle, scanning, synchronizing, success, upToDate, failed }

class DaylysportSyncState {
  const DaylysportSyncState({
    required this.phase,
    required this.statusText,
    required this.watcherSupported,
    this.lastResult,
    this.lastCheckedAtUtc,
    this.lastCompletedAtUtc,
    this.errorMessage,
    this.currentFile,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.importedFiles = 0,
    this.skippedFiles = 0,
    this.failedFiles = 0,
  });

  const DaylysportSyncState.initial()
    : phase = DaylysportSyncPhase.idle,
      statusText = 'Waiting to scan daylySport data',
      watcherSupported = false,
      lastResult = null,
      lastCheckedAtUtc = null,
      lastCompletedAtUtc = null,
      errorMessage = null,
      currentFile = null,
      totalFiles = 0,
      processedFiles = 0,
      importedFiles = 0,
      skippedFiles = 0,
      failedFiles = 0;

  final DaylysportSyncPhase phase;
  final String statusText;
  final bool watcherSupported;
  final DaylysportSyncResult? lastResult;
  final DateTime? lastCheckedAtUtc;
  final DateTime? lastCompletedAtUtc;
  final String? errorMessage;
  final String? currentFile;
  final int totalFiles;
  final int processedFiles;
  final int importedFiles;
  final int skippedFiles;
  final int failedFiles;

  bool get isBusy {
    return phase == DaylysportSyncPhase.scanning ||
        phase == DaylysportSyncPhase.synchronizing;
  }

  DaylysportSyncState copyWith({
    DaylysportSyncPhase? phase,
    String? statusText,
    bool? watcherSupported,
    DaylysportSyncResult? lastResult,
    DateTime? lastCheckedAtUtc,
    DateTime? lastCompletedAtUtc,
    String? errorMessage,
    String? currentFile,
    int? totalFiles,
    int? processedFiles,
    int? importedFiles,
    int? skippedFiles,
    int? failedFiles,
    bool clearError = false,
    bool clearCurrentFile = false,
  }) {
    return DaylysportSyncState(
      phase: phase ?? this.phase,
      statusText: statusText ?? this.statusText,
      watcherSupported: watcherSupported ?? this.watcherSupported,
      lastResult: lastResult ?? this.lastResult,
      lastCheckedAtUtc: lastCheckedAtUtc ?? this.lastCheckedAtUtc,
      lastCompletedAtUtc: lastCompletedAtUtc ?? this.lastCompletedAtUtc,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentFile: clearCurrentFile ? null : (currentFile ?? this.currentFile),
      totalFiles: totalFiles ?? this.totalFiles,
      processedFiles: processedFiles ?? this.processedFiles,
      importedFiles: importedFiles ?? this.importedFiles,
      skippedFiles: skippedFiles ?? this.skippedFiles,
      failedFiles: failedFiles ?? this.failedFiles,
    );
  }
}

class DaylysportRefreshBus extends Notifier<Map<DaylysportDataDomain, int>> {
  @override
  Map<DaylysportDataDomain, int> build() {
    return {
      for (final domain in DaylysportDataDomain.values) domain: 0,
    };
  }

  void bump(Iterable<DaylysportDataDomain> domains) {
    final next = Map<DaylysportDataDomain, int>.from(state);
    for (final domain in domains) {
      next[domain] = (next[domain] ?? 0) + 1;
    }
    state = next;
  }

  void bumpAll() {
    bump(DaylysportDataDomain.values);
  }
}

final daylysportRefreshBusProvider =
    NotifierProvider<DaylysportRefreshBus, Map<DaylysportDataDomain, int>>(
      DaylysportRefreshBus.new,
    );

final daylysportRefreshTokenProvider = Provider.family<int, DaylysportDataDomain>((
  ref,
  domain,
) {
  return ref.watch(
    daylysportRefreshBusProvider.select((state) => state[domain] ?? 0),
  );
});

final dataRefreshTokenProvider = Provider<int>((ref) {
  var total = 0;
  for (final domain in DaylysportDataDomain.values) {
    total += ref.watch(daylysportRefreshTokenProvider(domain));
  }
  return total;
});

final daylysportSyncControllerProvider =
    NotifierProvider<DaylysportSyncController, DaylysportSyncState>(
      DaylysportSyncController.new,
    );

final daylysportAutoMonitoringEnabledProvider = Provider<bool>((ref) => true);

class DaylysportSyncController extends Notifier<DaylysportSyncState> {
  StreamSubscription<void>? _watchSubscription;
  Timer? _watchDebounce;
  bool _monitoringStarted = false;
  DateTime? _lastResumeAttemptAtUtc;

  @override
  DaylysportSyncState build() {
    ref.onDispose(() async {
      _watchDebounce?.cancel();
      await _watchSubscription?.cancel();
    });
    return const DaylysportSyncState.initial();
  }

  Future<void> ensureMonitoringStarted() async {
    if (_monitoringStarted) {
      return;
    }
    _monitoringStarted = true;

    final services = ref.read(appServicesProvider);
    final stream = await services.daylysportSyncCoordinator.watchJsonChanges();
    state = state.copyWith(watcherSupported: stream != null);
    if (stream == null) {
      return;
    }

    _watchSubscription = stream.listen((_) {
      _watchDebounce?.cancel();
      _watchDebounce = Timer(const Duration(milliseconds: 1200), () {
        unawaited(runBackgroundSync(triggerType: 'watch'));
      });
    });
  }

  Future<DaylysportSyncResult> runStartupSync() {
    return _runSync(
      triggerType: 'startup',
      preferTrackedPaths: true,
      announceScanning: false,
    );
  }

  Future<DaylysportSyncResult> runManualSync() {
    return _runSync(triggerType: 'manual', announceScanning: true);
  }

  Future<DaylysportSyncResult> runBackgroundSync({
    required String triggerType,
  }) {
    return _runSync(triggerType: triggerType, announceScanning: false);
  }

  Future<void> runResumeSyncIfNeeded() async {
    final now = DateTime.now().toUtc();
    final lastAttempt = _lastResumeAttemptAtUtc;
    if (lastAttempt != null && now.difference(lastAttempt).inSeconds < 20) {
      return;
    }

    _lastResumeAttemptAtUtc = now;
    await runBackgroundSync(triggerType: 'resume');
  }

  void recordSyncResult(DaylysportSyncResult result) {
    state = state.copyWith(
      lastResult: result,
      lastCheckedAtUtc: result.finishedAtUtc,
      lastCompletedAtUtc:
          result.status == DaylysportSyncStatus.failed
              ? state.lastCompletedAtUtc
              : result.finishedAtUtc,
      phase: _phaseForResult(result),
      statusText: _statusTextForResult(result),
      errorMessage: result.errorMessage,
      clearCurrentFile: true,
      totalFiles: result.importReport?.processedFileCount ?? 0,
      processedFiles: result.importReport?.processedFileCount ?? 0,
      importedFiles: result.importReport?.importedFileCount ?? 0,
      skippedFiles: result.importReport?.skippedFileCount ?? 0,
      failedFiles: result.importReport?.failedFileCount ?? 0,
    );
  }

  Future<DaylysportSyncResult> _runSync({
    required String triggerType,
    required bool announceScanning,
    bool preferTrackedPaths = false,
  }) async {
    state = state.copyWith(
      phase:
          announceScanning
              ? DaylysportSyncPhase.scanning
              : DaylysportSyncPhase.synchronizing,
      statusText:
          announceScanning
              ? 'Scanning daylySport folder'
              : 'Checking daylySport data',
      lastCheckedAtUtc: DateTime.now().toUtc(),
      clearError: true,
      clearCurrentFile: true,
      totalFiles: 0,
      processedFiles: 0,
      importedFiles: 0,
      skippedFiles: 0,
      failedFiles: 0,
    );

    final services = ref.read(appServicesProvider);
    final result = await services.daylysportSyncCoordinator.synchronize(
      triggerType: triggerType,
      preferTrackedPaths: preferTrackedPaths,
      onProgress: _handleProgress,
    );

    if (result.status != DaylysportSyncStatus.failed) {
      _applySyncImpact(result);
    }
    recordSyncResult(result);
    return result;
  }

  void _handleProgress(ImportProgressUpdate update) {
    state = state.copyWith(
      phase: DaylysportSyncPhase.synchronizing,
      statusText: _statusTextForProgress(update),
      currentFile: update.currentRelativePath,
      totalFiles: update.totalFiles,
      processedFiles: update.processedFiles,
      importedFiles: update.importedFiles,
      skippedFiles: update.skippedFiles,
      failedFiles: update.failedFiles,
    );
  }

  void _applySyncImpact(DaylysportSyncResult result) {
    final services = ref.read(appServicesProvider);
    final affectedDomains = result.affectedDomains;
    if (affectedDomains.isEmpty && !result.hasChanges) {
      return;
    }

    if (affectedDomains.contains(DaylysportDataDomain.assets) ||
        affectedDomains.contains(DaylysportDataDomain.catalog) ||
        affectedDomains.contains(DaylysportDataDomain.playerStats)) {
      services.assetResolver.invalidateCache(clearPersistent: true);
    }

    if (affectedDomains.contains(DaylysportDataDomain.standings)) {
      services.leagueStandingsSource.invalidateCache(clearPersistent: true);
    }

    if (affectedDomains.isEmpty) {
      ref.read(daylysportRefreshBusProvider.notifier).bumpAll();
      return;
    }

    ref.read(daylysportRefreshBusProvider.notifier).bump(affectedDomains);
  }

  DaylysportSyncPhase _phaseForResult(DaylysportSyncResult result) {
    switch (result.status) {
      case DaylysportSyncStatus.synchronized:
        return DaylysportSyncPhase.success;
      case DaylysportSyncStatus.upToDate:
        return DaylysportSyncPhase.upToDate;
      case DaylysportSyncStatus.failed:
        return DaylysportSyncPhase.failed;
    }
  }

  String _statusTextForResult(DaylysportSyncResult result) {
    switch (result.status) {
      case DaylysportSyncStatus.synchronized:
        final report = result.importReport;
        if (report == null) {
          return 'Synchronization completed';
        }
        return 'Synchronized ${report.importedFileCount} changed file${report.importedFileCount == 1 ? '' : 's'}';
      case DaylysportSyncStatus.upToDate:
        return 'daylySport data is already up to date';
      case DaylysportSyncStatus.failed:
        return 'Synchronization failed';
    }
  }

  String _statusTextForProgress(ImportProgressUpdate update) {
    switch (update.stage) {
      case 'queued':
        return 'Preparing changed datasets';
      case 'imported':
        return 'Imported ${update.processedFiles} of ${update.totalFiles} changed files';
      case 'skipped':
        return 'Checked ${update.processedFiles} of ${update.totalFiles} changed files';
      case 'failed':
        return 'Import issue in ${update.currentRelativePath ?? 'current file'}';
      default:
        return 'Synchronizing daylySport data';
    }
  }
}