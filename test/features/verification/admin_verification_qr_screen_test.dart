import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:eri_sports/features/verification/presentation/admin_verification_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin QR screen renders full-screen scan target', (
    tester,
  ) async {
    final request = ClientVerificationRequest(
      requestCode: 'ERI-REQ1-test-request',
      feature: 'offline_content',
      requestDayKey: '20260426',
      deviceDigest: 'device-digest',
      seedSource: VerificationSeedSource.macAddress,
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 1,
        videoHighlights: 2,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 1,
      ),
      generatedAtUtc: DateTime.utc(2026, 4, 26, 12),
    );

    final payload = VerificationQrPayload(
      qrPayload: 'ERI-QR1-test-payload',
      request: request,
      verificationCode: 'ERI-VER1-ABCD-EFGH-IJKL-MNOP-QRST',
      issuedAtUtc: DateTime.utc(2026, 4, 26, 12, 5),
    );

    await tester.pumpWidget(
      MaterialApp(home: AdminVerificationQrScreen(payload: payload)),
    );

    expect(
      find.text('Scan this QR from the client Settings screen'),
      findsOneWidget,
    );
    expect(find.text('Manual fallback verification code'), findsOneWidget);
    expect(find.text('4 pending items'), findsOneWidget);
    expect(find.text(payload.verificationCode), findsOneWidget);
  });
}
