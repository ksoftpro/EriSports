import 'dart:convert';
import 'dart:typed_data';

import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/features/media/security/media_crypto_config.dart';

const String kSecureContentKeyEnvName = 'ERI_SECURE_CONTENT_KEY_B64';

String configuredSecureContentKeyBase64() {
  const configured = String.fromEnvironment(
    kSecureContentKeyEnvName,
    defaultValue: '',
  );
  final trimmed = configured.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return configuredMediaKeyBase64();
}

Uint8List decodeSecureContentMasterKey(String keyBase64) {
  final normalized = keyBase64.trim();
  if (normalized.isEmpty) {
    throw SecureContentCryptoException('Secure content key is empty.');
  }

  late final Uint8List decoded;
  try {
    decoded = base64Decode(normalized);
  } catch (_) {
    throw SecureContentCryptoException('Secure content key is not valid base64.');
  }

  if (decoded.length < 16) {
    throw SecureContentCryptoException(
      'Secure content key is too short. Use at least 16 bytes.',
    );
  }

  return decoded;
}
