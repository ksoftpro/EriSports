import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/data/local_files/daylysport_locator.dart';
import 'package:eri_sports/data/secure_content/daylysport_secure_content_coordinator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/encrypted_image_service.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
import 'package:eri_sports/data/secure_content/file_fingerprint_cache.dart';
import 'package:eri_sports/data/secure_content/secure_content_encryption_job_manager.dart';
import 'package:eri_sports/features/media/security/encrypted_media_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminAppServices {
  AdminAppServices({
    required this.daylySportLocator,
    required this.secureContentCoordinator,
    required this.secureContentEncryptionJobManager,
  });

  final DaylySportLocator daylySportLocator;
  final DaylysportSecureContentCoordinator secureContentCoordinator;
  final SecureContentEncryptionJobManager secureContentEncryptionJobManager;

  static Future<AdminAppServices> create({
    required SharedPreferences sharedPreferences,
  }) async {
    final daylySportLocator = DaylySportLocator(
      sharedPreferences: sharedPreferences,
    );
    final cacheStore = DaylySportCacheStore(
      sharedPreferences: sharedPreferences,
    );
    final encryptedFileResolver = const EncryptedFileResolver();
    final fingerprintCache = FileFingerprintCache(cacheStore: cacheStore);
    final encryptedJsonService = EncryptedJsonService(
      fingerprintCache: fingerprintCache,
    );
    final encryptedImageService = EncryptedImageService(
      fingerprintCache: fingerprintCache,
    );
    final encryptedMediaService = EncryptedMediaService(
      fingerprintCache: fingerprintCache,
    );
    final secureContentCoordinator = DaylysportSecureContentCoordinator(
      daylySportLocator: daylySportLocator,
      fileResolver: encryptedFileResolver,
      encryptedJsonService: encryptedJsonService,
      encryptedImageService: encryptedImageService,
      encryptedMediaService: encryptedMediaService,
    );

    return AdminAppServices(
      daylySportLocator: daylySportLocator,
      secureContentCoordinator: secureContentCoordinator,
      secureContentEncryptionJobManager: SecureContentEncryptionJobManager(
        coordinator: secureContentCoordinator,
      ),
    );
  }
}

final adminAppServicesProvider = Provider<AdminAppServices>(
  (ref) => throw UnimplementedError('AdminAppServices override missing.'),
);