import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:eri_sports/features/verification/presentation/client_verification_request_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('client request QR screen renders the first verification step', (
    tester,
  ) async {
    final request = ClientVerificationRequest(
      requestCode: 'ERI-REQ1-test-request',
      feature: 'offline_content',
      requestDayKey: '20260429',
      deviceDigest: 'device-digest',
      seedSource: VerificationSeedSource.hostnameFallback,
      pendingCounts: const ContentVerificationPendingCounts(
        reels: 1,
        videoHighlights: 2,
        videoNews: 0,
        videoUpdates: 0,
        newsImages: 1,
      ),
      generatedAtUtc: DateTime.utc(2026, 4, 29, 12),
    );

    await tester.pumpWidget(
      MaterialApp(home: ClientVerificationRequestQrScreen(request: request)),
    );

    expect(find.text('Client verification QR'), findsOneWidget);
    expect(find.text('Show this QR to the admin app first'), findsOneWidget);
    expect(find.text('Request day'), findsOneWidget);
    expect(find.text('Device seed'), findsOneWidget);
  });
}