import 'dart:io';

import 'package:crypto/crypto.dart';
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
  Future<List<LocalJsonFileSnapshot>> scanJsonFiles(Directory root) async {
    if (!await root.exists()) {
      return const [];
    }

    final files = await root
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .toList();

    final snapshots = <LocalJsonFileSnapshot>[];
    for (final file in files) {
      final stat = await file.stat();
      final checksum = await _sha256For(file);
      snapshots.add(
        LocalJsonFileSnapshot(
          fileName: p.basename(file.path),
          absolutePath: file.path,
          relativePath: p.relative(file.path, from: root.path),
          checksum: checksum,
          sizeBytes: stat.size,
          modifiedAtUtc: stat.modified.toUtc(),
        ),
      );
    }

    snapshots.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return snapshots;
  }

  Future<String> _sha256For(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}