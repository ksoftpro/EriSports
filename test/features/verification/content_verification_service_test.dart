import 'dart:convert';

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

  test('request-bound admin QR payload round-trips and validates', () {
    final request = service.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'request-bound-device',
        source: VerificationSeedSource.hostnameFallback,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 1,
        videoHighlights: 0,
        videoNews: 1,
        videoUpdates: 0,
        newsImages: 0,
      ),
      now: DateTime.utc(2025, 3, 8, 11, 45),
    );
    final generatedQr = service.generateVerificationQrPayload(
      request: request,
      now: DateTime.utc(2025, 3, 8, 11, 50),
    );
    final parsedQr = service.parseVerificationQrPayload(generatedQr.qrPayload);
    final validatedQr = service.validateVerificationQrPayload(
      qrPayload: generatedQr.qrPayload,
      expectedRequest: request,
      currentState: const ClientVerificationState(),
      now: DateTime.utc(2025, 3, 8, 11, 55),
    );

    expect(generatedQr.qrPayload, startsWith('ERI-QR1-'));
    expect(parsedQr.feature, 'offline_content');
    expect(parsedQr.requestCode, request.requestCode);
    expect(parsedQr.verificationCode, generatedQr.verificationCode);
    expect(validatedQr.expiresAtUtc, generatedQr.expiresAtUtc);
  });

  test('request-bound admin QR payload rejects tampering and expired approvals', () {
    final request = service.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'tamper-device',
        source: VerificationSeedSource.macAddress,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 1,
        videoHighlights: 1,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 0,
      ),
      now: DateTime.utc(2025, 3, 8, 12),
    );
    final generatedQr = service.generateVerificationQrPayload(
      request: request,
      now: DateTime.utc(2025, 3, 8, 12, 5),
    );

    final encodedPayload = generatedQr.qrPayload.substring('ERI-QR1-'.length);
    final decodedPayload =
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(encodedPayload)),
              ),
            )
            as Map<String, dynamic>;
    decodedPayload['verificationCode'] = 'ERI-VER1-0000-0000-0000-0000-0000';
    final tamperedQr =
        'ERI-QR1-${base64Url.encode(utf8.encode(jsonEncode(decodedPayload)))}';

    expect(
      () => service.parseVerificationQrPayload(tamperedQr),
      throwsA(
        isA<FormatException>().having(
          (error) => '${error.message}',
          'message',
          contains('checksum is invalid'),
        ),
      ),
    );
    expect(
      () => service.validateVerificationQrPayload(
        qrPayload: generatedQr.qrPayload,
        expectedRequest: request,
        currentState: const ClientVerificationState(),
        now: generatedQr.expiresAtUtc.add(const Duration(seconds: 1)),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => '${error.message}',
          'message',
          contains('expired'),
        ),
      ),
    );
  });

  test('client verification record can be created locally after scan', () {
    final request = service.createClientVerificationRecord(
      identity: const DeviceVerificationIdentity(
        seed: 'scanner-device',
        source: VerificationSeedSource.macAddress,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 1,
        videoHighlights: 1,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 1,
      ),
      now: DateTime.utc(2025, 3, 8, 12),
    );

    expect(request.feature, 'offline_content');
    expect(request.pendingCounts.totalPending, 3);
    expect(request.requestCode, startsWith('ERI-REQ1-'));
  });

  test('saving a new request clears stale verified state and exposes the pending request', () async {
    final initialRequest = service.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'saved-state-device',
        source: VerificationSeedSource.hostnameFallback,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 0,
        videoHighlights: 1,
        videoNews: 1,
        videoUpdates: 0,
        newsImages: 0,
      ),
      now: DateTime.utc(2025, 4, 1, 9),
    );
    await service.saveGeneratedRequest(initialRequest);
    await service.markClientVerified(
      request: initialRequest,
      verificationCode: service.generateVerificationCode(initialRequest.requestCode),
      verifiedAtUtc: DateTime.utc(2025, 4, 1, 9, 10),
    );

    final nextRequest = service.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'saved-state-device',
        source: VerificationSeedSource.hostnameFallback,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 1,
        videoHighlights: 0,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 0,
      ),
      now: DateTime.utc(2025, 4, 1, 9, 20),
    );
    await service.saveGeneratedRequest(nextRequest);

    final state = service.readClientState();

    expect(state.lastRequestCode, nextRequest.requestCode);
    expect(state.lastVerifiedAtUtc, isNull);
    expect(state.lastVerifiedRequestCode, isNull);
    expect(service.readPendingClientRequest()?.requestCode, nextRequest.requestCode);
  });
}
