import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DaylySportLocator {
  Future<Directory> getOrCreateDaylySportDirectory() async {
    if (Platform.isAndroid) {
      await _ensureAndroidStoragePermission();
    }

    final candidates = await _candidateDirectories();
    Object? lastError;

    for (final candidate in candidates) {
      try {
        if (!await candidate.exists()) {
          await candidate.create(recursive: true);
        }
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