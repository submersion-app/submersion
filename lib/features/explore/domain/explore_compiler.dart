import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/domain/entity_resolver.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

class ExploreCompilerContext {
  final UnitPrefs units;
  final NameIndex names;
  final DateTime now;
  const ExploreCompilerContext({
    required this.units,
    required this.names,
    required this.now,
  });
}

/// Numeric fields with no plain filter axis, lowered to inclusive bounds on
/// the dive query field of the same name. Values are metric, like the
/// registry's.
const Set<String> _numberQueryFields = {
  'avgDepth',
  'airTemp',
  'diveNumber',
  'sac',
  'sacChange',
  'finalStopExcursion',
  'finalStopDuration',
};

typedef _Lowered = ({DiveFilterState? filter, ClauseChip? chip, String? error});

_Lowered _fail(String error) => (filter: null, chip: null, error: error);

/// Deterministic lowering of a [ParsedQuery] to a [DiveFilterState].
///
/// The model chose the words; everything about units, names, ids and ranges
/// is decided here, so a canned JSON payload fully specifies the outcome.
abstract final class ExploreCompiler {
  static ExploreCompilation compile(
    ParsedQuery query,
    ExploreCompilerContext ctx,
  ) {
    if (query.subject != ParsedSubject.dives) {
      return ExploreCompilation(
        filter: const DiveFilterState(),
        chips: const [],
        unresolved: const [],
        unplaced: [
          UnplacedItem(query.subject.name, reason: 'subjectNotSupported'),
          for (final w in query.unplaced) UnplacedItem(w),
        ],
        charts: const [],
      );
    }

    final chips = <QueryChip>[];
    final unresolved = <UnresolvedMention>[];
    final unplaced = <UnplacedItem>[];
    var filter = const DiveFilterState();

    final numericFields = <String>[];
    for (var i = 0; i < query.clauses.length; i++) {
      final c = query.clauses[i];
      final r = _lowerClause(c, filter, ctx.units);
      if (r.error != null) {
        unplaced.add(UnplacedItem(c.text, reason: r.error));
        continue;
      }
      filter = r.filter!;
      chips.add(QueryChip(ref: ChipRef.clause, index: i, payload: r.chip!));
      if (r.chip!.dimension != FieldDimension.none) {
        numericFields.add(r.chip!.field.name);
      }
    }

    final entityIds = <MentionKind, Set<String>>{};
    for (var i = 0; i < query.mentions.length; i++) {
      final m = query.mentions[i];
      final res = resolveMention(m, ctx.names);
      switch (res) {
        case Resolved(:final entry):
          filter = _lowerMention(entry, filter);
          chips.add(
            QueryChip(
              ref: ChipRef.mention,
              index: i,
              payload: MentionChip(kind: m.kind, entry: entry),
            ),
          );
          entityIds.putIfAbsent(m.kind, () => {}).addAll(entry.ids);
        case Ambiguous(:final candidates):
          unresolved.add(
            UnresolvedMention(index: i, mention: m, candidates: candidates),
          );
        case Unresolved():
          unresolved.add(
            UnresolvedMention(
              index: i,
              mention: m,
              candidates: _nearest(m, ctx.names),
            ),
          );
      }
    }

    if (query.time != null) {
      final range = parseDateText(query.time!.text, now: ctx.now);
      if (range == null) {
        unplaced.add(UnplacedItem(query.time!.text, reason: 'unknownTime'));
      } else {
        filter = filter.copyWith(startDate: range.start, endDate: range.end);
        chips.add(
          QueryChip(
            ref: ChipRef.time,
            index: 0,
            payload: TimeChip(start: range.start, end: range.end),
          ),
        );
      }
    }

    for (final w in query.unplaced) {
      unplaced.add(UnplacedItem(w));
    }

    return ExploreCompilation(
      filter: filter,
      chips: chips,
      unresolved: unresolved,
      unplaced: unplaced,
      charts: selectCharts(
        numericFields: numericFields,
        resolvedEntityCounts: {
          for (final e in entityIds.entries) e.key: e.value.length,
        },
      ),
    );
  }

  /// Up to five labels above a loose similarity floor, offered as candidates
  /// for a mention the strict resolver could not place. Searches the same
  /// kinds the resolver does, so a misspelt place can suggest a site.
  static List<NameEntry> _nearest(QueryMention m, NameIndex names) {
    final q = normalize(m.text);
    final scored = <(NameEntry, double)>[];
    for (final e in [
      for (final k in mentionSearchKinds(m.kind)) ...entriesForKind(names, k),
    ]) {
      final s = diceCoefficient(q, normalize(e.label));
      if (s > 0.3) scored.add((e, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final seen = <String>{};
    return [
      for (final s in scored)
        if (seen.add(s.$1.identity)) s.$1,
    ].take(5).toList();
  }

  static _Lowered _lowerClause(
    QueryClause c,
    DiveFilterState f,
    UnitPrefs units,
  ) {
    final field = exploreField(c.field);
    if (field == null) return _fail('unknownField');
    if (!field.ops.contains(c.op)) return _fail('invalid');

    switch (field.kind) {
      case ExploreValueKind.number:
        return _lowerNumber(c, field, f, units);
      case ExploreValueKind.flag:
        return _lowerFlag(c, field, f);
      case ExploreValueKind.enumName:
      case ExploreValueKind.typeName:
        return _lowerEnum(c, field, f);
    }
  }

  static _Lowered _lowerFlag(
    QueryClause c,
    ExploreField field,
    DiveFilterState f,
  ) {
    final v = c.value;
    final on = v == true;
    final off = v == false;
    if (!on && !off) return _fail('invalid');
    DiveFilterState? next;
    switch (field.name) {
      case 'favorite':
        if (on) next = f.copyWith(favoritesOnly: true);
      case 'noBuddy':
        if (on) next = f.copyWith(noBuddyOnly: true);
      case 'deco':
        next = f.copyWith(decoOnly: on);
      default:
        break;
    }
    if (next == null) return _fail('invalid');
    return (
      filter: next,
      chip: ClauseChip(
        field: field,
        op: c.op,
        value: on,
        dimension: FieldDimension.none,
      ),
      error: null,
    );
  }

  static _Lowered _lowerEnum(
    QueryClause c,
    ExploreField field,
    DiveFilterState f,
  ) {
    final raw = c.value;
    final values = raw is List
        ? raw.whereType<String>().toList()
        : [if (raw is String) raw];
    if (values.isEmpty) return _fail('invalid');
    final chip = ClauseChip(
      field: field,
      op: c.op,
      value: values,
      dimension: FieldDimension.none,
    );
    final allowed = field.enumValues;
    if (allowed == null) {
      // A dive type is the diver's own entity, named in their words: an
      // exact (case-insensitive) match on any of the names through the
      // types junction, which the query compiler emits as one LOWER IN.
      if (field.name != 'diveType') return _fail('invalid');
      return (
        filter: _andQuery(
          f,
          ConditionNode(
            FieldPath(['types', 'name']),
            QueryOp.inList,
            ListValue([for (final v in values) StringValue(v)]),
          ),
        ),
        chip: chip,
        error: null,
      );
    }
    if (values.any((v) => !allowed.contains(v))) return _fail('invalid');
    // Every enum field lowers onto its registry path (a finding onto the
    // rule of the dive's findings); its values come from the registry.
    final key = field.name;
    // "Not" keeps the dives where the field was never recorded: the query
    // tree's NOT treats an unknown as not matching, where the complement of
    // the listed values would silently drop every blank dive.
    if (c.op == ClauseOp.not) {
      return (
        filter: _andQuery(f, NotNode(_enumCondition(field, key, values))),
        chip: chip,
        error: null,
      );
    }
    // Each clause is its own condition, ANDed with the rest. The first
    // water-type or weekday clause uses the plain filter axis; a second one
    // on the same field must not merge into that axis, whose values OR.
    switch (field.name) {
      case 'waterType' when f.waterTypes.isEmpty:
        final types = values.map((v) => WaterType.values.byName(v)).toList();
        return (filter: f.copyWith(waterTypes: types), chip: chip, error: null);
      case 'weekday' when f.weekdays.isEmpty:
        final days = values.map((v) => kWeekdayTokens.indexOf(v) + 1).toList();
        return (filter: f.copyWith(weekdays: days), chip: chip, error: null);
      default:
        return (
          filter: _andQuery(f, _enumCondition(field, key, values)),
          chip: chip,
          error: null,
        );
    }
  }

  /// Membership in [values] on the dive query field [key]. Weekday tokens
  /// map to the registry's own weekday names, which run Monday first too.
  static ConditionNode _enumCondition(
    ExploreField field,
    String key,
    List<String> values,
  ) {
    final names = field.name == 'weekday'
        ? [
            for (final v in values)
              diveQueryEntity.field(key)!.enumValues![kWeekdayTokens.indexOf(
                v,
              )],
          ]
        : values;
    return ConditionNode(
      FieldPath(field.path),
      QueryOp.inList,
      ListValue([for (final n in names) EnumValue(n)]),
    );
  }

  static _Lowered _lowerNumber(
    QueryClause c,
    ExploreField field,
    DiveFilterState f,
    UnitPrefs units,
  ) {
    if (!unitFits(field.dimension, c.unit)) return _fail('invalid');
    final rate = field.dimension == FieldDimension.pressureRate;
    // A rate keeps four decimals: psi/min bounds half a psi apart are only
    // 0.07 bar/min apart, and two decimals would round them together.
    double ground(num v) => double.parse(
      groundClause(
        v,
        c.unit,
        field.dimension,
        units,
      ).toStringAsFixed(rate ? 4 : 2),
    );
    double? lo;
    double? hi;
    Object chipValue;
    if (c.op == ClauseOp.between) {
      final raw = c.value;
      if (raw is! List || raw.length != 2 || raw.any((v) => v is! num)) {
        return _fail('invalid');
      }
      var a = ground(raw[0] as num);
      var b = ground(raw[1] as num);
      if (b < a) (a, b) = (b, a);
      if (!field.accepts(a) || !field.accepts(b)) {
        return _fail('outOfRange');
      }
      lo = a;
      hi = b;
      chipValue = [a, b];
    } else {
      final raw = c.value;
      if (raw is! num) return _fail('invalid');
      final v = ground(raw);
      chipValue = v;
      // The number said is what must be plausible; an "exactly" band may
      // reach half a unit past the bound.
      if (!field.accepts(v)) return _fail('outOfRange');
      switch (c.op) {
        case ClauseOp.lt:
        case ClauseOp.lte:
          hi = v;
        case ClauseOp.gt:
        case ClauseOp.gte:
          lo = v;
        case ClauseOp.eq:
          // A measured value is almost never exactly the number said, so
          // "exactly 15 m" is the half unit either side of it in the unit
          // the diver used, the way it would be rounded. SAC is read to a
          // tenth of a bar or a whole psi, so "a SAC of 1.2" is 1.15 to 1.25
          // bar/min and "20 psi/min" is 19.5 to 20.5. Counts stay exact.
          final half = switch (field.dimension) {
            FieldDimension.depth || FieldDimension.temperature => 0.5,
            FieldDimension.pressureRate =>
              rateUnitSaid(c.unit, units) == PressureUnit.psi ? 0.5 : 0.05,
            _ => 0.0,
          };
          lo = half == 0 ? v : ground(raw - half);
          hi = half == 0 ? v : ground(raw + half);
        default:
          return _fail('invalid');
      }
    }
    // The chip reports the op the filter ACTUALLY applies, not the one the
    // model wrote. Every numeric axis is an inclusive bound, so a strict
    // "deeper than 20" lowers to "at least 20": showing the diver "over 20 m"
    // while matching a 20 m dive would make the chip a small lie, and the
    // chip is the whole point of the feature.
    final chip = ClauseChip(
      field: field,
      op: switch (c.op) {
        ClauseOp.gt => ClauseOp.gte,
        ClauseOp.lt => ClauseOp.lte,
        _ => c.op,
      },
      value: chipValue,
      dimension: field.dimension,
    );
    switch (field.name) {
      case 'depth':
        return (
          filter: f.copyWith(minDepth: lo, maxDepth: hi),
          chip: chip,
          error: null,
        );
      case 'waterTemp':
        return (
          filter: f.copyWith(minWaterTemp: lo, maxWaterTemp: hi),
          chip: chip,
          error: null,
        );
      case 'visibility':
        return (
          filter: f.copyWith(minVisibility: lo, maxVisibility: hi),
          chip: chip,
          error: null,
        );
      case 'o2':
        return (
          filter: f.copyWith(minO2Percent: lo, maxO2Percent: hi),
          chip: chip,
          error: null,
        );
      case 'bottomTime':
        return (
          filter: f.copyWith(
            minBottomTimeMinutes: lo?.round(),
            maxBottomTimeMinutes: hi?.round(),
          ),
          chip: chip,
          error: null,
        );
      case 'rating':
        // The filter has only a minimum rating, so an upper bound is an
        // exact condition in the query tree. Without it "between 3 and 4"
        // and "exactly 4" would both match every rating from the lower bound
        // up, while the chip claimed the range.
        var next = lo == null ? f : f.copyWith(minRating: lo.round());
        if (hi != null) {
          next = _andQuery(
            next,
            ConditionNode(
              FieldPath(['rating']),
              QueryOp.lte,
              NumberValue(hi, null),
            ),
          );
        }
        return (filter: next, chip: chip, error: null);
      default:
        final key = _numberQueryFields.contains(field.name) ? field.name : null;
        if (key == null) return _fail('noAxis');
        var next = f;
        if (lo != null) {
          next = _andQuery(
            next,
            ConditionNode(FieldPath([key]), QueryOp.gte, NumberValue(lo, null)),
          );
        }
        if (hi != null) {
          next = _andQuery(
            next,
            ConditionNode(FieldPath([key]), QueryOp.lte, NumberValue(hi, null)),
          );
        }
        return (filter: next, chip: chip, error: null);
    }
  }

  /// [node] ANDed into the filter's query tree, flattening a top-level AND.
  static DiveFilterState _andQuery(DiveFilterState f, QueryNode node) {
    final current = f.query;
    final next = switch (current) {
      null => node,
      AndNode(:final children) => AndNode([...children, node]),
      _ => AndNode([current, node]),
    };
    return f.copyWith(query: next);
  }

  static DiveFilterState _lowerMention(NameEntry e, DiveFilterState f) {
    switch (e.target) {
      case NameTarget.siteId:
      case NameTarget.sitePlace:
        return f.copyWith(siteIds: [...f.siteIds, ...e.ids]);
      case NameTarget.speciesId:
        return f.copyWith(speciesIds: [...f.speciesIds, ...e.ids]);
      case NameTarget.equipmentId:
        return f.copyWith(equipmentIds: [...f.equipmentIds, ...e.ids]);
      case NameTarget.attrChoice:
        return f.copyWith(
          equipmentAttrConditions: [
            ...f.equipmentAttrConditions,
            EquipmentAttrCondition(key: e.attrKey!, choices: {e.attrChoice!}),
          ],
        );
      // Every resolved buddy is an EXACT match. The first uses the plain
      // buddy axis; each further one ANDs an exact condition into the query
      // tree. The name filter is a substring search split on commas, so it
      // would let "Ana" match Diana and break "Smith, John" in two.
      case NameTarget.buddyId:
        if (f.buddyId == null) return f.copyWith(buddyId: e.ids.single);
        return _andQuery(
          f,
          ConditionNode(
            FieldPath(['buddies']),
            QueryOp.eq,
            RefValue(e.ids.single, e.label),
          ),
        );
      case NameTarget.legacyBuddyName:
        // The label IS a whole stored `dives.buddy` value, so equality
        // (case-insensitive in the compiler) is exact.
        return _andQuery(
          f,
          ConditionNode(
            FieldPath(['legacyBuddy']),
            QueryOp.eq,
            StringValue(e.label),
          ),
        );
      case NameTarget.tagId:
        return f.copyWith(tagIds: [...f.tagIds, ...e.ids]);
      case NameTarget.centerId:
        return f.copyWith(diveCenterId: e.ids.single);
      case NameTarget.tripId:
        return f.copyWith(tripId: e.ids.single);
      case NameTarget.computerId:
        return f.copyWith(computerId: e.ids.single);
      // Typed-query rows: a sentence's mention kinds never resolve to these.
      case NameTarget.siteTypeId ||
          NameTarget.courseId ||
          NameTarget.diveTypeId ||
          NameTarget.row:
        return f;
    }
  }
}
