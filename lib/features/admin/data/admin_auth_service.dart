import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:eri_sports/features/admin/data/admin_activity_service.dart';
import 'package:eri_sports/features/admin/data/admin_models.dart';
import 'package:flutter/foundation.dart';

class AdminAuthService extends ChangeNotifier {
  AdminAuthService({
    required DaylySportCacheStore cacheStore,
    required AdminActivityService activityService,
  }) : _cacheStore = cacheStore,
       _activityService = activityService {
    _users = _loadUsers();
    _session = _loadSession();
    if (_session != null && !_users.any((user) => user.id == _session!.userId)) {
      _session = null;
      _persistSession();
    }
  }

  static const String _scope = 'admin_auth';
  static const String _usersKey = 'users_v1';
  static const String _sessionKey = 'session_v1';
  static const int _passwordIterations = 12000;
  static const int _minPasswordLength = 8;

  final DaylySportCacheStore _cacheStore;
  final AdminActivityService _activityService;

  List<AdminUserRecord> _users = const <AdminUserRecord>[];
  AdminSessionRecord? _session;

  UnmodifiableListView<AdminUserRecord> get users {
    final sorted = [..._users]
      ..sort((left, right) => left.username.compareTo(right.username));
    return UnmodifiableListView<AdminUserRecord>(sorted);
  }

  AdminSessionRecord? get currentSession => _session;

  bool get isAuthenticated => _session != null;

  bool get requiresSetup => _users.isEmpty;

  Future<AdminActionResult> createInitialAdmin({
    required String username,
    required String displayName,
    required String password,
    required String confirmPassword,
    required bool persistSession,
  }) async {
    if (_users.isNotEmpty) {
      return AdminActionResult.failure('Primary admin setup is already complete.');
    }

    final validation = _validateCredentialInputs(
      username: username,
      displayName: displayName,
      password: password,
      confirmPassword: confirmPassword,
    );
    if (validation != null) {
      return AdminActionResult.failure(validation);
    }

    final now = DateTime.now().toUtc();
    final normalizedUsername = adminNormalizeUsername(username);
    final saltBase64 = _generateSaltBase64();
    final hashBase64 = _hashPassword(password, saltBase64);
    final user = AdminUserRecord(
      id: adminGenerateId(),
      username: normalizedUsername,
      displayName: displayName.trim(),
      passwordSaltBase64: saltBase64,
      passwordHashBase64: hashBase64,
      createdAtUtc: now,
      updatedAtUtc: now,
      lastLoginAtUtc: now,
    );
    _users = <AdminUserRecord>[user];
    _session = _buildSession(user, persistSession: persistSession);
    await _persistUsers();
    await _persistSession();
    await _activityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.userCreated,
        occurredAtUtc: now,
        summary: 'Created the primary admin account.',
        category: 'security',
        actorUserId: user.id,
        actorUsername: user.username,
      ),
    );
    await _activityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.loginSuccess,
        occurredAtUtc: now,
        summary: 'Initialized the admin console and started the first session.',
        category: 'security',
        actorUserId: user.id,
        actorUsername: user.username,
      ),
    );
    notifyListeners();
    return AdminActionResult(
      success: true,
      session: _session,
      user: user,
    );
  }

  Future<AdminActionResult> login({
    required String username,
    required String password,
    required bool persistSession,
  }) async {
    final normalizedUsername = adminNormalizeUsername(username);
    if (normalizedUsername.isEmpty || password.isEmpty) {
      return AdminActionResult.failure('Enter both username and password.');
    }

    final user = _users.cast<AdminUserRecord?>().firstWhere(
      (candidate) => candidate?.username == normalizedUsername,
      orElse: () => null,
    );
    final now = DateTime.now().toUtc();
    if (user == null ||
        !_constantTimeEquals(
          _hashPassword(password, user.passwordSaltBase64),
          user.passwordHashBase64,
        )) {
      await _activityService.record(
        AdminActivityRecord(
          id: adminGenerateId(prefix: 'activity'),
          type: AdminActivityType.loginFailure,
          occurredAtUtc: now,
          summary: 'Rejected a login attempt.',
          category: 'security',
          actorUsername: normalizedUsername,
        ),
      );
      return AdminActionResult.failure('Invalid username or password.');
    }

    final updatedUser = user.copyWith(lastLoginAtUtc: now, updatedAtUtc: now);
    _replaceUser(updatedUser);
    _session = _buildSession(updatedUser, persistSession: persistSession);
    await _persistUsers();
    await _persistSession();
    await _activityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.loginSuccess,
        occurredAtUtc: now,
        summary: 'Signed in to the secure content dashboard.',
        category: 'security',
        actorUserId: updatedUser.id,
        actorUsername: updatedUser.username,
      ),
    );
    notifyListeners();
    return AdminActionResult(
      success: true,
      session: _session,
      user: updatedUser,
    );
  }

  Future<void> logout() async {
    final session = _session;
    _session = null;
    await _persistSession();
    if (session != null) {
      await _activityService.record(
        AdminActivityRecord(
          id: adminGenerateId(prefix: 'activity'),
          type: AdminActivityType.logout,
          occurredAtUtc: DateTime.now().toUtc(),
          summary: 'Signed out of the admin console.',
          category: 'security',
          actorUserId: session.userId,
          actorUsername: session.username,
        ),
      );
    }
    notifyListeners();
  }

  Future<AdminActionResult> createUser({
    required String username,
    required String displayName,
    required String password,
    required String confirmPassword,
  }) async {
    final session = _session;
    if (session == null) {
      return AdminActionResult.failure('Sign in before creating additional admins.');
    }

    final validation = _validateCredentialInputs(
      username: username,
      displayName: displayName,
      password: password,
      confirmPassword: confirmPassword,
    );
    if (validation != null) {
      return AdminActionResult.failure(validation);
    }

    final normalizedUsername = adminNormalizeUsername(username);
    if (_users.any((user) => user.username == normalizedUsername)) {
      return AdminActionResult.failure('That username is already assigned to another admin.');
    }

    final now = DateTime.now().toUtc();
    final saltBase64 = _generateSaltBase64();
    final user = AdminUserRecord(
      id: adminGenerateId(),
      username: normalizedUsername,
      displayName: displayName.trim(),
      passwordSaltBase64: saltBase64,
      passwordHashBase64: _hashPassword(password, saltBase64),
      createdAtUtc: now,
      updatedAtUtc: now,
    );
    _users = <AdminUserRecord>[..._users, user];
    await _persistUsers();
    await _activityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.userCreated,
        occurredAtUtc: now,
        summary: 'Created admin user ${user.username}.',
        category: 'security',
        actorUserId: session.userId,
        actorUsername: session.username,
      ),
    );
    notifyListeners();
    return AdminActionResult(success: true, user: user);
  }

  Future<AdminActionResult> updateCurrentProfile({
    required String username,
    required String displayName,
  }) async {
    final session = _session;
    if (session == null) {
      return AdminActionResult.failure('Sign in before updating account settings.');
    }

    final normalizedUsername = adminNormalizeUsername(username);
    if (normalizedUsername.length < 3) {
      return AdminActionResult.failure('Use at least 3 characters for the username.');
    }
    if (displayName.trim().length < 2) {
      return AdminActionResult.failure('Use at least 2 characters for the display name.');
    }
    if (_users.any(
      (user) => user.id != session.userId && user.username == normalizedUsername,
    )) {
      return AdminActionResult.failure('That username is already assigned to another admin.');
    }

    final existing = _users.firstWhere((user) => user.id == session.userId);
    final updated = existing.copyWith(
      username: normalizedUsername,
      displayName: displayName.trim(),
      updatedAtUtc: DateTime.now().toUtc(),
    );
    _replaceUser(updated);
    _session = AdminSessionRecord(
      userId: updated.id,
      username: updated.username,
      displayName: updated.displayName,
      authenticatedAtUtc: session.authenticatedAtUtc,
      persistAcrossLaunches: session.persistAcrossLaunches,
    );
    await _persistUsers();
    await _persistSession();
    await _activityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.profileUpdated,
        occurredAtUtc: DateTime.now().toUtc(),
        summary: 'Updated the signed-in admin profile.',
        category: 'security',
        actorUserId: updated.id,
        actorUsername: updated.username,
      ),
    );
    notifyListeners();
    return AdminActionResult(success: true, user: updated, session: _session);
  }

  Future<AdminActionResult> changeCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final session = _session;
    if (session == null) {
      return AdminActionResult.failure('Sign in before changing the password.');
    }

    final user = _users.firstWhere((entry) => entry.id == session.userId);
    if (!_constantTimeEquals(
      _hashPassword(currentPassword, user.passwordSaltBase64),
      user.passwordHashBase64,
    )) {
      return AdminActionResult.failure('Current password did not match the active account.');
    }

    final validation = _validatePassword(newPassword, confirmPassword);
    if (validation != null) {
      return AdminActionResult.failure(validation);
    }
    if (_constantTimeEquals(
      _hashPassword(newPassword, user.passwordSaltBase64),
      user.passwordHashBase64,
    )) {
      return AdminActionResult.failure('Choose a different password from the current one.');
    }

    final nextSaltBase64 = _generateSaltBase64();
    final updated = user.copyWith(
      passwordSaltBase64: nextSaltBase64,
      passwordHashBase64: _hashPassword(newPassword, nextSaltBase64),
      updatedAtUtc: DateTime.now().toUtc(),
    );
    _replaceUser(updated);
    await _persistUsers();
    await _activityService.record(
      AdminActivityRecord(
        id: adminGenerateId(prefix: 'activity'),
        type: AdminActivityType.passwordChanged,
        occurredAtUtc: DateTime.now().toUtc(),
        summary: 'Changed the active admin password.',
        category: 'security',
        actorUserId: updated.id,
        actorUsername: updated.username,
      ),
    );
    notifyListeners();
    return AdminActionResult(success: true, user: updated);
  }

  void _replaceUser(AdminUserRecord updated) {
    _users = _users
        .map((user) => user.id == updated.id ? updated : user)
        .toList(growable: false);
  }

  AdminSessionRecord _buildSession(
    AdminUserRecord user, {
    required bool persistSession,
  }) {
    return AdminSessionRecord(
      userId: user.id,
      username: user.username,
      displayName: user.displayName,
      authenticatedAtUtc: DateTime.now().toUtc(),
      persistAcrossLaunches: persistSession,
    );
  }

  String? _validateCredentialInputs({
    required String username,
    required String displayName,
    required String password,
    required String confirmPassword,
  }) {
    final normalizedUsername = adminNormalizeUsername(username);
    if (normalizedUsername.length < 3) {
      return 'Use at least 3 characters for the username.';
    }
    if (displayName.trim().length < 2) {
      return 'Use at least 2 characters for the display name.';
    }
    return _validatePassword(password, confirmPassword);
  }

  String? _validatePassword(String password, String confirmPassword) {
    if (password.length < _minPasswordLength) {
      return 'Use at least $_minPasswordLength characters for the password.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Include both letters and numbers in the password.';
    }
    if (password != confirmPassword) {
      return 'Password confirmation did not match.';
    }
    return null;
  }

  List<AdminUserRecord> _loadUsers() {
    final raw = _cacheStore.readJsonObjectList(_scope, _usersKey);
    return raw
        .map(AdminUserRecord.fromJson)
        .whereType<AdminUserRecord>()
        .toList(growable: false);
  }

  AdminSessionRecord? _loadSession() {
    final raw = _cacheStore.readJsonObject(_scope, _sessionKey);
    if (raw == null) {
      return null;
    }
    return AdminSessionRecord.fromJson(raw);
  }

  Future<void> _persistUsers() {
    return _cacheStore.writeJsonObjectList(
      _scope,
      _usersKey,
      _users.map((user) => user.toJson()).toList(growable: false),
    );
  }

  Future<void> _persistSession() {
    final session = _session;
    return _cacheStore.writeJsonObject(
      _scope,
      _sessionKey,
      session != null && session.persistAcrossLaunches ? session.toJson() : null,
    );
  }

  String _generateSaltBase64() {
    final random = Random.secure();
    final saltBytes = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    return base64Encode(saltBytes);
  }

  String _hashPassword(String password, String saltBase64) {
    final saltBytes = base64Decode(saltBase64);
    var material = Uint8List.fromList(
      <int>[
        ...utf8.encode('eri_sports_admin_auth_v1'),
        ...saltBytes,
        ...utf8.encode(password),
      ],
    );
    for (var index = 0; index < _passwordIterations; index += 1) {
      material = Uint8List.fromList(
        crypto.sha256.convert(<int>[...material, ...saltBytes, index % 251]).bytes,
      );
    }
    return base64Encode(material);
  }

  bool _constantTimeEquals(String left, String right) {
    final leftBytes = utf8.encode(left);
    final rightBytes = utf8.encode(right);
    if (leftBytes.length != rightBytes.length) {
      return false;
    }
    var diff = 0;
    for (var index = 0; index < leftBytes.length; index += 1) {
      diff |= leftBytes[index] ^ rightBytes[index];
    }
    return diff == 0;
  }
}