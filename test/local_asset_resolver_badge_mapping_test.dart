import 'dart:io';

import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory daylySportDir;
  late LocalAssetResolver resolver;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('erisports_asset_unit_');
    daylySportDir = Directory(p.join(tempRoot.path, 'daylySport'));
    await daylySportDir.create(recursive: true);

    final teamsDir = Directory(
      p.join(daylySportDir.path, 'teams', 'premier_league'),
    );
    await teamsDir.create(recursive: true);
    await File(
      p.join(teamsDir.path, 'team_Arsenal_9825_badge.png'),
    ).writeAsBytes(<int>[137, 80, 78, 71]);
    await File(
      p.join(teamsDir.path, 'team_Brighton_&_Hove_Albion_10204_badge.png'),
    ).writeAsBytes(<int>[137, 80, 78, 71]);
    await File(
      p.join(teamsDir.path, 'team_Fenerbahçe_8695_badge.png'),
    ).writeAsBytes(<int>[137, 80, 78, 71]);
    await File(
      p.join(teamsDir.path, 'team_1._FC_Köln_8722_badge.png'),
    ).writeAsBytes(<int>[137, 80, 78, 71]);

    resolver = LocalAssetResolver(
      daylySportLocator: _TestDaylySportLocator(daylySportDir),
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test(
    'resolves local team badge by id from league-categorized daylySport folder',
    () async {
      final resolved = await resolver.resolve(
        type: SportsAssetType.teams,
        entityId: '9825',
        entityName: 'Arsenal',
      );

      expect(resolved, isNotNull);
      expect(resolved!.isFile, isTrue);
      expect(resolved.path, contains('daylySport'));
      expect(resolved.path, contains('teams'));
      expect(resolved.path, contains('9825'));
    },
  );

  test('resolves every player image to the shared placeholder asset', () async {
    final resolved = await resolver.resolve(
      type: SportsAssetType.players,
      entityId: '12345',
      entityName: 'Any Player',
    );

    expect(resolved, isNotNull);
    expect(resolved!.isFile, isFalse);
    expect(resolved.path, 'assets/default.png');
  });

  test(
    'resolves local team badge when team name contains punctuation',
    () async {
      final resolved = await resolver.resolve(
        type: SportsAssetType.teams,
        entityId: '10204',
        entityName: 'Brighton & Hove Albion',
      );

      expect(resolved, isNotNull);
      expect(resolved!.isFile, isTrue);
      expect(resolved.path, contains('daylySport'));
      expect(resolved.path, contains('teams'));
      expect(resolved.path, contains('10204'));
    },
  );

  test(
    'resolves local team badge by name when id is missing and name uses ASCII fallback',
    () async {
      final resolved = await resolver.resolveTeamBadge(
        teamName: 'Fenerbahce',
        source: 'test.name-only-ascii',
      );

      expect(resolved, isNotNull);
      expect(resolved!.isFile, isTrue);
      expect(resolved.path, contains('8695'));
    },
  );

  test(
    'resolves local team badge by name when punctuation and diacritics differ',
    () async {
      final resolved = await resolver.resolveTeamBadge(
        teamName: '1. FC Koln',
        source: 'test.name-only-punctuation',
      );

      expect(resolved, isNotNull);
      expect(resolved!.isFile, isTrue);
      expect(resolved.path, contains('8722'));
    },
  );
}

class _TestDaylySportLocator extends DaylySportLocator {
  _TestDaylySportLocator(this.daylySportDirectory);

  final Directory daylySportDirectory;

  @override
  Future<Directory> getOrCreateDaylySportDirectory() async {
    if (!await daylySportDirectory.exists()) {
      await daylySportDirectory.create(recursive: true);
    }
    return daylySportDirectory;
  }
}
