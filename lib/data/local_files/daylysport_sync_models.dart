import 'package:eri_sports/data/local_files/file_inventory_scanner.dart';

enum DaylysportDataDomain {
  catalog,
  matches,
  standings,
  playerStats,
  matchDetails,
  assets,
}

enum DaylysportFileChangeType { added, updated, removed }

class DaylysportTrackedFileVersion {
  const DaylysportTrackedFileVersion({
    required this.fileName,
    required this.relativePath,
    required this.absolutePath,
    required this.checksum,
    required this.sizeBytes,
    required this.modifiedAtUtc,
  });

  final String fileName;
  final String relativePath;
  final String absolutePath;
  final String checksum;
  final int sizeBytes;
  final DateTime modifiedAtUtc;

  factory DaylysportTrackedFileVersion.fromSnapshot(
    LocalJsonFileSnapshot snapshot,
  ) {
    return DaylysportTrackedFileVersion(
      fileName: snapshot.fileName,
      relativePath: snapshot.relativePath,
      absolutePath: snapshot.absolutePath,
      checksum: snapshot.checksum,
      sizeBytes: snapshot.sizeBytes,
      modifiedAtUtc: snapshot.modifiedAtUtc,
    );
  }

  factory DaylysportTrackedFileVersion.fromJson(Map<String, dynamic> json) {
    return DaylysportTrackedFileVersion(
      fileName: json['fileName'] as String,
      relativePath: json['relativePath'] as String,
      absolutePath: json['absolutePath'] as String,
      checksum: json['checksum'] as String,
      sizeBytes: json['sizeBytes'] as int,
      modifiedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        json['modifiedAtEpochMs'] as int,
        isUtc: true,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'relativePath': relativePath,
      'absolutePath': absolutePath,
      'checksum': checksum,
      'sizeBytes': sizeBytes,
      'modifiedAtEpochMs': modifiedAtUtc.millisecondsSinceEpoch,
    };
  }
}

class DaylysportTrackedFileChange {
  const DaylysportTrackedFileChange({
    required this.relativePath,
    required this.fileName,
    required this.changeType,
    required this.domains,
    this.previousVersion,
    this.currentVersion,
  });

  final String relativePath;
  final String fileName;
  final DaylysportFileChangeType changeType;
  final Set<DaylysportDataDomain> domains;
  final DaylysportTrackedFileVersion? previousVersion;
  final DaylysportTrackedFileVersion? currentVersion;
}

class DaylysportDiscoverySnapshot {
  const DaylysportDiscoverySnapshot({
    required this.rootPath,
    required this.scannedAtUtc,
    required this.currentSnapshots,
    required this.trackedVersions,
    required this.changes,
  });

  final String rootPath;
  final DateTime scannedAtUtc;
  final List<LocalJsonFileSnapshot> currentSnapshots;
  final List<DaylysportTrackedFileVersion> trackedVersions;
  final List<DaylysportTrackedFileChange> changes;

  bool get hasChanges => changes.isNotEmpty;

  int get totalJsonFiles => currentSnapshots.length;

  int get changedJsonFiles => changes.length;

  List<String> get changedRelativePaths {
    return changes
        .where((change) => change.changeType != DaylysportFileChangeType.removed)
        .map((change) => change.relativePath)
        .toSet()
        .toList(growable: false)
      ..sort();
  }

  Set<DaylysportDataDomain> get affectedDomains {
    return {
      for (final change in changes) ...change.domains,
    };
  }
}

Set<DaylysportDataDomain> classifyDaylysportDomains(String relativePath) {
  final lowerPath = relativePath.replaceAll('\\', '/').toLowerCase();
  final fileName = lowerPath.split('/').last;
  final domains = <DaylysportDataDomain>{};
  final isLeagueFullDataJson =
      fileName.endsWith('_full_data.json') &&
      fileName != 'fixtures_full_data.json' &&
      fileName != 'fotmob_full_player_stats.json' &&
      !fileName.startsWith('top_standings_full_data');

  final isManifestJson =
      lowerPath.contains('/manifest/') || fileName.contains('manifest');
  if (isManifestJson) {
    domains.add(DaylysportDataDomain.assets);
  }

  if (fileName == 'fotmob_leagues_complete_data.json' ||
      fileName == 'fotmob_teams_data.json' ||
      fileName.contains('team') ||
      fileName.contains('league')) {
    domains.add(DaylysportDataDomain.catalog);
  }

  if (fileName == 'fotmob_matches_data.json' ||
      fileName == 'fixtures_full_data.json' ||
      fileName.contains('fixture') ||
      (fileName.contains('match') &&
          !fileName.contains('match_detail') &&
          !fileName.contains('match-detail'))) {
    domains.add(DaylysportDataDomain.matches);
  }

  if (fileName == 'fotmob_standings_data.json' ||
      fileName.startsWith('top_standings_full_data') ||
      isLeagueFullDataJson ||
      fileName.contains('standing') ||
      fileName.contains('table')) {
    domains.add(DaylysportDataDomain.standings);
  }

  if (fileName == 'top_score_data.json' ||
      fileName == 'fotmob_full_player_stats.json' ||
      fileName.contains('player') ||
      fileName.contains('scorer') ||
      fileName.contains('assist') ||
      fileName.contains('squad')) {
    domains.add(DaylysportDataDomain.playerStats);
  }

  if (fileName == 'fotmob_match_details_data.json' ||
      fileName.contains('match_detail') ||
      fileName.contains('match-detail') ||
      fileName.contains('timeline') ||
      fileName.contains('incidents') ||
      fileName.contains('events')) {
    domains.add(DaylysportDataDomain.matchDetails);
    domains.add(DaylysportDataDomain.matches);
  }

  if (lowerPath.contains('/assets/') || lowerPath.contains('/club_badges/')) {
    domains.add(DaylysportDataDomain.assets);
  }

  return domains;
}

String daylysportDomainLabel(DaylysportDataDomain domain) {
  switch (domain) {
    case DaylysportDataDomain.catalog:
      return 'catalog';
    case DaylysportDataDomain.matches:
      return 'matches';
    case DaylysportDataDomain.standings:
      return 'standings';
    case DaylysportDataDomain.playerStats:
      return 'player stats';
    case DaylysportDataDomain.matchDetails:
      return 'match details';
    case DaylysportDataDomain.assets:
      return 'assets';
  }
}

String daylysportFileChangeLabel(DaylysportFileChangeType type) {
  switch (type) {
    case DaylysportFileChangeType.added:
      return 'Added';
    case DaylysportFileChangeType.updated:
      return 'Updated';
    case DaylysportFileChangeType.removed:
      return 'Removed';
  }
}