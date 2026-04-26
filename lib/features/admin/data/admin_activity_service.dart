import 'dart:collection';

import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/admin/data/admin_models.dart';
import 'package:flutter/foundation.dart';

class AdminActivityService extends ChangeNotifier {
  AdminActivityService({required DaylySportCacheStore cacheStore})
    : _cacheStore = cacheStore {
    _records = _readPersistedRecords();
  }

  static const String _scope = 'admin_activity';
  static const String _recordsKey = 'records_v1';
  static const int _maxRecords = 300;

  final DaylySportCacheStore _cacheStore;
  List<AdminActivityRecord> _records = const <AdminActivityRecord>[];

  UnmodifiableListView<AdminActivityRecord> get records {
    return UnmodifiableListView<AdminActivityRecord>(_records);
  }

  Future<void> record(AdminActivityRecord record) async {
    _records = <AdminActivityRecord>[record, ..._records]
        .take(_maxRecords)
        .toList(growable: false);
    await _persist();
    notifyListeners();
  }

  Future<void> clearLoginRecords({
    required String actorUserId,
    required String actorUsername,
  }) async {
    _records = _records
        .where(
          (record) =>
              record.type != AdminActivityType.loginSuccess &&
              record.type != AdminActivityType.loginFailure &&
              record.type != AdminActivityType.logout,
        )
        .toList(growable: false);
    await record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.loginRecordsCleared,
        occurredAtUtc: DateTime.now().toUtc(),
        summary: 'Cleared persisted login and logout records.',
        category: 'security',
        actorUserId: actorUserId,
        actorUsername: actorUsername,
      ),
    );
  }

  Future<void> clearVerificationCodeRecords({
    required String actorUserId,
    required String actorUsername,
    String? feature,
  }) async {
    _records = _records
        .where((record) {
          if (record.type != AdminActivityType.verificationCodeGenerated) {
            return true;
          }
          if (feature == null || feature.trim().isEmpty) {
            return false;
          }
          return record.metadata?['feature'] != feature;
        })
        .toList(growable: false);
    final summary =
        feature == null || feature.trim().isEmpty
            ? 'Cleared persisted verification code generation records.'
            : 'Cleared persisted verification code records for $feature.';
    await record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.verificationCodeRecordsCleared,
        occurredAtUtc: DateTime.now().toUtc(),
        summary: summary,
        category: 'verification',
        actorUserId: actorUserId,
        actorUsername: actorUsername,
        metadata:
            feature == null || feature.trim().isEmpty
                ? null
                : <String, String>{'feature': feature},
      ),
    );
  }

  List<AdminActivityRecord> recentByTypes(Set<AdminActivityType> types) {
    return _records.where((record) => types.contains(record.type)).toList();
  }

  Future<void> _persist() {
    return _cacheStore.writeJsonObjectList(
      _scope,
      _recordsKey,
      _records.map((record) => record.toJson()).toList(growable: false),
    );
  }

  List<AdminActivityRecord> _readPersistedRecords() {
    final raw = _cacheStore.readJsonObjectList(_scope, _recordsKey);
    final parsed = raw
        .map(AdminActivityRecord.fromJson)
        .whereType<AdminActivityRecord>()
        .toList(growable: false);
    parsed.sort(
      (left, right) => right.occurredAtUtc.compareTo(left.occurredAtUtc),
    );
    return parsed;
  }
}