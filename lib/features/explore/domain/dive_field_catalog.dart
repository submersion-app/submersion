import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// What a numeric clause measures, so bare numbers can take the diver's unit.
enum FieldDimension {
  depth,
  temperature,
  pressure,
  minutes,
  percent,
  count,
  none,
}

enum FieldValueType { number, enumName, flag }

/// The fields the native schema constrains a dive clause to (schema v2).
///
/// Named `ExploreDiveField` because `DiveField` is the table-column enum.
enum ExploreDiveField {
  depth('depth'),
  avgDepth('avgDepth'),
  bottomTime('bottomTime'),
  waterTemp('waterTemp'),
  airTemp('airTemp'),
  visibility('visibility'),
  rating('rating'),
  o2('o2'),
  diveNumber('diveNumber'),
  waterType('waterType'),
  diveMode('diveMode'),
  entryMethod('entryMethod'),
  currentStrength('currentStrength'),
  favorite('favorite'),
  deco('deco'),
  noBuddy('noBuddy'),
  weekday('weekday'),
  diveType('diveType'),
  // Schema v2: the phase 2 derived fields. Each lowers to a
  // DerivedPredicate rather than to a stored column.
  sacTrend('sacTrend'),
  sacRoseAfter('sacRoseAfter'),
  finalStopUnstable('finalStopUnstable'),
  finalStopDuration('finalStopDuration'),
  safetyFinding('safetyFinding');

  final String jsonName;
  const ExploreDiveField(this.jsonName);
}

class FieldSpec {
  final FieldDimension dimension;
  final FieldValueType valueType;
  final Set<ClauseOp> ops;
  final List<String>? enumValues;

  const FieldSpec({
    required this.dimension,
    required this.valueType,
    required this.ops,
    this.enumValues,
  });
}

const Set<ClauseOp> _ordering = {
  ClauseOp.lt,
  ClauseOp.lte,
  ClauseOp.gt,
  ClauseOp.gte,
  ClauseOp.eq,
  ClauseOp.between,
};
const Set<ClauseOp> _membership = {ClauseOp.eq, ClauseOp.inList, ClauseOp.not};

const FieldSpec _number = FieldSpec(
  dimension: FieldDimension.count,
  valueType: FieldValueType.number,
  ops: _ordering,
);
const FieldSpec _depth = FieldSpec(
  dimension: FieldDimension.depth,
  valueType: FieldValueType.number,
  ops: _ordering,
);
const FieldSpec _temperature = FieldSpec(
  dimension: FieldDimension.temperature,
  valueType: FieldValueType.number,
  ops: _ordering,
);

/// The rule names the model may write for `safetyFinding`.
///
/// Spelled out because `enumValues` sits in a const map and
/// `SafetyRuleId.values.map(...)` is not a constant. A guard test asserts
/// this stays in step with [SafetyRuleId], so adding a rule without adding
/// it here fails rather than silently making the rule unaskable.
const List<String> safetyFindingNames = [
  'rapidAscent',
  'missedDecoStop',
  'omittedSafetyStop',
  'sawtoothProfile',
  'highSurfaceGf',
];

const FieldSpec _flag = FieldSpec(
  dimension: FieldDimension.none,
  valueType: FieldValueType.flag,
  ops: {ClauseOp.eq},
);

abstract final class DiveFieldCatalog {
  static const Map<ExploreDiveField, FieldSpec> _specs = {
    ExploreDiveField.depth: _depth,
    ExploreDiveField.avgDepth: _depth,
    ExploreDiveField.bottomTime: FieldSpec(
      dimension: FieldDimension.minutes,
      valueType: FieldValueType.number,
      ops: _ordering,
    ),
    ExploreDiveField.waterTemp: _temperature,
    ExploreDiveField.airTemp: _temperature,
    ExploreDiveField.visibility: _depth,
    ExploreDiveField.rating: _number,
    ExploreDiveField.o2: FieldSpec(
      dimension: FieldDimension.percent,
      valueType: FieldValueType.number,
      ops: _ordering,
    ),
    ExploreDiveField.diveNumber: _number,
    ExploreDiveField.waterType: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: ['salt', 'fresh', 'brackish'],
    ),
    ExploreDiveField.diveMode: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: ['oc', 'ccr', 'scr', 'gauge'],
    ),
    ExploreDiveField.entryMethod: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: [
        'shore',
        'boat',
        'backRoll',
        'giantStride',
        'seatedEntry',
        'ladder',
        'platform',
        'jetty',
        'other',
      ],
    ),
    ExploreDiveField.currentStrength: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: ['none', 'light', 'moderate', 'strong'],
    ),
    ExploreDiveField.favorite: _flag,
    ExploreDiveField.deco: _flag,
    ExploreDiveField.noBuddy: _flag,
    ExploreDiveField.weekday: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
    ),
    ExploreDiveField.diveType: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: {ClauseOp.eq},
    ),
    ExploreDiveField.sacTrend: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: {ClauseOp.eq},
      enumValues: ['rising', 'falling', 'flat'],
    ),
    // "after 20 minutes" is a mark in the dive, so only a lower bound and
    // equality make sense: there is no "rose before 20 minutes".
    ExploreDiveField.sacRoseAfter: FieldSpec(
      dimension: FieldDimension.minutes,
      valueType: FieldValueType.number,
      ops: {ClauseOp.eq, ClauseOp.gt, ClauseOp.gte},
    ),
    ExploreDiveField.finalStopUnstable: _flag,
    ExploreDiveField.finalStopDuration: FieldSpec(
      dimension: FieldDimension.minutes,
      valueType: FieldValueType.number,
      ops: _ordering,
    ),
    ExploreDiveField.safetyFinding: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: {ClauseOp.eq, ClauseOp.inList},
      enumValues: safetyFindingNames,
    ),
  };

  static ExploreDiveField? parse(String jsonName) {
    for (final f in ExploreDiveField.values) {
      if (f.jsonName == jsonName) return f;
    }
    return null;
  }

  static FieldSpec spec(ExploreDiveField field) => _specs[field]!;

  static List<String> get jsonNames =>
      ExploreDiveField.values.map((f) => f.jsonName).toList(growable: false);
}
