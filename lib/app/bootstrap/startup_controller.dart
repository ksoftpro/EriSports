import 'dart:async';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/features/bookmarks/presentation/bookmarks_providers.dart';
import 'package:eri_sports/features/home/presentation/home_providers.dart';
import 'package:eri_sports/features/leagues/presentation/leagues_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final dataRefreshTokenProvider = StateProvider<int>((ref) => 0);

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
      final report = await services.importCoordinator.runLocalImport(
        triggerType: 'startup',
      );

      services.assetResolver.invalidateCache(clearPersistent: true);
      services.leagueStandingsSource.invalidateCache(clearPersistent: true);

      ref.read(dataRefreshTokenProvider.notifier).state++;
      ref.invalidate(homeFeedProvider);
      ref.invalidate(followingDashboardProvider);
      ref.invalidate(leaguesProvider);

      state = state.copyWith(
        phase: StartupPhase.ready,
        hasCachedData: true,
        statusText: blocking ? 'Offline data ready' : 'Offline data refreshed',
        latestReport: report,
        clearError: true,
      );
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
}
