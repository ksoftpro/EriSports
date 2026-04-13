import 'dart:convert';
import 'dart:io';

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
  final keyBase64 = parsed['key-base64'] ?? Platform.environment[kMediaKeyEnvName];
  final overwrite = parsed.containsKey('overwrite');

  if (keyBase64 == null || keyBase64.trim().isEmpty) {
    stderr.writeln(
      'Missing key. Pass --key-base64 or set environment variable $kMediaKeyEnvName.',
    );
    exitCode = 2;
    return;
  }

  final masterKey = decodeMediaMasterKey(keyBase64);

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
    stdout.writeln('No supported source video files found in $inputPath');
    return;
  }

  final nowUtc = DateTime.now().toUtc().toIso8601String();
  final manifest = <Map<String, dynamic>>[];

  for (final sourceFile in files) {
    final relative = _relativeInputPath(
      sourcePath: sourceFile.path,
      inputPath: inputPath,
      inputEntity: inputEntity,
    );

    final encryptedRelative = '$relative$kEncryptedMediaExtension';
    final destinationPath = p.join(outputDirectory.path, encryptedRelative);

    final result = encryptMediaFileSync(
      sourcePath: sourceFile.path,
      destinationPath: destinationPath,
      masterKey: masterKey,
      overwrite: overwrite,
    );

    manifest.add({
      'sourceRelativePath': relative,
      'encryptedRelativePath': encryptedRelative,
      'sourceBytes': result.sourceBytes,
      'encryptedBytes': result.outputBytes,
      'algorithm': 'AES-CTR + HMAC-SHA256',
      'version': kMediaCryptoVersion,
      'encryptedAtUtc': nowUtc,
    });

    stdout.writeln('Encrypted $relative -> $encryptedRelative');
  }

  final manifestFile = File(
    p.join(outputDirectory.path, 'media_encryption_manifest.json'),
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
    final ext = p.extension(file.path).toLowerCase();
    if (isEncryptedMediaPath(file.path) ||
        !kSupportedPlainVideoExtensions.contains(ext)) {
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

    final ext = p.extension(entity.path).toLowerCase();
    if (isEncryptedMediaPath(entity.path)) {
      continue;
    }
    if (!kSupportedPlainVideoExtensions.contains(ext)) {
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
  stdout.writeln('Key can also come from environment variable $kMediaKeyEnvName.');
}
