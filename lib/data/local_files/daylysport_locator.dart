import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DaylySportLocator {
  Future<Directory> getOrCreateDaylySportDirectory() async {
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

      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final sharedRoot = _extractAndroidSharedRoot(externalDir.path);
        if (sharedRoot != null) {
          candidates.add(Directory(p.join(sharedRoot, 'daylySport')));
        }
      }
    }

    final docsDir = await getApplicationDocumentsDirectory();
    candidates.add(Directory(p.join(docsDir.path, 'daylySport')));

    final unique = <String, Directory>{};
    for (final candidate in candidates) {
      unique[candidate.path] = candidate;
    }

    return unique.values.toList(growable: false);
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