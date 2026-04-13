import 'package:eri_sports/core/log/app_logger.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_file_discovery_service.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/local_files/file_inventory_scanner.dart';
import 'package:eri_sports/data/local_files/json_data_version_tracker.dart';
import 'package:eri_sports/data/sync/daylysport_sync_coordinator.dart';
import 'package:eri_sports/features/media/security/encrypted_media_service.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:eri_sports/features/team/data/team_raw_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppServices {
  AppServices({
    required this.database,
    required this.daylySportLocator,
    required this.importCoordinator,
    required this.assetResolver,
    required this.encryptedMediaService,
    required this.leagueStandingsSource,
    required this.teamRawSource,
    required this.daylysportSyncCoordinator,
    required this.logger,
  });

  final AppDatabase database;
  final DaylySportLocator daylySportLocator;
  final ImportCoordinator importCoordinator;
  final LocalAssetResolver assetResolver;
  final EncryptedMediaService encryptedMediaService;
  final LeagueStandingsSource leagueStandingsSource;
  final TeamRawSource teamRawSource;
  final DaylysportSyncCoordinator daylysportSyncCoordinator;
  final AppLogger logger;

  static Future<AppServices> create({
    required SharedPreferences sharedPreferences,
  }) async {
    final logger = AppLogger();
    final database = AppDatabase();
    final daylySportLocator = DaylySportLocator(
      sharedPreferences: sharedPreferences,
    );
    final cacheStore = DaylySportCacheStore(
      sharedPreferences: sharedPreferences,
    );
    final scanner = FileInventoryScanner(cacheStore: cacheStore);
    final versionTracker = JsonDataVersionTracker(cacheStore: cacheStore);
    final assetResolver = LocalAssetResolver(
      daylySportLocator: daylySportLocator,
      logger: logger,
      cacheStore: cacheStore,
    );
    final encryptedMediaService = EncryptedMediaService();
    final importCoordinator = ImportCoordinator(
      database: database,
      daylySportLocator: daylySportLocator,
      scanner: scanner,
      logger: logger,
    );
    final leagueStandingsSource = LeagueStandingsSource(
      daylySportLocator: daylySportLocator,
      cacheStore: cacheStore,
    );
    final teamRawSource = TeamRawSource(
      daylySportLocator: daylySportLocator,
      cacheStore: cacheStore,
    );
    final discoveryService = DaylysportFileDiscoveryService(
      daylySportLocator: daylySportLocator,
      scanner: scanner,
      versionTracker: versionTracker,
    );
    final daylysportSyncCoordinator = DaylysportSyncCoordinator(
      discoveryService: discoveryService,
      versionTracker: versionTracker,
      importCoordinator: importCoordinator,
    );

    return AppServices(
      database: database,
      daylySportLocator: daylySportLocator,
      importCoordinator: importCoordinator,
      assetResolver: assetResolver,
      encryptedMediaService: encryptedMediaService,
      leagueStandingsSource: leagueStandingsSource,
      teamRawSource: teamRawSource,
      daylysportSyncCoordinator: daylysportSyncCoordinator,
      logger: logger,
    );
  }
}

final appServicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('AppServices override missing.'),
);
