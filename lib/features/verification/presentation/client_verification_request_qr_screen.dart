import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ClientVerificationRequestQrScreen extends StatelessWidget {
  const ClientVerificationRequestQrScreen({
    super.key,
    required this.request,
  });

  final ClientVerificationRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Client verification QR')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primary.withValues(alpha: 0.08),
              scheme.surface,
              scheme.tertiary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Show this QR to the admin app first',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The admin app must scan this client request QR before it can generate the unique approval QR for this device and verification session.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: request.requestCode,
                            version: QrVersions.auto,
                            size: 280,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            ContentVerificationService.featureLabel(
                              request.feature,
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${request.pendingCounts.totalPending} pending item${request.pendingCounts.totalPending == 1 ? '' : 's'} waiting for admin verification',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoChip(
                          label: 'Generated',
                          value: DateFormat(
                            'MMM d, yyyy HH:mm',
                          ).format(request.generatedAtUtc.toLocal()),
                        ),
                        _InfoChip(
                          label: 'Request day',
                          value: request.requestDayKey,
                        ),
                        _InfoChip(
                          label: 'Device seed',
                          value: request.seedSource.name,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}