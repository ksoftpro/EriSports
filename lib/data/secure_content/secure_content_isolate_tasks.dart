import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';

Future<void> runSecureFileDecryptInIsolate({
  required String sourcePath,
  required String destinationPath,
  required Uint8List masterKey,
  bool overwrite = true,
}) {
  final message = <String, Object?>{
    'sourcePath': sourcePath,
    'destinationPath': destinationPath,
    'masterKey': Uint8List.fromList(masterKey),
    'overwrite': overwrite,
  };
  return Isolate.run(() => _decryptSecureFileMessage(message));
}

Future<void> runSecureFileEncryptInIsolate({
  required String sourcePath,
  required String destinationPath,
  required Uint8List masterKey,
  required SecureContentType contentType,
  bool overwrite = true,
}) {
  final message = <String, Object?>{
    'sourcePath': sourcePath,
    'destinationPath': destinationPath,
    'masterKey': Uint8List.fromList(masterKey),
    'contentType': contentType.name,
    'overwrite': overwrite,
  };
  return Isolate.run(() => _encryptSecureFileMessage(message));
}

Future<String> readSecureFileOriginalExtensionInIsolate(String sourcePath) {
  final message = <String, Object?>{'sourcePath': sourcePath};
  return Isolate.run(() => _readSecureFileOriginalExtensionMessage(message));
}

Future<void> runMediaFileDecryptInIsolate({
  required String sourcePath,
  required String destinationPath,
  required Uint8List masterKey,
  bool overwrite = true,
}) {
  final message = <String, Object?>{
    'sourcePath': sourcePath,
    'destinationPath': destinationPath,
    'masterKey': Uint8List.fromList(masterKey),
    'overwrite': overwrite,
  };
  return Isolate.run(() => _decryptMediaFileMessage(message));
}

Future<void> runMediaFileEncryptInIsolate({
  required String sourcePath,
  required String destinationPath,
  required Uint8List masterKey,
  bool overwrite = true,
}) {
  final message = <String, Object?>{
    'sourcePath': sourcePath,
    'destinationPath': destinationPath,
    'masterKey': Uint8List.fromList(masterKey),
    'overwrite': overwrite,
  };
  return Isolate.run(() => _encryptMediaFileMessage(message));
}

Future<String> readMediaFileOriginalExtensionInIsolate(String sourcePath) {
  final message = <String, Object?>{'sourcePath': sourcePath};
  return Isolate.run(() => _readMediaFileOriginalExtensionMessage(message));
}

Future<dynamic> runJsonDecodeInIsolate(String raw) {
  final message = <String, Object?>{'raw': raw};
  return Isolate.run(() => _decodeJsonMessage(message));
}

void _decryptSecureFileMessage(Map<String, Object?> message) {
  decryptSecureFileSync(
    sourcePath: message['sourcePath']! as String,
    destinationPath: message['destinationPath']! as String,
    masterKey: message['masterKey']! as Uint8List,
    overwrite: message['overwrite']! as bool,
  );
}

void _encryptSecureFileMessage(Map<String, Object?> message) {
  encryptSecureFileSync(
    sourcePath: message['sourcePath']! as String,
    destinationPath: message['destinationPath']! as String,
    masterKey: message['masterKey']! as Uint8List,
    contentType: _secureContentTypeFromName(message['contentType']! as String),
    overwrite: message['overwrite']! as bool,
  );
}

String _readSecureFileOriginalExtensionMessage(Map<String, Object?> message) {
  final header = readEncryptedSecureContentHeaderFromPath(
    message['sourcePath']! as String,
  );
  return header.originalExtension;
}

void _decryptMediaFileMessage(Map<String, Object?> message) {
  decryptMediaFileSync(
    sourcePath: message['sourcePath']! as String,
    destinationPath: message['destinationPath']! as String,
    masterKey: message['masterKey']! as Uint8List,
    overwrite: message['overwrite']! as bool,
  );
}

void _encryptMediaFileMessage(Map<String, Object?> message) {
  encryptMediaFileSync(
    sourcePath: message['sourcePath']! as String,
    destinationPath: message['destinationPath']! as String,
    masterKey: message['masterKey']! as Uint8List,
    overwrite: message['overwrite']! as bool,
  );
}

String _readMediaFileOriginalExtensionMessage(Map<String, Object?> message) {
  final header = readEncryptedMediaHeaderFromPath(
    message['sourcePath']! as String,
  );
  return header.originalExtension;
}

dynamic _decodeJsonMessage(Map<String, Object?> message) {
  return jsonDecode(message['raw']! as String);
}

SecureContentType _secureContentTypeFromName(String name) {
  switch (name) {
    case 'json':
      return SecureContentType.json;
    case 'image':
      return SecureContentType.image;
  }
  throw ArgumentError.value(name, 'name', 'Unsupported secure content type');
}