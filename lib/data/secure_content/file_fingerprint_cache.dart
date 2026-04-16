import 'dart:io';

import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';

const String kSecureContentCacheScope = '__secure_content_cache_v1__';

class CachedFileFingerprintEntry {
  const CachedFileFingerprintEntry({
    required this.sourcePath,
    required this.sizeBytes,
    required this.modifiedAtEpochMs,
    required this.cachePath,
  });

  final String sourcePath;
  final int sizeBytes;
  final int modifiedAtEpochMs;
  final String cachePath;

  bool matches(String path, FileStat stat) {
    return sourcePath == path &&
        sizeBytes == stat.size &&
        modifiedAtEpochMs == stat.modified.toUtc().millisecondsSinceEpoch;
  }

  Map<String, dynamic> toJson() {
    return {
      'sourcePath': sourcePath,
      'sizeBytes': sizeBytes,
      'modifiedAtEpochMs': modifiedAtEpochMs,
      'cachePath': cachePath,
    };
  }

  static CachedFileFingerprintEntry? fromJson(Map<String, dynamic> json) {
    final sourcePath = json['sourcePath'];
    final sizeBytes = json['sizeBytes'];
    final modifiedAtEpochMs = json['modifiedAtEpochMs'];
    final cachePath = json['cachePath'];
    if (sourcePath is! String ||
        sizeBytes is! int ||
        modifiedAtEpochMs is! int ||
        cachePath is! String) {
      return null;
    }

    return CachedFileFingerprintEntry(
      sourcePath: sourcePath,
      sizeBytes: sizeBytes,
      modifiedAtEpochMs: modifiedAtEpochMs,
      cachePath: cachePath,
    );
  }
}

class FileFingerprintCache {
  FileFingerprintCache({required DaylySportCacheStore cacheStore})
    : _cacheStore = cacheStore;

  final DaylySportCacheStore _cacheStore;
  static const int _maxEntriesPerNamespace = 240;

  CachedFileFingerprintEntry? read(String namespace, String sourcePath) {
    final entries = _readEntries(namespace);
    for (final entry in entries) {
      if (entry.sourcePath == sourcePath) {
        return entry;
      }
    }
    return null;
  }

  Future<void> write(String namespace, CachedFileFingerprintEntry value) async {
    final entries = _readEntries(namespace)
        .where((entry) => entry.sourcePath != value.sourcePath)
        .toList(growable: true);
    entries.insert(0, value);
    final trimmed = entries
        .take(_maxEntriesPerNamespace)
        .toList(growable: false);
    await _cacheStore.writeJsonObjectList(
      kSecureContentCacheScope,
      _keyForNamespace(namespace),
      trimmed.map((entry) => entry.toJson()).toList(growable: false),
    );
  }

  Future<void> remove(String namespace, String sourcePath) async {
    final remaining = _readEntries(namespace)
        .where((entry) => entry.sourcePath != sourcePath)
        .map((entry) => entry.toJson())
        .toList(growable: false);
    await _cacheStore.writeJsonObjectList(
      kSecureContentCacheScope,
      _keyForNamespace(namespace),
      remaining,
    );
  }

  Future<void> clearNamespace(String namespace) async {
    await _cacheStore.writeJsonObjectList(
      kSecureContentCacheScope,
      _keyForNamespace(namespace),
      const <Map<String, dynamic>>[],
    );
  }

  List<CachedFileFingerprintEntry> _readEntries(String namespace) {
    final rawEntries = _cacheStore.readJsonObjectList(
      kSecureContentCacheScope,
      _keyForNamespace(namespace),
    );

    final entries = <CachedFileFingerprintEntry>[];
    for (final raw in rawEntries) {
      final parsed = CachedFileFingerprintEntry.fromJson(raw);
      if (parsed != null) {
        entries.add(parsed);
      }
    }
    return entries;
  }

  String _keyForNamespace(String namespace) {
    return 'fingerprint_cache::$namespace';
  }
}
