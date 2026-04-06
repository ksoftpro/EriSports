import 'package:eri_sports/core/log/app_logger.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/data/db/app_database.dart';
import 'package:eri_sports/data/import/import_coordinator.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/local_files/file_inventory_scanner.dart';
import 'package:eri_sports/features/leagues/data/league_standings_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppServices {
  AppServices({
    required this.database,
    required this.importCoordinator,
    required this.assetResolver,
    required this.leagueStandingsSource,
    required this.logger,
  });

  final AppDatabase database;
  final ImportCoordinator importCoordinator;
  final LocalAssetResolver assetResolver;
  final LeagueStandingsSource leagueStandingsSource;
  final AppLogger logger;

  static Future<AppServices> create({
    required SharedPreferences sharedPreferences,
  }) async {
    final logger = AppLogger();
    final database = AppDatabase();
    final daylySportLocator = DaylySportLocator();
    final cacheStore = DaylySportCacheStore(
      sharedPreferences: sharedPreferences,
    );
    final scanner = FileInventoryScanner(cacheStore: cacheStore);
    final assetResolver = LocalAssetResolver(
      daylySportLocator: daylySportLocator,
      logger: logger,
      cacheStore: cacheStore,
    );
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

    return AppServices(
      database: database,
      importCoordinator: importCoordinator,
      assetResolver: assetResolver,
      leagueStandingsSource: leagueStandingsSource,
      logger: logger,
    );
  }
}

final appServicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('AppServices override missing.'),
);
