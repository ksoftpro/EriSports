import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;

const String kEncryptedMediaExtension = '.esv';
const String kMediaCryptoMagic = 'ESM1';
const int kMediaCryptoVersion = 1;
const int kMacLengthBytes = 32;
const int _chunkSizeBytes = 1024 * 512;

typedef MediaCryptoProgressCallback = void Function({
  required int processedBytes,
  required int totalBytes,
  required bool isWritingOutput,
});

const Set<String> kSupportedPlainVideoExtensions = {
  '.mp4',
  '.mov',
  '.m4v',
  '.webm',
  '.mkv',
  '.avi',
  '.3gp',
};

bool isEncryptedMediaPath(String path) {
  return path.toLowerCase().endsWith(kEncryptedMediaExtension);
}

String encryptedOutputPathFor(String sourcePath) {
  return '$sourcePath$kEncryptedMediaExtension';
}

class MediaCryptoException implements Exception {
  MediaCryptoException(this.message);

  final String message;

  @override
  String toString() => 'MediaCryptoException: $message';
}

class EncryptedMediaHeader {
  const EncryptedMediaHeader({
    required this.version,
    required this.iv,
    required this.originalExtension,
    required this.headerLength,
  });

  final int version;
  final Uint8List iv;
  final String originalExtension;
  final int headerLength;
}

class MediaEncryptionResult {
  const MediaEncryptionResult({
    required this.destinationPath,
    required this.sourceBytes,
    required this.outputBytes,
    required this.header,
  });

  final String destinationPath;
  final int sourceBytes;
  final int outputBytes;
  final EncryptedMediaHeader header;
}

class MediaDecryptionResult {
  const MediaDecryptionResult({
    required this.destinationPath,
    required this.sourceBytes,
    required this.outputBytes,
    required this.header,
  });

  final String destinationPath;
  final int sourceBytes;
  final int outputBytes;
  final EncryptedMediaHeader header;
}

EncryptedMediaHeader readEncryptedMediaHeaderFromPath(String sourcePath) {
  final file = File(sourcePath);
  if (!file.existsSync()) {
    throw MediaCryptoException('Encrypted source does not exist: $sourcePath');
  }

  final raf = file.openSync(mode: FileMode.read);
  try {
    return _readHeader(raf);
  } finally {
    raf.closeSync();
  }
}

MediaEncryptionResult encryptMediaFileSync({
  required String sourcePath,
  required String destinationPath,
  required Uint8List masterKey,
  bool overwrite = false,
  MediaCryptoProgressCallback? onProgress,
}) {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    throw MediaCryptoException('Source file not found: $sourcePath');
  }

  final sourceExtension = _normalizeExtension(sourcePath);
  final totalBytes = sourceFile.lengthSync();
  if (!kSupportedPlainVideoExtensions.contains(sourceExtension)) {
    throw MediaCryptoException(
      'Unsupported source video extension: $sourceExtension',
    );
  }

  final destinationFile = File(destinationPath);
  if (destinationFile.existsSync() && !overwrite) {
    throw MediaCryptoException('Destination already exists: $destinationPath');
  }

  destinationFile.parent.createSync(recursive: true);

  final iv = _randomBytes(16);
  final headerBytes = _buildHeaderBytes(iv: iv, originalExtension: sourceExtension);
  final header = EncryptedMediaHeader(
    version: kMediaCryptoVersion,
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
      final chunk = input.readSync(_chunkSizeBytes);
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
    final mac = Uint8List.fromList(macSinkOutput.value.bytes);
    output.writeFromSync(mac);
  } finally {
    input.closeSync();
    output.closeSync();
  }

  return MediaEncryptionResult(
    destinationPath: destinationPath,
    sourceBytes: sourceBytes,
    outputBytes: destinationFile.lengthSync(),
    header: header,
  );
}

MediaDecryptionResult decryptMediaFileSync({
  required String sourcePath,
  required String destinationPath,
  required Uint8List masterKey,
  bool overwrite = true,
}) {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    throw MediaCryptoException('Encrypted source not found: $sourcePath');
  }

  final destinationFile = File(destinationPath);
  if (destinationFile.existsSync() && !overwrite) {
    throw MediaCryptoException('Destination already exists: $destinationPath');
  }

  destinationFile.parent.createSync(recursive: true);

  final input = sourceFile.openSync(mode: FileMode.read);
  final header = _readHeader(input);
  final sourceLength = sourceFile.lengthSync();

  final ciphertextLength = sourceLength - header.headerLength - kMacLengthBytes;
  if (ciphertextLength <= 0) {
    input.closeSync();
    throw MediaCryptoException('Encrypted file payload is invalid: $sourcePath');
  }

  input.setPositionSync(sourceLength - kMacLengthBytes);
  final expectedMac = input.readSync(kMacLengthBytes);
  if (expectedMac.length != kMacLengthBytes) {
    input.closeSync();
    throw MediaCryptoException('Encrypted file mac block is invalid: $sourcePath');
  }

  input.setPositionSync(0);
  final headerBytes = input.readSync(header.headerLength);
  if (headerBytes.length != header.headerLength) {
    input.closeSync();
    throw MediaCryptoException('Encrypted file header block is invalid: $sourcePath');
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
      final nextRead = min(_chunkSizeBytes, remaining);
      final encryptedChunk = input.readSync(nextRead);
      if (encryptedChunk.isEmpty) {
        throw MediaCryptoException(
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
      throw MediaCryptoException('Encrypted media verification failed: $sourcePath');
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

  return MediaDecryptionResult(
    destinationPath: destinationPath,
    sourceBytes: sourceLength,
    outputBytes: outputBytes,
    header: header,
  );
}

EncryptedMediaHeader _readHeader(RandomAccessFile input) {
  input.setPositionSync(0);
  final prelude = input.readSync(8);
  if (prelude.length != 8) {
    throw MediaCryptoException('Encrypted media header is truncated.');
  }

  final magic = ascii.decode(prelude.sublist(0, 4));
  if (magic != kMediaCryptoMagic) {
    throw MediaCryptoException('Encrypted media magic mismatch.');
  }

  final version = prelude[4];
  if (version != kMediaCryptoVersion) {
    throw MediaCryptoException('Unsupported media crypto version: $version');
  }

  final ivLength = prelude[5];
  final extensionLength = prelude[6];

  if (ivLength < 12 || ivLength > 32) {
    throw MediaCryptoException('Encrypted media iv length is invalid: $ivLength');
  }

  if (extensionLength < 2 || extensionLength > 16) {
    throw MediaCryptoException(
      'Encrypted media extension length is invalid: $extensionLength',
    );
  }

  final remainder = input.readSync(ivLength + extensionLength);
  if (remainder.length != ivLength + extensionLength) {
    throw MediaCryptoException('Encrypted media header content is truncated.');
  }

  final iv = Uint8List.fromList(remainder.sublist(0, ivLength));
  final originalExtension = _normalizeExtension(
    utf8.decode(remainder.sublist(ivLength, ivLength + extensionLength)),
  );

  return EncryptedMediaHeader(
    version: version,
    iv: iv,
    originalExtension: originalExtension,
    headerLength: 8 + ivLength + extensionLength,
  );
}

Uint8List _buildHeaderBytes({
  required Uint8List iv,
  required String originalExtension,
}) {
  final extensionBytes = utf8.encode(_normalizeExtension(originalExtension));
  if (extensionBytes.length > 16) {
    throw MediaCryptoException('Original extension is too long for header.');
  }

  return Uint8List.fromList(<int>[
    ...ascii.encode(kMediaCryptoMagic),
    kMediaCryptoVersion,
    iv.length,
    extensionBytes.length,
    0,
    ...iv,
    ...extensionBytes,
  ]);
}

Uint8List _deriveKey(Uint8List masterKey, String purpose, Uint8List iv) {
  final material = <int>[
    ...masterKey,
    ...utf8.encode('eri_sports_media::$purpose::v1'),
    ...iv,
  ];
  return Uint8List.fromList(crypto.sha256.convert(material).bytes);
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  final bytes = List<int>.generate(length, (_) => random.nextInt(256));
  return Uint8List.fromList(bytes);
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
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

class _DigestCaptureSink implements Sink<crypto.Digest> {
  crypto.Digest? _value;

  crypto.Digest get value {
    final digest = _value;
    if (digest == null) {
      throw MediaCryptoException('Digest was not produced.');
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
