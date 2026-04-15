import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:path/path.dart' as p;

class LocalJsonFileSnapshot {
  const LocalJsonFileSnapshot({
    required this.fileName,
    required this.absolutePath,
    required this.relativePath,
    required this.checksum,
    required this.sizeBytes,
    required this.modifiedAtUtc,
  });

  final String fileName;
  final String absolutePath;
  final String relativePath;
  final String checksum;
  final int sizeBytes;
  final DateTime modifiedAtUtc;
}

class FileInventoryScanner {
  FileInventoryScanner({this.cacheStore});

  final DaylySportCacheStore? cacheStore;

  Future<List<LocalJsonFileSnapshot>> scanJsonFiles(
    Directory root, {
    List<String> preferredRelativePaths = const [],
    bool preferCachedPaths = false,
  }) async {
    if (!await root.exists()) {
      return const [];
    }

    final cachedByRelative = {
      for (final entry in _readCachedSnapshots(root.path))
        entry.relativePath: entry,
    };

    if (preferCachedPaths && preferredRelativePaths.isNotEmpty) {
      final preferredSnapshots = await _buildPreferredSnapshots(
        root,
        preferredRelativePaths,
        cachedByRelative,
      );
      if (preferredSnapshots.length == preferredRelativePaths.length) {
        await _persistSnapshots(root.path, preferredSnapshots);
        preferredSnapshots.sort(
          (a, b) => a.relativePath.compareTo(b.relativePath),
        );
        return preferredSnapshots;
      }
    }

    final files =
        await root
            .list(recursive: true, followLinks: false)
            .where((entity) => entity is File)
            .cast<File>()
            .where((file) => isSupportedSecureJsonPath(file.path))
            .toList();

    final snapshotsByRelative = <String, LocalJsonFileSnapshot>{};
    for (final file in files) {
      final stat = await file.stat();
      final relativePath = logicalSecureContentRelativePath(
        file.path,
        fromDirectory: root.path,
      );
      final modifiedAtUtc = stat.modified.toUtc();
      final cached = cachedByRelative[relativePath];
      final checksum =
          cached != null &&
                  cached.sizeBytes == stat.size &&
                  cached.modifiedAtUtc == modifiedAtUtc
              ? cached.checksum
              : await _sha256For(file);

      final snapshot = LocalJsonFileSnapshot(
        fileName: logicalSecureContentFileName(file.path),
        absolutePath: file.path,
        relativePath: relativePath,
        checksum: checksum,
        sizeBytes: stat.size,
        modifiedAtUtc: modifiedAtUtc,
      );

      final existing = snapshotsByRelative[relativePath];
      if (existing == null || _shouldPreferSnapshot(file.path, existing.absolutePath)) {
        snapshotsByRelative[relativePath] = snapshot;
      }
    }

    final snapshots = snapshotsByRelative.values.toList(growable: false);

    snapshots.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    await _persistSnapshots(root.path, snapshots);
    return snapshots;
  }

  bool _shouldPreferSnapshot(String candidatePath, String existingPath) {
    final candidateEncrypted = isEncryptedJsonPath(candidatePath);
    final existingEncrypted = isEncryptedJsonPath(existingPath);
    if (candidateEncrypted != existingEncrypted) {
      return !candidateEncrypted;
    }
    return candidatePath.toLowerCase().compareTo(existingPath.toLowerCase()) < 0;
  }

  Future<List<LocalJsonFileSnapshot>> _buildPreferredSnapshots(
    Directory root,
    List<String> preferredRelativePaths,
    Map<String, LocalJsonFileSnapshot> cachedByRelative,
  ) async {
    final snapshots = <LocalJsonFileSnapshot>[];

    for (final relativePath in preferredRelativePaths) {
      final sourceFile = await _resolvePreferredSourceFile(root, relativePath);
      if (sourceFile == null) {
        return const [];
      }

      final stat = await sourceFile.stat();
      final modifiedAtUtc = stat.modified.toUtc();
      final cached = cachedByRelative[relativePath];
      final checksum =
          cached != null &&
                  cached.sizeBytes == stat.size &&
                  cached.modifiedAtUtc == modifiedAtUtc
              ? cached.checksum
              : await _sha256For(sourceFile);

      snapshots.add(
        LocalJsonFileSnapshot(
          fileName: logicalSecureContentFileName(sourceFile.path),
          absolutePath: sourceFile.path,
          relativePath: relativePath,
          checksum: checksum,
          sizeBytes: stat.size,
          modifiedAtUtc: modifiedAtUtc,
        ),
      );
    }

    return snapshots;
  }

  Future<File?> _resolvePreferredSourceFile(
    Directory root,
    String relativePath,
  ) async {
    for (final candidatePath in candidateSecureJsonPaths(
      p.join(root.path, relativePath),
    )) {
      final file = File(candidatePath);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  List<LocalJsonFileSnapshot> _readCachedSnapshots(String rootPath) {
    final entries = cacheStore?.readJsonInventoryEntries(rootPath) ?? const [];
    final snapshots = <LocalJsonFileSnapshot>[];

    for (final entry in entries) {
      final fileName = entry['fileName'];
      final absolutePath = entry['absolutePath'];
      final relativePath = entry['relativePath'];
      final checksum = entry['checksum'];
      final sizeBytes = entry['sizeBytes'];
      final modifiedAtEpochMs = entry['modifiedAtEpochMs'];

      if (fileName is! String ||
          absolutePath is! String ||
          relativePath is! String ||
          checksum is! String ||
          sizeBytes is! int ||
          modifiedAtEpochMs is! int) {
        continue;
      }

      snapshots.add(
        LocalJsonFileSnapshot(
          fileName: fileName,
          absolutePath: absolutePath,
          relativePath: relativePath,
          checksum: checksum,
          sizeBytes: sizeBytes,
          modifiedAtUtc: DateTime.fromMillisecondsSinceEpoch(
            modifiedAtEpochMs,
            isUtc: true,
          ),
        ),
      );
    }

    return snapshots;
  }

  Future<void> _persistSnapshots(
    String rootPath,
    List<LocalJsonFileSnapshot> snapshots,
  ) async {
    if (cacheStore == null) {
      return;
    }

    await cacheStore!.writeJsonInventoryEntries(
      rootPath,
      snapshots
          .map(
            (snapshot) => {
              'fileName': snapshot.fileName,
              'absolutePath': snapshot.absolutePath,
              'relativePath': snapshot.relativePath,
              'checksum': snapshot.checksum,
              'sizeBytes': snapshot.sizeBytes,
              'modifiedAtEpochMs':
                  snapshot.modifiedAtUtc.millisecondsSinceEpoch,
            },
          )
          .toList(growable: false),
    );
  }

  Future<String> _sha256For(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
