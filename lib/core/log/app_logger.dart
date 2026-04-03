import 'package:flutter/foundation.dart';

class AppLogger {
  void info(String message) {
    debugPrint('[INFO] $message');
  }

  void warn(String message) {
    debugPrint('[WARN] $message');
  }

  void error(String message, [Object? error]) {
    debugPrint('[ERROR] $message ${error ?? ''}');
  }
}