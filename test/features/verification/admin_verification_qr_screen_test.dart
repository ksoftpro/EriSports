import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:eri_sports/features/verification/presentation/admin_verification_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin QR screen renders full-screen scan target', (
    tester,
  ) async {
    final payload = VerificationQrPayload(
      qrPayload: 'ERI-QR1-test-payload',
      feature: 'offline_content',
      verificationCode: 'ERI-VER1-ABCD-EFGH-IJKL-MNOP-QRST',
      issuedAtUtc: DateTime.utc(2026, 4, 26, 12, 5),
      expiresAtUtc: DateTime.utc(2026, 4, 26, 12, 15),
    );

    await tester.pumpWidget(
      MaterialApp(home: AdminVerificationQrScreen(payload: payload)),
    );

    expect(
      find.text('Scan this QR from the client Settings screen'),
      findsOneWidget,
    );
    expect(find.text('Direct admin approval'), findsOneWidget);
    expect(find.text('Valid until'), findsOneWidget);
  });
}
