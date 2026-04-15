import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

bool _sqliteTestInitialized = false;

void initSqlite3ForTests() {
  if (_sqliteTestInitialized) {
    return;
  }

  if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, _openSqliteForWindowsTests);
  }

  _sqliteTestInitialized = true;
}

DynamicLibrary _openSqliteForWindowsTests() {
  try {
    return DynamicLibrary.open('sqlite3.dll');
  } on ArgumentError {
    return DynamicLibrary.open('winsqlite3.dll');
  }
}