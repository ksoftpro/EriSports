import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  test('verification QR payload round-trips and validates', () {
    final request = service.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'scanner-device',
        source: VerificationSeedSource.macAddress,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 1,
        videoHighlights: 2,
        videoNews: 1,
        videoUpdates: 0,
        newsImages: 0,
      ),
      now: DateTime.utc(2025, 3, 8, 11, 45),
    );

    final generatedQr = service.generateVerificationQrPayload(
      request.requestCode,
      now: DateTime.utc(2025, 3, 8, 11, 50),
    );
    final parsedQr = service.parseVerificationQrPayload(generatedQr.qrPayload);
    final validatedQr = service.validateVerificationQrPayload(
      qrPayload: generatedQr.qrPayload,
      expectedRequestCode: request.requestCode,
    );

    expect(generatedQr.qrPayload, startsWith('ERI-QR1-'));
    expect(parsedQr.request.requestCode, request.requestCode);
    expect(parsedQr.verificationCode, generatedQr.verificationCode);
    expect(validatedQr.request.pendingCounts.totalPending, 4);
    expect(
      service.isVerificationCodeValid(
        requestCode: validatedQr.request.requestCode,
        verificationCode: validatedQr.verificationCode,
      ),
      isTrue,
    );
  });

  test('verification QR payload rejects tampering and stale requests', () {
    final staleRequest = service.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'scanner-device',
        source: VerificationSeedSource.macAddress,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 1,
        videoHighlights: 0,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 0,
      ),
      now: DateTime.utc(2025, 3, 8, 10),
    );
    final currentRequest = service.generateClientRequest(
      identity: const DeviceVerificationIdentity(
        seed: 'scanner-device',
        source: VerificationSeedSource.macAddress,
      ),
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 2,
        videoHighlights: 1,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 1,
      ),
      now: DateTime.utc(2025, 3, 8, 12),
    );
    final staleQr = service.generateVerificationQrPayload(
      staleRequest.requestCode,
      now: DateTime.utc(2025, 3, 8, 12, 5),
    );

    final encodedPayload = staleQr.qrPayload.substring('ERI-QR1-'.length);
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
        qrPayload: staleQr.qrPayload,
        expectedRequestCode: currentRequest.requestCode,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => '${error.message}',
          'message',
          contains('has expired'),
        ),
      ),
    );
  });
}
