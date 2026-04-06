import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
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
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .toList();

    final snapshots = <LocalJsonFileSnapshot>[];
    for (final file in files) {
      final stat = await file.stat();
      final relativePath = p.relative(file.path, from: root.path);
      final modifiedAtUtc = stat.modified.toUtc();
      final cached = cachedByRelative[relativePath];
      final checksum =
          cached != null &&
                  cached.sizeBytes == stat.size &&
                  cached.modifiedAtUtc == modifiedAtUtc
              ? cached.checksum
              : await _sha256For(file);

      snapshots.add(
        LocalJsonFileSnapshot(
          fileName: p.basename(file.path),
          absolutePath: file.path,
          relativePath: relativePath,
          checksum: checksum,
          sizeBytes: stat.size,
          modifiedAtUtc: modifiedAtUtc,
        ),
      );
    }

    snapshots.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    await _persistSnapshots(root.path, snapshots);
    return snapshots;
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

  Future<List<LocalJsonFileSnapshot>> _buildPreferredSnapshots(
    Directory root,
    List<String> preferredRelativePaths,
    Map<String, LocalJsonFileSnapshot> cachedByRelative,
  ) async {
    final snapshots = <LocalJsonFileSnapshot>[];

    for (final relativePath in preferredRelativePaths) {
      final file = File(p.join(root.path, relativePath));
      if (!await file.exists()) {
        return const [];
      }

      final stat = await file.stat();
      final modifiedAtUtc = stat.modified.toUtc();
      final cached = cachedByRelative[relativePath];
      final checksum =
          cached != null &&
                  cached.sizeBytes == stat.size &&
                  cached.modifiedAtUtc == modifiedAtUtc
              ? cached.checksum
              : await _sha256For(file);

      snapshots.add(
        LocalJsonFileSnapshot(
          fileName: p.basename(file.path),
          absolutePath: file.path,
          relativePath: relativePath,
          checksum: checksum,
          sizeBytes: stat.size,
          modifiedAtUtc: modifiedAtUtc,
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
