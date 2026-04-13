import 'dart:convert';
import 'dart:typed_data';

import 'package:eri_sports/features/media/security/media_crypto.dart';

const String kDefaultMediaKeyBase64 =
    'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';

const String kMediaKeyEnvName = 'ERI_MEDIA_KEY_B64';

String configuredMediaKeyBase64() {
  const configured = String.fromEnvironment(
    kMediaKeyEnvName,
    defaultValue: kDefaultMediaKeyBase64,
  );
  return configured.trim();
}

Uint8List decodeMediaMasterKey(String keyBase64) {
  final normalized = keyBase64.trim();
  if (normalized.isEmpty) {
    throw MediaCryptoException('Media key is empty.');
  }

  late final Uint8List decoded;
  try {
    decoded = base64Decode(normalized);
  } catch (_) {
    throw MediaCryptoException('Media key is not valid base64.');
  }

  if (decoded.length < 16) {
    throw MediaCryptoException(
      'Media key is too short. Use at least 16 bytes (recommended 32).',
    );
  }

  return decoded;
}
