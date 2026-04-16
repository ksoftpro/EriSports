import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/features/team/data/team_raw_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TeamRawSource', () {
    late Directory tempDir;
    late Directory daylySportDir;
    late Uint8List masterKey;
    late String keyBase64;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('eri_team_raw_test_');
      daylySportDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}daylySport',
      )..createSync(recursive: true);
      masterKey = Uint8List.fromList(
        List<int>.generate(32, (index) => (index * 19) % 256),
      );
      keyBase64 = base64Encode(masterKey);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads encrypted team payload and ignores legacy plain json', () async {
      final jsonDir = Directory(
        '${daylySportDir.path}${Platform.pathSeparator}json',
      )..createSync(recursive: true);

      final plainPayload = {
        'teams': {
          '1': {
            'meta': {'teamId': '1'},
            'raw': {
              'details': {'id': '1', 'name': 'Legacy Team'},
            },
          },
        },
      };
      File(
        '${jsonDir.path}${Platform.pathSeparator}fotmob_teams_data.json',
      ).writeAsStringSync(jsonEncode(plainPayload));

      final sourceFile = File(
        '${tempDir.path}${Platform.pathSeparator}fotmob_teams_data.json',
      )..writeAsStringSync(
        jsonEncode({
          'teams': {
            '10': {
              'meta': {'teamId': '10'},
              'raw': {
                'details': {'id': '10', 'name': 'Encrypted Team'},
              },
            },
          },
        }),
      );

      encryptSecureFileSync(
        sourcePath: sourceFile.path,
        destinationPath:
            '${jsonDir.path}${Platform.pathSeparator}fotmob_teams_data.json.esj',
        masterKey: masterKey,
        contentType: SecureContentType.json,
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final encryptedJsonService = EncryptedJsonService(
        fingerprintCache: FileFingerprintCache(
          cacheStore: DaylySportCacheStore(sharedPreferences: preferences),
        ),
        keyBase64: keyBase64,
        cacheRootProvider: () async => tempDir,
      );

      final source = TeamRawSource(
        daylySportLocator: _TestDaylySportLocator(daylySportDir),
        encryptedJsonService: encryptedJsonService,
        cacheStore: DaylySportCacheStore(sharedPreferences: preferences),
      );

      final entry = await source.readTeamById('10');
      final missingLegacy = await source.readTeamById('1');

      expect(entry, isNotNull);
      expect(entry!.teamId, '10');
      expect(entry.raw['details'], isA<Map<String, dynamic>>());
      expect(missingLegacy, isNull);
    });
  });
}

class _TestDaylySportLocator extends DaylySportLocator {
  _TestDaylySportLocator(this.directory);

  final Directory directory;

  @override
  Future<Directory> getOrCreateDaylySportDirectory() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}