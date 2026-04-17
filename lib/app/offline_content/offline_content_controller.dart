import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _offlineContentScope = 'offline_content_v1';
const _offlineSeenKey = 'seen_items';
const _offlineMediaInventoryKey = 'media_inventory';
const _offlineNewsInventoryKey = 'news_inventory';

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

class OfflineContentRefreshState {
  const OfflineContentRefreshState({
    required this.isBusy,
    required this.statusText,
    required this.badges,
    this.lastCompletedAtUtc,
    this.lastError,
  });

  const OfflineContentRefreshState.initial()
    : isBusy = false,
      statusText = 'Offline content is ready',
      badges = const OfflineContentBadgeCounts.zero(),
      lastCompletedAtUtc = null,
      lastError = null;

  final bool isBusy;
  final String statusText;
  final OfflineContentBadgeCounts badges;
  final DateTime? lastCompletedAtUtc;
  final String? lastError;

  OfflineContentRefreshState copyWith({
    bool? isBusy,
    String? statusText,
    OfflineContentBadgeCounts? badges,
    DateTime? lastCompletedAtUtc,
    String? lastError,
    bool clearError = false,
  }) {
    return OfflineContentRefreshState(
      isBusy: isBusy ?? this.isBusy,
      statusText: statusText ?? this.statusText,
      badges: badges ?? this.badges,
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

class OfflineContentRefreshController
    extends Notifier<OfflineContentRefreshState> {
  Future<void>? _activeRefresh;

  @override
  OfflineContentRefreshState build() {
    final services = ref.read(appServicesProvider);
    final existingBadges = _buildBadges(
      _loadMediaInventory(services),
      _loadNewsInventory(services),
      _loadSeenItemIds(services),
    );
    return OfflineContentRefreshState.initial().copyWith(
      badges: existingBadges,
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
    await _markSeen(_mediaItemId(item));
  }

  Future<void> markNewsItemSeen(OfflineNewsMediaItem item) async {
    await _markSeen(_newsItemId(item));
  }

  Future<void> markNewsItemsSeen(Iterable<OfflineNewsMediaItem> items) async {
    final ids = items.map(_newsItemId).toSet();
    await _markSeenMany(ids);
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
    );
    final services = ref.read(appServicesProvider);

    try {
      if (runSync) {
        await ref
            .read(daylysportSyncControllerProvider.notifier)
            .runManualSync();
      }

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

      final previousMedia = _loadMediaInventory(services);
      final previousNews = _loadNewsInventory(services);

      final mediaRecords = _buildMediaRecords(mediaSnapshot, previousMedia);
      final newsRecords = _buildNewsRecords(newsSnapshot, previousNews);

      await _persistMediaInventory(services, mediaRecords);
      await _persistNewsInventory(services, newsRecords);

      await _prewarmDetectedContent(
        services: services,
        mediaSnapshot: mediaSnapshot,
        newsSnapshot: newsSnapshot,
        previousMedia: previousMedia,
        previousNews: previousNews,
        forcePrewarm:
            forcePrewarm || trigger == OfflineContentRefreshTrigger.startup,
      );

      final badges = _buildBadges(
        mediaRecords,
        newsRecords,
        _loadSeenItemIds(services),
      );

      state = state.copyWith(
        isBusy: false,
        statusText: 'Offline content is ready',
        badges: badges,
        lastCompletedAtUtc: DateTime.now().toUtc(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        statusText: 'Offline content refresh failed',
        lastError: '$error',
      );
    }
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
        final id = _mediaItemId(item);
        if (forcePrewarm || !previousMediaIds.contains(id)) {
          mediaToPrewarm.add(item.file);
        }
      }
    }

    final newsToPrewarm = <File>[];
    for (final item in newsSnapshot.images) {
      final id = _newsItemId(item);
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
        final id = _mediaItemId(item);
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
      final id = _newsItemId(item);
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

  String _mediaItemId(DaylySportMediaItem item) {
    return 'media|${item.relativePath}|${item.lastModified.toUtc().millisecondsSinceEpoch}|${item.sizeBytes}';
  }

  String _newsItemId(OfflineNewsMediaItem item) {
    return 'news|${item.file.path}|${item.lastModified.toUtc().millisecondsSinceEpoch}|${item.sizeBytes}';
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
}
