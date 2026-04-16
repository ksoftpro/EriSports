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

String _readMediaFileOriginalExtensionMessage(Map<String, Object?> message) {
  final header = readEncryptedMediaHeaderFromPath(
    message['sourcePath']! as String,
  );
  return header.originalExtension;
}

dynamic _decodeJsonMessage(Map<String, Object?> message) {
  return jsonDecode(message['raw']! as String);
}