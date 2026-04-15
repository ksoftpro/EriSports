import 'dart:io';

import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/encrypted_image_service.dart';
import 'package:eri_sports/data/secure_content/encrypted_json_service.dart';
import 'package:eri_sports/features/media/security/encrypted_media_service.dart';

class DaylysportSecureContentCoordinator {
  DaylysportSecureContentCoordinator({
    required this.fileResolver,
    required this.encryptedJsonService,
    required this.encryptedImageService,
    required this.encryptedMediaService,
  });

  final EncryptedFileResolver fileResolver;
  final EncryptedJsonService encryptedJsonService;
  final EncryptedImageService encryptedImageService;
  final EncryptedMediaService encryptedMediaService;

  Future<void> warmUp() async {
    await Future.wait<void>([
      encryptedJsonService.warmUpCache(),
      encryptedImageService.warmUpCache(),
      encryptedMediaService.warmUpCache(),
    ]);
  }

  Future<String> readJsonText(File sourceFile) {
    return encryptedJsonService.readTextFile(sourceFile);
  }

  Future<dynamic> readDecodedJson(File sourceFile) {
    return encryptedJsonService.readDecodedJson(sourceFile);
  }

  Future<ResolvedPlainJsonFile> resolveJsonFile(File sourceFile) {
    return encryptedJsonService.resolvePlaintextFile(sourceFile);
  }

  Future<ResolvedSecureImage> resolveImageFile(File sourceFile) {
    return encryptedImageService.resolveImageFile(sourceFile);
  }

  Future<ResolvedPlayableMedia> resolvePlayableMedia(File sourceFile) {
    return encryptedMediaService.resolvePlayableFile(sourceFile);
  }
}
