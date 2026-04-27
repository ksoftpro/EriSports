import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:eri_sports/data/local_files/daylysport_cache_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:eri_sports/app/bootstrap/app_services.dart';

const _contentVerificationScope = 'content_verification_v1';
const _clientVerificationStateKey = 'client_state';
const _requestCodePrefix = 'ERI-REQ1-';
const _verificationCodePrefix = 'ERI-VER1-';
const _verificationQrPrefix = 'ERI-QR1-';
const _verificationFeatureOfflineContent = 'offline_content';
const _verificationPepper = 'eri_sports_offline_verification_v1';
const _defaultVerificationApprovalTtl = Duration(minutes: 10);

enum VerificationSeedSource {
  macAddress,
  androidIdFallback,
  hostnameFallback,
  unknown,
}

class DeviceVerificationIdentity {
  const DeviceVerificationIdentity({required this.seed, required this.source});

  final String seed;
  final VerificationSeedSource source;
}

class ContentVerificationPendingCounts {
  const ContentVerificationPendingCounts({
    required this.reels,
    required this.videoHighlights,
    required this.videoNews,
    required this.videoUpdates,
    required this.newsImages,
  });

  const ContentVerificationPendingCounts.zero()
    : reels = 0,
      videoHighlights = 0,
      videoNews = 0,
      videoUpdates = 0,
      newsImages = 0;

  final int reels;
  final int videoHighlights;
  final int videoNews;
  final int videoUpdates;
  final int newsImages;

  int get totalPending {
    return reels + videoHighlights + videoNews + videoUpdates + newsImages;
  }

  bool get hasPending => totalPending > 0;

  Map<String, int> toJson() {
    return <String, int>{
      'reels': reels,
      'videoHighlights': videoHighlights,
      'videoNews': videoNews,
      'videoUpdates': videoUpdates,
      'newsImages': newsImages,
    };
  }

  List<String> get activeCategoryKeys {
    final keys = <String>[];
    if (reels > 0) {
      keys.add('reels');
    }
    if (videoHighlights > 0) {
      keys.add('videoHighlights');
    }
    if (videoNews > 0) {
      keys.add('videoNews');
    }
    if (videoUpdates > 0) {
      keys.add('videoUpdates');
    }
    if (newsImages > 0) {
      keys.add('newsImages');
    }
    return keys;
  }

  String get signature {
    return 'r:$reels|vh:$videoHighlights|vn:$videoNews|vu:$videoUpdates|n:$newsImages';
  }

  static ContentVerificationPendingCounts fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ContentVerificationPendingCounts.zero();
    }
    return ContentVerificationPendingCounts(
      reels: json['reels'] as int? ?? 0,
      videoHighlights: json['videoHighlights'] as int? ?? 0,
      videoNews: json['videoNews'] as int? ?? 0,
      videoUpdates: json['videoUpdates'] as int? ?? 0,
      newsImages: json['newsImages'] as int? ?? 0,
    );
  }
}

class ClientVerificationRequest {
  const ClientVerificationRequest({
    required this.requestCode,
    required this.feature,
    required this.requestDayKey,
    required this.deviceDigest,
    required this.seedSource,
    required this.pendingCounts,
    required this.generatedAtUtc,
  });

  final String requestCode;
  final String feature;
  final String requestDayKey;
  final String deviceDigest;
  final VerificationSeedSource seedSource;
  final ContentVerificationPendingCounts pendingCounts;
  final DateTime generatedAtUtc;
}

class VerificationQrPayload {
  const VerificationQrPayload({
    required this.qrPayload,
    required this.feature,
    required this.verificationCode,
    required this.issuedAtUtc,
    required this.expiresAtUtc,
  });

  final String qrPayload;
  final String feature;
  final String verificationCode;
  final DateTime issuedAtUtc;
  final DateTime expiresAtUtc;
}

class ClientVerificationState {
  const ClientVerificationState({
    this.lastRequestCode,
    this.lastRequestAtUtc,
    this.lastVerifiedAtUtc,
    this.lastVerifiedRequestCode,
    this.lastSeedSource,
    this.lastPendingCounts = const ContentVerificationPendingCounts.zero(),
  });

  final String? lastRequestCode;
  final DateTime? lastRequestAtUtc;
  final DateTime? lastVerifiedAtUtc;
  final String? lastVerifiedRequestCode;
  final VerificationSeedSource? lastSeedSource;
  final ContentVerificationPendingCounts lastPendingCounts;

  bool get hasVerifiedRequest =>
      lastVerifiedAtUtc != null && lastVerifiedRequestCode != null;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lastRequestCode': lastRequestCode,
      'lastRequestAtUtc': lastRequestAtUtc?.toIso8601String(),
      'lastVerifiedAtUtc': lastVerifiedAtUtc?.toIso8601String(),
      'lastVerifiedRequestCode': lastVerifiedRequestCode,
      'lastSeedSource': lastSeedSource?.name,
      'lastPendingCounts': lastPendingCounts.toJson(),
    };
  }

  static ClientVerificationState fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ClientVerificationState();
    }

    final seedSourceName = json['lastSeedSource'] as String?;
    final seedSource = VerificationSeedSource.values
        .where((value) => value.name == seedSourceName)
        .cast<VerificationSeedSource?>()
        .firstWhere((value) => value != null, orElse: () => null);

    return ClientVerificationState(
      lastRequestCode: json['lastRequestCode'] as String?,
      lastRequestAtUtc: _tryParseDateTime(json['lastRequestAtUtc']),
      lastVerifiedAtUtc: _tryParseDateTime(json['lastVerifiedAtUtc']),
      lastVerifiedRequestCode: json['lastVerifiedRequestCode'] as String?,
      lastSeedSource: seedSource,
      lastPendingCounts: ContentVerificationPendingCounts.fromJson(
        json['lastPendingCounts'] as Map<String, dynamic>?,
      ),
    );
  }
}

class ContentVerificationService {
  ContentVerificationService({required DaylySportCacheStore cacheStore})
    : _cacheStore = cacheStore;

  final DaylySportCacheStore _cacheStore;

  ClientVerificationState readClientState() {
    return ClientVerificationState.fromJson(
      _cacheStore.readJsonObject(
        _contentVerificationScope,
        _clientVerificationStateKey,
      ),
    );
  }

  Future<void> saveGeneratedRequest(ClientVerificationRequest request) {
    final current = readClientState();
    return _cacheStore.writeJsonObject(
      _contentVerificationScope,
      _clientVerificationStateKey,
      ClientVerificationState(
        lastRequestCode: request.requestCode,
        lastRequestAtUtc: request.generatedAtUtc,
        lastVerifiedAtUtc: current.lastVerifiedAtUtc,
        lastVerifiedRequestCode: current.lastVerifiedRequestCode,
        lastSeedSource: request.seedSource,
        lastPendingCounts: request.pendingCounts,
      ).toJson(),
    );
  }

  Future<void> markClientVerified({
    required ClientVerificationRequest request,
    required String verificationCode,
    DateTime? verifiedAtUtc,
  }) {
    final approvedAtUtc = verifiedAtUtc?.toUtc() ?? DateTime.now().toUtc();
    return _cacheStore.writeJsonObject(
      _contentVerificationScope,
      _clientVerificationStateKey,
      ClientVerificationState(
        lastRequestCode: request.requestCode,
        lastRequestAtUtc: request.generatedAtUtc,
        lastVerifiedAtUtc: approvedAtUtc,
        lastVerifiedRequestCode: _normalizeVerificationCode(verificationCode),
        lastSeedSource: request.seedSource,
        lastPendingCounts: request.pendingCounts,
      ).toJson(),
    );
  }

  ClientVerificationRequest generateClientRequest({
    required DeviceVerificationIdentity identity,
    required ContentVerificationPendingCounts pendingCounts,
    DateTime? now,
  }) {
    final generatedAtUtc = (now ?? DateTime.now()).toUtc();
    final requestDayKey = _dateKeyFor(generatedAtUtc);
    final deviceDigest = _digest(
      'device|$_verificationPepper|${identity.seed}|$requestDayKey',
      length: 24,
    );
    final payload = <String, dynamic>{
      'v': 1,
      'feature': _verificationFeatureOfflineContent,
      'day': requestDayKey,
      'deviceDigest': deviceDigest,
      'seedSource': identity.source.name,
      'counts': pendingCounts.toJson(),
      'generatedAtUtc': generatedAtUtc.toIso8601String(),
    };
    payload['checksum'] = _digest(
      'request|$_verificationPepper|$requestDayKey|$deviceDigest|${pendingCounts.signature}',
      length: 16,
    );

    final requestCode =
        '$_requestCodePrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
    return ClientVerificationRequest(
      requestCode: requestCode,
      feature: _verificationFeatureOfflineContent,
      requestDayKey: requestDayKey,
      deviceDigest: deviceDigest,
      seedSource: identity.source,
      pendingCounts: pendingCounts,
      generatedAtUtc: generatedAtUtc,
    );
  }

  ClientVerificationRequest parseClientRequest(String requestCode) {
    final normalized = requestCode.trim();
    if (!normalized.startsWith(_requestCodePrefix)) {
      throw const FormatException('Request code format is not recognized.');
    }

    final encodedPayload = normalized.substring(_requestCodePrefix.length);
    final decoded = utf8.decode(
      base64Url.decode(base64Url.normalize(encodedPayload)),
    );
    final payload = jsonDecode(decoded);
    if (payload is! Map) {
      throw const FormatException('Request code payload is invalid.');
    }

    final normalizedPayload = payload.map(
      (key, value) => MapEntry('$key', value),
    );
    final requestDayKey = normalizedPayload['day'] as String?;
    final deviceDigest = normalizedPayload['deviceDigest'] as String?;
    final feature = normalizedPayload['feature'] as String?;
    final checksum = normalizedPayload['checksum'] as String?;
    final generatedAtUtc = _tryParseDateTime(
      normalizedPayload['generatedAtUtc'],
    );
    final seedSourceName = normalizedPayload['seedSource'] as String?;
    if (requestDayKey == null ||
        deviceDigest == null ||
        feature == null ||
        checksum == null ||
        generatedAtUtc == null) {
      throw const FormatException('Request code payload is incomplete.');
    }

    final pendingCounts = ContentVerificationPendingCounts.fromJson(
      normalizedPayload['counts'] as Map<String, dynamic>?,
    );
    final expectedChecksum = _digest(
      'request|$_verificationPepper|$requestDayKey|$deviceDigest|${pendingCounts.signature}',
      length: 16,
    );
    if (checksum != expectedChecksum) {
      throw const FormatException('Request code checksum is invalid.');
    }

    final seedSource = VerificationSeedSource.values.firstWhere(
      (value) => value.name == seedSourceName,
      orElse: () => VerificationSeedSource.unknown,
    );

    return ClientVerificationRequest(
      requestCode: normalized,
      feature: feature,
      requestDayKey: requestDayKey,
      deviceDigest: deviceDigest,
      seedSource: seedSource,
      pendingCounts: pendingCounts,
      generatedAtUtc: generatedAtUtc,
    );
  }

  String generateVerificationCode(String requestCode) {
    final request = parseClientRequest(requestCode);
    final rawCode =
        _digest(
          'verification|$_verificationPepper|${request.requestDayKey}|${request.deviceDigest}|${request.feature}|${request.pendingCounts.signature}',
          length: 20,
        ).toUpperCase();
    final segments = <String>[];
    for (var index = 0; index < rawCode.length; index += 4) {
      final end = (index + 4).clamp(0, rawCode.length);
      segments.add(rawCode.substring(index, end));
    }
    return '$_verificationCodePrefix${segments.join('-')}';
  }

  String generateAdminVerificationCode({
    String feature = _verificationFeatureOfflineContent,
    DateTime? issuedAtUtc,
    DateTime? expiresAtUtc,
  }) {
    final normalizedIssuedAtUtc = (issuedAtUtc ?? DateTime.now()).toUtc();
    final normalizedExpiresAtUtc =
        (expiresAtUtc ??
                normalizedIssuedAtUtc.add(_defaultVerificationApprovalTtl))
            .toUtc();
    final rawCode =
        _digest(
          'admin-verification|$_verificationPepper|$feature|${normalizedIssuedAtUtc.toIso8601String()}|${normalizedExpiresAtUtc.toIso8601String()}',
          length: 20,
        ).toUpperCase();
    final segments = <String>[];
    for (var index = 0; index < rawCode.length; index += 4) {
      final end = (index + 4).clamp(0, rawCode.length);
      segments.add(rawCode.substring(index, end));
    }
    return '$_verificationCodePrefix${segments.join('-')}';
  }

  VerificationQrPayload generateVerificationQrPayload({
    String feature = _verificationFeatureOfflineContent,
    DateTime? now,
    Duration ttl = _defaultVerificationApprovalTtl,
  }) {
    final issuedAtUtc = (now ?? DateTime.now()).toUtc();
    final expiresAtUtc = issuedAtUtc.add(ttl).toUtc();
    final verificationCode = generateAdminVerificationCode(
      feature: feature,
      issuedAtUtc: issuedAtUtc,
      expiresAtUtc: expiresAtUtc,
    );
    final payload = <String, dynamic>{
      'v': 1,
      'feature': feature,
      'verificationCode': verificationCode,
      'issuedAtUtc': issuedAtUtc.toIso8601String(),
      'expiresAtUtc': expiresAtUtc.toIso8601String(),
    };
    payload['checksum'] = _digest(
      'qr|$_verificationPepper|$feature|${_normalizeVerificationCode(verificationCode)}|${issuedAtUtc.toIso8601String()}|${expiresAtUtc.toIso8601String()}',
      length: 20,
    );

    return VerificationQrPayload(
      qrPayload:
          '$_verificationQrPrefix${base64Url.encode(utf8.encode(jsonEncode(payload)))}',
      feature: feature,
      verificationCode: verificationCode,
      issuedAtUtc: issuedAtUtc,
      expiresAtUtc: expiresAtUtc,
    );
  }

  VerificationQrPayload parseVerificationQrPayload(String qrPayload) {
    final normalized = qrPayload.trim();
    if (!normalized.startsWith(_verificationQrPrefix)) {
      throw const FormatException('QR payload format is not recognized.');
    }

    final encodedPayload = normalized.substring(_verificationQrPrefix.length);
    final decoded = utf8.decode(
      base64Url.decode(base64Url.normalize(encodedPayload)),
    );
    final payload = jsonDecode(decoded);
    if (payload is! Map) {
      throw const FormatException('QR payload is invalid.');
    }

    final normalizedPayload = payload.map(
      (key, value) => MapEntry('$key', value),
    );
    final verificationCode = normalizedPayload['verificationCode'] as String?;
    final feature = normalizedPayload['feature'] as String?;
    final checksum = normalizedPayload['checksum'] as String?;
    final issuedAtUtc = _tryParseDateTime(normalizedPayload['issuedAtUtc']);
    final expiresAtUtc = _tryParseDateTime(
      normalizedPayload['expiresAtUtc'],
    );
    if (verificationCode == null ||
        feature == null ||
        checksum == null ||
        issuedAtUtc == null ||
        expiresAtUtc == null) {
      throw const FormatException('QR payload is incomplete.');
    }

    final expectedChecksum = _digest(
      'qr|$_verificationPepper|$feature|${_normalizeVerificationCode(verificationCode)}|${issuedAtUtc.toIso8601String()}|${expiresAtUtc.toIso8601String()}',
      length: 20,
    );
    if (checksum != expectedChecksum) {
      throw const FormatException('QR payload checksum is invalid.');
    }

    final expectedCode = generateAdminVerificationCode(
      feature: feature,
      issuedAtUtc: issuedAtUtc,
      expiresAtUtc: expiresAtUtc,
    );
    if (_normalizeVerificationCode(verificationCode) !=
        _normalizeVerificationCode(expectedCode)) {
      throw const FormatException('QR payload verification code is invalid.');
    }

    return VerificationQrPayload(
      qrPayload: normalized,
      feature: feature,
      verificationCode: verificationCode,
      issuedAtUtc: issuedAtUtc,
      expiresAtUtc: expiresAtUtc,
    );
  }

  VerificationQrPayload validateVerificationQrPayload({
    required String qrPayload,
    String expectedFeature = _verificationFeatureOfflineContent,
    DateTime? now,
  }) {
    final parsed = parseVerificationQrPayload(qrPayload);
    if (parsed.feature != expectedFeature) {
      throw const FormatException(
        'This admin QR code does not match the current verification flow.',
      );
    }
    final comparisonTime = (now ?? DateTime.now()).toUtc();
    if (comparisonTime.isAfter(parsed.expiresAtUtc)) {
      throw const FormatException(
        'This admin QR code has expired.',
      );
    }

    return parsed;
  }

  ClientVerificationRequest createClientVerificationRecord({
    required DeviceVerificationIdentity identity,
    required ContentVerificationPendingCounts pendingCounts,
    DateTime? now,
  }) {
    return generateClientRequest(
      identity: identity,
      pendingCounts: pendingCounts,
      now: now,
    );
  }

  bool isVerificationCodeValid({
    required String requestCode,
    required String verificationCode,
  }) {
    final expected = _normalizeVerificationCode(
      generateVerificationCode(requestCode),
    );
    return expected == _normalizeVerificationCode(verificationCode);
  }

  String _normalizeVerificationCode(String code) {
    return code.trim().toUpperCase().replaceAll(' ', '');
  }

  static String featureLabel(String featureKey) {
    switch (featureKey) {
      case _verificationFeatureOfflineContent:
        return 'Offline content';
      default:
        return featureKey;
    }
  }

  static bool looksLikeVerificationQrPayload(String value) {
    return value.trim().startsWith(_verificationQrPrefix);
  }
}

final contentVerificationServiceProvider = Provider<ContentVerificationService>(
  (ref) {
    final services = ref.read(appServicesProvider);
    return ContentVerificationService(cacheStore: services.cacheStore);
  },
);

DateTime? _tryParseDateTime(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

String _dateKeyFor(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}$month$day';
}

String _digest(String input, {required int length}) {
  final full = sha256.convert(utf8.encode(input)).toString();
  return full.substring(0, length.clamp(1, full.length));
}
