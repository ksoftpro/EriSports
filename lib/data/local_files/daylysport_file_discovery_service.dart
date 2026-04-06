import 'dart:async';

import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/local_files/daylysport_sync_models.dart';
import 'package:eri_sports/data/local_files/file_inventory_scanner.dart';
import 'package:eri_sports/data/local_files/json_data_version_tracker.dart';

class DaylysportFileDiscoveryService {
  DaylysportFileDiscoveryService({
    required DaylySportLocator daylySportLocator,
    required FileInventoryScanner scanner,
    required JsonDataVersionTracker versionTracker,
  }) : _daylySportLocator = daylySportLocator,
       _scanner = scanner,
       _versionTracker = versionTracker;

  final DaylySportLocator _daylySportLocator;
  final FileInventoryScanner _scanner;
  final JsonDataVersionTracker _versionTracker;

  Future<DaylysportDiscoverySnapshot> discoverChanges({
    bool preferTrackedPaths = false,
  }) async {
    final root = await _daylySportLocator.getOrCreateDaylySportDirectory();
    final tracked = _versionTracker.readTrackedVersions(root.path);
    final preferredRelativePaths =
        tracked.map((entry) => entry.relativePath).toList(growable: false);
    final currentSnapshots = await _scanner.scanJsonFiles(
      root,
      preferredRelativePaths: preferredRelativePaths,
      preferCachedPaths: preferTrackedPaths && preferredRelativePaths.isNotEmpty,
    );

    final currentTracked = currentSnapshots
        .map(DaylysportTrackedFileVersion.fromSnapshot)
        .toList(growable: false);
    final changes = _diffTrackedVersions(
      previous: tracked,
      current: currentTracked,
    );

    return DaylysportDiscoverySnapshot(
      rootPath: root.path,
      scannedAtUtc: DateTime.now().toUtc(),
      currentSnapshots: currentSnapshots,
      trackedVersions: currentTracked,
      changes: changes,
    );
  }

  Future<Stream<void>?> tryWatchJsonChanges() async {
    try {
      final root = await _daylySportLocator.getOrCreateDaylySportDirectory();
      if (!await root.exists()) {
        return null;
      }

      return root
          .watch(recursive: true)
          .where((event) => event.path.toLowerCase().endsWith('.json'))
          .map((_) {});
    } catch (_) {
      return null;
    }
  }

  List<DaylysportTrackedFileChange> _diffTrackedVersions({
    required List<DaylysportTrackedFileVersion> previous,
    required List<DaylysportTrackedFileVersion> current,
  }) {
    final previousByPath = {
      for (final entry in previous) entry.relativePath: entry,
    };
    final currentByPath = {
      for (final entry in current) entry.relativePath: entry,
    };
    final changes = <DaylysportTrackedFileChange>[];

    for (final entry in current) {
      final earlier = previousByPath[entry.relativePath];
      if (earlier == null) {
        changes.add(
          DaylysportTrackedFileChange(
            relativePath: entry.relativePath,
            fileName: entry.fileName,
            changeType: DaylysportFileChangeType.added,
            currentVersion: entry,
            domains: classifyDaylysportDomains(entry.relativePath),
          ),
        );
        continue;
      }

      if (earlier.checksum != entry.checksum ||
          earlier.sizeBytes != entry.sizeBytes ||
          earlier.modifiedAtUtc != entry.modifiedAtUtc) {
        changes.add(
          DaylysportTrackedFileChange(
            relativePath: entry.relativePath,
            fileName: entry.fileName,
            changeType: DaylysportFileChangeType.updated,
            previousVersion: earlier,
            currentVersion: entry,
            domains: classifyDaylysportDomains(entry.relativePath),
          ),
        );
      }
    }

    for (final entry in previous) {
      if (currentByPath.containsKey(entry.relativePath)) {
        continue;
      }

      changes.add(
        DaylysportTrackedFileChange(
          relativePath: entry.relativePath,
          fileName: entry.fileName,
          changeType: DaylysportFileChangeType.removed,
          previousVersion: entry,
          domains: classifyDaylysportDomains(entry.relativePath),
        ),
      );
    }

    changes.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return changes;
  }
}