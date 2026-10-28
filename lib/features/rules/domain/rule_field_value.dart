import 'package:drift/drift.dart' show Constant, Variable;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_value_kind.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';

/// How a stored number converts for display, matching the dive and site
/// edit pages: depth-like lengths follow the depth unit, altitude its own,
/// wind speed its own, surface pressure shows in millibar, and the surface
/// interval is stored in seconds and entered in minutes.
enum RuleUnit { none, depth, altitude, windSpeed, millibar, seconds }

/// Every bulk-editable dive field a rule can set (#3513). The diver's own
/// role rides a separate lane, notes are appended rather than set, and the
/// site rides SiteOp, whose per-dive snap a rule's column write lacks (#3657).
final List<BulkField> kRuleSettableDiveFields = [
  for (final f in BulkField.values)
    if (f != BulkField.diverRole && f != BulkField.notes && f != BulkField.site)
      f,
];

/// The [BulkScalarInputs] members [field] writes, which key a
/// [SetDiveFieldAction]'s values.
List<String> diveFieldValueKeys(BulkField field) => switch (field) {
  BulkField.diveCenter => const ['diveCenterId'],
  BulkField.trip => const ['tripId'],
  BulkField.visibility => const [
    'visibilityMeters',
    'visibilityMinMeters',
    'visibilityMaxMeters',
  ],
  BulkField.surfaceInterval => const ['surfaceIntervalSeconds'],
  BulkField.diluentGas => const ['diluentO2', 'diluentHe'],
  _ => [field.name],
};

RuleValueKind diveFieldKind(BulkField field) => switch (field) {
  BulkField.diveCenter || BulkField.trip => RuleValueKind.entityRef,
  BulkField.rating => RuleValueKind.rating,
  BulkField.isFavorite ||
  BulkField.excludedFromStats ||
  BulkField.excludedFromGasStats => RuleValueKind.boolean,
  BulkField.waterType ||
  BulkField.currentDirection ||
  BulkField.currentStrength ||
  BulkField.entryMethod ||
  BulkField.exitMethod ||
  BulkField.windDirection ||
  BulkField.cloudCover ||
  BulkField.precipitation ||
  BulkField.diveMode ||
  BulkField.decoAlgorithm => RuleValueKind.enumName,
  BulkField.visibility ||
  BulkField.swellHeight ||
  BulkField.altitude ||
  BulkField.surfacePressure ||
  BulkField.surfaceInterval ||
  BulkField.gradientFactorLow ||
  BulkField.gradientFactorHigh ||
  BulkField.decoConservatism ||
  BulkField.windSpeed ||
  BulkField.humidity ||
  BulkField.setpointLow ||
  BulkField.setpointHigh ||
  BulkField.setpointDeco ||
  BulkField.diluentGas ||
  BulkField.scrubberDuration => RuleValueKind.number,
  _ => RuleValueKind.text,
};

/// Whether a number field stores whole numbers.
bool diveFieldIsInteger(BulkField field) => switch (field) {
  BulkField.surfaceInterval ||
  BulkField.gradientFactorLow ||
  BulkField.gradientFactorHigh ||
  BulkField.decoConservatism ||
  BulkField.scrubberDuration => true,
  _ => false,
};

/// The stored names an enum dive field accepts; empty for other kinds.
List<String> diveFieldEnumValues(BulkField field) => switch (field) {
  BulkField.waterType => _names(WaterType.values),
  BulkField.currentDirection ||
  BulkField.windDirection => _names(CurrentDirection.values),
  BulkField.currentStrength => _names(CurrentStrength.values),
  BulkField.entryMethod || BulkField.exitMethod => _names(EntryMethod.values),
  BulkField.cloudCover => _names(CloudCover.values),
  BulkField.precipitation => _names(Precipitation.values),
  BulkField.diveMode => [for (final m in DiveMode.values) m.code],
  BulkField.decoAlgorithm => const ['buhlmann', 'vpm', 'rgbm', 'dciem'],
  _ => const [],
};

RuleUnit diveFieldUnit(BulkField field) => switch (field) {
  BulkField.visibility || BulkField.swellHeight => RuleUnit.depth,
  BulkField.altitude => RuleUnit.altitude,
  BulkField.windSpeed => RuleUnit.windSpeed,
  BulkField.surfacePressure => RuleUnit.millibar,
  BulkField.surfaceInterval => RuleUnit.seconds,
  _ => RuleUnit.none,
};

RuleUnit siteFieldUnit(SiteRuleField field) => switch (field) {
  SiteRuleField.minDepth || SiteRuleField.maxDepth => RuleUnit.depth,
  SiteRuleField.altitude => RuleUnit.altitude,
  _ => RuleUnit.none,
};

List<String> _names(List<Enum> values) => [for (final v in values) v.name];

double? _d(Object? v) => (v as num?)?.toDouble();
int? _i(Object? v) => (v as num?)?.round();
String? _s(Object? v) => v as String?;
bool? _b(Object? v) => v as bool?;

/// The inputs bulk edit would collect for [field] holding [values].
BulkScalarInputs bulkInputsFor(BulkField field, Map<String, Object?> values) {
  Object? v(String k) => values[k];
  return BulkScalarInputs(
    diveCenterId: _s(v('diveCenterId')),
    diveOperator: _s(v('diveOperator')),
    boatName: _s(v('boatName')),
    boatCaptain: _s(v('boatCaptain')),
    tripId: _s(v('tripId')),
    rating: _i(v('rating')),
    isFavorite: _b(v('isFavorite')),
    excludedFromStats: _b(v('excludedFromStats')),
    excludedFromGasStats: _b(v('excludedFromGasStats')),
    waterType: _s(v('waterType')),
    visibilityMeters: _d(v('visibilityMeters')),
    visibilityMinMeters: _d(v('visibilityMinMeters')),
    visibilityMaxMeters: _d(v('visibilityMaxMeters')),
    currentDirection: _s(v('currentDirection')),
    currentStrength: _s(v('currentStrength')),
    swellHeight: _d(v('swellHeight')),
    surfaceConditions: _s(v('surfaceConditions')),
    entryMethod: _s(v('entryMethod')),
    exitMethod: _s(v('exitMethod')),
    altitude: _d(v('altitude')),
    surfacePressure: _d(v('surfacePressure')),
    surfaceIntervalSeconds: _i(v('surfaceIntervalSeconds')),
    gradientFactorLow: _i(v('gradientFactorLow')),
    gradientFactorHigh: _i(v('gradientFactorHigh')),
    decoAlgorithm: _s(v('decoAlgorithm')),
    decoConservatism: _i(v('decoConservatism')),
    diveComputerModel: _s(v('diveComputerModel')),
    windSpeed: _d(v('windSpeed')),
    windDirection: _s(v('windDirection')),
    cloudCover: _s(v('cloudCover')),
    precipitation: _s(v('precipitation')),
    humidity: _d(v('humidity')),
    weatherDescription: _s(v('weatherDescription')),
    diveMode: _s(v('diveMode')),
    setpointLow: _d(v('setpointLow')),
    setpointHigh: _d(v('setpointHigh')),
    setpointDeco: _d(v('setpointDeco')),
    diluentO2: _d(v('diluentO2')),
    diluentHe: _d(v('diluentHe')),
    scrubberType: _s(v('scrubberType')),
    scrubberDuration: _i(v('scrubberDuration')),
  );
}

/// The partial dive write a set-field action makes, with bulk edit's side
/// effects (visibility clears the legacy bucket, diluent sets O2 and He).
DivesCompanion diveCompanionFor(SetDiveFieldAction a) =>
    buildScalarCompanion({a.field}, bulkInputsFor(a.field, a.values));

/// The stored column [field]'s first value lands in, read off the write a
/// set-field action makes rather than guessed from the value's name. Null
/// for a field whose write sets no column (one not settable by a rule,
/// which a newer version's change row may still name).
String? diveFieldColumn(BulkField field) {
  final keys = diveFieldValueKeys(field);
  final enumValues = diveFieldEnumValues(field);
  final kind = diveFieldKind(field);
  if (keys.isEmpty || (kind == RuleValueKind.enumName && enumValues.isEmpty)) {
    return null;
  }
  final probe = switch (kind) {
    RuleValueKind.text || RuleValueKind.entityRef => 'x',
    RuleValueKind.enumName => enumValues.first,
    RuleValueKind.boolean => true,
    RuleValueKind.rating => 1,
    RuleValueKind.number => diveFieldIsInteger(field) ? 1 : 1.0,
  };
  final written = diveCompanionFor(
    SetDiveFieldAction(field, {keys.first: probe}),
  ).toColumns(false);
  for (final e in written.entries) {
    if (e.value case Variable(:final value) || Constant(:final value)
        when value != null) {
      return e.key;
    }
  }
  return null;
}
