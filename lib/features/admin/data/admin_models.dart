import 'dart:convert';

enum AdminActivityType {
  loginSuccess,
  loginFailure,
  logout,
  userCreated,
  passwordChanged,
  profileUpdated,
  inventoryRefresh,
  warmCaches,
  clearCaches,
  encryptionBatch,
  loginRecordsCleared,
}

class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    required this.username,
    required this.displayName,
    required this.passwordSaltBase64,
    required this.passwordHashBase64,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.lastLoginAtUtc,
  });

  final String id;
  final String username;
  final String displayName;
  final String passwordSaltBase64;
  final String passwordHashBase64;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? lastLoginAtUtc;

  AdminUserRecord copyWith({
    String? id,
    String? username,
    String? displayName,
    String? passwordSaltBase64,
    String? passwordHashBase64,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    DateTime? lastLoginAtUtc,
    bool clearLastLoginAtUtc = false,
  }) {
    return AdminUserRecord(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      passwordSaltBase64: passwordSaltBase64 ?? this.passwordSaltBase64,
      passwordHashBase64: passwordHashBase64 ?? this.passwordHashBase64,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      lastLoginAtUtc:
          clearLastLoginAtUtc ? null : (lastLoginAtUtc ?? this.lastLoginAtUtc),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'displayName': displayName,
      'passwordSaltBase64': passwordSaltBase64,
      'passwordHashBase64': passwordHashBase64,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
      'lastLoginAtUtc': lastLoginAtUtc?.toIso8601String(),
    };
  }

  static AdminUserRecord? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    final displayName = json['displayName'];
    final passwordSaltBase64 = json['passwordSaltBase64'];
    final passwordHashBase64 = json['passwordHashBase64'];
    final createdAtUtc = json['createdAtUtc'];
    final updatedAtUtc = json['updatedAtUtc'];
    final lastLoginAtUtc = json['lastLoginAtUtc'];
    if (id is! String ||
        username is! String ||
        displayName is! String ||
        passwordSaltBase64 is! String ||
        passwordHashBase64 is! String ||
        createdAtUtc is! String ||
        updatedAtUtc is! String) {
      return null;
    }

    final created = DateTime.tryParse(createdAtUtc);
    final updated = DateTime.tryParse(updatedAtUtc);
    final lastLogin =
        lastLoginAtUtc is String ? DateTime.tryParse(lastLoginAtUtc) : null;
    if (created == null || updated == null) {
      return null;
    }

    return AdminUserRecord(
      id: id,
      username: username,
      displayName: displayName,
      passwordSaltBase64: passwordSaltBase64,
      passwordHashBase64: passwordHashBase64,
      createdAtUtc: created.toUtc(),
      updatedAtUtc: updated.toUtc(),
      lastLoginAtUtc: lastLogin?.toUtc(),
    );
  }
}

class AdminSessionRecord {
  const AdminSessionRecord({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.authenticatedAtUtc,
    required this.persistAcrossLaunches,
  });

  final String userId;
  final String username;
  final String displayName;
  final DateTime authenticatedAtUtc;
  final bool persistAcrossLaunches;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'authenticatedAtUtc': authenticatedAtUtc.toIso8601String(),
      'persistAcrossLaunches': persistAcrossLaunches,
    };
  }

  static AdminSessionRecord? fromJson(Map<String, dynamic> json) {
    final userId = json['userId'];
    final username = json['username'];
    final displayName = json['displayName'];
    final authenticatedAtUtc = json['authenticatedAtUtc'];
    final persistAcrossLaunches = json['persistAcrossLaunches'];
    if (userId is! String ||
        username is! String ||
        displayName is! String ||
        authenticatedAtUtc is! String ||
        persistAcrossLaunches is! bool) {
      return null;
    }

    final authenticated = DateTime.tryParse(authenticatedAtUtc);
    if (authenticated == null) {
      return null;
    }

    return AdminSessionRecord(
      userId: userId,
      username: username,
      displayName: displayName,
      authenticatedAtUtc: authenticated.toUtc(),
      persistAcrossLaunches: persistAcrossLaunches,
    );
  }
}

class AdminActivityRecord {
  const AdminActivityRecord({
    required this.id,
    required this.type,
    required this.occurredAtUtc,
    required this.summary,
    required this.category,
    this.actorUserId,
    this.actorUsername,
    this.itemCount,
    this.totalBytes,
    this.metadata,
  });

  final String id;
  final AdminActivityType type;
  final DateTime occurredAtUtc;
  final String summary;
  final String category;
  final String? actorUserId;
  final String? actorUsername;
  final int? itemCount;
  final int? totalBytes;
  final Map<String, String>? metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'occurredAtUtc': occurredAtUtc.toIso8601String(),
      'summary': summary,
      'category': category,
      'actorUserId': actorUserId,
      'actorUsername': actorUsername,
      'itemCount': itemCount,
      'totalBytes': totalBytes,
      'metadata': metadata,
    };
  }

  static AdminActivityRecord? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final occurredAtUtc = json['occurredAtUtc'];
    final summary = json['summary'];
    final category = json['category'];
    if (id is! String ||
        type is! String ||
        occurredAtUtc is! String ||
        summary is! String ||
        category is! String) {
      return null;
    }

    final parsedOccurredAt = DateTime.tryParse(occurredAtUtc);
    final parsedType = AdminActivityType.values.where((value) => value.name == type);
    if (parsedOccurredAt == null || parsedType.isEmpty) {
      return null;
    }

    final rawMetadata = json['metadata'];
    Map<String, String>? metadata;
    if (rawMetadata is Map) {
      metadata = rawMetadata.map(
        (key, value) => MapEntry('$key', '$value'),
      );
    }

    return AdminActivityRecord(
      id: id,
      type: parsedType.first,
      occurredAtUtc: parsedOccurredAt.toUtc(),
      summary: summary,
      category: category,
      actorUserId: json['actorUserId'] as String?,
      actorUsername: json['actorUsername'] as String?,
      itemCount: json['itemCount'] as int?,
      totalBytes: json['totalBytes'] as int?,
      metadata: metadata,
    );
  }
}

class AdminActionResult {
  const AdminActionResult({
    required this.success,
    this.message,
    this.session,
    this.user,
  });

  final bool success;
  final String? message;
  final AdminSessionRecord? session;
  final AdminUserRecord? user;

  static const AdminActionResult ok = AdminActionResult(success: true);

  factory AdminActionResult.failure(String message) {
    return AdminActionResult(success: false, message: message);
  }
}

String adminNormalizeUsername(String raw) {
  return raw.trim().toLowerCase();
}

String adminGenerateId({String prefix = 'adm'}) {
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(
    36,
  );
  final entropy = base64Url.encode(
    utf8.encode('${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().hashCode}'),
  );
  return '$prefix-$timestamp-${entropy.substring(0, 8)}';
}