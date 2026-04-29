import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ContentVerificationService> createService() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    return ContentVerificationService(
      cacheStore: DaylySportCacheStore(sharedPreferences: preferences),
    );
  }

  ClientVerificationRequest createRequest(
    ContentVerificationService service,
  ) {
    return service.createClientVerificationRecord(
      identity: const DeviceVerificationIdentity(
        seed: 'client-test-device',
        source: VerificationSeedSource.androidIdFallback,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 2,
        videoHighlights: 1,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 3,
      ),
      now: DateTime.utc(2026, 4, 29, 8, 30),
    );
  }

  test('generated admin QR is bound to the originating client request', () async {
    final service = await createService();
    final request = createRequest(service);

    final payload = service.generateVerificationQrPayload(
      request: request,
      now: DateTime.utc(2026, 4, 29, 8, 35),
    );

    final parsed = service.validateVerificationQrPayload(
      qrPayload: payload.qrPayload,
      expectedRequest: request,
      currentState: const ClientVerificationState(),
      now: DateTime.utc(2026, 4, 29, 8, 36),
    );

    expect(parsed.requestCode, request.requestCode);
    expect(parsed.requestDayKey, request.requestDayKey);
    expect(parsed.deviceDigest, request.deviceDigest);
    expect(parsed.verificationCode, service.generateVerificationCode(request.requestCode));
  });

  test('validation rejects an admin QR generated for a different client request', () async {
    final service = await createService();
    final expectedRequest = createRequest(service);
    final otherRequest = service.createClientVerificationRecord(
      identity: const DeviceVerificationIdentity(
        seed: 'other-client-device',
        source: VerificationSeedSource.hostnameFallback,
      ),
      pendingCounts: expectedRequest.pendingCounts,
      now: DateTime.utc(2026, 4, 29, 8, 31),
    );
    final payload = service.generateVerificationQrPayload(
      request: otherRequest,
      now: DateTime.utc(2026, 4, 29, 8, 35),
    );

    expect(
      () => service.validateVerificationQrPayload(
        qrPayload: payload.qrPayload,
        expectedRequest: expectedRequest,
        currentState: const ClientVerificationState(),
        now: DateTime.utc(2026, 4, 29, 8, 36),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'This admin QR code does not match the current verification request.',
        ),
      ),
    );
  });

  test('saving a new request clears stale verified state and exposes the pending request', () async {
    final service = await createService();
    final originalRequest = createRequest(service);
    await service.saveGeneratedRequest(originalRequest);
    await service.markClientVerified(
      request: originalRequest,
      verificationCode: service.generateVerificationCode(originalRequest.requestCode),
      verifiedAtUtc: DateTime.utc(2026, 4, 29, 8, 40),
    );

    final nextRequest = service.createClientVerificationRecord(
      identity: const DeviceVerificationIdentity(
        seed: 'client-test-device',
        source: VerificationSeedSource.androidIdFallback,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 0,
        videoHighlights: 1,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 0,
      ),
      now: DateTime.utc(2026, 4, 29, 8, 45),
    );
    await service.saveGeneratedRequest(nextRequest);

    final state = service.readClientState();

    expect(state.lastRequestCode, nextRequest.requestCode);
    expect(state.lastVerifiedAtUtc, isNull);
    expect(state.lastVerifiedRequestCode, isNull);
    expect(service.readPendingClientRequest()?.requestCode, nextRequest.requestCode);
  });
}