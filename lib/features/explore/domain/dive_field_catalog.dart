import 'package:submersion/core/constants/enums.dart';
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

/// The weekday tokens the model writes, Monday first: a token's index plus
/// one is its [DateTime.weekday]. The one list every weekday mapping reads.
const List<String> kWeekdayTokens = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

List<String> _names(List<Enum> values) => [for (final v in values) v.name];

/// The fields the native schema constrains a dive clause to (schema v1).
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
  diveType('diveType');

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
const FieldSpec _flag = FieldSpec(
  dimension: FieldDimension.none,
  valueType: FieldValueType.flag,
  ops: {ClauseOp.eq},
);

abstract final class DiveFieldCatalog {
  // Enum values are the Dart enums' names, which are also the dive query
  // registry's, so a value added to an enum reaches Explore unedited.
  static final Map<ExploreDiveField, FieldSpec> _specs = {
    ExploreDiveField.depth: _depth,
    ExploreDiveField.avgDepth: _depth,
    ExploreDiveField.bottomTime: const FieldSpec(
      dimension: FieldDimension.minutes,
      valueType: FieldValueType.number,
      ops: _ordering,
    ),
    ExploreDiveField.waterTemp: _temperature,
    ExploreDiveField.airTemp: _temperature,
    ExploreDiveField.visibility: _depth,
    ExploreDiveField.rating: _number,
    ExploreDiveField.o2: const FieldSpec(
      dimension: FieldDimension.percent,
      valueType: FieldValueType.number,
      ops: _ordering,
    ),
    ExploreDiveField.diveNumber: _number,
    ExploreDiveField.waterType: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: _names(WaterType.values),
    ),
    ExploreDiveField.diveMode: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: _names(DiveMode.values),
    ),
    ExploreDiveField.entryMethod: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: _names(EntryMethod.values),
    ),
    ExploreDiveField.currentStrength: FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: _names(CurrentStrength.values),
    ),
    ExploreDiveField.favorite: _flag,
    ExploreDiveField.deco: _flag,
    ExploreDiveField.noBuddy: _flag,
    ExploreDiveField.weekday: const FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: _membership,
      enumValues: kWeekdayTokens,
    ),
    ExploreDiveField.diveType: const FieldSpec(
      dimension: FieldDimension.none,
      valueType: FieldValueType.enumName,
      ops: {ClauseOp.eq, ClauseOp.inList},
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
