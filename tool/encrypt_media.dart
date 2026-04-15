import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto_config.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:eri_sports/features/media/security/media_crypto_config.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final parsed = _parseArgs(args);
  if (parsed == null) {
    _printUsage();
    exitCode = 2;
    return;
  }

  final inputPath = parsed['input']!;
  final outputPath = parsed['output']!;
  final keyBase64 =
      parsed['key-base64'] ??
      Platform.environment[kSecureContentKeyEnvName] ??
      Platform.environment[kMediaKeyEnvName];
  final overwrite = parsed.containsKey('overwrite');

  if (keyBase64 == null || keyBase64.trim().isEmpty) {
    stderr.writeln(
      'Missing key. Pass --key-base64 or set environment variable $kSecureContentKeyEnvName or $kMediaKeyEnvName.',
    );
    exitCode = 2;
    return;
  }

  final mediaMasterKey = decodeMediaMasterKey(keyBase64);
  final secureContentMasterKey = decodeSecureContentMasterKey(keyBase64);

  final inputEntity = FileSystemEntity.typeSync(inputPath);
  if (inputEntity == FileSystemEntityType.notFound) {
    stderr.writeln('Input path not found: $inputPath');
    exitCode = 2;
    return;
  }

  final outputDirectory = Directory(outputPath);
  outputDirectory.createSync(recursive: true);

  final files = _collectSourceFiles(inputPath, inputEntity);
  if (files.isEmpty) {
    stdout.writeln('No supported source JSON/image/video files found in $inputPath');
    return;
  }

  final nowUtc = DateTime.now().toUtc().toIso8601String();
  final manifest = <Map<String, dynamic>>[];

  for (final sourceFile in files) {
    final target = _encryptedTargetFor(sourceFile.path);
    if (target == null) {
      continue;
    }

    final relative = _relativeInputPath(
      sourcePath: sourceFile.path,
      inputPath: inputPath,
      inputEntity: inputEntity,
    );

    final encryptedRelative = '$relative${target.encryptedExtension}';
    final destinationPath = p.join(outputDirectory.path, encryptedRelative);

    final sourceBytes = sourceFile.lengthSync();
    final outputBytes = _encryptFile(
      sourcePath: sourceFile.path,
      destinationPath: destinationPath,
      target: target,
      mediaMasterKey: mediaMasterKey,
      secureContentMasterKey: secureContentMasterKey,
      overwrite: overwrite,
    );

    manifest.add({
      'contentKind': target.kindLabel,
      'sourceRelativePath': relative,
      'encryptedRelativePath': encryptedRelative,
      'sourceBytes': sourceBytes,
      'encryptedBytes': outputBytes,
      'algorithm': 'AES-CTR + HMAC-SHA256',
      'version': 1,
      'encryptedAtUtc': nowUtc,
    });

    stdout.writeln('[${target.kindLabel}] $relative -> $encryptedRelative');
  }

  final manifestFile = File(
    p.join(outputDirectory.path, 'secure_content_manifest.json'),
  );
  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'createdAtUtc': nowUtc,
      'source': inputPath,
      'output': outputPath,
      'totalFiles': manifest.length,
      'files': manifest,
    }),
  );

  stdout.writeln('Done. Encrypted ${manifest.length} files.');
  stdout.writeln('Manifest: ${manifestFile.path}');
}

int _encryptFile({
  required String sourcePath,
  required String destinationPath,
  required _EncryptedTarget target,
  required List<int> mediaMasterKey,
  required List<int> secureContentMasterKey,
  required bool overwrite,
}) {
  if (target.secureContentType != null) {
    final result = encryptSecureFileSync(
      sourcePath: sourcePath,
      destinationPath: destinationPath,
      masterKey: Uint8List.fromList(secureContentMasterKey),
      contentType: target.secureContentType!,
      overwrite: overwrite,
    );
    return result.outputBytes;
  }

  final result = encryptMediaFileSync(
    sourcePath: sourcePath,
    destinationPath: destinationPath,
    masterKey: Uint8List.fromList(mediaMasterKey),
    overwrite: overwrite,
  );
  return result.outputBytes;
}

Map<String, String>? _parseArgs(List<String> args) {
  final result = <String, String>{};

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--input':
      case '--output':
      case '--key-base64':
        if (i + 1 >= args.length) {
          return null;
        }
        result[arg.substring(2)] = args[++i];
        break;
      case '--overwrite':
        result['overwrite'] = 'true';
        break;
      case '--help':
      case '-h':
        return null;
      default:
        return null;
    }
  }

  if (!result.containsKey('input') || !result.containsKey('output')) {
    return null;
  }

  return result;
}

List<File> _collectSourceFiles(
  String inputPath,
  FileSystemEntityType inputType,
) {
  if (inputType == FileSystemEntityType.file) {
    final file = File(inputPath);
    if (_encryptedTargetFor(file.path) == null) {
      return const <File>[];
    }
    return <File>[file];
  }

  final directory = Directory(inputPath);
  final files = <File>[];

  for (final entity in directory.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }

    if (_encryptedTargetFor(entity.path) == null) {
      continue;
    }

    files.add(entity);
  }

  files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  return files;
}

String _relativeInputPath({
  required String sourcePath,
  required String inputPath,
  required FileSystemEntityType inputEntity,
}) {
  if (inputEntity == FileSystemEntityType.file) {
    return p.basename(sourcePath);
  }

  return p.relative(sourcePath, from: inputPath);
}

void _printUsage() {
  stdout.writeln('Usage:');
  stdout.writeln(
    '  dart run tool/encrypt_media.dart --input <file-or-directory> --output <directory> [--key-base64 <base64>] [--overwrite]',
  );
  stdout.writeln('');
  stdout.writeln(
    'Key can also come from environment variable $kSecureContentKeyEnvName or $kMediaKeyEnvName.',
  );
}

_EncryptedTarget? _encryptedTargetFor(String sourcePath) {
  final lower = sourcePath.toLowerCase();
  final extension = p.extension(lower);
  if (isEncryptedSecureContentPath(lower)) {
    return null;
  }
  if (kSupportedPlainJsonExtensions.contains(extension)) {
    return const _EncryptedTarget.json();
  }
  if (kSupportedPlainImageExtensions.contains(extension)) {
    return const _EncryptedTarget.image();
  }
  if (kSupportedPlainVideoExtensions.contains(extension)) {
    return const _EncryptedTarget.video();
  }
  return null;
}

class _EncryptedTarget {
  const _EncryptedTarget({
    required this.kindLabel,
    required this.encryptedExtension,
    required this.secureContentType,
  });

  const _EncryptedTarget.json()
    : kindLabel = 'json',
      encryptedExtension = kEncryptedJsonExtension,
      secureContentType = SecureContentType.json;

  const _EncryptedTarget.image()
    : kindLabel = 'image',
      encryptedExtension = kEncryptedImageExtension,
      secureContentType = SecureContentType.image;

  const _EncryptedTarget.video()
    : kindLabel = 'video',
      encryptedExtension = kEncryptedMediaExtension,
      secureContentType = null;

  final String kindLabel;
  final String encryptedExtension;
  final SecureContentType? secureContentType;
}
