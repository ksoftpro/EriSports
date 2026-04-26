import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_verification_service.dart';

const _deviceIdentityChannel = MethodChannel(
  'eri_sports/device_verification_identity',
);

class DeviceVerificationIdentityService {
  const DeviceVerificationIdentityService();

  Future<DeviceVerificationIdentity> resolveIdentity() async {
    if (Platform.isAndroid) {
      try {
        final result = await _deviceIdentityChannel.invokeMapMethod<String, dynamic>(
          'getDeviceIdentity',
        );
        if (result != null) {
          final seed = result['seed'] as String?;
          final sourceName = result['source'] as String?;
          if (seed != null && seed.trim().isNotEmpty) {
            return DeviceVerificationIdentity(
              seed: seed.trim(),
              source: VerificationSeedSource.values.firstWhere(
                (value) => value.name == sourceName,
                orElse: () => VerificationSeedSource.unknown,
              ),
            );
          }
        }
      } on MissingPluginException {
        // Fall through to the platform fallback when the channel is unavailable.
      } on PlatformException {
        // Fall through to the platform fallback when native identity lookup fails.
      }
    }

    final fallbackSeed =
        Platform.localHostname.trim().isEmpty ? 'unknown-host' : Platform.localHostname.trim();
    return DeviceVerificationIdentity(
      seed: fallbackSeed,
      source: VerificationSeedSource.hostnameFallback,
    );
  }
}

final deviceVerificationIdentityServiceProvider =
    Provider<DeviceVerificationIdentityService>((ref) {
      return const DeviceVerificationIdentityService();
    });