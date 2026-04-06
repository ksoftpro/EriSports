import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CachedLocatedFile {
  const CachedLocatedFile({
    required this.path,
    required this.modifiedAtEpochMs,
  });

  final String path;
  final int modifiedAtEpochMs;

  Map<String, dynamic> toJson() => {
    'path': path,
    'modifiedAtEpochMs': modifiedAtEpochMs,
  };

  static CachedLocatedFile? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final path = raw['path'];
    final modifiedAtEpochMs = raw['modifiedAtEpochMs'];
    if (path is! String || modifiedAtEpochMs is! int) {
      return null;
    }

    return CachedLocatedFile(path: path, modifiedAtEpochMs: modifiedAtEpochMs);
  }
}

class DaylySportCacheStore {
  DaylySportCacheStore({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  List<Map<String, dynamic>> readJsonInventoryEntries(String scope) {
    final raw = _sharedPreferences.getString(
      _scopedKey('json_inventory', scope),
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map((entry) {
            return entry.map((key, value) => MapEntry('$key', value));
          })
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeJsonInventoryEntries(
    String scope,
    List<Map<String, dynamic>> entries,
  ) {
    return _sharedPreferences.setString(
      _scopedKey('json_inventory', scope),
      jsonEncode(entries),
    );
  }

  List<Map<String, dynamic>> readJsonObjectList(String scope, String key) {
    final raw = _sharedPreferences.getString(_scopedKey('json::$key', scope));
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeJsonObjectList(
    String scope,
    String key,
    List<Map<String, dynamic>> entries,
  ) {
    return _sharedPreferences.setString(
      _scopedKey('json::$key', scope),
      jsonEncode(entries),
    );
  }

  List<String> readPathList(String scope, String key) {
    return _sharedPreferences.getStringList(_scopedKey('paths::$key', scope)) ??
        const [];
  }

  Future<void> writePathList(String scope, String key, List<String> paths) {
    return _sharedPreferences.setStringList(
      _scopedKey('paths::$key', scope),
      paths,
    );
  }

  Future<void> removePathList(String scope, String key) {
    return _sharedPreferences.remove(_scopedKey('paths::$key', scope));
  }

  CachedLocatedFile? readLocatedFile(String scope, String key) {
    final raw = _sharedPreferences.getString(
      _scopedKey('located::$key', scope),
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return CachedLocatedFile.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeLocatedFile(
    String scope,
    String key,
    CachedLocatedFile? value,
  ) {
    final scopedKey = _scopedKey('located::$key', scope);
    if (value == null) {
      return _sharedPreferences.remove(scopedKey);
    }

    return _sharedPreferences.setString(scopedKey, jsonEncode(value.toJson()));
  }

  String _scopedKey(String prefix, String scope) {
    final encodedScope = base64Url.encode(utf8.encode(scope));
    return 'daylysport_cache::$prefix::$encodedScope';
  }
}
