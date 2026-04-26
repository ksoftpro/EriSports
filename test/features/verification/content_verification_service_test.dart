import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late ContentVerificationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    service = ContentVerificationService(
      cacheStore: DaylySportCacheStore(sharedPreferences: preferences),
    );
  });

  test('request codes round-trip through parsing and verification', () {
    final request = service.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'AA:BB:CC:DD:EE:FF',
        source: VerificationSeedSource.macAddress,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 2,
        videoHighlights: 1,
        videoNews: 0,
        videoUpdates: 1,
        newsImages: 3,
      ),
      now: DateTime.utc(2025, 1, 14, 13, 5),
    );

    final parsed = service.parseClientRequest(request.requestCode);
    final verificationCode = service.generateVerificationCode(
      request.requestCode,
    );

    expect(request.requestCode, startsWith('ERI-REQ1-'));
    expect(parsed.feature, 'offline_content');
    expect(parsed.requestDayKey, '20250114');
    expect(parsed.pendingCounts.totalPending, 7);
    expect(verificationCode, startsWith('ERI-VER1-'));
    expect(
      service.isVerificationCodeValid(
        requestCode: request.requestCode,
        verificationCode: verificationCode,
      ),
      isTrue,
    );
    expect(
      service.isVerificationCodeValid(
        requestCode: request.requestCode,
        verificationCode: 'ERI-VER1-0000-0000-0000-0000-0000',
      ),
      isFalse,
    );
  });

  test('generated and verified client state is persisted', () async {
    final request = service.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'device-hostname',
        source: VerificationSeedSource.hostnameFallback,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 0,
        videoHighlights: 1,
        videoNews: 1,
        videoUpdates: 0,
        newsImages: 0,
      ),
      now: DateTime.utc(2025, 2, 2, 9),
    );
    final verificationCode = service.generateVerificationCode(
      request.requestCode,
    );

    await service.saveGeneratedRequest(request);
    await service.markClientVerified(
      request: request,
      verificationCode: verificationCode,
      verifiedAtUtc: DateTime.utc(2025, 2, 2, 9, 30),
    );

    final state = service.readClientState();
    expect(state.lastRequestCode, request.requestCode);
    expect(state.lastVerifiedRequestCode, verificationCode);
    expect(state.lastSeedSource, VerificationSeedSource.hostnameFallback);
    expect(state.lastPendingCounts.totalPending, 2);
    expect(state.lastVerifiedAtUtc, DateTime.utc(2025, 2, 2, 9, 30));
  });
}