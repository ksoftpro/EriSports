import 'dart:async';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _startupLastRefreshEpochKey = 'startup.last_refresh_epoch_ms';
const _startupRefreshCooldown = Duration(minutes: 4);

enum StartupPhase { idle, blockingImport, backgroundRefresh, ready, failed }

@immutable
class StartupState {
  const StartupState({
    required this.phase,
    required this.hasCachedData,
    required this.statusText,
    this.latestReport,
    this.errorMessage,
  });

  const StartupState.initial()
    : phase = StartupPhase.idle,
      hasCachedData = false,
      statusText = 'Preparing offline data',
      latestReport = null,
      errorMessage = null;

  final StartupPhase phase;
  final bool hasCachedData;
  final String statusText;
  final ImportRunReport? latestReport;
  final String? errorMessage;

  bool get showBlockingOverlay {
    return !hasCachedData &&
        (phase == StartupPhase.blockingImport || phase == StartupPhase.failed);
  }

  bool get isBackgroundRefreshing => phase == StartupPhase.backgroundRefresh;

  StartupState copyWith({
    StartupPhase? phase,
    bool? hasCachedData,
    String? statusText,
    ImportRunReport? latestReport,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StartupState(
      phase: phase ?? this.phase,
      hasCachedData: hasCachedData ?? this.hasCachedData,
      statusText: statusText ?? this.statusText,
      latestReport: latestReport ?? this.latestReport,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final startupControllerProvider =
    NotifierProvider<StartupController, StartupState>(StartupController.new);

final startupImportReportProvider = Provider<ImportRunReport?>((ref) {
  return ref.watch(startupControllerProvider).latestReport;
});

class StartupController extends Notifier<StartupState> {
  bool _started = false;

  @override
  StartupState build() {
    return const StartupState.initial();
  }

  Future<void> ensureStarted() async {
    if (_started) {
      return;
    }
    _started = true;

    final services = ref.read(appServicesProvider);
    final hasCachedData = await services.database.hasBootstrapData();

    if (hasCachedData && _shouldSkipBackgroundRefresh()) {
      state = state.copyWith(
        phase: StartupPhase.ready,
        hasCachedData: true,
        statusText: 'Offline data ready',
        clearError: true,
      );
      _warmRuntimeCaches(services);
      return;
    }

    state = state.copyWith(
      phase:
          hasCachedData
              ? StartupPhase.backgroundRefresh
              : StartupPhase.blockingImport,
      hasCachedData: hasCachedData,
      statusText:
          hasCachedData
              ? 'Refreshing offline data in the background'
              : 'Loading offline matches, standings, and player data',
      clearError: true,
    );

    if (hasCachedData) {
      unawaited(_runStartupImport(services, blocking: false));
      _warmRuntimeCaches(services);
      return;
    }

    await _runStartupImport(services, blocking: true);
  }

  Future<void> retry() async {
    final services = ref.read(appServicesProvider);
    state = state.copyWith(
      phase: StartupPhase.blockingImport,
      statusText: 'Retrying offline data import',
      clearError: true,
    );
    await _runStartupImport(services, blocking: true);
  }

  Future<void> _runStartupImport(
    AppServices services, {
    required bool blocking,
  }) async {
    try {
      final result =
          await ref
              .read(daylysportSyncControllerProvider.notifier)
              .runStartupSync();
      final report = result.importReport;

      state = state.copyWith(
        phase: StartupPhase.ready,
        hasCachedData: true,
        statusText:
            blocking
                ? 'Offline data ready'
                : 'Offline data refreshed in the background',
        latestReport: report,
        clearError: true,
      );
      await _recordBackgroundRefresh(result.finishedAtUtc);
      _warmRuntimeCaches(services);
    } catch (error) {
      services.logger.error('Startup import failed.', error);
      state = state.copyWith(
        phase: blocking ? StartupPhase.failed : StartupPhase.ready,
        hasCachedData: state.hasCachedData,
        statusText:
            blocking
                ? 'Unable to load offline data'
                : 'Background refresh failed',
        errorMessage: error.toString(),
      );
    }
  }

  bool _shouldSkipBackgroundRefresh() {
    final prefs = ref.read(sharedPreferencesProvider);
    final lastEpochMs = prefs.getInt(_startupLastRefreshEpochKey);
    if (lastEpochMs == null || lastEpochMs <= 0) {
      return false;
    }

    final lastRefresh = DateTime.fromMillisecondsSinceEpoch(
      lastEpochMs,
      isUtc: true,
    );
    return DateTime.now().toUtc().difference(lastRefresh) <
        _startupRefreshCooldown;
  }

  Future<void> _recordBackgroundRefresh(DateTime timestampUtc) {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.setInt(
      _startupLastRefreshEpochKey,
      timestampUtc.toUtc().millisecondsSinceEpoch,
    );
  }

  void _warmRuntimeCaches(AppServices services) {
    unawaited(services.teamRawSource.warmUp(preloadBundle: false));
    unawaited(
      services.assetResolver.warmUp(
        includeTeamAssets: true,
        includePlayerAssets: true,
      ),
    );
    unawaited(services.encryptedMediaService.warmUpCache());
  }
}
