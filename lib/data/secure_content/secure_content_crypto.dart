import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;

const String kSecureContentCryptoMagic = 'ESC1';
const int kSecureContentCryptoVersion = 1;
const int kSecureContentMacLengthBytes = 32;
const int _secureContentChunkSizeBytes = 1024 * 512;

typedef SecureContentCryptoProgressCallback = void Function({
  required int processedBytes,
  required int totalBytes,
  required bool isWritingOutput,
});

enum SecureContentType { json, image }

class SecureContentCryptoException implements Exception {
  SecureContentCryptoException(this.message);

  final String message;

  @override
  String toString() => 'SecureContentCryptoException: $message';
}

class EncryptedSecureContentHeader {
  const EncryptedSecureContentHeader({
    required this.version,
    required this.contentType,
    required this.iv,
    required this.originalExtension,
    required this.headerLength,
  });

  final int version;
  final SecureContentType contentType;
  final Uint8List iv;
  final String originalExtension;
  final int headerLength;
}

class SecureContentEncryptionResult {
  const SecureContentEncryptionResult({
    required this.destinationPath,
    required this.sourceBytes,
    required this.outputBytes,
    required this.header,
  });

  final String destinationPath;
  final int sourceBytes;
  final int outputBytes;
  final EncryptedSecureContentHeader header;
}

class SecureContentDecryptionResult {
  const SecureContentDecryptionResult({
    required this.destinationPath,
    required this.sourceBytes,
    required this.outputBytes,
    required this.header,
  });

  final String destinationPath;
  final int sourceBytes;
  final int outputBytes;
  final EncryptedSecureContentHeader header;
}

EncryptedSecureContentHeader readEncryptedSecureContentHeaderFromPath(
  String sourcePath,
) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw SecureContentCryptoException(
      'Encrypted source does not exist: $sourcePath',
    );
  }

  final raf = file.openSync(mode: FileMode.read);
  try {
    return _readHeader(raf);
  } finally {
    raf.closeSync();
  }
}

SecureContentEncryptionResult encryptSecureFileSync({
  required String sourcePath,
  required String destinationPath,
  required Uint8List masterKey,
  required SecureContentType contentType,
  bool overwrite = false,
  SecureContentCryptoProgressCallback? onProgress,
}) {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    throw SecureContentCryptoException('Source file not found: $sourcePath');
  }

  final destinationFile = File(destinationPath);
  if (destinationFile.existsSync() && !overwrite) {
    throw SecureContentCryptoException(
      'Destination already exists: $destinationPath',
    );
  }

  destinationFile.parent.createSync(recursive: true);

  final sourceExtension = _normalizeExtension(sourcePath);
  final totalBytes = sourceFile.lengthSync();
  final iv = _randomBytes(16);
  final headerBytes = _buildHeaderBytes(
    iv: iv,
    originalExtension: sourceExtension,
    contentType: contentType,
  );
  final header = EncryptedSecureContentHeader(
    version: kSecureContentCryptoVersion,
    contentType: contentType,
    iv: iv,
    originalExtension: sourceExtension,
    headerLength: headerBytes.length,
  );

  final encryptionKey = _deriveKey(masterKey, 'enc', iv);
  final authKey = _deriveKey(masterKey, 'auth', iv);

  final cipher = pc.StreamCipher('AES/CTR')
    ..init(true, pc.ParametersWithIV(pc.KeyParameter(encryptionKey), iv));

  final macSinkOutput = _DigestCaptureSink();
  final macSink =
      crypto.Hmac(crypto.sha256, authKey).startChunkedConversion(macSinkOutput);
  macSink.add(headerBytes);

  final input = sourceFile.openSync(mode: FileMode.read);
  final output = destinationFile.openSync(mode: FileMode.write);

  var sourceBytes = 0;
  try {
    output.writeFromSync(headerBytes);
    onProgress?.call(
      processedBytes: sourceBytes,
      totalBytes: totalBytes,
      isWritingOutput: false,
    );

    while (true) {
      final chunk = input.readSync(_secureContentChunkSizeBytes);
      if (chunk.isEmpty) {
        break;
      }
      sourceBytes += chunk.length;
      final encryptedChunk = cipher.process(Uint8List.fromList(chunk));
      macSink.add(encryptedChunk);
      output.writeFromSync(encryptedChunk);
      onProgress?.call(
        processedBytes: sourceBytes,
        totalBytes: totalBytes,
        isWritingOutput: false,
      );
    }

    onProgress?.call(
      processedBytes: sourceBytes,
      totalBytes: totalBytes,
      isWritingOutput: true,
    );
    macSink.close();
    output.writeFromSync(Uint8List.fromList(macSinkOutput.value.bytes));
  } finally {
    input.closeSync();
    output.closeSync();
  }

  return SecureContentEncryptionResult(
    destinationPath: destinationPath,
    sourceBytes: sourceBytes,
    outputBytes: destinationFile.lengthSync(),
    header: header,
  );
}

SecureContentDecryptionResult decryptSecureFileSync({
  required String sourcePath,
  required String destinationPath,
  required Uint8List masterKey,
  bool overwrite = true,
}) {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    throw SecureContentCryptoException(
      'Encrypted source not found: $sourcePath',
    );
  }

  final destinationFile = File(destinationPath);
  if (destinationFile.existsSync() && !overwrite) {
    throw SecureContentCryptoException(
      'Destination already exists: $destinationPath',
    );
  }

  destinationFile.parent.createSync(recursive: true);

  final input = sourceFile.openSync(mode: FileMode.read);
  final header = _readHeader(input);
  final sourceLength = sourceFile.lengthSync();
  final ciphertextLength =
      sourceLength - header.headerLength - kSecureContentMacLengthBytes;
  if (ciphertextLength <= 0) {
    input.closeSync();
    throw SecureContentCryptoException(
      'Encrypted file payload is invalid: $sourcePath',
    );
  }

  input.setPositionSync(sourceLength - kSecureContentMacLengthBytes);
  final expectedMac = input.readSync(kSecureContentMacLengthBytes);
  if (expectedMac.length != kSecureContentMacLengthBytes) {
    input.closeSync();
    throw SecureContentCryptoException(
      'Encrypted file mac block is invalid: $sourcePath',
    );
  }

  input.setPositionSync(0);
  final headerBytes = input.readSync(header.headerLength);
  if (headerBytes.length != header.headerLength) {
    input.closeSync();
    throw SecureContentCryptoException(
      'Encrypted file header block is invalid: $sourcePath',
    );
  }

  final decryptionKey = _deriveKey(masterKey, 'enc', header.iv);
  final authKey = _deriveKey(masterKey, 'auth', header.iv);

  final cipher = pc.StreamCipher('AES/CTR')
    ..init(false, pc.ParametersWithIV(pc.KeyParameter(decryptionKey), header.iv));

  final macSinkOutput = _DigestCaptureSink();
  final macSink =
      crypto.Hmac(crypto.sha256, authKey).startChunkedConversion(macSinkOutput);
  macSink.add(headerBytes);

  final output = destinationFile.openSync(mode: FileMode.write);
  var outputBytes = 0;

  try {
    input.setPositionSync(header.headerLength);
    var remaining = ciphertextLength;
    while (remaining > 0) {
      final nextRead = min(_secureContentChunkSizeBytes, remaining);
      final encryptedChunk = input.readSync(nextRead);
      if (encryptedChunk.isEmpty) {
        throw SecureContentCryptoException(
          'Encrypted payload ended unexpectedly: $sourcePath',
        );
      }

      remaining -= encryptedChunk.length;
      macSink.add(encryptedChunk);

      final plainChunk = cipher.process(Uint8List.fromList(encryptedChunk));
      output.writeFromSync(plainChunk);
      outputBytes += plainChunk.length;
    }

    macSink.close();
    final actualMac = Uint8List.fromList(macSinkOutput.value.bytes);
    if (!_constantTimeEquals(actualMac, expectedMac)) {
      throw SecureContentCryptoException(
        'Encrypted content verification failed: $sourcePath',
      );
    }
  } catch (_) {
    output.closeSync();
    input.closeSync();
    if (destinationFile.existsSync()) {
      destinationFile.deleteSync();
    }
    rethrow;
  }

  output.closeSync();
  input.closeSync();

  return SecureContentDecryptionResult(
    destinationPath: destinationPath,
    sourceBytes: sourceLength,
    outputBytes: outputBytes,
    header: header,
  );
}

EncryptedSecureContentHeader _readHeader(RandomAccessFile input) {
  input.setPositionSync(0);
  final prelude = input.readSync(9);
  if (prelude.length != 9) {
    throw SecureContentCryptoException('Encrypted content header is truncated.');
  }

  final magic = ascii.decode(prelude.sublist(0, 4));
  if (magic != kSecureContentCryptoMagic) {
    throw SecureContentCryptoException('Encrypted content magic mismatch.');
  }

  final version = prelude[4];
  if (version != kSecureContentCryptoVersion) {
    throw SecureContentCryptoException(
      'Unsupported secure content version: $version',
    );
  }

  final contentType = _contentTypeFromCode(prelude[5]);
  final ivLength = prelude[6];
  final extensionLength = prelude[7];

  if (ivLength < 12 || ivLength > 32) {
    throw SecureContentCryptoException('Encrypted content iv length is invalid.');
  }
  if (extensionLength < 2 || extensionLength > 16) {
    throw SecureContentCryptoException(
      'Encrypted content extension length is invalid.',
    );
  }

  final remainder = input.readSync(ivLength + extensionLength);
  if (remainder.length != ivLength + extensionLength) {
    throw SecureContentCryptoException(
      'Encrypted content header content is truncated.',
    );
  }

  final iv = Uint8List.fromList(remainder.sublist(0, ivLength));
  final originalExtension = _normalizeExtension(
    utf8.decode(remainder.sublist(ivLength, ivLength + extensionLength)),
  );

  return EncryptedSecureContentHeader(
    version: version,
    contentType: contentType,
    iv: iv,
    originalExtension: originalExtension,
    headerLength: 9 + ivLength + extensionLength,
  );
}

Uint8List _buildHeaderBytes({
  required Uint8List iv,
  required String originalExtension,
  required SecureContentType contentType,
}) {
  final extensionBytes = utf8.encode(_normalizeExtension(originalExtension));
  if (extensionBytes.length > 16) {
    throw SecureContentCryptoException(
      'Original extension is too long for header.',
    );
  }

  return Uint8List.fromList(<int>[
    ...ascii.encode(kSecureContentCryptoMagic),
    kSecureContentCryptoVersion,
    _contentTypeCode(contentType),
    iv.length,
    extensionBytes.length,
    0,
    ...iv,
    ...extensionBytes,
  ]);
}

int _contentTypeCode(SecureContentType contentType) {
  switch (contentType) {
    case SecureContentType.json:
      return 1;
    case SecureContentType.image:
      return 2;
  }
}

SecureContentType _contentTypeFromCode(int code) {
  switch (code) {
    case 1:
      return SecureContentType.json;
    case 2:
      return SecureContentType.image;
  }
  throw SecureContentCryptoException('Unsupported secure content type: $code');
}

Uint8List _deriveKey(Uint8List masterKey, String purpose, Uint8List iv) {
  final material = <int>[
    ...masterKey,
    ...utf8.encode('eri_sports_secure_content::$purpose::v1'),
    ...iv,
  ];
  return Uint8List.fromList(crypto.sha256.convert(material).bytes);
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

String _normalizeExtension(String extensionOrPath) {
  final lower = extensionOrPath.trim().toLowerCase();
  if (lower.isEmpty) {
    return '.bin';
  }
  if (lower.startsWith('.')) {
    return lower;
  }
  final dotIndex = lower.lastIndexOf('.');
  if (dotIndex >= 0 && dotIndex < lower.length - 1) {
    return lower.substring(dotIndex);
  }
  return '.$lower';
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }

  var diff = 0;
  for (var index = 0; index < a.length; index++) {
    diff |= a[index] ^ b[index];
  }
  return diff == 0;
}

class _DigestCaptureSink implements Sink<crypto.Digest> {
  crypto.Digest? _value;

  crypto.Digest get value {
    final digest = _value;
    if (digest == null) {
      throw SecureContentCryptoException('Digest was not produced.');
    }
    return digest;
  }

  @override
  void add(crypto.Digest data) {
    _value = data;
  }

  @override
  void close() {}
}
