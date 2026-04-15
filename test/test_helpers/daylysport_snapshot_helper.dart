import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:eri_sports/data/local_files/file_inventory_scanner.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:path/path.dart' as p;

List<LocalJsonFileSnapshot> buildDaylysportJsonSnapshotsSync(Directory root) {
  if (!root.existsSync()) {
    return const <LocalJsonFileSnapshot>[];
  }

  final snapshotsByRelative = <String, LocalJsonFileSnapshot>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !isSupportedSecureJsonPath(entity.path)) {
      continue;
    }

    final stat = entity.statSync();
    final relativePath = logicalSecureContentRelativePath(
      entity.path,
      fromDirectory: root.path,
    );
    final snapshot = LocalJsonFileSnapshot(
      fileName: logicalSecureContentFileName(entity.path),
      absolutePath: entity.path,
      relativePath: relativePath,
      checksum: sha256.convert(entity.readAsBytesSync()).toString(),
      sizeBytes: stat.size,
      modifiedAtUtc: stat.modified.toUtc(),
    );

    final existing = snapshotsByRelative[relativePath];
    if (existing == null || _shouldPreferSnapshot(entity.path, existing.absolutePath)) {
      snapshotsByRelative[relativePath] = snapshot;
    }
  }

  final snapshots = snapshotsByRelative.values.toList(growable: false);
  snapshots.sort((a, b) => a.relativePath.compareTo(b.relativePath));
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