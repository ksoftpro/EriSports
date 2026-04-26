import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/admin/data/admin_activity_service.dart';
import 'package:eri_sports/features/admin/data/admin_models.dart';
import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdminActivityService adminActivityService;
  late ContentVerificationService contentVerificationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final cacheStore = DaylySportCacheStore(sharedPreferences: preferences);
    adminActivityService = AdminActivityService(cacheStore: cacheStore);
    contentVerificationService = ContentVerificationService(
      cacheStore: cacheStore,
    );
  });

  test('admin verification records are generated with feature metadata', () async {
    final request = contentVerificationService.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'device-alpha',
        source: VerificationSeedSource.hostnameFallback,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 2,
        videoHighlights: 1,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 3,
      ),
      now: DateTime.utc(2025, 1, 14, 10),
    );
    final verificationCode = contentVerificationService.generateVerificationCode(
      request.requestCode,
    );

    await adminActivityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.verificationCodeGenerated,
        occurredAtUtc: DateTime.utc(2025, 1, 14, 10, 5),
        summary:
            'Generated offline content verification code for ${request.pendingCounts.totalPending} pending items.',
        category: 'verification',
        actorUserId: 'admin-1',
        actorUsername: 'opslead',
        itemCount: request.pendingCounts.totalPending,
        metadata: <String, String>{
          'feature': request.feature,
          'requestDayKey': request.requestDayKey,
          'contentCategory': 'mixed',
          'pendingCategories': request.pendingCounts.activeCategoryKeys.join(','),
          'seedSource': request.seedSource.name,
          'verificationCode': verificationCode,
        },
      ),
    );

    final record = adminActivityService.records.singleWhere(
      (activity) => activity.type == AdminActivityType.verificationCodeGenerated,
    );
    expect(record.category, 'verification');
    expect(record.itemCount, 6);
    expect(record.metadata?['feature'], 'offline_content');
    expect(record.metadata?['contentCategory'], 'mixed');
    expect(record.metadata?['verificationCode'], verificationCode);
  });

  test('admin verification generation records can be cleared', () async {
    await adminActivityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.verificationCodeGenerated,
        occurredAtUtc: DateTime.utc(2025, 1, 14, 10, 5),
        summary: 'Generated offline content verification code.',
        category: 'verification',
        actorUserId: 'admin-1',
        actorUsername: 'opslead',
        metadata: const <String, String>{'feature': 'offline_content'},
      ),
    );
    await adminActivityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.encryptionBatch,
        occurredAtUtc: DateTime.utc(2025, 1, 14, 11),
        summary: 'Processed secure content batch.',
        category: 'mixed',
        actorUserId: 'admin-1',
        actorUsername: 'opslead',
      ),
    );

    await adminActivityService.clearVerificationCodeRecords(
      actorUserId: 'admin-1',
      actorUsername: 'opslead',
    );

    expect(
      adminActivityService.records.any(
        (activity) => activity.type == AdminActivityType.verificationCodeGenerated,
      ),
      isFalse,
    );
    expect(
      adminActivityService.records.any(
        (activity) =>
            activity.type == AdminActivityType.verificationCodeRecordsCleared,
      ),
      isTrue,
    );
    expect(
      adminActivityService.records.any(
        (activity) => activity.type == AdminActivityType.encryptionBatch,
      ),
      isTrue,
    );
  });
}
