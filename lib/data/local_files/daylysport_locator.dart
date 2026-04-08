import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DaylySportLocator {
  DaylySportLocator({SharedPreferences? sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const _customFolderPrefKey = 'daylysport.custom_json_folder';
  final SharedPreferences? _sharedPreferences;
  Directory? _cachedResolvedDirectory;
  bool _androidPermissionValidated = false;

  String? readCustomDirectoryPath() {
    final path = _sharedPreferences?.getString(_customFolderPrefKey);
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return path.trim();
  }

  Future<void> setCustomDirectoryPath(String? path) async {
    _cachedResolvedDirectory = null;

    final prefs = _sharedPreferences;
    if (prefs == null) {
      return;
    }

    if (path == null || path.trim().isEmpty) {
      await prefs.remove(_customFolderPrefKey);
      return;
    }

    await prefs.setString(_customFolderPrefKey, path.trim());
  }

  Future<Directory> getOrCreateDaylySportDirectory() async {
    if (Platform.isAndroid && !_androidPermissionValidated) {
      await _ensureAndroidStoragePermission();
      _androidPermissionValidated = true;
    }

    final cached = _cachedResolvedDirectory;
    if (cached != null) {
      try {
        if (await cached.exists()) {
          return cached;
        }
      } catch (_) {
        // Ignore stale cache and continue with normal discovery.
      }
      _cachedResolvedDirectory = null;
    }

    final customPath = readCustomDirectoryPath();
    if (customPath != null) {
      final customDir = Directory(customPath);
      try {
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        _cachedResolvedDirectory = customDir;
        return customDir;
      } catch (_) {
        // Fall back to default candidate lookup if custom path is inaccessible.
      }
    }

    final candidates = await _candidateDirectories();
    Object? lastError;

    for (final candidate in candidates) {
      try {
        if (!await candidate.exists()) {
          await candidate.create(recursive: true);
        }
        _cachedResolvedDirectory = candidate;
        return candidate;
      } catch (error) {
        lastError = error;
      }
    }

    throw FileSystemException(
      'Unable to access daylySport directory in any known storage location. '
      'Last error: ${lastError ?? 'unknown'}',
      candidates.isNotEmpty ? candidates.first.path : null,
    );
  }

  Future<List<Directory>> _candidateDirectories() async {
    final candidates = <Directory>[];

    if (Platform.isAndroid) {
      candidates.add(Directory('/storage/emulated/0/daylySport'));
      candidates.add(Directory('/sdcard/daylySport'));
      candidates.add(Directory('/storage/self/primary/daylySport'));

      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final sharedRoot = _extractAndroidSharedRoot(externalDir.path);
        if (sharedRoot != null) {
          candidates.add(Directory(p.join(sharedRoot, 'daylySport')));
        }
      }

      final uniqueAndroid = <String, Directory>{};
      for (final candidate in candidates) {
        uniqueAndroid[candidate.path] = candidate;
      }
      return uniqueAndroid.values.toList(growable: false);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    candidates.add(Directory(p.join(docsDir.path, 'daylySport')));

    final unique = <String, Directory>{};
    for (final candidate in candidates) {
      unique[candidate.path] = candidate;
    }

    return unique.values.toList(growable: false);
  }

  Future<void> _ensureAndroidStoragePermission() async {
    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      return;
    }

    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) {
      return;
    }

    final requestedManage = await Permission.manageExternalStorage.request();
    if (requestedManage.isGranted) {
      return;
    }

    final requestedStorage = await Permission.storage.request();
    if (requestedStorage.isGranted) {
      return;
    }

    throw const FileSystemException(
      'Storage permission denied. Enable "All files access" for EriSports to read /storage/emulated/0/daylySport.',
    );
  }

  String? _extractAndroidSharedRoot(String externalPath) {
    final marker = '${Platform.pathSeparator}Android${Platform.pathSeparator}';
    final index = externalPath.indexOf(marker);
    if (index <= 0) {
      return null;
    }

    return externalPath.substring(0, index);
  }
}
