import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openDriftConnection() {
  return WebDatabase('eri_sports_web_db');
}
