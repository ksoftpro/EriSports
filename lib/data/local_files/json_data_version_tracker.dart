import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';

class JsonDataVersionTracker {
  JsonDataVersionTracker({required DaylySportCacheStore cacheStore})
    : _cacheStore = cacheStore;

  static const _versionsKey = 'sync_versions';
  final DaylySportCacheStore _cacheStore;

  List<DaylysportTrackedFileVersion> readTrackedVersions(String scope) {
    final entries = _cacheStore.readJsonObjectList(scope, _versionsKey);
    final tracked = <DaylysportTrackedFileVersion>[];

    for (final entry in entries) {
      try {
        tracked.add(DaylysportTrackedFileVersion.fromJson(entry));
      } catch (_) {}
    }

    tracked.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return tracked;
  }

  Future<void> writeTrackedVersions(
    String scope,
    List<DaylysportTrackedFileVersion> versions,
  ) {
    return _cacheStore.writeJsonObjectList(
      scope,
      _versionsKey,
      versions.map((entry) => entry.toJson()).toList(growable: false),
    );
  }
}