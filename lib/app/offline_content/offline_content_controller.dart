import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:eri_sports/features/news/presentation/offline_news_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _offlineContentScope = 'offline_content_v1';
const _offlineSeenKey = 'seen_items';
const _offlineMediaInventoryKey = 'media_inventory';
const _offlineNewsInventoryKey = 'news_inventory';

String offlineContentMediaItemId(DaylySportMediaItem item) {
  return 'media|${item.relativePath}|${item.lastModified.toUtc().millisecondsSinceEpoch}|${item.sizeBytes}';
}

String offlineContentNewsItemId(OfflineNewsMediaItem item) {
  return 'news|${item.file.path}|${item.lastModified.toUtc().millisecondsSinceEpoch}|${item.sizeBytes}';
}

bool isOfflineMediaItemSeen(
  DaylySportMediaItem item,
  Set<String> seenItemIds,
) {
  return seenItemIds.contains(offlineContentMediaItemId(item));
}

bool isOfflineNewsItemSeen(
  OfflineNewsMediaItem item,
  Set<String> seenItemIds,
) {
  return seenItemIds.contains(offlineContentNewsItemId(item));
}

List<DaylySportMediaItem> sortOfflineMediaItemsForDisplay(
  Iterable<DaylySportMediaItem> items,
  Set<String> seenItemIds,
) {
  final sorted = items.toList(growable: false);
  sorted.sort((a, b) {
    return _compareOfflineDisplayPriority(
      aSeen: isOfflineMediaItemSeen(a, seenItemIds),
      bSeen: isOfflineMediaItemSeen(b, seenItemIds),
      aModifiedAtUtc: a.lastModified,
      bModifiedAtUtc: b.lastModified,
      aTieBreaker: a.relativePath,
      bTieBreaker: b.relativePath,
    );
  });
  return sorted;
}

List<OfflineNewsMediaItem> sortOfflineNewsItemsForDisplay(
  Iterable<OfflineNewsMediaItem> items,
  Set<String> seenItemIds,
) {
  final sorted = items.toList(growable: false);
  sorted.sort((a, b) {
    return _compareOfflineDisplayPriority(
      aSeen: isOfflineNewsItemSeen(a, seenItemIds),
      bSeen: isOfflineNewsItemSeen(b, seenItemIds),
      aModifiedAtUtc: a.lastModified,
      bModifiedAtUtc: b.lastModified,
      aTieBreaker: a.file.path,
      bTieBreaker: b.file.path,
    );
  });
  return sorted;
}

int _compareOfflineDisplayPriority({
  required bool aSeen,
  required bool bSeen,
  required DateTime aModifiedAtUtc,
  required DateTime bModifiedAtUtc,
  required String aTieBreaker,
  required String bTieBreaker,
}) {
  final seenComparison = (aSeen ? 1 : 0).compareTo(bSeen ? 1 : 0);
  if (seenComparison != 0) {
    return seenComparison;
  }

  final modifiedComparison = bModifiedAtUtc.compareTo(aModifiedAtUtc);
  if (modifiedComparison != 0) {
    return modifiedComparison;
  }

  return aTieBreaker.toLowerCase().compareTo(bTieBreaker.toLowerCase());
}

enum OfflineContentManualAction { sync, decrypt, cache }

enum OfflineContentRefreshTrigger { startup, manual, syncResult }

enum OfflineContentKind {
  reel,
  videoHighlights,
  videoNews,
  videoUpdates,
  newsImage,
}

class OfflineContentItemRecord {
  const OfflineContentItemRecord({
    required this.id,
    required this.relativePath,
    required this.kind,
    required this.discoveredAtUtc,
    required this.modifiedAtUtc,
    required this.sizeBytes,
  });

  final String id;
  final String relativePath;
  final OfflineContentKind kind;
  final DateTime discoveredAtUtc;
  final DateTime modifiedAtUtc;
  final int sizeBytes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'relativePath': relativePath,
      'kind': kind.name,
      'discoveredAtEpochMs': discoveredAtUtc.toUtc().millisecondsSinceEpoch,
      'modifiedAtEpochMs': modifiedAtUtc.toUtc().millisecondsSinceEpoch,
      'sizeBytes': sizeBytes,
    };
  }

  static OfflineContentItemRecord? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final relativePath = json['relativePath'];
    final kindName = json['kind'];
    final discoveredAtEpochMs = json['discoveredAtEpochMs'];
    final modifiedAtEpochMs = json['modifiedAtEpochMs'];
    final sizeBytes = json['sizeBytes'];
    if (id is! String ||
        relativePath is! String ||
        kindName is! String ||
        discoveredAtEpochMs is! int ||
        modifiedAtEpochMs is! int ||
        sizeBytes is! int) {
      return null;
    }

    final kind = OfflineContentKind.values.where(
      (value) => value.name == kindName,
    );
    if (kind.isEmpty) {
      return null;
    }

    return OfflineContentItemRecord(
      id: id,
      relativePath: relativePath,
      kind: kind.first,
      discoveredAtUtc: DateTime.fromMillisecondsSinceEpoch(
        discoveredAtEpochMs,
        isUtc: true,
      ),
      modifiedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        modifiedAtEpochMs,
        isUtc: true,
      ),
      sizeBytes: sizeBytes,
    );
  }
}

class OfflineContentBadgeCounts {
  const OfflineContentBadgeCounts({
    required this.reels,
    required this.videoTotal,
    required this.videoHighlights,
    required this.videoNews,
    required this.videoUpdates,
    required this.newsImages,
  });

  const OfflineContentBadgeCounts.zero()
    : reels = 0,
      videoTotal = 0,
      videoHighlights = 0,
      videoNews = 0,
      videoUpdates = 0,
      newsImages = 0;

  final int reels;
  final int videoTotal;
  final int videoHighlights;
  final int videoNews;
  final int videoUpdates;
  final int newsImages;

  bool get hasAny =>
      reels > 0 ||
      videoTotal > 0 ||
      videoHighlights > 0 ||
      videoNews > 0 ||
      videoUpdates > 0 ||
      newsImages > 0;
}

class OfflineContentDeletionProgress {
  const OfflineContentDeletionProgress({
    required this.totalCount,
    required this.currentIndex,
    required this.completedCount,
    required this.currentLabel,
    required this.currentFileName,
    required this.deletedCount,
    required this.missingCount,
    required this.failedCount,
  });

  final int totalCount;
  final int currentIndex;
  final int completedCount;
  final String currentLabel;
  final String currentFileName;
  final int deletedCount;
  final int missingCount;
  final int failedCount;

  double get progressValue {
    if (totalCount <= 0) {
      return 0;
    }
    return (currentIndex / totalCount).clamp(0.0, 1.0);
  }

  int get progressPercent => (progressValue * 100).round().clamp(0, 100);

  String get progressText => 'Deleting $currentIndex of $totalCount items...';

  String get detailText {
    if (currentFileName.isEmpty) {
      return currentLabel;
    }
    return '$currentLabel - $currentFileName';
  }
}

class OfflineContentDeleteResult {
  const OfflineContentDeleteResult({
    required this.requestedCount,
    required this.deletedCount,
    required this.missingCount,
    required this.failedCount,
    required this.cacheWarningCount,
    required this.failedPaths,
  });

  const OfflineContentDeleteResult.zero()
    : requestedCount = 0,
      deletedCount = 0,
      missingCount = 0,
      failedCount = 0,
      cacheWarningCount = 0,
      failedPaths = const <String>[];

  final int requestedCount;
  final int deletedCount;
  final int missingCount;
  final int failedCount;
  final int cacheWarningCount;
  final List<String> failedPaths;

  int get removedOrMissingCount => deletedCount + missingCount;

  bool get hasFailures => failedCount > 0;

  bool get hasCacheWarnings => cacheWarningCount > 0;
}

class OfflineContentRefreshState {
  const OfflineContentRefreshState({
    required this.isBusy,
    required this.statusText,
    required this.badges,
    required this.seenItemIds,
    this.deletionProgress,
    this.lastCompletedAtUtc,
    this.lastError,
  });

  const OfflineContentRefreshState.initial()
    : isBusy = false,
      statusText = 'Offline content is ready',
      badges = const OfflineContentBadgeCounts.zero(),
      seenItemIds = const <String>{},
      deletionProgress = null,
      lastCompletedAtUtc = null,
      lastError = null;

  final bool isBusy;
  final String statusText;
  final OfflineContentBadgeCounts badges;
  final Set<String> seenItemIds;
  final OfflineContentDeletionProgress? deletionProgress;
  final DateTime? lastCompletedAtUtc;
  final String? lastError;

  OfflineContentRefreshState copyWith({
    bool? isBusy,
    String? statusText,
    OfflineContentBadgeCounts? badges,
    Set<String>? seenItemIds,
    OfflineContentDeletionProgress? deletionProgress,
    DateTime? lastCompletedAtUtc,
    String? lastError,
    bool clearError = false,
    bool clearDeletionProgress = false,
  }) {
    return OfflineContentRefreshState(
      isBusy: isBusy ?? this.isBusy,
      statusText: statusText ?? this.statusText,
      badges: badges ?? this.badges,
        seenItemIds: seenItemIds ?? this.seenItemIds,
      deletionProgress:
          clearDeletionProgress
              ? null
              : (deletionProgress ?? this.deletionProgress),
      lastCompletedAtUtc: lastCompletedAtUtc ?? this.lastCompletedAtUtc,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

final offlineContentRefreshControllerProvider = NotifierProvider<
  OfflineContentRefreshController,
  OfflineContentRefreshState
>(OfflineContentRefreshController.new);

final offlineContentBadgeCountsProvider = Provider<OfflineContentBadgeCounts>((
  ref,
) {
  return ref.watch(offlineContentRefreshControllerProvider).badges;
});

final offlineSeenItemIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(offlineContentRefreshControllerProvider).seenItemIds;
});

final offlineContentDeletionProgressProvider =
    Provider<OfflineContentDeletionProgress?>((ref) {
      return ref
          .watch(offlineContentRefreshControllerProvider)
          .deletionProgress;
    });

class OfflineContentRefreshController
    extends Notifier<OfflineContentRefreshState> {
  Future<void>? _activeRefresh;

  @override
  OfflineContentRefreshState build() {
    final services = ref.read(appServicesProvider);
    final seenItemIds = _loadSeenItemIds(services);
    final existingBadges = _buildBadges(
      _loadMediaInventory(services),
      _loadNewsInventory(services),
      seenItemIds,
    );
    return OfflineContentRefreshState.initial().copyWith(
      badges: existingBadges,
      seenItemIds: seenItemIds,
    );
  }

  Future<void> refreshOnStartup() {
    return _runRefresh(
      trigger: OfflineContentRefreshTrigger.startup,
      statusText: 'Refreshing encrypted offline content',
      runSync: false,
    );
  }

  Future<void> refreshAfterSync() {
    return _runRefresh(
      trigger: OfflineContentRefreshTrigger.syncResult,
      statusText: 'Updating offline content cache',
      runSync: false,
    );
  }

  Future<void> runManualAction(OfflineContentManualAction action) {
    switch (action) {
      case OfflineContentManualAction.sync:
        return _runRefresh(
          trigger: OfflineContentRefreshTrigger.manual,
          statusText: 'Synchronizing offline encrypted content',
          runSync: true,
        );
      case OfflineContentManualAction.decrypt:
        return _runRefresh(
          trigger: OfflineContentRefreshTrigger.manual,
          statusText: 'Prewarming encrypted content',
          runSync: false,
          forcePrewarm: true,
        );
      case OfflineContentManualAction.cache:
        return _runRefresh(
          trigger: OfflineContentRefreshTrigger.manual,
          statusText: 'Refreshing offline content cache',
          runSync: false,
          forcePrewarm: true,
        );
    }
  }

  Future<void> markMediaItemSeen(DaylySportMediaItem item) async {
    await _markSeen(offlineContentMediaItemId(item));
  }

  Future<void> markNewsItemSeen(OfflineNewsMediaItem item) async {
    await _markSeen(offlineContentNewsItemId(item));
  }

  Future<void> markNewsItemsSeen(Iterable<OfflineNewsMediaItem> items) async {
    final ids = items.map(offlineContentNewsItemId).toSet();
    await _markSeenMany(ids);
  }

  Future<OfflineContentDeleteResult> deleteItems({
    Iterable<DaylySportMediaItem> mediaItems = const <DaylySportMediaItem>[],
    Iterable<OfflineNewsMediaItem> newsItems = const <OfflineNewsMediaItem>[],
  }) async {
    final pendingRefresh = _activeRefresh;
    if (pendingRefresh != null) {
      try {
        await pendingRefresh;
      } catch (_) {
        // Ignore stale refresh failures; deletion still needs to proceed.
      }
    }

    final targets = <String, _OfflineDeletionTarget>{
      for (final item in mediaItems)
        item.file.path: _OfflineDeletionTarget.media(
          id: offlineContentMediaItemId(item),
          file: item.file,
          kind: _contentKindForMedia(item),
        ),
      for (final item in newsItems)
        item.file.path: _OfflineDeletionTarget.news(
          id: offlineContentNewsItemId(item),
          file: item.file,
        ),
    }.values.toList(growable: false);

    if (targets.isEmpty) {
      return const OfflineContentDeleteResult.zero();
    }

    state = state.copyWith(
      isBusy: true,
      statusText: 'Preparing deletion',
      clearError: true,
      clearDeletionProgress: true,
    );

    final services = ref.read(appServicesProvider);
    final previousMedia = _loadMediaInventory(services);
    final previousNews = _loadNewsInventory(services);
    final removedIds = <String>{};
    final failedPaths = <String>[];
    var deletedCount = 0;
    var missingCount = 0;
    var failedCount = 0;
    var cacheWarningCount = 0;

    for (var index = 0; index < targets.length; index++) {
      final target = targets[index];
      _setDeletionProgress(
        targets: targets,
        currentIndex: index + 1,
        completedCount: deletedCount + missingCount + failedCount,
        deletedCount: deletedCount,
        missingCount: missingCount,
        failedCount: failedCount,
      );

      final outcome = await _deleteTarget(services, target);
      if (outcome.deleted) {
        deletedCount += 1;
        removedIds.add(target.id);
      } else if (outcome.missing) {
        missingCount += 1;
        removedIds.add(target.id);
      } else {
        failedCount += 1;
        failedPaths.add(target.file.path);
      }
      if (outcome.cacheWarning) {
        cacheWarningCount += 1;
      }
    }

    _setDeletionProgress(
      targets: targets,
      currentIndex: targets.length,
      completedCount: targets.length,
      deletedCount: deletedCount,
      missingCount: missingCount,
      failedCount: failedCount,
      statusText: 'Finalizing offline content deletion...',
    );

    try {
      if (removedIds.isNotEmpty) {
        final seenIds = _loadSeenItemIds(services)..removeAll(removedIds);
        await _persistSeenItemIds(services, seenIds);
      }

      final synced = await _scanAndPersistOfflineContent(
        services: services,
        previousMedia: previousMedia,
        previousNews: previousNews,
        prewarm: false,
      );

      if (removedIds.isNotEmpty) {
        ref.read(daylysportRefreshBusProvider.notifier).bumpAll();
        ref.invalidate(daylySportMediaRepositoryProvider);
        ref.invalidate(daylySportMediaSnapshotProvider);
        ref.invalidate(offlineNewsRepositoryProvider);
        ref.invalidate(offlineNewsGalleryProvider);
      }

      final hasHardFailures = failedCount > 0;
      final statusText =
          hasHardFailures
              ? 'Offline content deleted with some issues'
              : 'Offline content is ready';
      state = state.copyWith(
        isBusy: false,
        statusText: statusText,
        badges: synced.badges,
        seenItemIds: _loadSeenItemIds(services),
        lastCompletedAtUtc: DateTime.now().toUtc(),
        lastError:
            hasHardFailures
                ? 'Unable to delete $failedCount item${failedCount == 1 ? '' : 's'}.'
                : null,
        clearError: !hasHardFailures,
        clearDeletionProgress: true,
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        statusText: 'Offline content deletion failed',
        lastError: '$error',
        clearDeletionProgress: true,
      );
    }

    return OfflineContentDeleteResult(
      requestedCount: targets.length,
      deletedCount: deletedCount,
      missingCount: missingCount,
      failedCount: failedCount,
      cacheWarningCount: cacheWarningCount,
      failedPaths: failedPaths,
    );
  }

  Future<void> _runRefresh({
    required OfflineContentRefreshTrigger trigger,
    required String statusText,
    required bool runSync,
    bool forcePrewarm = false,
  }) {
    final existing = _activeRefresh;
    if (existing != null) {
      return existing;
    }

    final future = _refreshInternal(
      trigger: trigger,
      statusText: statusText,
      runSync: runSync,
      forcePrewarm: forcePrewarm,
    );
    _activeRefresh = future;
    return future.whenComplete(() {
      if (identical(_activeRefresh, future)) {
        _activeRefresh = null;
      }
    });
  }

  Future<void> _refreshInternal({
    required OfflineContentRefreshTrigger trigger,
    required String statusText,
    required bool runSync,
    required bool forcePrewarm,
  }) async {
    state = state.copyWith(
      isBusy: true,
      statusText: statusText,
      clearError: true,
      clearDeletionProgress: true,
    );
    final services = ref.read(appServicesProvider);

    try {
      if (runSync) {
        await ref
            .read(daylysportSyncControllerProvider.notifier)
            .runManualSync();
      }

      final previousMedia = _loadMediaInventory(services);
      final previousNews = _loadNewsInventory(services);

      final synced = await _scanAndPersistOfflineContent(
        services: services,
        previousMedia: previousMedia,
        previousNews: previousNews,
        prewarm:
            forcePrewarm || trigger == OfflineContentRefreshTrigger.startup,
      );

      state = state.copyWith(
        isBusy: false,
        statusText: 'Offline content is ready',
        badges: synced.badges,
        seenItemIds: _loadSeenItemIds(services),
        lastCompletedAtUtc: DateTime.now().toUtc(),
        clearError: true,
        clearDeletionProgress: true,
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        statusText: 'Offline content refresh failed',
        lastError: '$error',
        clearDeletionProgress: true,
      );
    }
  }

  void _setDeletionProgress({
    required List<_OfflineDeletionTarget> targets,
    required int currentIndex,
    required int completedCount,
    required int deletedCount,
    required int missingCount,
    required int failedCount,
    String? statusText,
  }) {
    if (targets.isEmpty) {
      return;
    }

    final safeIndex = currentIndex.clamp(1, targets.length);
    final target = targets[safeIndex - 1];
    final progress = OfflineContentDeletionProgress(
      totalCount: targets.length,
      currentIndex: safeIndex,
      completedCount: completedCount.clamp(0, targets.length),
      currentLabel: _deletionLabelForKind(target.kind),
      currentFileName: _fileNameForPath(target.file.path),
      deletedCount: deletedCount,
      missingCount: missingCount,
      failedCount: failedCount,
    );

    state = state.copyWith(
      isBusy: true,
      statusText: statusText ?? progress.progressText,
      deletionProgress: progress,
      clearError: true,
    );
  }

  Future<void> _prewarmDetectedContent({
    required AppServices services,
    required DaylySportMediaSnapshot mediaSnapshot,
    required OfflineNewsGallerySnapshot newsSnapshot,
    required List<OfflineContentItemRecord> previousMedia,
    required List<OfflineContentItemRecord> previousNews,
    required bool forcePrewarm,
  }) async {
    final previousMediaIds = previousMedia.map((item) => item.id).toSet();
    final previousNewsIds = previousNews.map((item) => item.id).toSet();

    final mediaToPrewarm = <File>[];
    for (final section in DaylySportMediaSection.values) {
      for (final item in mediaSnapshot.section(section).videoItems) {
        final id = offlineContentMediaItemId(item);
        if (forcePrewarm || !previousMediaIds.contains(id)) {
          mediaToPrewarm.add(item.file);
        }
      }
    }

    final newsToPrewarm = <File>[];
    for (final item in newsSnapshot.images) {
      final id = offlineContentNewsItemId(item);
      if (forcePrewarm || !previousNewsIds.contains(id)) {
        newsToPrewarm.add(item.file);
      }
    }

    if (mediaToPrewarm.isNotEmpty) {
      await services.encryptedMediaService.prewarmPlayableFiles(
        mediaToPrewarm,
        maxItems: forcePrewarm ? mediaToPrewarm.length : 6,
      );
    }

    if (newsToPrewarm.isNotEmpty) {
      await services.secureContentCoordinator.prewarmImages(
        newsToPrewarm,
        maxItems: forcePrewarm ? newsToPrewarm.length : 8,
      );
    }

    await services.secureContentCoordinator.prewarmJsonFiles(
      mediaSnapshot.rootDirectory,
      maxItems: forcePrewarm ? 24 : 8,
    );
  }

  Future<void> _markSeen(String id) async {
    await _markSeenMany(<String>{id});
  }

  Future<void> _markSeenMany(Set<String> ids) async {
    if (ids.isEmpty) {
      return;
    }

    final services = ref.read(appServicesProvider);
    final seenIds = _loadSeenItemIds(services)..addAll(ids);
    await _persistSeenItemIds(services, seenIds);
    state = state.copyWith(
      seenItemIds: seenIds,
      badges: _buildBadges(
        _loadMediaInventory(services),
        _loadNewsInventory(services),
        seenIds,
      ),
    );
  }

  OfflineContentBadgeCounts _buildBadges(
    List<OfflineContentItemRecord> mediaRecords,
    List<OfflineContentItemRecord> newsRecords,
    Set<String> seenItemIds,
  ) {
    var reels = 0;
    var videoHighlights = 0;
    var videoNews = 0;
    var videoUpdates = 0;
    var newsImages = 0;

    for (final item in mediaRecords) {
      if (seenItemIds.contains(item.id)) {
        continue;
      }
      switch (item.kind) {
        case OfflineContentKind.reel:
          reels += 1;
        case OfflineContentKind.videoHighlights:
          videoHighlights += 1;
        case OfflineContentKind.videoNews:
          videoNews += 1;
        case OfflineContentKind.videoUpdates:
          videoUpdates += 1;
        case OfflineContentKind.newsImage:
          break;
      }
    }

    for (final item in newsRecords) {
      if (!seenItemIds.contains(item.id)) {
        newsImages += 1;
      }
    }

    return OfflineContentBadgeCounts(
      reels: reels,
      videoTotal: videoHighlights + videoNews + videoUpdates,
      videoHighlights: videoHighlights,
      videoNews: videoNews,
      videoUpdates: videoUpdates,
      newsImages: newsImages,
    );
  }

  List<OfflineContentItemRecord> _buildMediaRecords(
    DaylySportMediaSnapshot snapshot,
    List<OfflineContentItemRecord> previous,
  ) {
    final previousById = {for (final item in previous) item.id: item};
    final next = <OfflineContentItemRecord>[];

    for (final section in DaylySportMediaSection.values) {
      for (final item in snapshot.section(section).videoItems) {
        final id = offlineContentMediaItemId(item);
        final existing = previousById[id];
        next.add(
          OfflineContentItemRecord(
            id: id,
            relativePath: item.relativePath,
            kind: _contentKindForMedia(item),
            discoveredAtUtc:
                existing?.discoveredAtUtc ?? DateTime.now().toUtc(),
            modifiedAtUtc: item.lastModified.toUtc(),
            sizeBytes: item.sizeBytes,
          ),
        );
      }
    }

    next.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return next;
  }

  List<OfflineContentItemRecord> _buildNewsRecords(
    OfflineNewsGallerySnapshot snapshot,
    List<OfflineContentItemRecord> previous,
  ) {
    final previousById = {for (final item in previous) item.id: item};
    final next = <OfflineContentItemRecord>[];
    for (final item in snapshot.images) {
      final id = offlineContentNewsItemId(item);
      final existing = previousById[id];
      next.add(
        OfflineContentItemRecord(
          id: id,
          relativePath: item.file.path,
          kind: OfflineContentKind.newsImage,
          discoveredAtUtc: existing?.discoveredAtUtc ?? DateTime.now().toUtc(),
          modifiedAtUtc: item.lastModified.toUtc(),
          sizeBytes: item.sizeBytes,
        ),
      );
    }

    next.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return next;
  }

  OfflineContentKind _contentKindForMedia(DaylySportMediaItem item) {
    switch (item.section) {
      case DaylySportMediaSection.reels:
        return OfflineContentKind.reel;
      case DaylySportMediaSection.highlights:
        return OfflineContentKind.videoHighlights;
      case DaylySportMediaSection.news:
        return OfflineContentKind.videoNews;
      case DaylySportMediaSection.updates:
        return OfflineContentKind.videoUpdates;
    }
  }

  Set<String> _loadSeenItemIds(AppServices services) {
    return services.cacheStore
        .readPathList(_offlineContentScope, _offlineSeenKey)
        .toSet();
  }

  Future<void> _persistSeenItemIds(AppServices services, Set<String> ids) {
    return services.cacheStore.writePathList(
      _offlineContentScope,
      _offlineSeenKey,
      ids.toList(growable: false)..sort(),
    );
  }

  List<OfflineContentItemRecord> _loadMediaInventory(AppServices services) {
    return _loadItemRecords(services.cacheStore, _offlineMediaInventoryKey);
  }

  List<OfflineContentItemRecord> _loadNewsInventory(AppServices services) {
    return _loadItemRecords(services.cacheStore, _offlineNewsInventoryKey);
  }

  Future<void> _persistMediaInventory(
    AppServices services,
    List<OfflineContentItemRecord> records,
  ) {
    return _persistItemRecords(
      services.cacheStore,
      _offlineMediaInventoryKey,
      records,
    );
  }

  Future<void> _persistNewsInventory(
    AppServices services,
    List<OfflineContentItemRecord> records,
  ) {
    return _persistItemRecords(
      services.cacheStore,
      _offlineNewsInventoryKey,
      records,
    );
  }

  List<OfflineContentItemRecord> _loadItemRecords(
    DaylySportCacheStore cacheStore,
    String key,
  ) {
    return cacheStore
        .readJsonObjectList(_offlineContentScope, key)
        .map(OfflineContentItemRecord.fromJson)
        .whereType<OfflineContentItemRecord>()
        .toList(growable: false);
  }

  Future<void> _persistItemRecords(
    DaylySportCacheStore cacheStore,
    String key,
    List<OfflineContentItemRecord> records,
  ) {
    return cacheStore.writeJsonObjectList(
      _offlineContentScope,
      key,
      records.map((record) => record.toJson()).toList(growable: false),
    );
  }

  Future<_OfflineContentScanResult> _scanAndPersistOfflineContent({
    required AppServices services,
    required List<OfflineContentItemRecord> previousMedia,
    required List<OfflineContentItemRecord> previousNews,
    required bool prewarm,
  }) async {
    final mediaRepository = DaylySportMediaRepository(
      daylySportLocator: services.daylySportLocator,
    );
    final newsRepository = OfflineNewsRepository(
      daylySportLocator: services.daylySportLocator,
    );

    final mediaSnapshot = await mediaRepository.loadSnapshot(
      forceRefresh: true,
    );
    final newsSnapshot = await newsRepository.loadGallery(forceRefresh: true);

    final mediaRecords = _buildMediaRecords(mediaSnapshot, previousMedia);
    final newsRecords = _buildNewsRecords(newsSnapshot, previousNews);

    await _persistMediaInventory(services, mediaRecords);
    await _persistNewsInventory(services, newsRecords);

    if (prewarm) {
      await _prewarmDetectedContent(
        services: services,
        mediaSnapshot: mediaSnapshot,
        newsSnapshot: newsSnapshot,
        previousMedia: previousMedia,
        previousNews: previousNews,
        forcePrewarm: true,
      );
    }

    return _OfflineContentScanResult(
      mediaRecords: mediaRecords,
      newsRecords: newsRecords,
      badges: _buildBadges(
        mediaRecords,
        newsRecords,
        _loadSeenItemIds(services),
      ),
    );
  }

  Future<_OfflineDeletionOutcome> _deleteTarget(
    AppServices services,
    _OfflineDeletionTarget target,
  ) async {
    var cacheWarning = false;
    var deleted = false;
    var missing = false;

    try {
      if (await target.file.exists()) {
        await target.file.delete();
        deleted = true;
      } else {
        missing = true;
      }
    } catch (_) {
      return const _OfflineDeletionOutcome.failed();
    }

    try {
      switch (target.kind) {
        case OfflineContentKind.newsImage:
          await services.encryptedImageService.evictSourceFile(target.file);
        case OfflineContentKind.reel:
        case OfflineContentKind.videoHighlights:
        case OfflineContentKind.videoNews:
        case OfflineContentKind.videoUpdates:
          await services.encryptedMediaService.evictSourceFile(target.file);
      }
    } catch (_) {
      cacheWarning = true;
    }

    return _OfflineDeletionOutcome(
      deleted: deleted,
      missing: missing,
      cacheWarning: cacheWarning,
    );
  }

  String _deletionLabelForKind(OfflineContentKind kind) {
    switch (kind) {
      case OfflineContentKind.reel:
        return 'Reel';
      case OfflineContentKind.videoHighlights:
      case OfflineContentKind.videoNews:
      case OfflineContentKind.videoUpdates:
        return 'Video';
      case OfflineContentKind.newsImage:
        return 'News image';
    }
  }

  String _fileNameForPath(String path) {
    final file = File(path);
    if (file.uri.pathSegments.isNotEmpty) {
      return file.uri.pathSegments.last;
    }
    return path;
  }
}

class _OfflineContentScanResult {
  const _OfflineContentScanResult({
    required this.mediaRecords,
    required this.newsRecords,
    required this.badges,
  });

  final List<OfflineContentItemRecord> mediaRecords;
  final List<OfflineContentItemRecord> newsRecords;
  final OfflineContentBadgeCounts badges;
}

class _OfflineDeletionTarget {
  const _OfflineDeletionTarget._({
    required this.id,
    required this.file,
    required this.kind,
  });

  factory _OfflineDeletionTarget.media({
    required String id,
    required File file,
    required OfflineContentKind kind,
  }) {
    return _OfflineDeletionTarget._(id: id, file: file, kind: kind);
  }

  factory _OfflineDeletionTarget.news({
    required String id,
    required File file,
  }) {
    return _OfflineDeletionTarget._(
      id: id,
      file: file,
      kind: OfflineContentKind.newsImage,
    );
  }

  final String id;
  final File file;
  final OfflineContentKind kind;
}

class _OfflineDeletionOutcome {
  const _OfflineDeletionOutcome({
    required this.deleted,
    required this.missing,
    required this.cacheWarning,
  });

  const _OfflineDeletionOutcome.failed()
    : deleted = false,
      missing = false,
      cacheWarning = false;

  final bool deleted;
  final bool missing;
  final bool cacheWarning;
}
