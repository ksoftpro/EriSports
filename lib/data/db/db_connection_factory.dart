import 'package:drift/drift.dart';

import 'db_connection_native.dart'
    if (dart.library.js_interop) 'db_connection_web.dart' as impl;

QueryExecutor openDriftConnection() {
  return impl.openDriftConnection();
}
