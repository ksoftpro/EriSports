// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CompetitionsTable extends Competitions
    with TableInfo<$CompetitionsTable, CompetitionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompetitionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoAssetKeyMeta = const VerificationMeta(
    'logoAssetKey',
  );
  @override
  late final GeneratedColumn<String> logoAssetKey = GeneratedColumn<String>(
    'logo_asset_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    country,
    logoAssetKey,
    displayOrder,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'competitions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompetitionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('logo_asset_key')) {
      context.handle(
        _logoAssetKeyMeta,
        logoAssetKey.isAcceptableOrUnknown(
          data['logo_asset_key']!,
          _logoAssetKeyMeta,
        ),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompetitionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompetitionRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      logoAssetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_asset_key'],
      ),
      displayOrder:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}display_order'],
          )!,
      updatedAtUtc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at_utc'],
          )!,
    );
  }

  @override
  $CompetitionsTable createAlias(String alias) {
    return $CompetitionsTable(attachedDatabase, alias);
  }
}

class CompetitionRow extends DataClass implements Insertable<CompetitionRow> {
  final String id;
  final String name;
  final String? country;
  final String? logoAssetKey;
  final int displayOrder;
  final DateTime updatedAtUtc;
  const CompetitionRow({
    required this.id,
    required this.name,
    this.country,
    this.logoAssetKey,
    required this.displayOrder,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || logoAssetKey != null) {
      map['logo_asset_key'] = Variable<String>(logoAssetKey);
    }
    map['display_order'] = Variable<int>(displayOrder);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  CompetitionsCompanion toCompanion(bool nullToAbsent) {
    return CompetitionsCompanion(
      id: Value(id),
      name: Value(name),
      country:
          country == null && nullToAbsent
              ? const Value.absent()
              : Value(country),
      logoAssetKey:
          logoAssetKey == null && nullToAbsent
              ? const Value.absent()
              : Value(logoAssetKey),
      displayOrder: Value(displayOrder),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory CompetitionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompetitionRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      country: serializer.fromJson<String?>(json['country']),
      logoAssetKey: serializer.fromJson<String?>(json['logoAssetKey']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'country': serializer.toJson<String?>(country),
      'logoAssetKey': serializer.toJson<String?>(logoAssetKey),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  CompetitionRow copyWith({
    String? id,
    String? name,
    Value<String?> country = const Value.absent(),
    Value<String?> logoAssetKey = const Value.absent(),
    int? displayOrder,
    DateTime? updatedAtUtc,
  }) => CompetitionRow(
    id: id ?? this.id,
    name: name ?? this.name,
    country: country.present ? country.value : this.country,
    logoAssetKey: logoAssetKey.present ? logoAssetKey.value : this.logoAssetKey,
    displayOrder: displayOrder ?? this.displayOrder,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  CompetitionRow copyWithCompanion(CompetitionsCompanion data) {
    return CompetitionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      country: data.country.present ? data.country.value : this.country,
      logoAssetKey:
          data.logoAssetKey.present
              ? data.logoAssetKey.value
              : this.logoAssetKey,
      displayOrder:
          data.displayOrder.present
              ? data.displayOrder.value
              : this.displayOrder,
      updatedAtUtc:
          data.updatedAtUtc.present
              ? data.updatedAtUtc.value
              : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompetitionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('logoAssetKey: $logoAssetKey, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, country, logoAssetKey, displayOrder, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompetitionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.country == this.country &&
          other.logoAssetKey == this.logoAssetKey &&
          other.displayOrder == this.displayOrder &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class CompetitionsCompanion extends UpdateCompanion<CompetitionRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> country;
  final Value<String?> logoAssetKey;
  final Value<int> displayOrder;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const CompetitionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.country = const Value.absent(),
    this.logoAssetKey = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompetitionsCompanion.insert({
    required String id,
    required String name,
    this.country = const Value.absent(),
    this.logoAssetKey = const Value.absent(),
    this.displayOrder = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<CompetitionRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? country,
    Expression<String>? logoAssetKey,
    Expression<int>? displayOrder,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (country != null) 'country': country,
      if (logoAssetKey != null) 'logo_asset_key': logoAssetKey,
      if (displayOrder != null) 'display_order': displayOrder,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompetitionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? country,
    Value<String?>? logoAssetKey,
    Value<int>? displayOrder,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return CompetitionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      logoAssetKey: logoAssetKey ?? this.logoAssetKey,
      displayOrder: displayOrder ?? this.displayOrder,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (logoAssetKey.present) {
      map['logo_asset_key'] = Variable<String>(logoAssetKey.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompetitionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('logoAssetKey: $logoAssetKey, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TeamsTable extends Teams with TableInfo<$TeamsTable, TeamRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeamsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shortNameMeta = const VerificationMeta(
    'shortName',
  );
  @override
  late final GeneratedColumn<String> shortName = GeneratedColumn<String>(
    'short_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _competitionIdMeta = const VerificationMeta(
    'competitionId',
  );
  @override
  late final GeneratedColumn<String> competitionId = GeneratedColumn<String>(
    'competition_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES competitions (id)',
    ),
  );
  static const VerificationMeta _badgeAssetKeyMeta = const VerificationMeta(
    'badgeAssetKey',
  );
  @override
  late final GeneratedColumn<String> badgeAssetKey = GeneratedColumn<String>(
    'badge_asset_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    shortName,
    competitionId,
    badgeAssetKey,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'teams';
  @override
  VerificationContext validateIntegrity(
    Insertable<TeamRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('short_name')) {
      context.handle(
        _shortNameMeta,
        shortName.isAcceptableOrUnknown(data['short_name']!, _shortNameMeta),
      );
    }
    if (data.containsKey('competition_id')) {
      context.handle(
        _competitionIdMeta,
        competitionId.isAcceptableOrUnknown(
          data['competition_id']!,
          _competitionIdMeta,
        ),
      );
    }
    if (data.containsKey('badge_asset_key')) {
      context.handle(
        _badgeAssetKeyMeta,
        badgeAssetKey.isAcceptableOrUnknown(
          data['badge_asset_key']!,
          _badgeAssetKeyMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TeamRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TeamRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      shortName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}short_name'],
      ),
      competitionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}competition_id'],
      ),
      badgeAssetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}badge_asset_key'],
      ),
      updatedAtUtc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at_utc'],
          )!,
    );
  }

  @override
  $TeamsTable createAlias(String alias) {
    return $TeamsTable(attachedDatabase, alias);
  }
}

class TeamRow extends DataClass implements Insertable<TeamRow> {
  final String id;
  final String name;
  final String? shortName;
  final String? competitionId;
  final String? badgeAssetKey;
  final DateTime updatedAtUtc;
  const TeamRow({
    required this.id,
    required this.name,
    this.shortName,
    this.competitionId,
    this.badgeAssetKey,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || shortName != null) {
      map['short_name'] = Variable<String>(shortName);
    }
    if (!nullToAbsent || competitionId != null) {
      map['competition_id'] = Variable<String>(competitionId);
    }
    if (!nullToAbsent || badgeAssetKey != null) {
      map['badge_asset_key'] = Variable<String>(badgeAssetKey);
    }
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  TeamsCompanion toCompanion(bool nullToAbsent) {
    return TeamsCompanion(
      id: Value(id),
      name: Value(name),
      shortName:
          shortName == null && nullToAbsent
              ? const Value.absent()
              : Value(shortName),
      competitionId:
          competitionId == null && nullToAbsent
              ? const Value.absent()
              : Value(competitionId),
      badgeAssetKey:
          badgeAssetKey == null && nullToAbsent
              ? const Value.absent()
              : Value(badgeAssetKey),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory TeamRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TeamRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      shortName: serializer.fromJson<String?>(json['shortName']),
      competitionId: serializer.fromJson<String?>(json['competitionId']),
      badgeAssetKey: serializer.fromJson<String?>(json['badgeAssetKey']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'shortName': serializer.toJson<String?>(shortName),
      'competitionId': serializer.toJson<String?>(competitionId),
      'badgeAssetKey': serializer.toJson<String?>(badgeAssetKey),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  TeamRow copyWith({
    String? id,
    String? name,
    Value<String?> shortName = const Value.absent(),
    Value<String?> competitionId = const Value.absent(),
    Value<String?> badgeAssetKey = const Value.absent(),
    DateTime? updatedAtUtc,
  }) => TeamRow(
    id: id ?? this.id,
    name: name ?? this.name,
    shortName: shortName.present ? shortName.value : this.shortName,
    competitionId:
        competitionId.present ? competitionId.value : this.competitionId,
    badgeAssetKey:
        badgeAssetKey.present ? badgeAssetKey.value : this.badgeAssetKey,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  TeamRow copyWithCompanion(TeamsCompanion data) {
    return TeamRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      shortName: data.shortName.present ? data.shortName.value : this.shortName,
      competitionId:
          data.competitionId.present
              ? data.competitionId.value
              : this.competitionId,
      badgeAssetKey:
          data.badgeAssetKey.present
              ? data.badgeAssetKey.value
              : this.badgeAssetKey,
      updatedAtUtc:
          data.updatedAtUtc.present
              ? data.updatedAtUtc.value
              : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TeamRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('competitionId: $competitionId, ')
          ..write('badgeAssetKey: $badgeAssetKey, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    shortName,
    competitionId,
    badgeAssetKey,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeamRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.shortName == this.shortName &&
          other.competitionId == this.competitionId &&
          other.badgeAssetKey == this.badgeAssetKey &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class TeamsCompanion extends UpdateCompanion<TeamRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> shortName;
  final Value<String?> competitionId;
  final Value<String?> badgeAssetKey;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const TeamsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.shortName = const Value.absent(),
    this.competitionId = const Value.absent(),
    this.badgeAssetKey = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TeamsCompanion.insert({
    required String id,
    required String name,
    this.shortName = const Value.absent(),
    this.competitionId = const Value.absent(),
    this.badgeAssetKey = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<TeamRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? shortName,
    Expression<String>? competitionId,
    Expression<String>? badgeAssetKey,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (shortName != null) 'short_name': shortName,
      if (competitionId != null) 'competition_id': competitionId,
      if (badgeAssetKey != null) 'badge_asset_key': badgeAssetKey,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TeamsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? shortName,
    Value<String?>? competitionId,
    Value<String?>? badgeAssetKey,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return TeamsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      competitionId: competitionId ?? this.competitionId,
      badgeAssetKey: badgeAssetKey ?? this.badgeAssetKey,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (shortName.present) {
      map['short_name'] = Variable<String>(shortName.value);
    }
    if (competitionId.present) {
      map['competition_id'] = Variable<String>(competitionId.value);
    }
    if (badgeAssetKey.present) {
      map['badge_asset_key'] = Variable<String>(badgeAssetKey.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeamsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('shortName: $shortName, ')
          ..write('competitionId: $competitionId, ')
          ..write('badgeAssetKey: $badgeAssetKey, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayersTable extends Players with TableInfo<$PlayersTable, PlayerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<String> teamId = GeneratedColumn<String>(
    'team_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<String> position = GeneratedColumn<String>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jerseyNumberMeta = const VerificationMeta(
    'jerseyNumber',
  );
  @override
  late final GeneratedColumn<int> jerseyNumber = GeneratedColumn<int>(
    'jersey_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoAssetKeyMeta = const VerificationMeta(
    'photoAssetKey',
  );
  @override
  late final GeneratedColumn<String> photoAssetKey = GeneratedColumn<String>(
    'photo_asset_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    teamId,
    name,
    position,
    jerseyNumber,
    photoAssetKey,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'players';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('jersey_number')) {
      context.handle(
        _jerseyNumberMeta,
        jerseyNumber.isAcceptableOrUnknown(
          data['jersey_number']!,
          _jerseyNumberMeta,
        ),
      );
    }
    if (data.containsKey('photo_asset_key')) {
      context.handle(
        _photoAssetKeyMeta,
        photoAssetKey.isAcceptableOrUnknown(
          data['photo_asset_key']!,
          _photoAssetKeyMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayerRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      teamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}team_id'],
      ),
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}position'],
      ),
      jerseyNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jersey_number'],
      ),
      photoAssetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_asset_key'],
      ),
      updatedAtUtc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at_utc'],
          )!,
    );
  }

  @override
  $PlayersTable createAlias(String alias) {
    return $PlayersTable(attachedDatabase, alias);
  }
}

class PlayerRow extends DataClass implements Insertable<PlayerRow> {
  final String id;
  final String? teamId;
  final String name;
  final String? position;
  final int? jerseyNumber;
  final String? photoAssetKey;
  final DateTime updatedAtUtc;
  const PlayerRow({
    required this.id,
    this.teamId,
    required this.name,
    this.position,
    this.jerseyNumber,
    this.photoAssetKey,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || teamId != null) {
      map['team_id'] = Variable<String>(teamId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<String>(position);
    }
    if (!nullToAbsent || jerseyNumber != null) {
      map['jersey_number'] = Variable<int>(jerseyNumber);
    }
    if (!nullToAbsent || photoAssetKey != null) {
      map['photo_asset_key'] = Variable<String>(photoAssetKey);
    }
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  PlayersCompanion toCompanion(bool nullToAbsent) {
    return PlayersCompanion(
      id: Value(id),
      teamId:
          teamId == null && nullToAbsent ? const Value.absent() : Value(teamId),
      name: Value(name),
      position:
          position == null && nullToAbsent
              ? const Value.absent()
              : Value(position),
      jerseyNumber:
          jerseyNumber == null && nullToAbsent
              ? const Value.absent()
              : Value(jerseyNumber),
      photoAssetKey:
          photoAssetKey == null && nullToAbsent
              ? const Value.absent()
              : Value(photoAssetKey),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory PlayerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayerRow(
      id: serializer.fromJson<String>(json['id']),
      teamId: serializer.fromJson<String?>(json['teamId']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<String?>(json['position']),
      jerseyNumber: serializer.fromJson<int?>(json['jerseyNumber']),
      photoAssetKey: serializer.fromJson<String?>(json['photoAssetKey']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'teamId': serializer.toJson<String?>(teamId),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<String?>(position),
      'jerseyNumber': serializer.toJson<int?>(jerseyNumber),
      'photoAssetKey': serializer.toJson<String?>(photoAssetKey),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  PlayerRow copyWith({
    String? id,
    Value<String?> teamId = const Value.absent(),
    String? name,
    Value<String?> position = const Value.absent(),
    Value<int?> jerseyNumber = const Value.absent(),
    Value<String?> photoAssetKey = const Value.absent(),
    DateTime? updatedAtUtc,
  }) => PlayerRow(
    id: id ?? this.id,
    teamId: teamId.present ? teamId.value : this.teamId,
    name: name ?? this.name,
    position: position.present ? position.value : this.position,
    jerseyNumber: jerseyNumber.present ? jerseyNumber.value : this.jerseyNumber,
    photoAssetKey:
        photoAssetKey.present ? photoAssetKey.value : this.photoAssetKey,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  PlayerRow copyWithCompanion(PlayersCompanion data) {
    return PlayerRow(
      id: data.id.present ? data.id.value : this.id,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      jerseyNumber:
          data.jerseyNumber.present
              ? data.jerseyNumber.value
              : this.jerseyNumber,
      photoAssetKey:
          data.photoAssetKey.present
              ? data.photoAssetKey.value
              : this.photoAssetKey,
      updatedAtUtc:
          data.updatedAtUtc.present
              ? data.updatedAtUtc.value
              : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerRow(')
          ..write('id: $id, ')
          ..write('teamId: $teamId, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('jerseyNumber: $jerseyNumber, ')
          ..write('photoAssetKey: $photoAssetKey, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    teamId,
    name,
    position,
    jerseyNumber,
    photoAssetKey,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerRow &&
          other.id == this.id &&
          other.teamId == this.teamId &&
          other.name == this.name &&
          other.position == this.position &&
          other.jerseyNumber == this.jerseyNumber &&
          other.photoAssetKey == this.photoAssetKey &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class PlayersCompanion extends UpdateCompanion<PlayerRow> {
  final Value<String> id;
  final Value<String?> teamId;
  final Value<String> name;
  final Value<String?> position;
  final Value<int?> jerseyNumber;
  final Value<String?> photoAssetKey;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const PlayersCompanion({
    this.id = const Value.absent(),
    this.teamId = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.jerseyNumber = const Value.absent(),
    this.photoAssetKey = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayersCompanion.insert({
    required String id,
    this.teamId = const Value.absent(),
    required String name,
    this.position = const Value.absent(),
    this.jerseyNumber = const Value.absent(),
    this.photoAssetKey = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<PlayerRow> custom({
    Expression<String>? id,
    Expression<String>? teamId,
    Expression<String>? name,
    Expression<String>? position,
    Expression<int>? jerseyNumber,
    Expression<String>? photoAssetKey,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (teamId != null) 'team_id': teamId,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (jerseyNumber != null) 'jersey_number': jerseyNumber,
      if (photoAssetKey != null) 'photo_asset_key': photoAssetKey,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayersCompanion copyWith({
    Value<String>? id,
    Value<String?>? teamId,
    Value<String>? name,
    Value<String?>? position,
    Value<int?>? jerseyNumber,
    Value<String?>? photoAssetKey,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return PlayersCompanion(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      position: position ?? this.position,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      photoAssetKey: photoAssetKey ?? this.photoAssetKey,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<String>(teamId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<String>(position.value);
    }
    if (jerseyNumber.present) {
      map['jersey_number'] = Variable<int>(jerseyNumber.value);
    }
    if (photoAssetKey.present) {
      map['photo_asset_key'] = Variable<String>(photoAssetKey.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayersCompanion(')
          ..write('id: $id, ')
          ..write('teamId: $teamId, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('jerseyNumber: $jerseyNumber, ')
          ..write('photoAssetKey: $photoAssetKey, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchesTable extends Matches with TableInfo<$MatchesTable, MatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _competitionIdMeta = const VerificationMeta(
    'competitionId',
  );
  @override
  late final GeneratedColumn<String> competitionId = GeneratedColumn<String>(
    'competition_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES competitions (id)',
    ),
  );
  static const VerificationMeta _seasonIdMeta = const VerificationMeta(
    'seasonId',
  );
  @override
  late final GeneratedColumn<String> seasonId = GeneratedColumn<String>(
    'season_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _homeTeamIdMeta = const VerificationMeta(
    'homeTeamId',
  );
  @override
  late final GeneratedColumn<String> homeTeamId = GeneratedColumn<String>(
    'home_team_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id)',
    ),
  );
  static const VerificationMeta _awayTeamIdMeta = const VerificationMeta(
    'awayTeamId',
  );
  @override
  late final GeneratedColumn<String> awayTeamId = GeneratedColumn<String>(
    'away_team_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id)',
    ),
  );
  static const VerificationMeta _kickoffUtcMeta = const VerificationMeta(
    'kickoffUtc',
  );
  @override
  late final GeneratedColumn<DateTime> kickoffUtc = GeneratedColumn<DateTime>(
    'kickoff_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('scheduled'),
  );
  static const VerificationMeta _homeScoreMeta = const VerificationMeta(
    'homeScore',
  );
  @override
  late final GeneratedColumn<int> homeScore = GeneratedColumn<int>(
    'home_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _awayScoreMeta = const VerificationMeta(
    'awayScore',
  );
  @override
  late final GeneratedColumn<int> awayScore = GeneratedColumn<int>(
    'away_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _roundLabelMeta = const VerificationMeta(
    'roundLabel',
  );
  @override
  late final GeneratedColumn<String> roundLabel = GeneratedColumn<String>(
    'round_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    competitionId,
    seasonId,
    homeTeamId,
    awayTeamId,
    kickoffUtc,
    status,
    homeScore,
    awayScore,
    roundLabel,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('competition_id')) {
      context.handle(
        _competitionIdMeta,
        competitionId.isAcceptableOrUnknown(
          data['competition_id']!,
          _competitionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_competitionIdMeta);
    }
    if (data.containsKey('season_id')) {
      context.handle(
        _seasonIdMeta,
        seasonId.isAcceptableOrUnknown(data['season_id']!, _seasonIdMeta),
      );
    }
    if (data.containsKey('home_team_id')) {
      context.handle(
        _homeTeamIdMeta,
        homeTeamId.isAcceptableOrUnknown(
          data['home_team_id']!,
          _homeTeamIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_homeTeamIdMeta);
    }
    if (data.containsKey('away_team_id')) {
      context.handle(
        _awayTeamIdMeta,
        awayTeamId.isAcceptableOrUnknown(
          data['away_team_id']!,
          _awayTeamIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_awayTeamIdMeta);
    }
    if (data.containsKey('kickoff_utc')) {
      context.handle(
        _kickoffUtcMeta,
        kickoffUtc.isAcceptableOrUnknown(data['kickoff_utc']!, _kickoffUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_kickoffUtcMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('home_score')) {
      context.handle(
        _homeScoreMeta,
        homeScore.isAcceptableOrUnknown(data['home_score']!, _homeScoreMeta),
      );
    }
    if (data.containsKey('away_score')) {
      context.handle(
        _awayScoreMeta,
        awayScore.isAcceptableOrUnknown(data['away_score']!, _awayScoreMeta),
      );
    }
    if (data.containsKey('round_label')) {
      context.handle(
        _roundLabelMeta,
        roundLabel.isAcceptableOrUnknown(data['round_label']!, _roundLabelMeta),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      competitionId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}competition_id'],
          )!,
      seasonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}season_id'],
      ),
      homeTeamId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}home_team_id'],
          )!,
      awayTeamId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}away_team_id'],
          )!,
      kickoffUtc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}kickoff_utc'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      homeScore:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}home_score'],
          )!,
      awayScore:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}away_score'],
          )!,
      roundLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}round_label'],
      ),
      updatedAtUtc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at_utc'],
          )!,
    );
  }

  @override
  $MatchesTable createAlias(String alias) {
    return $MatchesTable(attachedDatabase, alias);
  }
}

class MatchRow extends DataClass implements Insertable<MatchRow> {
  final String id;
  final String competitionId;
  final String? seasonId;
  final String homeTeamId;
  final String awayTeamId;
  final DateTime kickoffUtc;
  final String status;
  final int homeScore;
  final int awayScore;
  final String? roundLabel;
  final DateTime updatedAtUtc;
  const MatchRow({
    required this.id,
    required this.competitionId,
    this.seasonId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.kickoffUtc,
    required this.status,
    required this.homeScore,
    required this.awayScore,
    this.roundLabel,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['competition_id'] = Variable<String>(competitionId);
    if (!nullToAbsent || seasonId != null) {
      map['season_id'] = Variable<String>(seasonId);
    }
    map['home_team_id'] = Variable<String>(homeTeamId);
    map['away_team_id'] = Variable<String>(awayTeamId);
    map['kickoff_utc'] = Variable<DateTime>(kickoffUtc);
    map['status'] = Variable<String>(status);
    map['home_score'] = Variable<int>(homeScore);
    map['away_score'] = Variable<int>(awayScore);
    if (!nullToAbsent || roundLabel != null) {
      map['round_label'] = Variable<String>(roundLabel);
    }
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  MatchesCompanion toCompanion(bool nullToAbsent) {
    return MatchesCompanion(
      id: Value(id),
      competitionId: Value(competitionId),
      seasonId:
          seasonId == null && nullToAbsent
              ? const Value.absent()
              : Value(seasonId),
      homeTeamId: Value(homeTeamId),
      awayTeamId: Value(awayTeamId),
      kickoffUtc: Value(kickoffUtc),
      status: Value(status),
      homeScore: Value(homeScore),
      awayScore: Value(awayScore),
      roundLabel:
          roundLabel == null && nullToAbsent
              ? const Value.absent()
              : Value(roundLabel),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory MatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchRow(
      id: serializer.fromJson<String>(json['id']),
      competitionId: serializer.fromJson<String>(json['competitionId']),
      seasonId: serializer.fromJson<String?>(json['seasonId']),
      homeTeamId: serializer.fromJson<String>(json['homeTeamId']),
      awayTeamId: serializer.fromJson<String>(json['awayTeamId']),
      kickoffUtc: serializer.fromJson<DateTime>(json['kickoffUtc']),
      status: serializer.fromJson<String>(json['status']),
      homeScore: serializer.fromJson<int>(json['homeScore']),
      awayScore: serializer.fromJson<int>(json['awayScore']),
      roundLabel: serializer.fromJson<String?>(json['roundLabel']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'competitionId': serializer.toJson<String>(competitionId),
      'seasonId': serializer.toJson<String?>(seasonId),
      'homeTeamId': serializer.toJson<String>(homeTeamId),
      'awayTeamId': serializer.toJson<String>(awayTeamId),
      'kickoffUtc': serializer.toJson<DateTime>(kickoffUtc),
      'status': serializer.toJson<String>(status),
      'homeScore': serializer.toJson<int>(homeScore),
      'awayScore': serializer.toJson<int>(awayScore),
      'roundLabel': serializer.toJson<String?>(roundLabel),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  MatchRow copyWith({
    String? id,
    String? competitionId,
    Value<String?> seasonId = const Value.absent(),
    String? homeTeamId,
    String? awayTeamId,
    DateTime? kickoffUtc,
    String? status,
    int? homeScore,
    int? awayScore,
    Value<String?> roundLabel = const Value.absent(),
    DateTime? updatedAtUtc,
  }) => MatchRow(
    id: id ?? this.id,
    competitionId: competitionId ?? this.competitionId,
    seasonId: seasonId.present ? seasonId.value : this.seasonId,
    homeTeamId: homeTeamId ?? this.homeTeamId,
    awayTeamId: awayTeamId ?? this.awayTeamId,
    kickoffUtc: kickoffUtc ?? this.kickoffUtc,
    status: status ?? this.status,
    homeScore: homeScore ?? this.homeScore,
    awayScore: awayScore ?? this.awayScore,
    roundLabel: roundLabel.present ? roundLabel.value : this.roundLabel,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  MatchRow copyWithCompanion(MatchesCompanion data) {
    return MatchRow(
      id: data.id.present ? data.id.value : this.id,
      competitionId:
          data.competitionId.present
              ? data.competitionId.value
              : this.competitionId,
      seasonId: data.seasonId.present ? data.seasonId.value : this.seasonId,
      homeTeamId:
          data.homeTeamId.present ? data.homeTeamId.value : this.homeTeamId,
      awayTeamId:
          data.awayTeamId.present ? data.awayTeamId.value : this.awayTeamId,
      kickoffUtc:
          data.kickoffUtc.present ? data.kickoffUtc.value : this.kickoffUtc,
      status: data.status.present ? data.status.value : this.status,
      homeScore: data.homeScore.present ? data.homeScore.value : this.homeScore,
      awayScore: data.awayScore.present ? data.awayScore.value : this.awayScore,
      roundLabel:
          data.roundLabel.present ? data.roundLabel.value : this.roundLabel,
      updatedAtUtc:
          data.updatedAtUtc.present
              ? data.updatedAtUtc.value
              : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchRow(')
          ..write('id: $id, ')
          ..write('competitionId: $competitionId, ')
          ..write('seasonId: $seasonId, ')
          ..write('homeTeamId: $homeTeamId, ')
          ..write('awayTeamId: $awayTeamId, ')
          ..write('kickoffUtc: $kickoffUtc, ')
          ..write('status: $status, ')
          ..write('homeScore: $homeScore, ')
          ..write('awayScore: $awayScore, ')
          ..write('roundLabel: $roundLabel, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    competitionId,
    seasonId,
    homeTeamId,
    awayTeamId,
    kickoffUtc,
    status,
    homeScore,
    awayScore,
    roundLabel,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchRow &&
          other.id == this.id &&
          other.competitionId == this.competitionId &&
          other.seasonId == this.seasonId &&
          other.homeTeamId == this.homeTeamId &&
          other.awayTeamId == this.awayTeamId &&
          other.kickoffUtc == this.kickoffUtc &&
          other.status == this.status &&
          other.homeScore == this.homeScore &&
          other.awayScore == this.awayScore &&
          other.roundLabel == this.roundLabel &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class MatchesCompanion extends UpdateCompanion<MatchRow> {
  final Value<String> id;
  final Value<String> competitionId;
  final Value<String?> seasonId;
  final Value<String> homeTeamId;
  final Value<String> awayTeamId;
  final Value<DateTime> kickoffUtc;
  final Value<String> status;
  final Value<int> homeScore;
  final Value<int> awayScore;
  final Value<String?> roundLabel;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const MatchesCompanion({
    this.id = const Value.absent(),
    this.competitionId = const Value.absent(),
    this.seasonId = const Value.absent(),
    this.homeTeamId = const Value.absent(),
    this.awayTeamId = const Value.absent(),
    this.kickoffUtc = const Value.absent(),
    this.status = const Value.absent(),
    this.homeScore = const Value.absent(),
    this.awayScore = const Value.absent(),
    this.roundLabel = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchesCompanion.insert({
    required String id,
    required String competitionId,
    this.seasonId = const Value.absent(),
    required String homeTeamId,
    required String awayTeamId,
    required DateTime kickoffUtc,
    this.status = const Value.absent(),
    this.homeScore = const Value.absent(),
    this.awayScore = const Value.absent(),
    this.roundLabel = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       competitionId = Value(competitionId),
       homeTeamId = Value(homeTeamId),
       awayTeamId = Value(awayTeamId),
       kickoffUtc = Value(kickoffUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<MatchRow> custom({
    Expression<String>? id,
    Expression<String>? competitionId,
    Expression<String>? seasonId,
    Expression<String>? homeTeamId,
    Expression<String>? awayTeamId,
    Expression<DateTime>? kickoffUtc,
    Expression<String>? status,
    Expression<int>? homeScore,
    Expression<int>? awayScore,
    Expression<String>? roundLabel,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (competitionId != null) 'competition_id': competitionId,
      if (seasonId != null) 'season_id': seasonId,
      if (homeTeamId != null) 'home_team_id': homeTeamId,
      if (awayTeamId != null) 'away_team_id': awayTeamId,
      if (kickoffUtc != null) 'kickoff_utc': kickoffUtc,
      if (status != null) 'status': status,
      if (homeScore != null) 'home_score': homeScore,
      if (awayScore != null) 'away_score': awayScore,
      if (roundLabel != null) 'round_label': roundLabel,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? competitionId,
    Value<String?>? seasonId,
    Value<String>? homeTeamId,
    Value<String>? awayTeamId,
    Value<DateTime>? kickoffUtc,
    Value<String>? status,
    Value<int>? homeScore,
    Value<int>? awayScore,
    Value<String?>? roundLabel,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return MatchesCompanion(
      id: id ?? this.id,
      competitionId: competitionId ?? this.competitionId,
      seasonId: seasonId ?? this.seasonId,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      kickoffUtc: kickoffUtc ?? this.kickoffUtc,
      status: status ?? this.status,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      roundLabel: roundLabel ?? this.roundLabel,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (competitionId.present) {
      map['competition_id'] = Variable<String>(competitionId.value);
    }
    if (seasonId.present) {
      map['season_id'] = Variable<String>(seasonId.value);
    }
    if (homeTeamId.present) {
      map['home_team_id'] = Variable<String>(homeTeamId.value);
    }
    if (awayTeamId.present) {
      map['away_team_id'] = Variable<String>(awayTeamId.value);
    }
    if (kickoffUtc.present) {
      map['kickoff_utc'] = Variable<DateTime>(kickoffUtc.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (homeScore.present) {
      map['home_score'] = Variable<int>(homeScore.value);
    }
    if (awayScore.present) {
      map['away_score'] = Variable<int>(awayScore.value);
    }
    if (roundLabel.present) {
      map['round_label'] = Variable<String>(roundLabel.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchesCompanion(')
          ..write('id: $id, ')
          ..write('competitionId: $competitionId, ')
          ..write('seasonId: $seasonId, ')
          ..write('homeTeamId: $homeTeamId, ')
          ..write('awayTeamId: $awayTeamId, ')
          ..write('kickoffUtc: $kickoffUtc, ')
          ..write('status: $status, ')
          ..write('homeScore: $homeScore, ')
          ..write('awayScore: $awayScore, ')
          ..write('roundLabel: $roundLabel, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchEventsTable extends MatchEvents
    with TableInfo<$MatchEventsTable, MatchEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id)',
    ),
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<String> teamId = GeneratedColumn<String>(
    'team_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id)',
    ),
  );
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id)',
    ),
  );
  static const VerificationMeta _playerNameMeta = const VerificationMeta(
    'playerName',
  );
  @override
  late final GeneratedColumn<String> playerName = GeneratedColumn<String>(
    'player_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    minute,
    eventType,
    teamId,
    playerId,
    playerName,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    }
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    }
    if (data.containsKey('player_name')) {
      context.handle(
        _playerNameMeta,
        playerName.isAcceptableOrUnknown(data['player_name']!, _playerNameMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchEventRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      matchId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}match_id'],
          )!,
      minute:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}minute'],
          )!,
      eventType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}event_type'],
          )!,
      teamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}team_id'],
      ),
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      ),
      playerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_name'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
    );
  }

  @override
  $MatchEventsTable createAlias(String alias) {
    return $MatchEventsTable(attachedDatabase, alias);
  }
}

class MatchEventRow extends DataClass implements Insertable<MatchEventRow> {
  final int id;
  final String matchId;
  final int minute;
  final String eventType;
  final String? teamId;
  final String? playerId;
  final String? playerName;
  final String? detail;
  const MatchEventRow({
    required this.id,
    required this.matchId,
    required this.minute,
    required this.eventType,
    this.teamId,
    this.playerId,
    this.playerName,
    this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['match_id'] = Variable<String>(matchId);
    map['minute'] = Variable<int>(minute);
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || teamId != null) {
      map['team_id'] = Variable<String>(teamId);
    }
    if (!nullToAbsent || playerId != null) {
      map['player_id'] = Variable<String>(playerId);
    }
    if (!nullToAbsent || playerName != null) {
      map['player_name'] = Variable<String>(playerName);
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    return map;
  }

  MatchEventsCompanion toCompanion(bool nullToAbsent) {
    return MatchEventsCompanion(
      id: Value(id),
      matchId: Value(matchId),
      minute: Value(minute),
      eventType: Value(eventType),
      teamId:
          teamId == null && nullToAbsent ? const Value.absent() : Value(teamId),
      playerId:
          playerId == null && nullToAbsent
              ? const Value.absent()
              : Value(playerId),
      playerName:
          playerName == null && nullToAbsent
              ? const Value.absent()
              : Value(playerName),
      detail:
          detail == null && nullToAbsent ? const Value.absent() : Value(detail),
    );
  }

  factory MatchEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchEventRow(
      id: serializer.fromJson<int>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      minute: serializer.fromJson<int>(json['minute']),
      eventType: serializer.fromJson<String>(json['eventType']),
      teamId: serializer.fromJson<String?>(json['teamId']),
      playerId: serializer.fromJson<String?>(json['playerId']),
      playerName: serializer.fromJson<String?>(json['playerName']),
      detail: serializer.fromJson<String?>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'matchId': serializer.toJson<String>(matchId),
      'minute': serializer.toJson<int>(minute),
      'eventType': serializer.toJson<String>(eventType),
      'teamId': serializer.toJson<String?>(teamId),
      'playerId': serializer.toJson<String?>(playerId),
      'playerName': serializer.toJson<String?>(playerName),
      'detail': serializer.toJson<String?>(detail),
    };
  }

  MatchEventRow copyWith({
    int? id,
    String? matchId,
    int? minute,
    String? eventType,
    Value<String?> teamId = const Value.absent(),
    Value<String?> playerId = const Value.absent(),
    Value<String?> playerName = const Value.absent(),
    Value<String?> detail = const Value.absent(),
  }) => MatchEventRow(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    minute: minute ?? this.minute,
    eventType: eventType ?? this.eventType,
    teamId: teamId.present ? teamId.value : this.teamId,
    playerId: playerId.present ? playerId.value : this.playerId,
    playerName: playerName.present ? playerName.value : this.playerName,
    detail: detail.present ? detail.value : this.detail,
  );
  MatchEventRow copyWithCompanion(MatchEventsCompanion data) {
    return MatchEventRow(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      minute: data.minute.present ? data.minute.value : this.minute,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      playerName:
          data.playerName.present ? data.playerName.value : this.playerName,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchEventRow(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('minute: $minute, ')
          ..write('eventType: $eventType, ')
          ..write('teamId: $teamId, ')
          ..write('playerId: $playerId, ')
          ..write('playerName: $playerName, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    matchId,
    minute,
    eventType,
    teamId,
    playerId,
    playerName,
    detail,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchEventRow &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.minute == this.minute &&
          other.eventType == this.eventType &&
          other.teamId == this.teamId &&
          other.playerId == this.playerId &&
          other.playerName == this.playerName &&
          other.detail == this.detail);
}

class MatchEventsCompanion extends UpdateCompanion<MatchEventRow> {
  final Value<int> id;
  final Value<String> matchId;
  final Value<int> minute;
  final Value<String> eventType;
  final Value<String?> teamId;
  final Value<String?> playerId;
  final Value<String?> playerName;
  final Value<String?> detail;
  const MatchEventsCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.minute = const Value.absent(),
    this.eventType = const Value.absent(),
    this.teamId = const Value.absent(),
    this.playerId = const Value.absent(),
    this.playerName = const Value.absent(),
    this.detail = const Value.absent(),
  });
  MatchEventsCompanion.insert({
    this.id = const Value.absent(),
    required String matchId,
    required int minute,
    required String eventType,
    this.teamId = const Value.absent(),
    this.playerId = const Value.absent(),
    this.playerName = const Value.absent(),
    this.detail = const Value.absent(),
  }) : matchId = Value(matchId),
       minute = Value(minute),
       eventType = Value(eventType);
  static Insertable<MatchEventRow> custom({
    Expression<int>? id,
    Expression<String>? matchId,
    Expression<int>? minute,
    Expression<String>? eventType,
    Expression<String>? teamId,
    Expression<String>? playerId,
    Expression<String>? playerName,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (minute != null) 'minute': minute,
      if (eventType != null) 'event_type': eventType,
      if (teamId != null) 'team_id': teamId,
      if (playerId != null) 'player_id': playerId,
      if (playerName != null) 'player_name': playerName,
      if (detail != null) 'detail': detail,
    });
  }

  MatchEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? matchId,
    Value<int>? minute,
    Value<String>? eventType,
    Value<String?>? teamId,
    Value<String?>? playerId,
    Value<String?>? playerName,
    Value<String?>? detail,
  }) {
    return MatchEventsCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      minute: minute ?? this.minute,
      eventType: eventType ?? this.eventType,
      teamId: teamId ?? this.teamId,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<String>(teamId.value);
    }
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (playerName.present) {
      map['player_name'] = Variable<String>(playerName.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchEventsCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('minute: $minute, ')
          ..write('eventType: $eventType, ')
          ..write('teamId: $teamId, ')
          ..write('playerId: $playerId, ')
          ..write('playerName: $playerName, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $MatchTeamStatsTable extends MatchTeamStats
    with TableInfo<$MatchTeamStatsTable, MatchTeamStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchTeamStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id)',
    ),
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<String> teamId = GeneratedColumn<String>(
    'team_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id)',
    ),
  );
  static const VerificationMeta _statKeyMeta = const VerificationMeta(
    'statKey',
  );
  @override
  late final GeneratedColumn<String> statKey = GeneratedColumn<String>(
    'stat_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statValueMeta = const VerificationMeta(
    'statValue',
  );
  @override
  late final GeneratedColumn<double> statValue = GeneratedColumn<double>(
    'stat_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    teamId,
    statKey,
    statValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_team_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchTeamStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    } else if (isInserting) {
      context.missing(_teamIdMeta);
    }
    if (data.containsKey('stat_key')) {
      context.handle(
        _statKeyMeta,
        statKey.isAcceptableOrUnknown(data['stat_key']!, _statKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_statKeyMeta);
    }
    if (data.containsKey('stat_value')) {
      context.handle(
        _statValueMeta,
        statValue.isAcceptableOrUnknown(data['stat_value']!, _statValueMeta),
      );
    } else if (isInserting) {
      context.missing(_statValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchTeamStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchTeamStatRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      matchId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}match_id'],
          )!,
      teamId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}team_id'],
          )!,
      statKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}stat_key'],
          )!,
      statValue:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}stat_value'],
          )!,
    );
  }

  @override
  $MatchTeamStatsTable createAlias(String alias) {
    return $MatchTeamStatsTable(attachedDatabase, alias);
  }
}

class MatchTeamStatRow extends DataClass
    implements Insertable<MatchTeamStatRow> {
  final int id;
  final String matchId;
  final String teamId;
  final String statKey;
  final double statValue;
  const MatchTeamStatRow({
    required this.id,
    required this.matchId,
    required this.teamId,
    required this.statKey,
    required this.statValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['match_id'] = Variable<String>(matchId);
    map['team_id'] = Variable<String>(teamId);
    map['stat_key'] = Variable<String>(statKey);
    map['stat_value'] = Variable<double>(statValue);
    return map;
  }

  MatchTeamStatsCompanion toCompanion(bool nullToAbsent) {
    return MatchTeamStatsCompanion(
      id: Value(id),
      matchId: Value(matchId),
      teamId: Value(teamId),
      statKey: Value(statKey),
      statValue: Value(statValue),
    );
  }

  factory MatchTeamStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchTeamStatRow(
      id: serializer.fromJson<int>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      teamId: serializer.fromJson<String>(json['teamId']),
      statKey: serializer.fromJson<String>(json['statKey']),
      statValue: serializer.fromJson<double>(json['statValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'matchId': serializer.toJson<String>(matchId),
      'teamId': serializer.toJson<String>(teamId),
      'statKey': serializer.toJson<String>(statKey),
      'statValue': serializer.toJson<double>(statValue),
    };
  }

  MatchTeamStatRow copyWith({
    int? id,
    String? matchId,
    String? teamId,
    String? statKey,
    double? statValue,
  }) => MatchTeamStatRow(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    teamId: teamId ?? this.teamId,
    statKey: statKey ?? this.statKey,
    statValue: statValue ?? this.statValue,
  );
  MatchTeamStatRow copyWithCompanion(MatchTeamStatsCompanion data) {
    return MatchTeamStatRow(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      statKey: data.statKey.present ? data.statKey.value : this.statKey,
      statValue: data.statValue.present ? data.statValue.value : this.statValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchTeamStatRow(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('teamId: $teamId, ')
          ..write('statKey: $statKey, ')
          ..write('statValue: $statValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, matchId, teamId, statKey, statValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchTeamStatRow &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.teamId == this.teamId &&
          other.statKey == this.statKey &&
          other.statValue == this.statValue);
}

class MatchTeamStatsCompanion extends UpdateCompanion<MatchTeamStatRow> {
  final Value<int> id;
  final Value<String> matchId;
  final Value<String> teamId;
  final Value<String> statKey;
  final Value<double> statValue;
  const MatchTeamStatsCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.teamId = const Value.absent(),
    this.statKey = const Value.absent(),
    this.statValue = const Value.absent(),
  });
  MatchTeamStatsCompanion.insert({
    this.id = const Value.absent(),
    required String matchId,
    required String teamId,
    required String statKey,
    required double statValue,
  }) : matchId = Value(matchId),
       teamId = Value(teamId),
       statKey = Value(statKey),
       statValue = Value(statValue);
  static Insertable<MatchTeamStatRow> custom({
    Expression<int>? id,
    Expression<String>? matchId,
    Expression<String>? teamId,
    Expression<String>? statKey,
    Expression<double>? statValue,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (teamId != null) 'team_id': teamId,
      if (statKey != null) 'stat_key': statKey,
      if (statValue != null) 'stat_value': statValue,
    });
  }

  MatchTeamStatsCompanion copyWith({
    Value<int>? id,
    Value<String>? matchId,
    Value<String>? teamId,
    Value<String>? statKey,
    Value<double>? statValue,
  }) {
    return MatchTeamStatsCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      teamId: teamId ?? this.teamId,
      statKey: statKey ?? this.statKey,
      statValue: statValue ?? this.statValue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<String>(teamId.value);
    }
    if (statKey.present) {
      map['stat_key'] = Variable<String>(statKey.value);
    }
    if (statValue.present) {
      map['stat_value'] = Variable<double>(statValue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchTeamStatsCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('teamId: $teamId, ')
          ..write('statKey: $statKey, ')
          ..write('statValue: $statValue')
          ..write(')'))
        .toString();
  }
}

class $TopPlayerStatsTable extends TopPlayerStats
    with TableInfo<$TopPlayerStatsTable, TopPlayerStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TopPlayerStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _competitionIdMeta = const VerificationMeta(
    'competitionId',
  );
  @override
  late final GeneratedColumn<String> competitionId = GeneratedColumn<String>(
    'competition_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES competitions (id)',
    ),
  );
  static const VerificationMeta _seasonIdMeta = const VerificationMeta(
    'seasonId',
  );
  @override
  late final GeneratedColumn<String> seasonId = GeneratedColumn<String>(
    'season_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statTypeMeta = const VerificationMeta(
    'statType',
  );
  @override
  late final GeneratedColumn<String> statType = GeneratedColumn<String>(
    'stat_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id)',
    ),
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<String> teamId = GeneratedColumn<String>(
    'team_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id)',
    ),
  );
  static const VerificationMeta _playerNameMeta = const VerificationMeta(
    'playerName',
  );
  @override
  late final GeneratedColumn<String> playerName = GeneratedColumn<String>(
    'player_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statValueMeta = const VerificationMeta(
    'statValue',
  );
  @override
  late final GeneratedColumn<double> statValue = GeneratedColumn<double>(
    'stat_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subStatValueMeta = const VerificationMeta(
    'subStatValue',
  );
  @override
  late final GeneratedColumn<double> subStatValue = GeneratedColumn<double>(
    'sub_stat_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    competitionId,
    seasonId,
    statType,
    playerId,
    teamId,
    playerName,
    rank,
    statValue,
    subStatValue,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'top_player_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<TopPlayerStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('competition_id')) {
      context.handle(
        _competitionIdMeta,
        competitionId.isAcceptableOrUnknown(
          data['competition_id']!,
          _competitionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_competitionIdMeta);
    }
    if (data.containsKey('season_id')) {
      context.handle(
        _seasonIdMeta,
        seasonId.isAcceptableOrUnknown(data['season_id']!, _seasonIdMeta),
      );
    }
    if (data.containsKey('stat_type')) {
      context.handle(
        _statTypeMeta,
        statType.isAcceptableOrUnknown(data['stat_type']!, _statTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_statTypeMeta);
    }
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    }
    if (data.containsKey('player_name')) {
      context.handle(
        _playerNameMeta,
        playerName.isAcceptableOrUnknown(data['player_name']!, _playerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_playerNameMeta);
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    } else if (isInserting) {
      context.missing(_rankMeta);
    }
    if (data.containsKey('stat_value')) {
      context.handle(
        _statValueMeta,
        statValue.isAcceptableOrUnknown(data['stat_value']!, _statValueMeta),
      );
    } else if (isInserting) {
      context.missing(_statValueMeta);
    }
    if (data.containsKey('sub_stat_value')) {
      context.handle(
        _subStatValueMeta,
        subStatValue.isAcceptableOrUnknown(
          data['sub_stat_value']!,
          _subStatValueMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TopPlayerStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TopPlayerStatRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      competitionId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}competition_id'],
          )!,
      seasonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}season_id'],
      ),
      statType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}stat_type'],
          )!,
      playerId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}player_id'],
          )!,
      teamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}team_id'],
      ),
      playerName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}player_name'],
          )!,
      rank:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}rank'],
          )!,
      statValue:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}stat_value'],
          )!,
      subStatValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sub_stat_value'],
      ),
      updatedAtUtc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at_utc'],
          )!,
    );
  }

  @override
  $TopPlayerStatsTable createAlias(String alias) {
    return $TopPlayerStatsTable(attachedDatabase, alias);
  }
}

class TopPlayerStatRow extends DataClass
    implements Insertable<TopPlayerStatRow> {
  final int id;
  final String competitionId;
  final String? seasonId;
  final String statType;
  final String playerId;
  final String? teamId;
  final String playerName;
  final int rank;
  final double statValue;
  final double? subStatValue;
  final DateTime updatedAtUtc;
  const TopPlayerStatRow({
    required this.id,
    required this.competitionId,
    this.seasonId,
    required this.statType,
    required this.playerId,
    this.teamId,
    required this.playerName,
    required this.rank,
    required this.statValue,
    this.subStatValue,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['competition_id'] = Variable<String>(competitionId);
    if (!nullToAbsent || seasonId != null) {
      map['season_id'] = Variable<String>(seasonId);
    }
    map['stat_type'] = Variable<String>(statType);
    map['player_id'] = Variable<String>(playerId);
    if (!nullToAbsent || teamId != null) {
      map['team_id'] = Variable<String>(teamId);
    }
    map['player_name'] = Variable<String>(playerName);
    map['rank'] = Variable<int>(rank);
    map['stat_value'] = Variable<double>(statValue);
    if (!nullToAbsent || subStatValue != null) {
      map['sub_stat_value'] = Variable<double>(subStatValue);
    }
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  TopPlayerStatsCompanion toCompanion(bool nullToAbsent) {
    return TopPlayerStatsCompanion(
      id: Value(id),
      competitionId: Value(competitionId),
      seasonId:
          seasonId == null && nullToAbsent
              ? const Value.absent()
              : Value(seasonId),
      statType: Value(statType),
      playerId: Value(playerId),
      teamId:
          teamId == null && nullToAbsent ? const Value.absent() : Value(teamId),
      playerName: Value(playerName),
      rank: Value(rank),
      statValue: Value(statValue),
      subStatValue:
          subStatValue == null && nullToAbsent
              ? const Value.absent()
              : Value(subStatValue),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory TopPlayerStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TopPlayerStatRow(
      id: serializer.fromJson<int>(json['id']),
      competitionId: serializer.fromJson<String>(json['competitionId']),
      seasonId: serializer.fromJson<String?>(json['seasonId']),
      statType: serializer.fromJson<String>(json['statType']),
      playerId: serializer.fromJson<String>(json['playerId']),
      teamId: serializer.fromJson<String?>(json['teamId']),
      playerName: serializer.fromJson<String>(json['playerName']),
      rank: serializer.fromJson<int>(json['rank']),
      statValue: serializer.fromJson<double>(json['statValue']),
      subStatValue: serializer.fromJson<double?>(json['subStatValue']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'competitionId': serializer.toJson<String>(competitionId),
      'seasonId': serializer.toJson<String?>(seasonId),
      'statType': serializer.toJson<String>(statType),
      'playerId': serializer.toJson<String>(playerId),
      'teamId': serializer.toJson<String?>(teamId),
      'playerName': serializer.toJson<String>(playerName),
      'rank': serializer.toJson<int>(rank),
      'statValue': serializer.toJson<double>(statValue),
      'subStatValue': serializer.toJson<double?>(subStatValue),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  TopPlayerStatRow copyWith({
    int? id,
    String? competitionId,
    Value<String?> seasonId = const Value.absent(),
    String? statType,
    String? playerId,
    Value<String?> teamId = const Value.absent(),
    String? playerName,
    int? rank,
    double? statValue,
    Value<double?> subStatValue = const Value.absent(),
    DateTime? updatedAtUtc,
  }) => TopPlayerStatRow(
    id: id ?? this.id,
    competitionId: competitionId ?? this.competitionId,
    seasonId: seasonId.present ? seasonId.value : this.seasonId,
    statType: statType ?? this.statType,
    playerId: playerId ?? this.playerId,
    teamId: teamId.present ? teamId.value : this.teamId,
    playerName: playerName ?? this.playerName,
    rank: rank ?? this.rank,
    statValue: statValue ?? this.statValue,
    subStatValue: subStatValue.present ? subStatValue.value : this.subStatValue,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  TopPlayerStatRow copyWithCompanion(TopPlayerStatsCompanion data) {
    return TopPlayerStatRow(
      id: data.id.present ? data.id.value : this.id,
      competitionId:
          data.competitionId.present
              ? data.competitionId.value
              : this.competitionId,
      seasonId: data.seasonId.present ? data.seasonId.value : this.seasonId,
      statType: data.statType.present ? data.statType.value : this.statType,
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      playerName:
          data.playerName.present ? data.playerName.value : this.playerName,
      rank: data.rank.present ? data.rank.value : this.rank,
      statValue: data.statValue.present ? data.statValue.value : this.statValue,
      subStatValue:
          data.subStatValue.present
              ? data.subStatValue.value
              : this.subStatValue,
      updatedAtUtc:
          data.updatedAtUtc.present
              ? data.updatedAtUtc.value
              : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TopPlayerStatRow(')
          ..write('id: $id, ')
          ..write('competitionId: $competitionId, ')
          ..write('seasonId: $seasonId, ')
          ..write('statType: $statType, ')
          ..write('playerId: $playerId, ')
          ..write('teamId: $teamId, ')
          ..write('playerName: $playerName, ')
          ..write('rank: $rank, ')
          ..write('statValue: $statValue, ')
          ..write('subStatValue: $subStatValue, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    competitionId,
    seasonId,
    statType,
    playerId,
    teamId,
    playerName,
    rank,
    statValue,
    subStatValue,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TopPlayerStatRow &&
          other.id == this.id &&
          other.competitionId == this.competitionId &&
          other.seasonId == this.seasonId &&
          other.statType == this.statType &&
          other.playerId == this.playerId &&
          other.teamId == this.teamId &&
          other.playerName == this.playerName &&
          other.rank == this.rank &&
          other.statValue == this.statValue &&
          other.subStatValue == this.subStatValue &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class TopPlayerStatsCompanion extends UpdateCompanion<TopPlayerStatRow> {
  final Value<int> id;
  final Value<String> competitionId;
  final Value<String?> seasonId;
  final Value<String> statType;
  final Value<String> playerId;
  final Value<String?> teamId;
  final Value<String> playerName;
  final Value<int> rank;
  final Value<double> statValue;
  final Value<double?> subStatValue;
  final Value<DateTime> updatedAtUtc;
  const TopPlayerStatsCompanion({
    this.id = const Value.absent(),
    this.competitionId = const Value.absent(),
    this.seasonId = const Value.absent(),
    this.statType = const Value.absent(),
    this.playerId = const Value.absent(),
    this.teamId = const Value.absent(),
    this.playerName = const Value.absent(),
    this.rank = const Value.absent(),
    this.statValue = const Value.absent(),
    this.subStatValue = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
  });
  TopPlayerStatsCompanion.insert({
    this.id = const Value.absent(),
    required String competitionId,
    this.seasonId = const Value.absent(),
    required String statType,
    required String playerId,
    this.teamId = const Value.absent(),
    required String playerName,
    required int rank,
    required double statValue,
    this.subStatValue = const Value.absent(),
    required DateTime updatedAtUtc,
  }) : competitionId = Value(competitionId),
       statType = Value(statType),
       playerId = Value(playerId),
       playerName = Value(playerName),
       rank = Value(rank),
       statValue = Value(statValue),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<TopPlayerStatRow> custom({
    Expression<int>? id,
    Expression<String>? competitionId,
    Expression<String>? seasonId,
    Expression<String>? statType,
    Expression<String>? playerId,
    Expression<String>? teamId,
    Expression<String>? playerName,
    Expression<int>? rank,
    Expression<double>? statValue,
    Expression<double>? subStatValue,
    Expression<DateTime>? updatedAtUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (competitionId != null) 'competition_id': competitionId,
      if (seasonId != null) 'season_id': seasonId,
      if (statType != null) 'stat_type': statType,
      if (playerId != null) 'player_id': playerId,
      if (teamId != null) 'team_id': teamId,
      if (playerName != null) 'player_name': playerName,
      if (rank != null) 'rank': rank,
      if (statValue != null) 'stat_value': statValue,
      if (subStatValue != null) 'sub_stat_value': subStatValue,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
    });
  }

  TopPlayerStatsCompanion copyWith({
    Value<int>? id,
    Value<String>? competitionId,
    Value<String?>? seasonId,
    Value<String>? statType,
    Value<String>? playerId,
    Value<String?>? teamId,
    Value<String>? playerName,
    Value<int>? rank,
    Value<double>? statValue,
    Value<double?>? subStatValue,
    Value<DateTime>? updatedAtUtc,
  }) {
    return TopPlayerStatsCompanion(
      id: id ?? this.id,
      competitionId: competitionId ?? this.competitionId,
      seasonId: seasonId ?? this.seasonId,
      statType: statType ?? this.statType,
      playerId: playerId ?? this.playerId,
      teamId: teamId ?? this.teamId,
      playerName: playerName ?? this.playerName,
      rank: rank ?? this.rank,
      statValue: statValue ?? this.statValue,
      subStatValue: subStatValue ?? this.subStatValue,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (competitionId.present) {
      map['competition_id'] = Variable<String>(competitionId.value);
    }
    if (seasonId.present) {
      map['season_id'] = Variable<String>(seasonId.value);
    }
    if (statType.present) {
      map['stat_type'] = Variable<String>(statType.value);
    }
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<String>(teamId.value);
    }
    if (playerName.present) {
      map['player_name'] = Variable<String>(playerName.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (statValue.present) {
      map['stat_value'] = Variable<double>(statValue.value);
    }
    if (subStatValue.present) {
      map['sub_stat_value'] = Variable<double>(subStatValue.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TopPlayerStatsCompanion(')
          ..write('id: $id, ')
          ..write('competitionId: $competitionId, ')
          ..write('seasonId: $seasonId, ')
          ..write('statType: $statType, ')
          ..write('playerId: $playerId, ')
          ..write('teamId: $teamId, ')
          ..write('playerName: $playerName, ')
          ..write('rank: $rank, ')
          ..write('statValue: $statValue, ')
          ..write('subStatValue: $subStatValue, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }
}

class $StandingsRowsTable extends StandingsRows
    with TableInfo<$StandingsRowsTable, StandingsRowData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StandingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _competitionIdMeta = const VerificationMeta(
    'competitionId',
  );
  @override
  late final GeneratedColumn<String> competitionId = GeneratedColumn<String>(
    'competition_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES competitions (id)',
    ),
  );
  static const VerificationMeta _seasonIdMeta = const VerificationMeta(
    'seasonId',
  );
  @override
  late final GeneratedColumn<String> seasonId = GeneratedColumn<String>(
    'season_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<String> teamId = GeneratedColumn<String>(
    'team_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedMeta = const VerificationMeta('played');
  @override
  late final GeneratedColumn<int> played = GeneratedColumn<int>(
    'played',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wonMeta = const VerificationMeta('won');
  @override
  late final GeneratedColumn<int> won = GeneratedColumn<int>(
    'won',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _drawMeta = const VerificationMeta('draw');
  @override
  late final GeneratedColumn<int> draw = GeneratedColumn<int>(
    'draw',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lostMeta = const VerificationMeta('lost');
  @override
  late final GeneratedColumn<int> lost = GeneratedColumn<int>(
    'lost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _goalsForMeta = const VerificationMeta(
    'goalsFor',
  );
  @override
  late final GeneratedColumn<int> goalsFor = GeneratedColumn<int>(
    'goals_for',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _goalsAgainstMeta = const VerificationMeta(
    'goalsAgainst',
  );
  @override
  late final GeneratedColumn<int> goalsAgainst = GeneratedColumn<int>(
    'goals_against',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _goalDiffMeta = const VerificationMeta(
    'goalDiff',
  );
  @override
  late final GeneratedColumn<int> goalDiff = GeneratedColumn<int>(
    'goal_diff',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _formMeta = const VerificationMeta('form');
  @override
  late final GeneratedColumn<String> form = GeneratedColumn<String>(
    'form',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    competitionId,
    seasonId,
    teamId,
    position,
    played,
    won,
    draw,
    lost,
    goalsFor,
    goalsAgainst,
    goalDiff,
    points,
    form,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'standings_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<StandingsRowData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('competition_id')) {
      context.handle(
        _competitionIdMeta,
        competitionId.isAcceptableOrUnknown(
          data['competition_id']!,
          _competitionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_competitionIdMeta);
    }
    if (data.containsKey('season_id')) {
      context.handle(
        _seasonIdMeta,
        seasonId.isAcceptableOrUnknown(data['season_id']!, _seasonIdMeta),
      );
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    } else if (isInserting) {
      context.missing(_teamIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('played')) {
      context.handle(
        _playedMeta,
        played.isAcceptableOrUnknown(data['played']!, _playedMeta),
      );
    }
    if (data.containsKey('won')) {
      context.handle(
        _wonMeta,
        won.isAcceptableOrUnknown(data['won']!, _wonMeta),
      );
    }
    if (data.containsKey('draw')) {
      context.handle(
        _drawMeta,
        draw.isAcceptableOrUnknown(data['draw']!, _drawMeta),
      );
    }
    if (data.containsKey('lost')) {
      context.handle(
        _lostMeta,
        lost.isAcceptableOrUnknown(data['lost']!, _lostMeta),
      );
    }
    if (data.containsKey('goals_for')) {
      context.handle(
        _goalsForMeta,
        goalsFor.isAcceptableOrUnknown(data['goals_for']!, _goalsForMeta),
      );
    }
    if (data.containsKey('goals_against')) {
      context.handle(
        _goalsAgainstMeta,
        goalsAgainst.isAcceptableOrUnknown(
          data['goals_against']!,
          _goalsAgainstMeta,
        ),
      );
    }
    if (data.containsKey('goal_diff')) {
      context.handle(
        _goalDiffMeta,
        goalDiff.isAcceptableOrUnknown(data['goal_diff']!, _goalDiffMeta),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    if (data.containsKey('form')) {
      context.handle(
        _formMeta,
        form.isAcceptableOrUnknown(data['form']!, _formMeta),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StandingsRowData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StandingsRowData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      competitionId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}competition_id'],
          )!,
      seasonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}season_id'],
      ),
      teamId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}team_id'],
          )!,
      position:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}position'],
          )!,
      played:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}played'],
          )!,
      won:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}won'],
          )!,
      draw:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}draw'],
          )!,
      lost:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}lost'],
          )!,
      goalsFor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}goals_for'],
          )!,
      goalsAgainst:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}goals_against'],
          )!,
      goalDiff:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}goal_diff'],
          )!,
      points:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}points'],
          )!,
      form: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form'],
      ),
      updatedAtUtc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at_utc'],
          )!,
    );
  }

  @override
  $StandingsRowsTable createAlias(String alias) {
    return $StandingsRowsTable(attachedDatabase, alias);
  }
}

class StandingsRowData extends DataClass
    implements Insertable<StandingsRowData> {
  final int id;
  final String competitionId;
  final String? seasonId;
  final String teamId;
  final int position;
  final int played;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final int points;
  final String? form;
  final DateTime updatedAtUtc;
  const StandingsRowData({
    required this.id,
    required this.competitionId,
    this.seasonId,
    required this.teamId,
    required this.position,
    required this.played,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    this.form,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['competition_id'] = Variable<String>(competitionId);
    if (!nullToAbsent || seasonId != null) {
      map['season_id'] = Variable<String>(seasonId);
    }
    map['team_id'] = Variable<String>(teamId);
    map['position'] = Variable<int>(position);
    map['played'] = Variable<int>(played);
    map['won'] = Variable<int>(won);
    map['draw'] = Variable<int>(draw);
    map['lost'] = Variable<int>(lost);
    map['goals_for'] = Variable<int>(goalsFor);
    map['goals_against'] = Variable<int>(goalsAgainst);
    map['goal_diff'] = Variable<int>(goalDiff);
    map['points'] = Variable<int>(points);
    if (!nullToAbsent || form != null) {
      map['form'] = Variable<String>(form);
    }
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  StandingsRowsCompanion toCompanion(bool nullToAbsent) {
    return StandingsRowsCompanion(
      id: Value(id),
      competitionId: Value(competitionId),
      seasonId:
          seasonId == null && nullToAbsent
              ? const Value.absent()
              : Value(seasonId),
      teamId: Value(teamId),
      position: Value(position),
      played: Value(played),
      won: Value(won),
      draw: Value(draw),
      lost: Value(lost),
      goalsFor: Value(goalsFor),
      goalsAgainst: Value(goalsAgainst),
      goalDiff: Value(goalDiff),
      points: Value(points),
      form: form == null && nullToAbsent ? const Value.absent() : Value(form),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory StandingsRowData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StandingsRowData(
      id: serializer.fromJson<int>(json['id']),
      competitionId: serializer.fromJson<String>(json['competitionId']),
      seasonId: serializer.fromJson<String?>(json['seasonId']),
      teamId: serializer.fromJson<String>(json['teamId']),
      position: serializer.fromJson<int>(json['position']),
      played: serializer.fromJson<int>(json['played']),
      won: serializer.fromJson<int>(json['won']),
      draw: serializer.fromJson<int>(json['draw']),
      lost: serializer.fromJson<int>(json['lost']),
      goalsFor: serializer.fromJson<int>(json['goalsFor']),
      goalsAgainst: serializer.fromJson<int>(json['goalsAgainst']),
      goalDiff: serializer.fromJson<int>(json['goalDiff']),
      points: serializer.fromJson<int>(json['points']),
      form: serializer.fromJson<String?>(json['form']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'competitionId': serializer.toJson<String>(competitionId),
      'seasonId': serializer.toJson<String?>(seasonId),
      'teamId': serializer.toJson<String>(teamId),
      'position': serializer.toJson<int>(position),
      'played': serializer.toJson<int>(played),
      'won': serializer.toJson<int>(won),
      'draw': serializer.toJson<int>(draw),
      'lost': serializer.toJson<int>(lost),
      'goalsFor': serializer.toJson<int>(goalsFor),
      'goalsAgainst': serializer.toJson<int>(goalsAgainst),
      'goalDiff': serializer.toJson<int>(goalDiff),
      'points': serializer.toJson<int>(points),
      'form': serializer.toJson<String?>(form),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  StandingsRowData copyWith({
    int? id,
    String? competitionId,
    Value<String?> seasonId = const Value.absent(),
    String? teamId,
    int? position,
    int? played,
    int? won,
    int? draw,
    int? lost,
    int? goalsFor,
    int? goalsAgainst,
    int? goalDiff,
    int? points,
    Value<String?> form = const Value.absent(),
    DateTime? updatedAtUtc,
  }) => StandingsRowData(
    id: id ?? this.id,
    competitionId: competitionId ?? this.competitionId,
    seasonId: seasonId.present ? seasonId.value : this.seasonId,
    teamId: teamId ?? this.teamId,
    position: position ?? this.position,
    played: played ?? this.played,
    won: won ?? this.won,
    draw: draw ?? this.draw,
    lost: lost ?? this.lost,
    goalsFor: goalsFor ?? this.goalsFor,
    goalsAgainst: goalsAgainst ?? this.goalsAgainst,
    goalDiff: goalDiff ?? this.goalDiff,
    points: points ?? this.points,
    form: form.present ? form.value : this.form,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  StandingsRowData copyWithCompanion(StandingsRowsCompanion data) {
    return StandingsRowData(
      id: data.id.present ? data.id.value : this.id,
      competitionId:
          data.competitionId.present
              ? data.competitionId.value
              : this.competitionId,
      seasonId: data.seasonId.present ? data.seasonId.value : this.seasonId,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      position: data.position.present ? data.position.value : this.position,
      played: data.played.present ? data.played.value : this.played,
      won: data.won.present ? data.won.value : this.won,
      draw: data.draw.present ? data.draw.value : this.draw,
      lost: data.lost.present ? data.lost.value : this.lost,
      goalsFor: data.goalsFor.present ? data.goalsFor.value : this.goalsFor,
      goalsAgainst:
          data.goalsAgainst.present
              ? data.goalsAgainst.value
              : this.goalsAgainst,
      goalDiff: data.goalDiff.present ? data.goalDiff.value : this.goalDiff,
      points: data.points.present ? data.points.value : this.points,
      form: data.form.present ? data.form.value : this.form,
      updatedAtUtc:
          data.updatedAtUtc.present
              ? data.updatedAtUtc.value
              : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StandingsRowData(')
          ..write('id: $id, ')
          ..write('competitionId: $competitionId, ')
          ..write('seasonId: $seasonId, ')
          ..write('teamId: $teamId, ')
          ..write('position: $position, ')
          ..write('played: $played, ')
          ..write('won: $won, ')
          ..write('draw: $draw, ')
          ..write('lost: $lost, ')
          ..write('goalsFor: $goalsFor, ')
          ..write('goalsAgainst: $goalsAgainst, ')
          ..write('goalDiff: $goalDiff, ')
          ..write('points: $points, ')
          ..write('form: $form, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    competitionId,
    seasonId,
    teamId,
    position,
    played,
    won,
    draw,
    lost,
    goalsFor,
    goalsAgainst,
    goalDiff,
    points,
    form,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StandingsRowData &&
          other.id == this.id &&
          other.competitionId == this.competitionId &&
          other.seasonId == this.seasonId &&
          other.teamId == this.teamId &&
          other.position == this.position &&
          other.played == this.played &&
          other.won == this.won &&
          other.draw == this.draw &&
          other.lost == this.lost &&
          other.goalsFor == this.goalsFor &&
          other.goalsAgainst == this.goalsAgainst &&
          other.goalDiff == this.goalDiff &&
          other.points == this.points &&
          other.form == this.form &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class StandingsRowsCompanion extends UpdateCompanion<StandingsRowData> {
  final Value<int> id;
  final Value<String> competitionId;
  final Value<String?> seasonId;
  final Value<String> teamId;
  final Value<int> position;
  final Value<int> played;
  final Value<int> won;
  final Value<int> draw;
  final Value<int> lost;
  final Value<int> goalsFor;
  final Value<int> goalsAgainst;
  final Value<int> goalDiff;
  final Value<int> points;
  final Value<String?> form;
  final Value<DateTime> updatedAtUtc;
  const StandingsRowsCompanion({
    this.id = const Value.absent(),
    this.competitionId = const Value.absent(),
    this.seasonId = const Value.absent(),
    this.teamId = const Value.absent(),
    this.position = const Value.absent(),
    this.played = const Value.absent(),
    this.won = const Value.absent(),
    this.draw = const Value.absent(),
    this.lost = const Value.absent(),
    this.goalsFor = const Value.absent(),
    this.goalsAgainst = const Value.absent(),
    this.goalDiff = const Value.absent(),
    this.points = const Value.absent(),
    this.form = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
  });
  StandingsRowsCompanion.insert({
    this.id = const Value.absent(),
    required String competitionId,
    this.seasonId = const Value.absent(),
    required String teamId,
    required int position,
    this.played = const Value.absent(),
    this.won = const Value.absent(),
    this.draw = const Value.absent(),
    this.lost = const Value.absent(),
    this.goalsFor = const Value.absent(),
    this.goalsAgainst = const Value.absent(),
    this.goalDiff = const Value.absent(),
    this.points = const Value.absent(),
    this.form = const Value.absent(),
    required DateTime updatedAtUtc,
  }) : competitionId = Value(competitionId),
       teamId = Value(teamId),
       position = Value(position),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<StandingsRowData> custom({
    Expression<int>? id,
    Expression<String>? competitionId,
    Expression<String>? seasonId,
    Expression<String>? teamId,
    Expression<int>? position,
    Expression<int>? played,
    Expression<int>? won,
    Expression<int>? draw,
    Expression<int>? lost,
    Expression<int>? goalsFor,
    Expression<int>? goalsAgainst,
    Expression<int>? goalDiff,
    Expression<int>? points,
    Expression<String>? form,
    Expression<DateTime>? updatedAtUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (competitionId != null) 'competition_id': competitionId,
      if (seasonId != null) 'season_id': seasonId,
      if (teamId != null) 'team_id': teamId,
      if (position != null) 'position': position,
      if (played != null) 'played': played,
      if (won != null) 'won': won,
      if (draw != null) 'draw': draw,
      if (lost != null) 'lost': lost,
      if (goalsFor != null) 'goals_for': goalsFor,
      if (goalsAgainst != null) 'goals_against': goalsAgainst,
      if (goalDiff != null) 'goal_diff': goalDiff,
      if (points != null) 'points': points,
      if (form != null) 'form': form,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
    });
  }

  StandingsRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? competitionId,
    Value<String?>? seasonId,
    Value<String>? teamId,
    Value<int>? position,
    Value<int>? played,
    Value<int>? won,
    Value<int>? draw,
    Value<int>? lost,
    Value<int>? goalsFor,
    Value<int>? goalsAgainst,
    Value<int>? goalDiff,
    Value<int>? points,
    Value<String?>? form,
    Value<DateTime>? updatedAtUtc,
  }) {
    return StandingsRowsCompanion(
      id: id ?? this.id,
      competitionId: competitionId ?? this.competitionId,
      seasonId: seasonId ?? this.seasonId,
      teamId: teamId ?? this.teamId,
      position: position ?? this.position,
      played: played ?? this.played,
      won: won ?? this.won,
      draw: draw ?? this.draw,
      lost: lost ?? this.lost,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
      goalDiff: goalDiff ?? this.goalDiff,
      points: points ?? this.points,
      form: form ?? this.form,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (competitionId.present) {
      map['competition_id'] = Variable<String>(competitionId.value);
    }
    if (seasonId.present) {
      map['season_id'] = Variable<String>(seasonId.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<String>(teamId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (played.present) {
      map['played'] = Variable<int>(played.value);
    }
    if (won.present) {
      map['won'] = Variable<int>(won.value);
    }
    if (draw.present) {
      map['draw'] = Variable<int>(draw.value);
    }
    if (lost.present) {
      map['lost'] = Variable<int>(lost.value);
    }
    if (goalsFor.present) {
      map['goals_for'] = Variable<int>(goalsFor.value);
    }
    if (goalsAgainst.present) {
      map['goals_against'] = Variable<int>(goalsAgainst.value);
    }
    if (goalDiff.present) {
      map['goal_diff'] = Variable<int>(goalDiff.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    if (form.present) {
      map['form'] = Variable<String>(form.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StandingsRowsCompanion(')
          ..write('id: $id, ')
          ..write('competitionId: $competitionId, ')
          ..write('seasonId: $seasonId, ')
          ..write('teamId: $teamId, ')
          ..write('position: $position, ')
          ..write('played: $played, ')
          ..write('won: $won, ')
          ..write('draw: $draw, ')
          ..write('lost: $lost, ')
          ..write('goalsFor: $goalsFor, ')
          ..write('goalsAgainst: $goalsAgainst, ')
          ..write('goalDiff: $goalDiff, ')
          ..write('points: $points, ')
          ..write('form: $form, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }
}

class $AssetRefsTable extends AssetRefs
    with TableInfo<$AssetRefsTable, AssetRefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _variantMeta = const VerificationMeta(
    'variant',
  );
  @override
  late final GeneratedColumn<String> variant = GeneratedColumn<String>(
    'variant',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    variant,
    filePath,
    fileHash,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_refs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetRefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('variant')) {
      context.handle(
        _variantMeta,
        variant.isAcceptableOrUnknown(data['variant']!, _variantMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssetRefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetRefRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      entityType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}entity_type'],
          )!,
      entityId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}entity_id'],
          )!,
      variant:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}variant'],
          )!,
      filePath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}file_path'],
          )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      ),
      updatedAtUtc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at_utc'],
          )!,
    );
  }

  @override
  $AssetRefsTable createAlias(String alias) {
    return $AssetRefsTable(attachedDatabase, alias);
  }
}

class AssetRefRow extends DataClass implements Insertable<AssetRefRow> {
  final int id;
  final String entityType;
  final String entityId;
  final String variant;
  final String filePath;
  final String? fileHash;
  final DateTime updatedAtUtc;
  const AssetRefRow({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.variant,
    required this.filePath,
    this.fileHash,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['variant'] = Variable<String>(variant);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || fileHash != null) {
      map['file_hash'] = Variable<String>(fileHash);
    }
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  AssetRefsCompanion toCompanion(bool nullToAbsent) {
    return AssetRefsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      variant: Value(variant),
      filePath: Value(filePath),
      fileHash:
          fileHash == null && nullToAbsent
              ? const Value.absent()
              : Value(fileHash),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory AssetRefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetRefRow(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      variant: serializer.fromJson<String>(json['variant']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileHash: serializer.fromJson<String?>(json['fileHash']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'variant': serializer.toJson<String>(variant),
      'filePath': serializer.toJson<String>(filePath),
      'fileHash': serializer.toJson<String?>(fileHash),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  AssetRefRow copyWith({
    int? id,
    String? entityType,
    String? entityId,
    String? variant,
    String? filePath,
    Value<String?> fileHash = const Value.absent(),
    DateTime? updatedAtUtc,
  }) => AssetRefRow(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    variant: variant ?? this.variant,
    filePath: filePath ?? this.filePath,
    fileHash: fileHash.present ? fileHash.value : this.fileHash,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  AssetRefRow copyWithCompanion(AssetRefsCompanion data) {
    return AssetRefRow(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      variant: data.variant.present ? data.variant.value : this.variant,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      updatedAtUtc:
          data.updatedAtUtc.present
              ? data.updatedAtUtc.value
              : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetRefRow(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('variant: $variant, ')
          ..write('filePath: $filePath, ')
          ..write('fileHash: $fileHash, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    variant,
    filePath,
    fileHash,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetRefRow &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.variant == this.variant &&
          other.filePath == this.filePath &&
          other.fileHash == this.fileHash &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class AssetRefsCompanion extends UpdateCompanion<AssetRefRow> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> variant;
  final Value<String> filePath;
  final Value<String?> fileHash;
  final Value<DateTime> updatedAtUtc;
  const AssetRefsCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.variant = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
  });
  AssetRefsCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    this.variant = const Value.absent(),
    required String filePath,
    this.fileHash = const Value.absent(),
    required DateTime updatedAtUtc,
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       filePath = Value(filePath),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<AssetRefRow> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? variant,
    Expression<String>? filePath,
    Expression<String>? fileHash,
    Expression<DateTime>? updatedAtUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (variant != null) 'variant': variant,
      if (filePath != null) 'file_path': filePath,
      if (fileHash != null) 'file_hash': fileHash,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
    });
  }

  AssetRefsCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? variant,
    Value<String>? filePath,
    Value<String?>? fileHash,
    Value<DateTime>? updatedAtUtc,
  }) {
    return AssetRefsCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      variant: variant ?? this.variant,
      filePath: filePath ?? this.filePath,
      fileHash: fileHash ?? this.fileHash,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (variant.present) {
      map['variant'] = Variable<String>(variant.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetRefsCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('variant: $variant, ')
          ..write('filePath: $filePath, ')
          ..write('fileHash: $fileHash, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }
}

class $ImportRunsTable extends ImportRuns
    with TableInfo<$ImportRunsTable, ImportRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _triggerTypeMeta = const VerificationMeta(
    'triggerType',
  );
  @override
  late final GeneratedColumn<String> triggerType = GeneratedColumn<String>(
    'trigger_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> startedAtUtc = GeneratedColumn<DateTime>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtUtcMeta = const VerificationMeta(
    'finishedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAtUtc =
      GeneratedColumn<DateTime>(
        'finished_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    triggerType,
    startedAtUtc,
    finishedAtUtc,
    status,
    summaryJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trigger_type')) {
      context.handle(
        _triggerTypeMeta,
        triggerType.isAcceptableOrUnknown(
          data['trigger_type']!,
          _triggerTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_triggerTypeMeta);
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMeta);
    }
    if (data.containsKey('finished_at_utc')) {
      context.handle(
        _finishedAtUtcMeta,
        finishedAtUtc.isAcceptableOrUnknown(
          data['finished_at_utc']!,
          _finishedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportRunRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      triggerType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}trigger_type'],
          )!,
      startedAtUtc:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}started_at_utc'],
          )!,
      finishedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at_utc'],
      ),
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      summaryJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}summary_json'],
          )!,
    );
  }

  @override
  $ImportRunsTable createAlias(String alias) {
    return $ImportRunsTable(attachedDatabase, alias);
  }
}

class ImportRunRow extends DataClass implements Insertable<ImportRunRow> {
  final int id;
  final String triggerType;
  final DateTime startedAtUtc;
  final DateTime? finishedAtUtc;
  final String status;
  final String summaryJson;
  const ImportRunRow({
    required this.id,
    required this.triggerType,
    required this.startedAtUtc,
    this.finishedAtUtc,
    required this.status,
    required this.summaryJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trigger_type'] = Variable<String>(triggerType);
    map['started_at_utc'] = Variable<DateTime>(startedAtUtc);
    if (!nullToAbsent || finishedAtUtc != null) {
      map['finished_at_utc'] = Variable<DateTime>(finishedAtUtc);
    }
    map['status'] = Variable<String>(status);
    map['summary_json'] = Variable<String>(summaryJson);
    return map;
  }

  ImportRunsCompanion toCompanion(bool nullToAbsent) {
    return ImportRunsCompanion(
      id: Value(id),
      triggerType: Value(triggerType),
      startedAtUtc: Value(startedAtUtc),
      finishedAtUtc:
          finishedAtUtc == null && nullToAbsent
              ? const Value.absent()
              : Value(finishedAtUtc),
      status: Value(status),
      summaryJson: Value(summaryJson),
    );
  }

  factory ImportRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportRunRow(
      id: serializer.fromJson<int>(json['id']),
      triggerType: serializer.fromJson<String>(json['triggerType']),
      startedAtUtc: serializer.fromJson<DateTime>(json['startedAtUtc']),
      finishedAtUtc: serializer.fromJson<DateTime?>(json['finishedAtUtc']),
      status: serializer.fromJson<String>(json['status']),
      summaryJson: serializer.fromJson<String>(json['summaryJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'triggerType': serializer.toJson<String>(triggerType),
      'startedAtUtc': serializer.toJson<DateTime>(startedAtUtc),
      'finishedAtUtc': serializer.toJson<DateTime?>(finishedAtUtc),
      'status': serializer.toJson<String>(status),
      'summaryJson': serializer.toJson<String>(summaryJson),
    };
  }

  ImportRunRow copyWith({
    int? id,
    String? triggerType,
    DateTime? startedAtUtc,
    Value<DateTime?> finishedAtUtc = const Value.absent(),
    String? status,
    String? summaryJson,
  }) => ImportRunRow(
    id: id ?? this.id,
    triggerType: triggerType ?? this.triggerType,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    finishedAtUtc:
        finishedAtUtc.present ? finishedAtUtc.value : this.finishedAtUtc,
    status: status ?? this.status,
    summaryJson: summaryJson ?? this.summaryJson,
  );
  ImportRunRow copyWithCompanion(ImportRunsCompanion data) {
    return ImportRunRow(
      id: data.id.present ? data.id.value : this.id,
      triggerType:
          data.triggerType.present ? data.triggerType.value : this.triggerType,
      startedAtUtc:
          data.startedAtUtc.present
              ? data.startedAtUtc.value
              : this.startedAtUtc,
      finishedAtUtc:
          data.finishedAtUtc.present
              ? data.finishedAtUtc.value
              : this.finishedAtUtc,
      status: data.status.present ? data.status.value : this.status,
      summaryJson:
          data.summaryJson.present ? data.summaryJson.value : this.summaryJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportRunRow(')
          ..write('id: $id, ')
          ..write('triggerType: $triggerType, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('finishedAtUtc: $finishedAtUtc, ')
          ..write('status: $status, ')
          ..write('summaryJson: $summaryJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    triggerType,
    startedAtUtc,
    finishedAtUtc,
    status,
    summaryJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportRunRow &&
          other.id == this.id &&
          other.triggerType == this.triggerType &&
          other.startedAtUtc == this.startedAtUtc &&
          other.finishedAtUtc == this.finishedAtUtc &&
          other.status == this.status &&
          other.summaryJson == this.summaryJson);
}

class ImportRunsCompanion extends UpdateCompanion<ImportRunRow> {
  final Value<int> id;
  final Value<String> triggerType;
  final Value<DateTime> startedAtUtc;
  final Value<DateTime?> finishedAtUtc;
  final Value<String> status;
  final Value<String> summaryJson;
  const ImportRunsCompanion({
    this.id = const Value.absent(),
    this.triggerType = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.finishedAtUtc = const Value.absent(),
    this.status = const Value.absent(),
    this.summaryJson = const Value.absent(),
  });
  ImportRunsCompanion.insert({
    this.id = const Value.absent(),
    required String triggerType,
    required DateTime startedAtUtc,
    this.finishedAtUtc = const Value.absent(),
    required String status,
    this.summaryJson = const Value.absent(),
  }) : triggerType = Value(triggerType),
       startedAtUtc = Value(startedAtUtc),
       status = Value(status);
  static Insertable<ImportRunRow> custom({
    Expression<int>? id,
    Expression<String>? triggerType,
    Expression<DateTime>? startedAtUtc,
    Expression<DateTime>? finishedAtUtc,
    Expression<String>? status,
    Expression<String>? summaryJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (triggerType != null) 'trigger_type': triggerType,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (finishedAtUtc != null) 'finished_at_utc': finishedAtUtc,
      if (status != null) 'status': status,
      if (summaryJson != null) 'summary_json': summaryJson,
    });
  }

  ImportRunsCompanion copyWith({
    Value<int>? id,
    Value<String>? triggerType,
    Value<DateTime>? startedAtUtc,
    Value<DateTime?>? finishedAtUtc,
    Value<String>? status,
    Value<String>? summaryJson,
  }) {
    return ImportRunsCompanion(
      id: id ?? this.id,
      triggerType: triggerType ?? this.triggerType,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      finishedAtUtc: finishedAtUtc ?? this.finishedAtUtc,
      status: status ?? this.status,
      summaryJson: summaryJson ?? this.summaryJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (triggerType.present) {
      map['trigger_type'] = Variable<String>(triggerType.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<DateTime>(startedAtUtc.value);
    }
    if (finishedAtUtc.present) {
      map['finished_at_utc'] = Variable<DateTime>(finishedAtUtc.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportRunsCompanion(')
          ..write('id: $id, ')
          ..write('triggerType: $triggerType, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('finishedAtUtc: $finishedAtUtc, ')
          ..write('status: $status, ')
          ..write('summaryJson: $summaryJson')
          ..write(')'))
        .toString();
  }
}

class $ImportFilesTable extends ImportFiles
    with TableInfo<$ImportFilesTable, ImportFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<int> runId = GeneratedColumn<int>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES import_runs (id)',
    ),
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    fileName,
    relativePath,
    checksum,
    status,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportFileRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      runId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}run_id'],
          )!,
      fileName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}file_name'],
          )!,
      relativePath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}relative_path'],
          )!,
      checksum:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}checksum'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $ImportFilesTable createAlias(String alias) {
    return $ImportFilesTable(attachedDatabase, alias);
  }
}

class ImportFileRow extends DataClass implements Insertable<ImportFileRow> {
  final int id;
  final int runId;
  final String fileName;
  final String relativePath;
  final String checksum;
  final String status;
  final String? errorMessage;
  const ImportFileRow({
    required this.id,
    required this.runId,
    required this.fileName,
    required this.relativePath,
    required this.checksum,
    required this.status,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['run_id'] = Variable<int>(runId);
    map['file_name'] = Variable<String>(fileName);
    map['relative_path'] = Variable<String>(relativePath);
    map['checksum'] = Variable<String>(checksum);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  ImportFilesCompanion toCompanion(bool nullToAbsent) {
    return ImportFilesCompanion(
      id: Value(id),
      runId: Value(runId),
      fileName: Value(fileName),
      relativePath: Value(relativePath),
      checksum: Value(checksum),
      status: Value(status),
      errorMessage:
          errorMessage == null && nullToAbsent
              ? const Value.absent()
              : Value(errorMessage),
    );
  }

  factory ImportFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportFileRow(
      id: serializer.fromJson<int>(json['id']),
      runId: serializer.fromJson<int>(json['runId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      checksum: serializer.fromJson<String>(json['checksum']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'runId': serializer.toJson<int>(runId),
      'fileName': serializer.toJson<String>(fileName),
      'relativePath': serializer.toJson<String>(relativePath),
      'checksum': serializer.toJson<String>(checksum),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  ImportFileRow copyWith({
    int? id,
    int? runId,
    String? fileName,
    String? relativePath,
    String? checksum,
    String? status,
    Value<String?> errorMessage = const Value.absent(),
  }) => ImportFileRow(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    fileName: fileName ?? this.fileName,
    relativePath: relativePath ?? this.relativePath,
    checksum: checksum ?? this.checksum,
    status: status ?? this.status,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  ImportFileRow copyWithCompanion(ImportFilesCompanion data) {
    return ImportFileRow(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      relativePath:
          data.relativePath.present
              ? data.relativePath.value
              : this.relativePath,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      status: data.status.present ? data.status.value : this.status,
      errorMessage:
          data.errorMessage.present
              ? data.errorMessage.value
              : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportFileRow(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('fileName: $fileName, ')
          ..write('relativePath: $relativePath, ')
          ..write('checksum: $checksum, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    fileName,
    relativePath,
    checksum,
    status,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportFileRow &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.fileName == this.fileName &&
          other.relativePath == this.relativePath &&
          other.checksum == this.checksum &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage);
}

class ImportFilesCompanion extends UpdateCompanion<ImportFileRow> {
  final Value<int> id;
  final Value<int> runId;
  final Value<String> fileName;
  final Value<String> relativePath;
  final Value<String> checksum;
  final Value<String> status;
  final Value<String?> errorMessage;
  const ImportFilesCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.checksum = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
  });
  ImportFilesCompanion.insert({
    this.id = const Value.absent(),
    required int runId,
    required String fileName,
    required String relativePath,
    required String checksum,
    required String status,
    this.errorMessage = const Value.absent(),
  }) : runId = Value(runId),
       fileName = Value(fileName),
       relativePath = Value(relativePath),
       checksum = Value(checksum),
       status = Value(status);
  static Insertable<ImportFileRow> custom({
    Expression<int>? id,
    Expression<int>? runId,
    Expression<String>? fileName,
    Expression<String>? relativePath,
    Expression<String>? checksum,
    Expression<String>? status,
    Expression<String>? errorMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (fileName != null) 'file_name': fileName,
      if (relativePath != null) 'relative_path': relativePath,
      if (checksum != null) 'checksum': checksum,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
    });
  }

  ImportFilesCompanion copyWith({
    Value<int>? id,
    Value<int>? runId,
    Value<String>? fileName,
    Value<String>? relativePath,
    Value<String>? checksum,
    Value<String>? status,
    Value<String?>? errorMessage,
  }) {
    return ImportFilesCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      fileName: fileName ?? this.fileName,
      relativePath: relativePath ?? this.relativePath,
      checksum: checksum ?? this.checksum,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<int>(runId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportFilesCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('fileName: $fileName, ')
          ..write('relativePath: $relativePath, ')
          ..write('checksum: $checksum, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CompetitionsTable competitions = $CompetitionsTable(this);
  late final $TeamsTable teams = $TeamsTable(this);
  late final $PlayersTable players = $PlayersTable(this);
  late final $MatchesTable matches = $MatchesTable(this);
  late final $MatchEventsTable matchEvents = $MatchEventsTable(this);
  late final $MatchTeamStatsTable matchTeamStats = $MatchTeamStatsTable(this);
  late final $TopPlayerStatsTable topPlayerStats = $TopPlayerStatsTable(this);
  late final $StandingsRowsTable standingsRows = $StandingsRowsTable(this);
  late final $AssetRefsTable assetRefs = $AssetRefsTable(this);
  late final $ImportRunsTable importRuns = $ImportRunsTable(this);
  late final $ImportFilesTable importFiles = $ImportFilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    competitions,
    teams,
    players,
    matches,
    matchEvents,
    matchTeamStats,
    topPlayerStats,
    standingsRows,
    assetRefs,
    importRuns,
    importFiles,
  ];
}

typedef $$CompetitionsTableCreateCompanionBuilder =
    CompetitionsCompanion Function({
      required String id,
      required String name,
      Value<String?> country,
      Value<String?> logoAssetKey,
      Value<int> displayOrder,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$CompetitionsTableUpdateCompanionBuilder =
    CompetitionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> country,
      Value<String?> logoAssetKey,
      Value<int> displayOrder,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

final class $$CompetitionsTableReferences
    extends BaseReferences<_$AppDatabase, $CompetitionsTable, CompetitionRow> {
  $$CompetitionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TeamsTable, List<TeamRow>> _teamsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.teams,
    aliasName: $_aliasNameGenerator(db.competitions.id, db.teams.competitionId),
  );

  $$TeamsTableProcessedTableManager get teamsRefs {
    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.competitionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_teamsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchesTable, List<MatchRow>> _matchesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.matches,
    aliasName: $_aliasNameGenerator(
      db.competitions.id,
      db.matches.competitionId,
    ),
  );

  $$MatchesTableProcessedTableManager get matchesRefs {
    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.competitionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TopPlayerStatsTable, List<TopPlayerStatRow>>
  _topPlayerStatsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.topPlayerStats,
    aliasName: $_aliasNameGenerator(
      db.competitions.id,
      db.topPlayerStats.competitionId,
    ),
  );

  $$TopPlayerStatsTableProcessedTableManager get topPlayerStatsRefs {
    final manager = $$TopPlayerStatsTableTableManager(
      $_db,
      $_db.topPlayerStats,
    ).filter((f) => f.competitionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_topPlayerStatsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StandingsRowsTable, List<StandingsRowData>>
  _standingsRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.standingsRows,
    aliasName: $_aliasNameGenerator(
      db.competitions.id,
      db.standingsRows.competitionId,
    ),
  );

  $$StandingsRowsTableProcessedTableManager get standingsRowsRefs {
    final manager = $$StandingsRowsTableTableManager(
      $_db,
      $_db.standingsRows,
    ).filter((f) => f.competitionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_standingsRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CompetitionsTableFilterComposer
    extends Composer<_$AppDatabase, $CompetitionsTable> {
  $$CompetitionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoAssetKey => $composableBuilder(
    column: $table.logoAssetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> teamsRefs(
    Expression<bool> Function($$TeamsTableFilterComposer f) f,
  ) {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.competitionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchesRefs(
    Expression<bool> Function($$MatchesTableFilterComposer f) f,
  ) {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.competitionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> topPlayerStatsRefs(
    Expression<bool> Function($$TopPlayerStatsTableFilterComposer f) f,
  ) {
    final $$TopPlayerStatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.topPlayerStats,
      getReferencedColumn: (t) => t.competitionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopPlayerStatsTableFilterComposer(
            $db: $db,
            $table: $db.topPlayerStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> standingsRowsRefs(
    Expression<bool> Function($$StandingsRowsTableFilterComposer f) f,
  ) {
    final $$StandingsRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.standingsRows,
      getReferencedColumn: (t) => t.competitionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StandingsRowsTableFilterComposer(
            $db: $db,
            $table: $db.standingsRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CompetitionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompetitionsTable> {
  $$CompetitionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoAssetKey => $composableBuilder(
    column: $table.logoAssetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompetitionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompetitionsTable> {
  $$CompetitionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get logoAssetKey => $composableBuilder(
    column: $table.logoAssetKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  Expression<T> teamsRefs<T extends Object>(
    Expression<T> Function($$TeamsTableAnnotationComposer a) f,
  ) {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.competitionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchesRefs<T extends Object>(
    Expression<T> Function($$MatchesTableAnnotationComposer a) f,
  ) {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.competitionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> topPlayerStatsRefs<T extends Object>(
    Expression<T> Function($$TopPlayerStatsTableAnnotationComposer a) f,
  ) {
    final $$TopPlayerStatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.topPlayerStats,
      getReferencedColumn: (t) => t.competitionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopPlayerStatsTableAnnotationComposer(
            $db: $db,
            $table: $db.topPlayerStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> standingsRowsRefs<T extends Object>(
    Expression<T> Function($$StandingsRowsTableAnnotationComposer a) f,
  ) {
    final $$StandingsRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.standingsRows,
      getReferencedColumn: (t) => t.competitionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StandingsRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.standingsRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CompetitionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompetitionsTable,
          CompetitionRow,
          $$CompetitionsTableFilterComposer,
          $$CompetitionsTableOrderingComposer,
          $$CompetitionsTableAnnotationComposer,
          $$CompetitionsTableCreateCompanionBuilder,
          $$CompetitionsTableUpdateCompanionBuilder,
          (CompetitionRow, $$CompetitionsTableReferences),
          CompetitionRow,
          PrefetchHooks Function({
            bool teamsRefs,
            bool matchesRefs,
            bool topPlayerStatsRefs,
            bool standingsRowsRefs,
          })
        > {
  $$CompetitionsTableTableManager(_$AppDatabase db, $CompetitionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CompetitionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CompetitionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$CompetitionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> logoAssetKey = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompetitionsCompanion(
                id: id,
                name: name,
                country: country,
                logoAssetKey: logoAssetKey,
                displayOrder: displayOrder,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> country = const Value.absent(),
                Value<String?> logoAssetKey = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => CompetitionsCompanion.insert(
                id: id,
                name: name,
                country: country,
                logoAssetKey: logoAssetKey,
                displayOrder: displayOrder,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$CompetitionsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            teamsRefs = false,
            matchesRefs = false,
            topPlayerStatsRefs = false,
            standingsRowsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (teamsRefs) db.teams,
                if (matchesRefs) db.matches,
                if (topPlayerStatsRefs) db.topPlayerStats,
                if (standingsRowsRefs) db.standingsRows,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (teamsRefs)
                    await $_getPrefetchedData<
                      CompetitionRow,
                      $CompetitionsTable,
                      TeamRow
                    >(
                      currentTable: table,
                      referencedTable: $$CompetitionsTableReferences
                          ._teamsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$CompetitionsTableReferences(
                                db,
                                table,
                                p0,
                              ).teamsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.competitionId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (matchesRefs)
                    await $_getPrefetchedData<
                      CompetitionRow,
                      $CompetitionsTable,
                      MatchRow
                    >(
                      currentTable: table,
                      referencedTable: $$CompetitionsTableReferences
                          ._matchesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$CompetitionsTableReferences(
                                db,
                                table,
                                p0,
                              ).matchesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.competitionId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (topPlayerStatsRefs)
                    await $_getPrefetchedData<
                      CompetitionRow,
                      $CompetitionsTable,
                      TopPlayerStatRow
                    >(
                      currentTable: table,
                      referencedTable: $$CompetitionsTableReferences
                          ._topPlayerStatsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$CompetitionsTableReferences(
                                db,
                                table,
                                p0,
                              ).topPlayerStatsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.competitionId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (standingsRowsRefs)
                    await $_getPrefetchedData<
                      CompetitionRow,
                      $CompetitionsTable,
                      StandingsRowData
                    >(
                      currentTable: table,
                      referencedTable: $$CompetitionsTableReferences
                          ._standingsRowsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$CompetitionsTableReferences(
                                db,
                                table,
                                p0,
                              ).standingsRowsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.competitionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CompetitionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompetitionsTable,
      CompetitionRow,
      $$CompetitionsTableFilterComposer,
      $$CompetitionsTableOrderingComposer,
      $$CompetitionsTableAnnotationComposer,
      $$CompetitionsTableCreateCompanionBuilder,
      $$CompetitionsTableUpdateCompanionBuilder,
      (CompetitionRow, $$CompetitionsTableReferences),
      CompetitionRow,
      PrefetchHooks Function({
        bool teamsRefs,
        bool matchesRefs,
        bool topPlayerStatsRefs,
        bool standingsRowsRefs,
      })
    >;
typedef $$TeamsTableCreateCompanionBuilder =
    TeamsCompanion Function({
      required String id,
      required String name,
      Value<String?> shortName,
      Value<String?> competitionId,
      Value<String?> badgeAssetKey,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$TeamsTableUpdateCompanionBuilder =
    TeamsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> shortName,
      Value<String?> competitionId,
      Value<String?> badgeAssetKey,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

final class $$TeamsTableReferences
    extends BaseReferences<_$AppDatabase, $TeamsTable, TeamRow> {
  $$TeamsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompetitionsTable _competitionIdTable(_$AppDatabase db) =>
      db.competitions.createAlias(
        $_aliasNameGenerator(db.teams.competitionId, db.competitions.id),
      );

  $$CompetitionsTableProcessedTableManager? get competitionId {
    final $_column = $_itemColumn<String>('competition_id');
    if ($_column == null) return null;
    final manager = $$CompetitionsTableTableManager(
      $_db,
      $_db.competitions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_competitionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PlayersTable, List<PlayerRow>> _playersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.players,
    aliasName: $_aliasNameGenerator(db.teams.id, db.players.teamId),
  );

  $$PlayersTableProcessedTableManager get playersRefs {
    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.teamId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchEventsTable, List<MatchEventRow>>
  _matchEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchEvents,
    aliasName: $_aliasNameGenerator(db.teams.id, db.matchEvents.teamId),
  );

  $$MatchEventsTableProcessedTableManager get matchEventsRefs {
    final manager = $$MatchEventsTableTableManager(
      $_db,
      $_db.matchEvents,
    ).filter((f) => f.teamId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchTeamStatsTable, List<MatchTeamStatRow>>
  _matchTeamStatsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchTeamStats,
    aliasName: $_aliasNameGenerator(db.teams.id, db.matchTeamStats.teamId),
  );

  $$MatchTeamStatsTableProcessedTableManager get matchTeamStatsRefs {
    final manager = $$MatchTeamStatsTableTableManager(
      $_db,
      $_db.matchTeamStats,
    ).filter((f) => f.teamId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchTeamStatsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TopPlayerStatsTable, List<TopPlayerStatRow>>
  _topPlayerStatsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.topPlayerStats,
    aliasName: $_aliasNameGenerator(db.teams.id, db.topPlayerStats.teamId),
  );

  $$TopPlayerStatsTableProcessedTableManager get topPlayerStatsRefs {
    final manager = $$TopPlayerStatsTableTableManager(
      $_db,
      $_db.topPlayerStats,
    ).filter((f) => f.teamId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_topPlayerStatsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StandingsRowsTable, List<StandingsRowData>>
  _standingsRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.standingsRows,
    aliasName: $_aliasNameGenerator(db.teams.id, db.standingsRows.teamId),
  );

  $$StandingsRowsTableProcessedTableManager get standingsRowsRefs {
    final manager = $$StandingsRowsTableTableManager(
      $_db,
      $_db.standingsRows,
    ).filter((f) => f.teamId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_standingsRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TeamsTableFilterComposer extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shortName => $composableBuilder(
    column: $table.shortName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get badgeAssetKey => $composableBuilder(
    column: $table.badgeAssetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$CompetitionsTableFilterComposer get competitionId {
    final $$CompetitionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableFilterComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> playersRefs(
    Expression<bool> Function($$PlayersTableFilterComposer f) f,
  ) {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchEventsRefs(
    Expression<bool> Function($$MatchEventsTableFilterComposer f) f,
  ) {
    final $$MatchEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableFilterComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchTeamStatsRefs(
    Expression<bool> Function($$MatchTeamStatsTableFilterComposer f) f,
  ) {
    final $$MatchTeamStatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchTeamStats,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchTeamStatsTableFilterComposer(
            $db: $db,
            $table: $db.matchTeamStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> topPlayerStatsRefs(
    Expression<bool> Function($$TopPlayerStatsTableFilterComposer f) f,
  ) {
    final $$TopPlayerStatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.topPlayerStats,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopPlayerStatsTableFilterComposer(
            $db: $db,
            $table: $db.topPlayerStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> standingsRowsRefs(
    Expression<bool> Function($$StandingsRowsTableFilterComposer f) f,
  ) {
    final $$StandingsRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.standingsRows,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StandingsRowsTableFilterComposer(
            $db: $db,
            $table: $db.standingsRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamsTableOrderingComposer
    extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shortName => $composableBuilder(
    column: $table.shortName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get badgeAssetKey => $composableBuilder(
    column: $table.badgeAssetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompetitionsTableOrderingComposer get competitionId {
    final $$CompetitionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableOrderingComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TeamsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get shortName =>
      $composableBuilder(column: $table.shortName, builder: (column) => column);

  GeneratedColumn<String> get badgeAssetKey => $composableBuilder(
    column: $table.badgeAssetKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  $$CompetitionsTableAnnotationComposer get competitionId {
    final $$CompetitionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableAnnotationComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> playersRefs<T extends Object>(
    Expression<T> Function($$PlayersTableAnnotationComposer a) f,
  ) {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchEventsRefs<T extends Object>(
    Expression<T> Function($$MatchEventsTableAnnotationComposer a) f,
  ) {
    final $$MatchEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchTeamStatsRefs<T extends Object>(
    Expression<T> Function($$MatchTeamStatsTableAnnotationComposer a) f,
  ) {
    final $$MatchTeamStatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchTeamStats,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchTeamStatsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchTeamStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> topPlayerStatsRefs<T extends Object>(
    Expression<T> Function($$TopPlayerStatsTableAnnotationComposer a) f,
  ) {
    final $$TopPlayerStatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.topPlayerStats,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopPlayerStatsTableAnnotationComposer(
            $db: $db,
            $table: $db.topPlayerStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> standingsRowsRefs<T extends Object>(
    Expression<T> Function($$StandingsRowsTableAnnotationComposer a) f,
  ) {
    final $$StandingsRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.standingsRows,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StandingsRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.standingsRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TeamsTable,
          TeamRow,
          $$TeamsTableFilterComposer,
          $$TeamsTableOrderingComposer,
          $$TeamsTableAnnotationComposer,
          $$TeamsTableCreateCompanionBuilder,
          $$TeamsTableUpdateCompanionBuilder,
          (TeamRow, $$TeamsTableReferences),
          TeamRow,
          PrefetchHooks Function({
            bool competitionId,
            bool playersRefs,
            bool matchEventsRefs,
            bool matchTeamStatsRefs,
            bool topPlayerStatsRefs,
            bool standingsRowsRefs,
          })
        > {
  $$TeamsTableTableManager(_$AppDatabase db, $TeamsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TeamsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$TeamsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$TeamsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> shortName = const Value.absent(),
                Value<String?> competitionId = const Value.absent(),
                Value<String?> badgeAssetKey = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TeamsCompanion(
                id: id,
                name: name,
                shortName: shortName,
                competitionId: competitionId,
                badgeAssetKey: badgeAssetKey,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> shortName = const Value.absent(),
                Value<String?> competitionId = const Value.absent(),
                Value<String?> badgeAssetKey = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => TeamsCompanion.insert(
                id: id,
                name: name,
                shortName: shortName,
                competitionId: competitionId,
                badgeAssetKey: badgeAssetKey,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$TeamsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            competitionId = false,
            playersRefs = false,
            matchEventsRefs = false,
            matchTeamStatsRefs = false,
            topPlayerStatsRefs = false,
            standingsRowsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playersRefs) db.players,
                if (matchEventsRefs) db.matchEvents,
                if (matchTeamStatsRefs) db.matchTeamStats,
                if (topPlayerStatsRefs) db.topPlayerStats,
                if (standingsRowsRefs) db.standingsRows,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (competitionId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.competitionId,
                            referencedTable: $$TeamsTableReferences
                                ._competitionIdTable(db),
                            referencedColumn:
                                $$TeamsTableReferences
                                    ._competitionIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playersRefs)
                    await $_getPrefetchedData<TeamRow, $TeamsTable, PlayerRow>(
                      currentTable: table,
                      referencedTable: $$TeamsTableReferences._playersRefsTable(
                        db,
                      ),
                      managerFromTypedResult:
                          (p0) =>
                              $$TeamsTableReferences(db, table, p0).playersRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.teamId == item.id),
                      typedResults: items,
                    ),
                  if (matchEventsRefs)
                    await $_getPrefetchedData<
                      TeamRow,
                      $TeamsTable,
                      MatchEventRow
                    >(
                      currentTable: table,
                      referencedTable: $$TeamsTableReferences
                          ._matchEventsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$TeamsTableReferences(
                                db,
                                table,
                                p0,
                              ).matchEventsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.teamId == item.id),
                      typedResults: items,
                    ),
                  if (matchTeamStatsRefs)
                    await $_getPrefetchedData<
                      TeamRow,
                      $TeamsTable,
                      MatchTeamStatRow
                    >(
                      currentTable: table,
                      referencedTable: $$TeamsTableReferences
                          ._matchTeamStatsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$TeamsTableReferences(
                                db,
                                table,
                                p0,
                              ).matchTeamStatsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.teamId == item.id),
                      typedResults: items,
                    ),
                  if (topPlayerStatsRefs)
                    await $_getPrefetchedData<
                      TeamRow,
                      $TeamsTable,
                      TopPlayerStatRow
                    >(
                      currentTable: table,
                      referencedTable: $$TeamsTableReferences
                          ._topPlayerStatsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$TeamsTableReferences(
                                db,
                                table,
                                p0,
                              ).topPlayerStatsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.teamId == item.id),
                      typedResults: items,
                    ),
                  if (standingsRowsRefs)
                    await $_getPrefetchedData<
                      TeamRow,
                      $TeamsTable,
                      StandingsRowData
                    >(
                      currentTable: table,
                      referencedTable: $$TeamsTableReferences
                          ._standingsRowsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$TeamsTableReferences(
                                db,
                                table,
                                p0,
                              ).standingsRowsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.teamId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TeamsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TeamsTable,
      TeamRow,
      $$TeamsTableFilterComposer,
      $$TeamsTableOrderingComposer,
      $$TeamsTableAnnotationComposer,
      $$TeamsTableCreateCompanionBuilder,
      $$TeamsTableUpdateCompanionBuilder,
      (TeamRow, $$TeamsTableReferences),
      TeamRow,
      PrefetchHooks Function({
        bool competitionId,
        bool playersRefs,
        bool matchEventsRefs,
        bool matchTeamStatsRefs,
        bool topPlayerStatsRefs,
        bool standingsRowsRefs,
      })
    >;
typedef $$PlayersTableCreateCompanionBuilder =
    PlayersCompanion Function({
      required String id,
      Value<String?> teamId,
      required String name,
      Value<String?> position,
      Value<int?> jerseyNumber,
      Value<String?> photoAssetKey,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$PlayersTableUpdateCompanionBuilder =
    PlayersCompanion Function({
      Value<String> id,
      Value<String?> teamId,
      Value<String> name,
      Value<String?> position,
      Value<int?> jerseyNumber,
      Value<String?> photoAssetKey,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

final class $$PlayersTableReferences
    extends BaseReferences<_$AppDatabase, $PlayersTable, PlayerRow> {
  $$PlayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TeamsTable _teamIdTable(_$AppDatabase db) => db.teams.createAlias(
    $_aliasNameGenerator(db.players.teamId, db.teams.id),
  );

  $$TeamsTableProcessedTableManager? get teamId {
    final $_column = $_itemColumn<String>('team_id');
    if ($_column == null) return null;
    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_teamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MatchEventsTable, List<MatchEventRow>>
  _matchEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchEvents,
    aliasName: $_aliasNameGenerator(db.players.id, db.matchEvents.playerId),
  );

  $$MatchEventsTableProcessedTableManager get matchEventsRefs {
    final manager = $$MatchEventsTableTableManager(
      $_db,
      $_db.matchEvents,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TopPlayerStatsTable, List<TopPlayerStatRow>>
  _topPlayerStatsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.topPlayerStats,
    aliasName: $_aliasNameGenerator(db.players.id, db.topPlayerStats.playerId),
  );

  $$TopPlayerStatsTableProcessedTableManager get topPlayerStatsRefs {
    final manager = $$TopPlayerStatsTableTableManager(
      $_db,
      $_db.topPlayerStats,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_topPlayerStatsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlayersTableFilterComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get jerseyNumber => $composableBuilder(
    column: $table.jerseyNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoAssetKey => $composableBuilder(
    column: $table.photoAssetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$TeamsTableFilterComposer get teamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> matchEventsRefs(
    Expression<bool> Function($$MatchEventsTableFilterComposer f) f,
  ) {
    final $$MatchEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableFilterComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> topPlayerStatsRefs(
    Expression<bool> Function($$TopPlayerStatsTableFilterComposer f) f,
  ) {
    final $$TopPlayerStatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.topPlayerStats,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopPlayerStatsTableFilterComposer(
            $db: $db,
            $table: $db.topPlayerStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get jerseyNumber => $composableBuilder(
    column: $table.jerseyNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoAssetKey => $composableBuilder(
    column: $table.photoAssetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$TeamsTableOrderingComposer get teamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get jerseyNumber => $composableBuilder(
    column: $table.jerseyNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoAssetKey => $composableBuilder(
    column: $table.photoAssetKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  $$TeamsTableAnnotationComposer get teamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> matchEventsRefs<T extends Object>(
    Expression<T> Function($$MatchEventsTableAnnotationComposer a) f,
  ) {
    final $$MatchEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> topPlayerStatsRefs<T extends Object>(
    Expression<T> Function($$TopPlayerStatsTableAnnotationComposer a) f,
  ) {
    final $$TopPlayerStatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.topPlayerStats,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopPlayerStatsTableAnnotationComposer(
            $db: $db,
            $table: $db.topPlayerStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayersTable,
          PlayerRow,
          $$PlayersTableFilterComposer,
          $$PlayersTableOrderingComposer,
          $$PlayersTableAnnotationComposer,
          $$PlayersTableCreateCompanionBuilder,
          $$PlayersTableUpdateCompanionBuilder,
          (PlayerRow, $$PlayersTableReferences),
          PlayerRow,
          PrefetchHooks Function({
            bool teamId,
            bool matchEventsRefs,
            bool topPlayerStatsRefs,
          })
        > {
  $$PlayersTableTableManager(_$AppDatabase db, $PlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$PlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$PlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$PlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> teamId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> position = const Value.absent(),
                Value<int?> jerseyNumber = const Value.absent(),
                Value<String?> photoAssetKey = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayersCompanion(
                id: id,
                teamId: teamId,
                name: name,
                position: position,
                jerseyNumber: jerseyNumber,
                photoAssetKey: photoAssetKey,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> teamId = const Value.absent(),
                required String name,
                Value<String?> position = const Value.absent(),
                Value<int?> jerseyNumber = const Value.absent(),
                Value<String?> photoAssetKey = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => PlayersCompanion.insert(
                id: id,
                teamId: teamId,
                name: name,
                position: position,
                jerseyNumber: jerseyNumber,
                photoAssetKey: photoAssetKey,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$PlayersTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            teamId = false,
            matchEventsRefs = false,
            topPlayerStatsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (matchEventsRefs) db.matchEvents,
                if (topPlayerStatsRefs) db.topPlayerStats,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (teamId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.teamId,
                            referencedTable: $$PlayersTableReferences
                                ._teamIdTable(db),
                            referencedColumn:
                                $$PlayersTableReferences._teamIdTable(db).id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (matchEventsRefs)
                    await $_getPrefetchedData<
                      PlayerRow,
                      $PlayersTable,
                      MatchEventRow
                    >(
                      currentTable: table,
                      referencedTable: $$PlayersTableReferences
                          ._matchEventsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).matchEventsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.playerId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (topPlayerStatsRefs)
                    await $_getPrefetchedData<
                      PlayerRow,
                      $PlayersTable,
                      TopPlayerStatRow
                    >(
                      currentTable: table,
                      referencedTable: $$PlayersTableReferences
                          ._topPlayerStatsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).topPlayerStatsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.playerId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayersTable,
      PlayerRow,
      $$PlayersTableFilterComposer,
      $$PlayersTableOrderingComposer,
      $$PlayersTableAnnotationComposer,
      $$PlayersTableCreateCompanionBuilder,
      $$PlayersTableUpdateCompanionBuilder,
      (PlayerRow, $$PlayersTableReferences),
      PlayerRow,
      PrefetchHooks Function({
        bool teamId,
        bool matchEventsRefs,
        bool topPlayerStatsRefs,
      })
    >;
typedef $$MatchesTableCreateCompanionBuilder =
    MatchesCompanion Function({
      required String id,
      required String competitionId,
      Value<String?> seasonId,
      required String homeTeamId,
      required String awayTeamId,
      required DateTime kickoffUtc,
      Value<String> status,
      Value<int> homeScore,
      Value<int> awayScore,
      Value<String?> roundLabel,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$MatchesTableUpdateCompanionBuilder =
    MatchesCompanion Function({
      Value<String> id,
      Value<String> competitionId,
      Value<String?> seasonId,
      Value<String> homeTeamId,
      Value<String> awayTeamId,
      Value<DateTime> kickoffUtc,
      Value<String> status,
      Value<int> homeScore,
      Value<int> awayScore,
      Value<String?> roundLabel,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

final class $$MatchesTableReferences
    extends BaseReferences<_$AppDatabase, $MatchesTable, MatchRow> {
  $$MatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompetitionsTable _competitionIdTable(_$AppDatabase db) =>
      db.competitions.createAlias(
        $_aliasNameGenerator(db.matches.competitionId, db.competitions.id),
      );

  $$CompetitionsTableProcessedTableManager get competitionId {
    final $_column = $_itemColumn<String>('competition_id')!;

    final manager = $$CompetitionsTableTableManager(
      $_db,
      $_db.competitions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_competitionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TeamsTable _homeTeamIdTable(_$AppDatabase db) => db.teams.createAlias(
    $_aliasNameGenerator(db.matches.homeTeamId, db.teams.id),
  );

  $$TeamsTableProcessedTableManager get homeTeamId {
    final $_column = $_itemColumn<String>('home_team_id')!;

    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_homeTeamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TeamsTable _awayTeamIdTable(_$AppDatabase db) => db.teams.createAlias(
    $_aliasNameGenerator(db.matches.awayTeamId, db.teams.id),
  );

  $$TeamsTableProcessedTableManager get awayTeamId {
    final $_column = $_itemColumn<String>('away_team_id')!;

    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_awayTeamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MatchEventsTable, List<MatchEventRow>>
  _matchEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchEvents,
    aliasName: $_aliasNameGenerator(db.matches.id, db.matchEvents.matchId),
  );

  $$MatchEventsTableProcessedTableManager get matchEventsRefs {
    final manager = $$MatchEventsTableTableManager(
      $_db,
      $_db.matchEvents,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MatchTeamStatsTable, List<MatchTeamStatRow>>
  _matchTeamStatsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchTeamStats,
    aliasName: $_aliasNameGenerator(db.matches.id, db.matchTeamStats.matchId),
  );

  $$MatchTeamStatsTableProcessedTableManager get matchTeamStatsRefs {
    final manager = $$MatchTeamStatsTableTableManager(
      $_db,
      $_db.matchTeamStats,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchTeamStatsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MatchesTableFilterComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seasonId => $composableBuilder(
    column: $table.seasonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get kickoffUtc => $composableBuilder(
    column: $table.kickoffUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get homeScore => $composableBuilder(
    column: $table.homeScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get awayScore => $composableBuilder(
    column: $table.awayScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roundLabel => $composableBuilder(
    column: $table.roundLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$CompetitionsTableFilterComposer get competitionId {
    final $$CompetitionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableFilterComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableFilterComposer get homeTeamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.homeTeamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableFilterComposer get awayTeamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.awayTeamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> matchEventsRefs(
    Expression<bool> Function($$MatchEventsTableFilterComposer f) f,
  ) {
    final $$MatchEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableFilterComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchTeamStatsRefs(
    Expression<bool> Function($$MatchTeamStatsTableFilterComposer f) f,
  ) {
    final $$MatchTeamStatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchTeamStats,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchTeamStatsTableFilterComposer(
            $db: $db,
            $table: $db.matchTeamStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seasonId => $composableBuilder(
    column: $table.seasonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get kickoffUtc => $composableBuilder(
    column: $table.kickoffUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get homeScore => $composableBuilder(
    column: $table.homeScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get awayScore => $composableBuilder(
    column: $table.awayScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roundLabel => $composableBuilder(
    column: $table.roundLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompetitionsTableOrderingComposer get competitionId {
    final $$CompetitionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableOrderingComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableOrderingComposer get homeTeamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.homeTeamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableOrderingComposer get awayTeamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.awayTeamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get seasonId =>
      $composableBuilder(column: $table.seasonId, builder: (column) => column);

  GeneratedColumn<DateTime> get kickoffUtc => $composableBuilder(
    column: $table.kickoffUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get homeScore =>
      $composableBuilder(column: $table.homeScore, builder: (column) => column);

  GeneratedColumn<int> get awayScore =>
      $composableBuilder(column: $table.awayScore, builder: (column) => column);

  GeneratedColumn<String> get roundLabel => $composableBuilder(
    column: $table.roundLabel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  $$CompetitionsTableAnnotationComposer get competitionId {
    final $$CompetitionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableAnnotationComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableAnnotationComposer get homeTeamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.homeTeamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableAnnotationComposer get awayTeamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.awayTeamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> matchEventsRefs<T extends Object>(
    Expression<T> Function($$MatchEventsTableAnnotationComposer a) f,
  ) {
    final $$MatchEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEvents,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchTeamStatsRefs<T extends Object>(
    Expression<T> Function($$MatchTeamStatsTableAnnotationComposer a) f,
  ) {
    final $$MatchTeamStatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchTeamStats,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchTeamStatsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchTeamStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchesTable,
          MatchRow,
          $$MatchesTableFilterComposer,
          $$MatchesTableOrderingComposer,
          $$MatchesTableAnnotationComposer,
          $$MatchesTableCreateCompanionBuilder,
          $$MatchesTableUpdateCompanionBuilder,
          (MatchRow, $$MatchesTableReferences),
          MatchRow,
          PrefetchHooks Function({
            bool competitionId,
            bool homeTeamId,
            bool awayTeamId,
            bool matchEventsRefs,
            bool matchTeamStatsRefs,
          })
        > {
  $$MatchesTableTableManager(_$AppDatabase db, $MatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$MatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$MatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$MatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> competitionId = const Value.absent(),
                Value<String?> seasonId = const Value.absent(),
                Value<String> homeTeamId = const Value.absent(),
                Value<String> awayTeamId = const Value.absent(),
                Value<DateTime> kickoffUtc = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> homeScore = const Value.absent(),
                Value<int> awayScore = const Value.absent(),
                Value<String?> roundLabel = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion(
                id: id,
                competitionId: competitionId,
                seasonId: seasonId,
                homeTeamId: homeTeamId,
                awayTeamId: awayTeamId,
                kickoffUtc: kickoffUtc,
                status: status,
                homeScore: homeScore,
                awayScore: awayScore,
                roundLabel: roundLabel,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String competitionId,
                Value<String?> seasonId = const Value.absent(),
                required String homeTeamId,
                required String awayTeamId,
                required DateTime kickoffUtc,
                Value<String> status = const Value.absent(),
                Value<int> homeScore = const Value.absent(),
                Value<int> awayScore = const Value.absent(),
                Value<String?> roundLabel = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion.insert(
                id: id,
                competitionId: competitionId,
                seasonId: seasonId,
                homeTeamId: homeTeamId,
                awayTeamId: awayTeamId,
                kickoffUtc: kickoffUtc,
                status: status,
                homeScore: homeScore,
                awayScore: awayScore,
                roundLabel: roundLabel,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$MatchesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            competitionId = false,
            homeTeamId = false,
            awayTeamId = false,
            matchEventsRefs = false,
            matchTeamStatsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (matchEventsRefs) db.matchEvents,
                if (matchTeamStatsRefs) db.matchTeamStats,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (competitionId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.competitionId,
                            referencedTable: $$MatchesTableReferences
                                ._competitionIdTable(db),
                            referencedColumn:
                                $$MatchesTableReferences
                                    ._competitionIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (homeTeamId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.homeTeamId,
                            referencedTable: $$MatchesTableReferences
                                ._homeTeamIdTable(db),
                            referencedColumn:
                                $$MatchesTableReferences
                                    ._homeTeamIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (awayTeamId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.awayTeamId,
                            referencedTable: $$MatchesTableReferences
                                ._awayTeamIdTable(db),
                            referencedColumn:
                                $$MatchesTableReferences
                                    ._awayTeamIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (matchEventsRefs)
                    await $_getPrefetchedData<
                      MatchRow,
                      $MatchesTable,
                      MatchEventRow
                    >(
                      currentTable: table,
                      referencedTable: $$MatchesTableReferences
                          ._matchEventsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).matchEventsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.matchId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (matchTeamStatsRefs)
                    await $_getPrefetchedData<
                      MatchRow,
                      $MatchesTable,
                      MatchTeamStatRow
                    >(
                      currentTable: table,
                      referencedTable: $$MatchesTableReferences
                          ._matchTeamStatsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).matchTeamStatsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.matchId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchesTable,
      MatchRow,
      $$MatchesTableFilterComposer,
      $$MatchesTableOrderingComposer,
      $$MatchesTableAnnotationComposer,
      $$MatchesTableCreateCompanionBuilder,
      $$MatchesTableUpdateCompanionBuilder,
      (MatchRow, $$MatchesTableReferences),
      MatchRow,
      PrefetchHooks Function({
        bool competitionId,
        bool homeTeamId,
        bool awayTeamId,
        bool matchEventsRefs,
        bool matchTeamStatsRefs,
      })
    >;
typedef $$MatchEventsTableCreateCompanionBuilder =
    MatchEventsCompanion Function({
      Value<int> id,
      required String matchId,
      required int minute,
      required String eventType,
      Value<String?> teamId,
      Value<String?> playerId,
      Value<String?> playerName,
      Value<String?> detail,
    });
typedef $$MatchEventsTableUpdateCompanionBuilder =
    MatchEventsCompanion Function({
      Value<int> id,
      Value<String> matchId,
      Value<int> minute,
      Value<String> eventType,
      Value<String?> teamId,
      Value<String?> playerId,
      Value<String?> playerName,
      Value<String?> detail,
    });

final class $$MatchEventsTableReferences
    extends BaseReferences<_$AppDatabase, $MatchEventsTable, MatchEventRow> {
  $$MatchEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MatchesTable _matchIdTable(_$AppDatabase db) => db.matches
      .createAlias($_aliasNameGenerator(db.matchEvents.matchId, db.matches.id));

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TeamsTable _teamIdTable(_$AppDatabase db) => db.teams.createAlias(
    $_aliasNameGenerator(db.matchEvents.teamId, db.teams.id),
  );

  $$TeamsTableProcessedTableManager? get teamId {
    final $_column = $_itemColumn<String>('team_id');
    if ($_column == null) return null;
    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_teamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias(
        $_aliasNameGenerator(db.matchEvents.playerId, db.players.id),
      );

  $$PlayersTableProcessedTableManager? get playerId {
    final $_column = $_itemColumn<String>('player_id');
    if ($_column == null) return null;
    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MatchEventsTableFilterComposer
    extends Composer<_$AppDatabase, $MatchEventsTable> {
  $$MatchEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableFilterComposer get teamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchEventsTable> {
  $$MatchEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableOrderingComposer get teamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchEventsTable> {
  $$MatchEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableAnnotationComposer get teamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchEventsTable,
          MatchEventRow,
          $$MatchEventsTableFilterComposer,
          $$MatchEventsTableOrderingComposer,
          $$MatchEventsTableAnnotationComposer,
          $$MatchEventsTableCreateCompanionBuilder,
          $$MatchEventsTableUpdateCompanionBuilder,
          (MatchEventRow, $$MatchEventsTableReferences),
          MatchEventRow,
          PrefetchHooks Function({bool matchId, bool teamId, bool playerId})
        > {
  $$MatchEventsTableTableManager(_$AppDatabase db, $MatchEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$MatchEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$MatchEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$MatchEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<int> minute = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String?> teamId = const Value.absent(),
                Value<String?> playerId = const Value.absent(),
                Value<String?> playerName = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => MatchEventsCompanion(
                id: id,
                matchId: matchId,
                minute: minute,
                eventType: eventType,
                teamId: teamId,
                playerId: playerId,
                playerName: playerName,
                detail: detail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String matchId,
                required int minute,
                required String eventType,
                Value<String?> teamId = const Value.absent(),
                Value<String?> playerId = const Value.absent(),
                Value<String?> playerName = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => MatchEventsCompanion.insert(
                id: id,
                matchId: matchId,
                minute: minute,
                eventType: eventType,
                teamId: teamId,
                playerId: playerId,
                playerName: playerName,
                detail: detail,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$MatchEventsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            matchId = false,
            teamId = false,
            playerId = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (matchId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.matchId,
                            referencedTable: $$MatchEventsTableReferences
                                ._matchIdTable(db),
                            referencedColumn:
                                $$MatchEventsTableReferences
                                    ._matchIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (teamId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.teamId,
                            referencedTable: $$MatchEventsTableReferences
                                ._teamIdTable(db),
                            referencedColumn:
                                $$MatchEventsTableReferences
                                    ._teamIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (playerId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.playerId,
                            referencedTable: $$MatchEventsTableReferences
                                ._playerIdTable(db),
                            referencedColumn:
                                $$MatchEventsTableReferences
                                    ._playerIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MatchEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchEventsTable,
      MatchEventRow,
      $$MatchEventsTableFilterComposer,
      $$MatchEventsTableOrderingComposer,
      $$MatchEventsTableAnnotationComposer,
      $$MatchEventsTableCreateCompanionBuilder,
      $$MatchEventsTableUpdateCompanionBuilder,
      (MatchEventRow, $$MatchEventsTableReferences),
      MatchEventRow,
      PrefetchHooks Function({bool matchId, bool teamId, bool playerId})
    >;
typedef $$MatchTeamStatsTableCreateCompanionBuilder =
    MatchTeamStatsCompanion Function({
      Value<int> id,
      required String matchId,
      required String teamId,
      required String statKey,
      required double statValue,
    });
typedef $$MatchTeamStatsTableUpdateCompanionBuilder =
    MatchTeamStatsCompanion Function({
      Value<int> id,
      Value<String> matchId,
      Value<String> teamId,
      Value<String> statKey,
      Value<double> statValue,
    });

final class $$MatchTeamStatsTableReferences
    extends
        BaseReferences<_$AppDatabase, $MatchTeamStatsTable, MatchTeamStatRow> {
  $$MatchTeamStatsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias(
        $_aliasNameGenerator(db.matchTeamStats.matchId, db.matches.id),
      );

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TeamsTable _teamIdTable(_$AppDatabase db) => db.teams.createAlias(
    $_aliasNameGenerator(db.matchTeamStats.teamId, db.teams.id),
  );

  $$TeamsTableProcessedTableManager get teamId {
    final $_column = $_itemColumn<String>('team_id')!;

    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_teamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MatchTeamStatsTableFilterComposer
    extends Composer<_$AppDatabase, $MatchTeamStatsTable> {
  $$MatchTeamStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statKey => $composableBuilder(
    column: $table.statKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statValue => $composableBuilder(
    column: $table.statValue,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableFilterComposer get teamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchTeamStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchTeamStatsTable> {
  $$MatchTeamStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statKey => $composableBuilder(
    column: $table.statKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statValue => $composableBuilder(
    column: $table.statValue,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableOrderingComposer get teamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchTeamStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchTeamStatsTable> {
  $$MatchTeamStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get statKey =>
      $composableBuilder(column: $table.statKey, builder: (column) => column);

  GeneratedColumn<double> get statValue =>
      $composableBuilder(column: $table.statValue, builder: (column) => column);

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableAnnotationComposer get teamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchTeamStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchTeamStatsTable,
          MatchTeamStatRow,
          $$MatchTeamStatsTableFilterComposer,
          $$MatchTeamStatsTableOrderingComposer,
          $$MatchTeamStatsTableAnnotationComposer,
          $$MatchTeamStatsTableCreateCompanionBuilder,
          $$MatchTeamStatsTableUpdateCompanionBuilder,
          (MatchTeamStatRow, $$MatchTeamStatsTableReferences),
          MatchTeamStatRow,
          PrefetchHooks Function({bool matchId, bool teamId})
        > {
  $$MatchTeamStatsTableTableManager(
    _$AppDatabase db,
    $MatchTeamStatsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$MatchTeamStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$MatchTeamStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$MatchTeamStatsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> teamId = const Value.absent(),
                Value<String> statKey = const Value.absent(),
                Value<double> statValue = const Value.absent(),
              }) => MatchTeamStatsCompanion(
                id: id,
                matchId: matchId,
                teamId: teamId,
                statKey: statKey,
                statValue: statValue,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String matchId,
                required String teamId,
                required String statKey,
                required double statValue,
              }) => MatchTeamStatsCompanion.insert(
                id: id,
                matchId: matchId,
                teamId: teamId,
                statKey: statKey,
                statValue: statValue,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$MatchTeamStatsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({matchId = false, teamId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (matchId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.matchId,
                            referencedTable: $$MatchTeamStatsTableReferences
                                ._matchIdTable(db),
                            referencedColumn:
                                $$MatchTeamStatsTableReferences
                                    ._matchIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (teamId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.teamId,
                            referencedTable: $$MatchTeamStatsTableReferences
                                ._teamIdTable(db),
                            referencedColumn:
                                $$MatchTeamStatsTableReferences
                                    ._teamIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MatchTeamStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchTeamStatsTable,
      MatchTeamStatRow,
      $$MatchTeamStatsTableFilterComposer,
      $$MatchTeamStatsTableOrderingComposer,
      $$MatchTeamStatsTableAnnotationComposer,
      $$MatchTeamStatsTableCreateCompanionBuilder,
      $$MatchTeamStatsTableUpdateCompanionBuilder,
      (MatchTeamStatRow, $$MatchTeamStatsTableReferences),
      MatchTeamStatRow,
      PrefetchHooks Function({bool matchId, bool teamId})
    >;
typedef $$TopPlayerStatsTableCreateCompanionBuilder =
    TopPlayerStatsCompanion Function({
      Value<int> id,
      required String competitionId,
      Value<String?> seasonId,
      required String statType,
      required String playerId,
      Value<String?> teamId,
      required String playerName,
      required int rank,
      required double statValue,
      Value<double?> subStatValue,
      required DateTime updatedAtUtc,
    });
typedef $$TopPlayerStatsTableUpdateCompanionBuilder =
    TopPlayerStatsCompanion Function({
      Value<int> id,
      Value<String> competitionId,
      Value<String?> seasonId,
      Value<String> statType,
      Value<String> playerId,
      Value<String?> teamId,
      Value<String> playerName,
      Value<int> rank,
      Value<double> statValue,
      Value<double?> subStatValue,
      Value<DateTime> updatedAtUtc,
    });

final class $$TopPlayerStatsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TopPlayerStatsTable, TopPlayerStatRow> {
  $$TopPlayerStatsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompetitionsTable _competitionIdTable(_$AppDatabase db) =>
      db.competitions.createAlias(
        $_aliasNameGenerator(
          db.topPlayerStats.competitionId,
          db.competitions.id,
        ),
      );

  $$CompetitionsTableProcessedTableManager get competitionId {
    final $_column = $_itemColumn<String>('competition_id')!;

    final manager = $$CompetitionsTableTableManager(
      $_db,
      $_db.competitions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_competitionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias(
        $_aliasNameGenerator(db.topPlayerStats.playerId, db.players.id),
      );

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TeamsTable _teamIdTable(_$AppDatabase db) => db.teams.createAlias(
    $_aliasNameGenerator(db.topPlayerStats.teamId, db.teams.id),
  );

  $$TeamsTableProcessedTableManager? get teamId {
    final $_column = $_itemColumn<String>('team_id');
    if ($_column == null) return null;
    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_teamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TopPlayerStatsTableFilterComposer
    extends Composer<_$AppDatabase, $TopPlayerStatsTable> {
  $$TopPlayerStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seasonId => $composableBuilder(
    column: $table.seasonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statType => $composableBuilder(
    column: $table.statType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statValue => $composableBuilder(
    column: $table.statValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get subStatValue => $composableBuilder(
    column: $table.subStatValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$CompetitionsTableFilterComposer get competitionId {
    final $$CompetitionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableFilterComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableFilterComposer get teamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TopPlayerStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $TopPlayerStatsTable> {
  $$TopPlayerStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seasonId => $composableBuilder(
    column: $table.seasonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statType => $composableBuilder(
    column: $table.statType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statValue => $composableBuilder(
    column: $table.statValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get subStatValue => $composableBuilder(
    column: $table.subStatValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompetitionsTableOrderingComposer get competitionId {
    final $$CompetitionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableOrderingComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableOrderingComposer get teamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TopPlayerStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TopPlayerStatsTable> {
  $$TopPlayerStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get seasonId =>
      $composableBuilder(column: $table.seasonId, builder: (column) => column);

  GeneratedColumn<String> get statType =>
      $composableBuilder(column: $table.statType, builder: (column) => column);

  GeneratedColumn<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<double> get statValue =>
      $composableBuilder(column: $table.statValue, builder: (column) => column);

  GeneratedColumn<double> get subStatValue => $composableBuilder(
    column: $table.subStatValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  $$CompetitionsTableAnnotationComposer get competitionId {
    final $$CompetitionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableAnnotationComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableAnnotationComposer get teamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TopPlayerStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TopPlayerStatsTable,
          TopPlayerStatRow,
          $$TopPlayerStatsTableFilterComposer,
          $$TopPlayerStatsTableOrderingComposer,
          $$TopPlayerStatsTableAnnotationComposer,
          $$TopPlayerStatsTableCreateCompanionBuilder,
          $$TopPlayerStatsTableUpdateCompanionBuilder,
          (TopPlayerStatRow, $$TopPlayerStatsTableReferences),
          TopPlayerStatRow,
          PrefetchHooks Function({
            bool competitionId,
            bool playerId,
            bool teamId,
          })
        > {
  $$TopPlayerStatsTableTableManager(
    _$AppDatabase db,
    $TopPlayerStatsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TopPlayerStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$TopPlayerStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$TopPlayerStatsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> competitionId = const Value.absent(),
                Value<String?> seasonId = const Value.absent(),
                Value<String> statType = const Value.absent(),
                Value<String> playerId = const Value.absent(),
                Value<String?> teamId = const Value.absent(),
                Value<String> playerName = const Value.absent(),
                Value<int> rank = const Value.absent(),
                Value<double> statValue = const Value.absent(),
                Value<double?> subStatValue = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
              }) => TopPlayerStatsCompanion(
                id: id,
                competitionId: competitionId,
                seasonId: seasonId,
                statType: statType,
                playerId: playerId,
                teamId: teamId,
                playerName: playerName,
                rank: rank,
                statValue: statValue,
                subStatValue: subStatValue,
                updatedAtUtc: updatedAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String competitionId,
                Value<String?> seasonId = const Value.absent(),
                required String statType,
                required String playerId,
                Value<String?> teamId = const Value.absent(),
                required String playerName,
                required int rank,
                required double statValue,
                Value<double?> subStatValue = const Value.absent(),
                required DateTime updatedAtUtc,
              }) => TopPlayerStatsCompanion.insert(
                id: id,
                competitionId: competitionId,
                seasonId: seasonId,
                statType: statType,
                playerId: playerId,
                teamId: teamId,
                playerName: playerName,
                rank: rank,
                statValue: statValue,
                subStatValue: subStatValue,
                updatedAtUtc: updatedAtUtc,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$TopPlayerStatsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            competitionId = false,
            playerId = false,
            teamId = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (competitionId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.competitionId,
                            referencedTable: $$TopPlayerStatsTableReferences
                                ._competitionIdTable(db),
                            referencedColumn:
                                $$TopPlayerStatsTableReferences
                                    ._competitionIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (playerId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.playerId,
                            referencedTable: $$TopPlayerStatsTableReferences
                                ._playerIdTable(db),
                            referencedColumn:
                                $$TopPlayerStatsTableReferences
                                    ._playerIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (teamId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.teamId,
                            referencedTable: $$TopPlayerStatsTableReferences
                                ._teamIdTable(db),
                            referencedColumn:
                                $$TopPlayerStatsTableReferences
                                    ._teamIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TopPlayerStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TopPlayerStatsTable,
      TopPlayerStatRow,
      $$TopPlayerStatsTableFilterComposer,
      $$TopPlayerStatsTableOrderingComposer,
      $$TopPlayerStatsTableAnnotationComposer,
      $$TopPlayerStatsTableCreateCompanionBuilder,
      $$TopPlayerStatsTableUpdateCompanionBuilder,
      (TopPlayerStatRow, $$TopPlayerStatsTableReferences),
      TopPlayerStatRow,
      PrefetchHooks Function({bool competitionId, bool playerId, bool teamId})
    >;
typedef $$StandingsRowsTableCreateCompanionBuilder =
    StandingsRowsCompanion Function({
      Value<int> id,
      required String competitionId,
      Value<String?> seasonId,
      required String teamId,
      required int position,
      Value<int> played,
      Value<int> won,
      Value<int> draw,
      Value<int> lost,
      Value<int> goalsFor,
      Value<int> goalsAgainst,
      Value<int> goalDiff,
      Value<int> points,
      Value<String?> form,
      required DateTime updatedAtUtc,
    });
typedef $$StandingsRowsTableUpdateCompanionBuilder =
    StandingsRowsCompanion Function({
      Value<int> id,
      Value<String> competitionId,
      Value<String?> seasonId,
      Value<String> teamId,
      Value<int> position,
      Value<int> played,
      Value<int> won,
      Value<int> draw,
      Value<int> lost,
      Value<int> goalsFor,
      Value<int> goalsAgainst,
      Value<int> goalDiff,
      Value<int> points,
      Value<String?> form,
      Value<DateTime> updatedAtUtc,
    });

final class $$StandingsRowsTableReferences
    extends
        BaseReferences<_$AppDatabase, $StandingsRowsTable, StandingsRowData> {
  $$StandingsRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompetitionsTable _competitionIdTable(_$AppDatabase db) =>
      db.competitions.createAlias(
        $_aliasNameGenerator(
          db.standingsRows.competitionId,
          db.competitions.id,
        ),
      );

  $$CompetitionsTableProcessedTableManager get competitionId {
    final $_column = $_itemColumn<String>('competition_id')!;

    final manager = $$CompetitionsTableTableManager(
      $_db,
      $_db.competitions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_competitionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TeamsTable _teamIdTable(_$AppDatabase db) => db.teams.createAlias(
    $_aliasNameGenerator(db.standingsRows.teamId, db.teams.id),
  );

  $$TeamsTableProcessedTableManager get teamId {
    final $_column = $_itemColumn<String>('team_id')!;

    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_teamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StandingsRowsTableFilterComposer
    extends Composer<_$AppDatabase, $StandingsRowsTable> {
  $$StandingsRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seasonId => $composableBuilder(
    column: $table.seasonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get won => $composableBuilder(
    column: $table.won,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get draw => $composableBuilder(
    column: $table.draw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lost => $composableBuilder(
    column: $table.lost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalsFor => $composableBuilder(
    column: $table.goalsFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalsAgainst => $composableBuilder(
    column: $table.goalsAgainst,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalDiff => $composableBuilder(
    column: $table.goalDiff,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$CompetitionsTableFilterComposer get competitionId {
    final $$CompetitionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableFilterComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableFilterComposer get teamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StandingsRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $StandingsRowsTable> {
  $$StandingsRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seasonId => $composableBuilder(
    column: $table.seasonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get won => $composableBuilder(
    column: $table.won,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get draw => $composableBuilder(
    column: $table.draw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lost => $composableBuilder(
    column: $table.lost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalsFor => $composableBuilder(
    column: $table.goalsFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalsAgainst => $composableBuilder(
    column: $table.goalsAgainst,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalDiff => $composableBuilder(
    column: $table.goalDiff,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompetitionsTableOrderingComposer get competitionId {
    final $$CompetitionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableOrderingComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableOrderingComposer get teamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StandingsRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StandingsRowsTable> {
  $$StandingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get seasonId =>
      $composableBuilder(column: $table.seasonId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get played =>
      $composableBuilder(column: $table.played, builder: (column) => column);

  GeneratedColumn<int> get won =>
      $composableBuilder(column: $table.won, builder: (column) => column);

  GeneratedColumn<int> get draw =>
      $composableBuilder(column: $table.draw, builder: (column) => column);

  GeneratedColumn<int> get lost =>
      $composableBuilder(column: $table.lost, builder: (column) => column);

  GeneratedColumn<int> get goalsFor =>
      $composableBuilder(column: $table.goalsFor, builder: (column) => column);

  GeneratedColumn<int> get goalsAgainst => $composableBuilder(
    column: $table.goalsAgainst,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goalDiff =>
      $composableBuilder(column: $table.goalDiff, builder: (column) => column);

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<String> get form =>
      $composableBuilder(column: $table.form, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  $$CompetitionsTableAnnotationComposer get competitionId {
    final $$CompetitionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.competitionId,
      referencedTable: $db.competitions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompetitionsTableAnnotationComposer(
            $db: $db,
            $table: $db.competitions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TeamsTableAnnotationComposer get teamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StandingsRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StandingsRowsTable,
          StandingsRowData,
          $$StandingsRowsTableFilterComposer,
          $$StandingsRowsTableOrderingComposer,
          $$StandingsRowsTableAnnotationComposer,
          $$StandingsRowsTableCreateCompanionBuilder,
          $$StandingsRowsTableUpdateCompanionBuilder,
          (StandingsRowData, $$StandingsRowsTableReferences),
          StandingsRowData,
          PrefetchHooks Function({bool competitionId, bool teamId})
        > {
  $$StandingsRowsTableTableManager(_$AppDatabase db, $StandingsRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StandingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$StandingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$StandingsRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> competitionId = const Value.absent(),
                Value<String?> seasonId = const Value.absent(),
                Value<String> teamId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> played = const Value.absent(),
                Value<int> won = const Value.absent(),
                Value<int> draw = const Value.absent(),
                Value<int> lost = const Value.absent(),
                Value<int> goalsFor = const Value.absent(),
                Value<int> goalsAgainst = const Value.absent(),
                Value<int> goalDiff = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<String?> form = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
              }) => StandingsRowsCompanion(
                id: id,
                competitionId: competitionId,
                seasonId: seasonId,
                teamId: teamId,
                position: position,
                played: played,
                won: won,
                draw: draw,
                lost: lost,
                goalsFor: goalsFor,
                goalsAgainst: goalsAgainst,
                goalDiff: goalDiff,
                points: points,
                form: form,
                updatedAtUtc: updatedAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String competitionId,
                Value<String?> seasonId = const Value.absent(),
                required String teamId,
                required int position,
                Value<int> played = const Value.absent(),
                Value<int> won = const Value.absent(),
                Value<int> draw = const Value.absent(),
                Value<int> lost = const Value.absent(),
                Value<int> goalsFor = const Value.absent(),
                Value<int> goalsAgainst = const Value.absent(),
                Value<int> goalDiff = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<String?> form = const Value.absent(),
                required DateTime updatedAtUtc,
              }) => StandingsRowsCompanion.insert(
                id: id,
                competitionId: competitionId,
                seasonId: seasonId,
                teamId: teamId,
                position: position,
                played: played,
                won: won,
                draw: draw,
                lost: lost,
                goalsFor: goalsFor,
                goalsAgainst: goalsAgainst,
                goalDiff: goalDiff,
                points: points,
                form: form,
                updatedAtUtc: updatedAtUtc,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$StandingsRowsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({competitionId = false, teamId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (competitionId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.competitionId,
                            referencedTable: $$StandingsRowsTableReferences
                                ._competitionIdTable(db),
                            referencedColumn:
                                $$StandingsRowsTableReferences
                                    ._competitionIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (teamId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.teamId,
                            referencedTable: $$StandingsRowsTableReferences
                                ._teamIdTable(db),
                            referencedColumn:
                                $$StandingsRowsTableReferences
                                    ._teamIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StandingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StandingsRowsTable,
      StandingsRowData,
      $$StandingsRowsTableFilterComposer,
      $$StandingsRowsTableOrderingComposer,
      $$StandingsRowsTableAnnotationComposer,
      $$StandingsRowsTableCreateCompanionBuilder,
      $$StandingsRowsTableUpdateCompanionBuilder,
      (StandingsRowData, $$StandingsRowsTableReferences),
      StandingsRowData,
      PrefetchHooks Function({bool competitionId, bool teamId})
    >;
typedef $$AssetRefsTableCreateCompanionBuilder =
    AssetRefsCompanion Function({
      Value<int> id,
      required String entityType,
      required String entityId,
      Value<String> variant,
      required String filePath,
      Value<String?> fileHash,
      required DateTime updatedAtUtc,
    });
typedef $$AssetRefsTableUpdateCompanionBuilder =
    AssetRefsCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> variant,
      Value<String> filePath,
      Value<String?> fileHash,
      Value<DateTime> updatedAtUtc,
    });

class $$AssetRefsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetRefsTable> {
  $$AssetRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AssetRefsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetRefsTable> {
  $$AssetRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssetRefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetRefsTable> {
  $$AssetRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get variant =>
      $composableBuilder(column: $table.variant, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$AssetRefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssetRefsTable,
          AssetRefRow,
          $$AssetRefsTableFilterComposer,
          $$AssetRefsTableOrderingComposer,
          $$AssetRefsTableAnnotationComposer,
          $$AssetRefsTableCreateCompanionBuilder,
          $$AssetRefsTableUpdateCompanionBuilder,
          (
            AssetRefRow,
            BaseReferences<_$AppDatabase, $AssetRefsTable, AssetRefRow>,
          ),
          AssetRefRow,
          PrefetchHooks Function()
        > {
  $$AssetRefsTableTableManager(_$AppDatabase db, $AssetRefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AssetRefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AssetRefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$AssetRefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> variant = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String?> fileHash = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
              }) => AssetRefsCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                variant: variant,
                filePath: filePath,
                fileHash: fileHash,
                updatedAtUtc: updatedAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityType,
                required String entityId,
                Value<String> variant = const Value.absent(),
                required String filePath,
                Value<String?> fileHash = const Value.absent(),
                required DateTime updatedAtUtc,
              }) => AssetRefsCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                variant: variant,
                filePath: filePath,
                fileHash: fileHash,
                updatedAtUtc: updatedAtUtc,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AssetRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssetRefsTable,
      AssetRefRow,
      $$AssetRefsTableFilterComposer,
      $$AssetRefsTableOrderingComposer,
      $$AssetRefsTableAnnotationComposer,
      $$AssetRefsTableCreateCompanionBuilder,
      $$AssetRefsTableUpdateCompanionBuilder,
      (
        AssetRefRow,
        BaseReferences<_$AppDatabase, $AssetRefsTable, AssetRefRow>,
      ),
      AssetRefRow,
      PrefetchHooks Function()
    >;
typedef $$ImportRunsTableCreateCompanionBuilder =
    ImportRunsCompanion Function({
      Value<int> id,
      required String triggerType,
      required DateTime startedAtUtc,
      Value<DateTime?> finishedAtUtc,
      required String status,
      Value<String> summaryJson,
    });
typedef $$ImportRunsTableUpdateCompanionBuilder =
    ImportRunsCompanion Function({
      Value<int> id,
      Value<String> triggerType,
      Value<DateTime> startedAtUtc,
      Value<DateTime?> finishedAtUtc,
      Value<String> status,
      Value<String> summaryJson,
    });

final class $$ImportRunsTableReferences
    extends BaseReferences<_$AppDatabase, $ImportRunsTable, ImportRunRow> {
  $$ImportRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ImportFilesTable, List<ImportFileRow>>
  _importFilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.importFiles,
    aliasName: $_aliasNameGenerator(db.importRuns.id, db.importFiles.runId),
  );

  $$ImportFilesTableProcessedTableManager get importFilesRefs {
    final manager = $$ImportFilesTableTableManager(
      $_db,
      $_db.importFiles,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_importFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ImportRunsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportRunsTable> {
  $$ImportRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAtUtc => $composableBuilder(
    column: $table.finishedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> importFilesRefs(
    Expression<bool> Function($$ImportFilesTableFilterComposer f) f,
  ) {
    final $$ImportFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importFiles,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportFilesTableFilterComposer(
            $db: $db,
            $table: $db.importFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportRunsTable> {
  $$ImportRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAtUtc => $composableBuilder(
    column: $table.finishedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportRunsTable> {
  $$ImportRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get finishedAtUtc => $composableBuilder(
    column: $table.finishedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  Expression<T> importFilesRefs<T extends Object>(
    Expression<T> Function($$ImportFilesTableAnnotationComposer a) f,
  ) {
    final $$ImportFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importFiles,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.importFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportRunsTable,
          ImportRunRow,
          $$ImportRunsTableFilterComposer,
          $$ImportRunsTableOrderingComposer,
          $$ImportRunsTableAnnotationComposer,
          $$ImportRunsTableCreateCompanionBuilder,
          $$ImportRunsTableUpdateCompanionBuilder,
          (ImportRunRow, $$ImportRunsTableReferences),
          ImportRunRow,
          PrefetchHooks Function({bool importFilesRefs})
        > {
  $$ImportRunsTableTableManager(_$AppDatabase db, $ImportRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ImportRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ImportRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ImportRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> triggerType = const Value.absent(),
                Value<DateTime> startedAtUtc = const Value.absent(),
                Value<DateTime?> finishedAtUtc = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> summaryJson = const Value.absent(),
              }) => ImportRunsCompanion(
                id: id,
                triggerType: triggerType,
                startedAtUtc: startedAtUtc,
                finishedAtUtc: finishedAtUtc,
                status: status,
                summaryJson: summaryJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String triggerType,
                required DateTime startedAtUtc,
                Value<DateTime?> finishedAtUtc = const Value.absent(),
                required String status,
                Value<String> summaryJson = const Value.absent(),
              }) => ImportRunsCompanion.insert(
                id: id,
                triggerType: triggerType,
                startedAtUtc: startedAtUtc,
                finishedAtUtc: finishedAtUtc,
                status: status,
                summaryJson: summaryJson,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ImportRunsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({importFilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (importFilesRefs) db.importFiles],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (importFilesRefs)
                    await $_getPrefetchedData<
                      ImportRunRow,
                      $ImportRunsTable,
                      ImportFileRow
                    >(
                      currentTable: table,
                      referencedTable: $$ImportRunsTableReferences
                          ._importFilesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ImportRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).importFilesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.runId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ImportRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportRunsTable,
      ImportRunRow,
      $$ImportRunsTableFilterComposer,
      $$ImportRunsTableOrderingComposer,
      $$ImportRunsTableAnnotationComposer,
      $$ImportRunsTableCreateCompanionBuilder,
      $$ImportRunsTableUpdateCompanionBuilder,
      (ImportRunRow, $$ImportRunsTableReferences),
      ImportRunRow,
      PrefetchHooks Function({bool importFilesRefs})
    >;
typedef $$ImportFilesTableCreateCompanionBuilder =
    ImportFilesCompanion Function({
      Value<int> id,
      required int runId,
      required String fileName,
      required String relativePath,
      required String checksum,
      required String status,
      Value<String?> errorMessage,
    });
typedef $$ImportFilesTableUpdateCompanionBuilder =
    ImportFilesCompanion Function({
      Value<int> id,
      Value<int> runId,
      Value<String> fileName,
      Value<String> relativePath,
      Value<String> checksum,
      Value<String> status,
      Value<String?> errorMessage,
    });

final class $$ImportFilesTableReferences
    extends BaseReferences<_$AppDatabase, $ImportFilesTable, ImportFileRow> {
  $$ImportFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ImportRunsTable _runIdTable(_$AppDatabase db) =>
      db.importRuns.createAlias(
        $_aliasNameGenerator(db.importFiles.runId, db.importRuns.id),
      );

  $$ImportRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<int>('run_id')!;

    final manager = $$ImportRunsTableTableManager(
      $_db,
      $_db.importRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImportFilesTableFilterComposer
    extends Composer<_$AppDatabase, $ImportFilesTable> {
  $$ImportFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  $$ImportRunsTableFilterComposer get runId {
    final $$ImportRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.importRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportRunsTableFilterComposer(
            $db: $db,
            $table: $db.importRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportFilesTable> {
  $$ImportFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImportRunsTableOrderingComposer get runId {
    final $$ImportRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.importRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportRunsTableOrderingComposer(
            $db: $db,
            $table: $db.importRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportFilesTable> {
  $$ImportFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  $$ImportRunsTableAnnotationComposer get runId {
    final $$ImportRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.importRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.importRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportFilesTable,
          ImportFileRow,
          $$ImportFilesTableFilterComposer,
          $$ImportFilesTableOrderingComposer,
          $$ImportFilesTableAnnotationComposer,
          $$ImportFilesTableCreateCompanionBuilder,
          $$ImportFilesTableUpdateCompanionBuilder,
          (ImportFileRow, $$ImportFilesTableReferences),
          ImportFileRow,
          PrefetchHooks Function({bool runId})
        > {
  $$ImportFilesTableTableManager(_$AppDatabase db, $ImportFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ImportFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ImportFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$ImportFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> runId = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
              }) => ImportFilesCompanion(
                id: id,
                runId: runId,
                fileName: fileName,
                relativePath: relativePath,
                checksum: checksum,
                status: status,
                errorMessage: errorMessage,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int runId,
                required String fileName,
                required String relativePath,
                required String checksum,
                required String status,
                Value<String?> errorMessage = const Value.absent(),
              }) => ImportFilesCompanion.insert(
                id: id,
                runId: runId,
                fileName: fileName,
                relativePath: relativePath,
                checksum: checksum,
                status: status,
                errorMessage: errorMessage,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ImportFilesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (runId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.runId,
                            referencedTable: $$ImportFilesTableReferences
                                ._runIdTable(db),
                            referencedColumn:
                                $$ImportFilesTableReferences._runIdTable(db).id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImportFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportFilesTable,
      ImportFileRow,
      $$ImportFilesTableFilterComposer,
      $$ImportFilesTableOrderingComposer,
      $$ImportFilesTableAnnotationComposer,
      $$ImportFilesTableCreateCompanionBuilder,
      $$ImportFilesTableUpdateCompanionBuilder,
      (ImportFileRow, $$ImportFilesTableReferences),
      ImportFileRow,
      PrefetchHooks Function({bool runId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CompetitionsTableTableManager get competitions =>
      $$CompetitionsTableTableManager(_db, _db.competitions);
  $$TeamsTableTableManager get teams =>
      $$TeamsTableTableManager(_db, _db.teams);
  $$PlayersTableTableManager get players =>
      $$PlayersTableTableManager(_db, _db.players);
  $$MatchesTableTableManager get matches =>
      $$MatchesTableTableManager(_db, _db.matches);
  $$MatchEventsTableTableManager get matchEvents =>
      $$MatchEventsTableTableManager(_db, _db.matchEvents);
  $$MatchTeamStatsTableTableManager get matchTeamStats =>
      $$MatchTeamStatsTableTableManager(_db, _db.matchTeamStats);
  $$TopPlayerStatsTableTableManager get topPlayerStats =>
      $$TopPlayerStatsTableTableManager(_db, _db.topPlayerStats);
  $$StandingsRowsTableTableManager get standingsRows =>
      $$StandingsRowsTableTableManager(_db, _db.standingsRows);
  $$AssetRefsTableTableManager get assetRefs =>
      $$AssetRefsTableTableManager(_db, _db.assetRefs);
  $$ImportRunsTableTableManager get importRuns =>
      $$ImportRunsTableTableManager(_db, _db.importRuns);
  $$ImportFilesTableTableManager get importFiles =>
      $$ImportFilesTableTableManager(_db, _db.importFiles);
}
