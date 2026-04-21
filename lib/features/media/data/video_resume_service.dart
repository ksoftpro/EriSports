import 'dart:math' as math;

import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';

class VideoResumeService {
  VideoResumeService({required DaylySportCacheStore cacheStore})
    : _cacheStore = cacheStore {
    _entries = _readEntries();
  }

  static const String _scope = 'video_resume';
  static const String _entriesKey = 'positions_v1';
  static const int _maxEntries = 300;
  static const int _minPositionMs = 500;
  static const double _completionThreshold = 0.95;

  final DaylySportCacheStore _cacheStore;
  late Map<String, _VideoResumeEntry> _entries;

  Future<Duration?> readPosition({
    required String videoKey,
    required Duration totalDuration,
  }) async {
    final normalizedKey = _normalizeVideoKey(videoKey);
    if (normalizedKey.isEmpty) {
      return null;
    }

    final entry = _entries[normalizedKey];
    if (entry == null) {
      return null;
    }

    final totalMs = totalDuration.inMilliseconds;
    if (totalMs <= 0) {
      return null;
    }

    if (_isNearComplete(entry.positionMs, totalMs)) {
      _entries.remove(normalizedKey);
      await _persist();
      return null;
    }

    final maxSeekMs = math.max(totalMs - 250, 0);
    final clampedPositionMs = math.min(entry.positionMs, maxSeekMs);
    if (clampedPositionMs < _minPositionMs) {
      return null;
    }

    return Duration(milliseconds: clampedPositionMs);
  }

  Future<void> savePosition({
    required String videoKey,
    required Duration position,
    required Duration totalDuration,
  }) async {
    final normalizedKey = _normalizeVideoKey(videoKey);
    if (normalizedKey.isEmpty) {
      return;
    }

    final totalMs = totalDuration.inMilliseconds;
    if (totalMs <= 0) {
      return;
    }

    final boundedPositionMs = math.max(
      0,
      math.min(position.inMilliseconds, totalMs),
    );

    if (boundedPositionMs < _minPositionMs ||
        _isNearComplete(boundedPositionMs, totalMs)) {
      final removed = _entries.remove(normalizedKey) != null;
      if (removed) {
        await _persist();
      }
      return;
    }

    _entries[normalizedKey] = _VideoResumeEntry(
      videoKey: normalizedKey,
      positionMs: boundedPositionMs,
      updatedAtEpochMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    _trimToCapacity();
    await _persist();
  }

  Future<void> clearPosition({required String videoKey}) async {
    final normalizedKey = _normalizeVideoKey(videoKey);
    if (normalizedKey.isEmpty) {
      return;
    }
    final removed = _entries.remove(normalizedKey) != null;
    if (removed) {
      await _persist();
    }
  }

  void _trimToCapacity() {
    if (_entries.length <= _maxEntries) {
      return;
    }

    final ordered = _entries.values.toList(growable: false)
      ..sort(
        (left, right) => right.updatedAtEpochMs.compareTo(left.updatedAtEpochMs),
      );
    _entries = <String, _VideoResumeEntry>{
      for (final entry in ordered.take(_maxEntries)) entry.videoKey: entry,
    };
  }

  Future<void> _persist() {
    final ordered = _entries.values.toList(growable: false)
      ..sort(
        (left, right) => right.updatedAtEpochMs.compareTo(left.updatedAtEpochMs),
      );

    return _cacheStore.writeJsonObject(_scope, _entriesKey, {
      'entries': ordered.map((entry) => entry.toJson()).toList(growable: false),
    });
  }

  Map<String, _VideoResumeEntry> _readEntries() {
    final raw = _cacheStore.readJsonObject(_scope, _entriesKey);
    if (raw == null) {
      return <String, _VideoResumeEntry>{};
    }

    final rawEntries = raw['entries'];
    if (rawEntries is! List) {
      return <String, _VideoResumeEntry>{};
    }

    final entries = <String, _VideoResumeEntry>{};
    for (final rawEntry in rawEntries) {
      final parsed = _VideoResumeEntry.fromJson(rawEntry);
      if (parsed != null) {
        entries[parsed.videoKey] = parsed;
      }
    }
    return entries;
  }

  String _normalizeVideoKey(String videoKey) {
    return videoKey.trim().replaceAll('\\', '/').toLowerCase();
  }

  bool _isNearComplete(int positionMs, int totalMs) {
    if (totalMs <= 0) {
      return false;
    }
    return (positionMs / totalMs) >= _completionThreshold;
  }
}

class _VideoResumeEntry {
  const _VideoResumeEntry({
    required this.videoKey,
    required this.positionMs,
    required this.updatedAtEpochMs,
  });

  final String videoKey;
  final int positionMs;
  final int updatedAtEpochMs;

  Map<String, dynamic> toJson() => {
    'videoKey': videoKey,
    'positionMs': positionMs,
    'updatedAtEpochMs': updatedAtEpochMs,
  };

  static _VideoResumeEntry? fromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final map = raw.map((key, value) => MapEntry('$key', value));

    final videoKey = map['videoKey'];
    final positionMs = map['positionMs'];
    final updatedAtEpochMs = map['updatedAtEpochMs'];
    if (videoKey is! String ||
        videoKey.trim().isEmpty ||
        positionMs is! num ||
        updatedAtEpochMs is! num) {
      return null;
    }

    return _VideoResumeEntry(
      videoKey: videoKey,
      positionMs: positionMs.toInt(),
      updatedAtEpochMs: updatedAtEpochMs.toInt(),
    );
  }
}