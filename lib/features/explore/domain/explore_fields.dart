import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// The weekday tokens the model writes, Monday first: a token's index plus
/// one is its [DateTime.weekday].
const List<String> kWeekdayTokens = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

enum ExploreValueKind { number, enumName, flag, typeName }

const Set<ClauseOp> _ordering = {
  ClauseOp.lt,
  ClauseOp.lte,
  ClauseOp.gt,
  ClauseOp.gte,
  ClauseOp.eq,
  ClauseOp.between,
};
const Set<ClauseOp> _membership = {ClauseOp.eq, ClauseOp.inList, ClauseOp.not};

/// One field the model may name (#2365 PR 5): its word, the dive registry
/// path it lowers onto, and everything else read from the registry.
class ExploreField {
  const ExploreField(
    this.name,
    this.path,
    this.kind, {
    this.wholeNumbers = false,
    this.bounds,
    this.tokens,
  });

  /// The model's word: part of the stored JSON contract, never renamed.
  final String name;
  final List<String> path;
  final ExploreValueKind kind;

  /// Bounds round to whole numbers, as the filter axes they replace did.
  final bool wholeNumbers;

  /// Explore's own bounds where the registry declares no sanity.
  final ({double min, double max})? bounds;

  /// The model's tokens when they differ from the registry's enum names.
  final List<String>? tokens;

  /// The registry field at [path], or null for a relation (noBuddy).
  QueryField? get field => _resolved.putIfAbsent(
    path.join('.'),
    () => resolvePath(appQueryRegistry, diveQueryEntity, FieldPath(path)).field,
  );

  /// Resolved registry fields by path: the registry never changes at run
  /// time, so each path is walked once.
  static final _resolved = <String, QueryField?>{};

  FieldDimension get dimension =>
      kind == ExploreValueKind.number ? field!.dimension : FieldDimension.none;

  List<String>? get enumValues => tokens ?? field?.enumValues;

  Set<ClauseOp> get ops => switch (kind) {
    ExploreValueKind.number => _ordering,
    ExploreValueKind.enumName => _membership,
    ExploreValueKind.flag => const {ClauseOp.eq},
    ExploreValueKind.typeName => const {ClauseOp.eq, ClauseOp.inList},
  };

  /// Whether a grounded value is plausible: the registry's sanity, else
  /// [bounds], else any non-negative number.
  bool accepts(double v) {
    final range = field?.sanity ?? bounds;
    if (range != null) return v >= range.min && v <= range.max;
    return v >= 0;
  }
}

/// Every field the model may name, in the prompt's order.
const List<ExploreField> kExploreFields = [
  ExploreField('depth', ['depth'], ExploreValueKind.number),
  ExploreField('avgDepth', ['avgDepth'], ExploreValueKind.number),
  ExploreField(
    'bottomTime',
    ['bottomTime'],
    ExploreValueKind.number,
    wholeNumbers: true,
    bounds: (min: 0, max: 24 * 60),
  ),
  ExploreField('waterTemp', ['waterTemp'], ExploreValueKind.number),
  ExploreField('airTemp', ['airTemp'], ExploreValueKind.number),
  ExploreField(
    'visibility',
    ['visibility'],
    ExploreValueKind.number,
    bounds: (min: 0, max: 200),
  ),
  ExploreField(
    'rating',
    ['rating'],
    ExploreValueKind.number,
    wholeNumbers: true,
  ),
  ExploreField(
    'o2',
    ['tanks', 'o2'],
    ExploreValueKind.number,
    bounds: (min: 1, max: 100),
  ),
  ExploreField('diveNumber', ['diveNumber'], ExploreValueKind.number),
  ExploreField('waterType', ['waterType'], ExploreValueKind.enumName),
  ExploreField('diveMode', ['diveMode'], ExploreValueKind.enumName),
  ExploreField('entryMethod', ['entryMethod'], ExploreValueKind.enumName),
  ExploreField('currentStrength', [
    'currentStrength',
  ], ExploreValueKind.enumName),
  ExploreField('favorite', ['favorite'], ExploreValueKind.flag),
  ExploreField('deco', ['deco'], ExploreValueKind.flag),
  ExploreField('noBuddy', ['buddies'], ExploreValueKind.flag),
  ExploreField(
    'weekday',
    ['weekday'],
    ExploreValueKind.enumName,
    tokens: kWeekdayTokens,
  ),
  ExploreField('diveType', ['types', 'name'], ExploreValueKind.typeName),
  ExploreField('sac', ['sac'], ExploreValueKind.number),
  ExploreField('sacTrend', ['sacTrend'], ExploreValueKind.enumName),
  ExploreField('sacChange', ['sacChange'], ExploreValueKind.number),
  ExploreField('finalStop', ['finalStop'], ExploreValueKind.enumName),
  ExploreField('finalStopExcursion', [
    'finalStopExcursion',
  ], ExploreValueKind.number),
  ExploreField('finalStopDuration', [
    'finalStopDuration',
  ], ExploreValueKind.number),
  ExploreField('finding', ['findings', 'rule'], ExploreValueKind.enumName),
];

ExploreField? exploreField(String name) {
  for (final f in kExploreFields) {
    if (f.name == name) return f;
  }
  return null;
}

/// A clause unit as the query language's unit, for a field of [dimension].
/// Divers drop "per minute", so a plain bar or psi said on a rate is the
/// rate. The volume rates (RMV) have no query unit; [unitFits] refuses them
/// on a SAC before grounding runs.
QueryUnit? queryUnitOf(ClauseUnit? unit, FieldDimension dimension) {
  if (dimension == FieldDimension.pressureRate) {
    return switch (unit) {
      ClauseUnit.bar || ClauseUnit.barMin => QueryUnit.barMin,
      ClauseUnit.psi || ClauseUnit.psiMin => QueryUnit.psiMin,
      _ => null,
    };
  }
  return switch (unit) {
    null => null,
    ClauseUnit.m => QueryUnit.m,
    ClauseUnit.ft => QueryUnit.ft,
    ClauseUnit.c => QueryUnit.c,
    ClauseUnit.f => QueryUnit.f,
    ClauseUnit.bar => QueryUnit.bar,
    ClauseUnit.psi => QueryUnit.psi,
    ClauseUnit.min => QueryUnit.min,
    ClauseUnit.barMin => QueryUnit.barMin,
    ClauseUnit.psiMin => QueryUnit.psiMin,
    ClauseUnit.lMin || ClauseUnit.cuftMin => null,
  };
}

/// A clause value in storage units: the unit said wins, a bare number takes
/// the diver's unit for [dimension], and a unitless field takes the number.
double groundClause(
  num value,
  ClauseUnit? unit,
  FieldDimension dimension,
  UnitPrefs prefs,
) => groundToStorage(value, queryUnitOf(unit, dimension), dimension, prefs);

/// The pressure unit a SAC was said in. Divers often drop "per minute", so
/// a plain bar or psi on a rate means bar/min or psi/min; no unit means the
/// diver's own.
PressureUnit rateUnitSaid(ClauseUnit? unit, UnitPrefs prefs) => switch (unit) {
  ClauseUnit.bar || ClauseUnit.barMin => PressureUnit.bar,
  ClauseUnit.psi || ClauseUnit.psiMin => PressureUnit.psi,
  _ => prefs.pressure,
};

/// Whether [unit] can be read on a field of [dimension]. A unit of another
/// kind (20 c on a depth, l/min on a SAC, which is RMV) would otherwise be
/// ignored and the number read in the diver's own unit, searching for the
/// wrong thing without saying so. No unit always fits, and a unitless field
/// takes whatever it is given, as it always has.
bool unitFits(FieldDimension dimension, ClauseUnit? unit) {
  if (unit == null) return true;
  return switch (dimension) {
    FieldDimension.percent ||
    FieldDimension.count ||
    FieldDimension.none => true,
    // The query unit the clause unit reads as on this field (a plain bar or
    // psi on a rate is the rate) must belong to the field's dimension. The
    // model has no weight or volume unit, so on such a field any unit said
    // is of another kind and refused; a bare number takes the diver's unit.
    _ => switch (queryUnitOf(unit, dimension)) {
      final q? => dimensionOfUnit(q) == dimension,
      null => false,
    },
  };
}
