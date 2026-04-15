import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:path/path.dart' as p;

const String kEncryptedJsonExtension = '.esj';
const String kEncryptedImageExtension = '.esi';

const Set<String> kSupportedPlainJsonExtensions = {'.json'};

const Set<String> kSupportedPlainImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.bmp',
};

enum SecureContentKind { json, image, video, other }

class SecureContentDescriptor {
  const SecureContentDescriptor({
    required this.path,
    required this.kind,
    required this.isEncrypted,
    required this.logicalPath,
    required this.logicalFileName,
    required this.logicalExtension,
  });

  final String path;
  final SecureContentKind kind;
  final bool isEncrypted;
  final String logicalPath;
  final String logicalFileName;
  final String logicalExtension;
}

class EncryptedFileResolver {
  const EncryptedFileResolver();

  SecureContentDescriptor describePath(String path) {
    final logicalPath = logicalSecureContentPath(path);
    return SecureContentDescriptor(
      path: path,
      kind: secureContentKindForPath(path),
      isEncrypted: isEncryptedSecureContentPath(path),
      logicalPath: logicalPath,
      logicalFileName: p.basename(logicalPath),
      logicalExtension: p.extension(logicalPath).toLowerCase(),
    );
  }

  String logicalFileName(String path) => logicalSecureContentFileName(path);

  String logicalRelativePath(String path, {required String fromDirectory}) {
    return logicalSecureContentRelativePath(path, fromDirectory: fromDirectory);
  }

  bool isSupportedJsonPath(String path) => isSupportedSecureJsonPath(path);

  bool isSupportedImagePath(String path) => isSupportedSecureImagePath(path);

  bool isSupportedVideoPath(String path) => isSupportedSecureVideoPath(path);

  bool isEncryptedPath(String path) => isEncryptedSecureContentPath(path);

  List<String> candidateJsonPaths(String logicalJsonPath) {
    return candidateSecureJsonPaths(logicalJsonPath);
  }
}

bool isEncryptedJsonPath(String path) {
  return path.toLowerCase().endsWith(kEncryptedJsonExtension);
}

bool isEncryptedImagePath(String path) {
  return path.toLowerCase().endsWith(kEncryptedImageExtension);
}

bool isEncryptedSecureContentPath(String path) {
  return isEncryptedJsonPath(path) ||
      isEncryptedImagePath(path) ||
      isEncryptedMediaPath(path);
}

bool isSupportedSecureJsonPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.json') || lower.endsWith('.json$kEncryptedJsonExtension');
}

bool isSupportedSecureImagePath(String path) {
  final lower = path.toLowerCase();
  if (isEncryptedImagePath(lower)) {
    return true;
  }
  return kSupportedPlainImageExtensions.contains(p.extension(lower));
}

bool isSupportedSecureVideoPath(String path) {
  final lower = path.toLowerCase();
  if (isEncryptedMediaPath(lower)) {
    return true;
  }
  return kSupportedPlainVideoExtensions.contains(p.extension(lower));
}

SecureContentKind secureContentKindForPath(String path) {
  if (isSupportedSecureJsonPath(path)) {
    return SecureContentKind.json;
  }
  if (isSupportedSecureImagePath(path)) {
    return SecureContentKind.image;
  }
  if (isSupportedSecureVideoPath(path)) {
    return SecureContentKind.video;
  }
  return SecureContentKind.other;
}

String logicalSecureContentPath(String path) {
  final lower = path.toLowerCase();
  if (isEncryptedJsonPath(lower) ||
      isEncryptedImagePath(lower) ||
      isEncryptedMediaPath(lower)) {
    return path.substring(0, path.length - 4);
  }
  return path;
}

String logicalSecureContentFileName(String path) {
  return p.basename(logicalSecureContentPath(path));
}

String logicalSecureContentRelativePath(
  String path, {
  required String fromDirectory,
}) {
  final relative = p.relative(path, from: fromDirectory);
  return logicalSecureContentPath(relative);
}

List<String> candidateSecureJsonPaths(String logicalJsonPath) {
  final normalized = logicalJsonPath.toLowerCase();
  if (normalized.endsWith('.json$kEncryptedJsonExtension')) {
    return [logicalJsonPath];
  }

  if (normalized.endsWith('.json')) {
    return [logicalJsonPath, '$logicalJsonPath$kEncryptedJsonExtension'];
  }

  return [logicalJsonPath, '$logicalJsonPath$kEncryptedJsonExtension'];
}
