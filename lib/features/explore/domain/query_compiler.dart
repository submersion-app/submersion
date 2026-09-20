import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/entity_resolver.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/domain/time_grammar.dart';
import 'package:submersion/features/explore/domain/unit_grounding.dart';

class CompilerContext {
  final UnitPrefs units;
  final NameIndex names;
  final DateTime now;
  const CompilerContext({
    required this.units,
    required this.names,
    required this.now,
  });
}

const Map<String, int> _weekdayNumbers = {
  'mon': 1,
  'tue': 2,
  'wed': 3,
  'thu': 4,
  'fri': 5,
  'sat': 6,
  'sun': 7,
};

typedef _Lowered = ({DiveFilterState? filter, ClauseChip? chip, String? error});

_Lowered _fail(String error) => (filter: null, chip: null, error: error);

/// Deterministic lowering of a [ParsedQuery] to a [DiveFilterState].
///
/// The model chose the words; everything about units, names, ids and ranges
/// is decided here, so a canned JSON payload fully specifies the outcome.
abstract final class QueryCompiler {
  static CompiledQuery compile(ParsedQuery query, CompilerContext ctx) {
    if (query.subject != QuerySubject.dives) {
      return CompiledQuery(
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

    final numericFields = <ExploreDiveField>[];
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
        numericFields.add(r.chip!.field);
      }
    }

    final entityIds = <MentionKind, Set<String>>{};
    final buddyLabels = <String>[];
    for (var i = 0; i < query.mentions.length; i++) {
      final m = query.mentions[i];
      final res = resolveMention(m, ctx.names);
      switch (res) {
        case Resolved(:final entry):
          filter = _lowerMention(entry, filter, buddyLabels);
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
      final range = parseTimeText(query.time!.text, now: ctx.now);
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

    return CompiledQuery(
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

  /// Up to five same-kind labels above a loose similarity floor, offered as
  /// candidates for a mention the strict resolver could not place.
  static List<NameEntry> _nearest(QueryMention m, NameIndex names) {
    final q = normalize(m.text);
    final scored = <(NameEntry, double)>[];
    for (final e in names.forKind(m.kind)) {
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
    final field = DiveFieldCatalog.parse(c.field);
    if (field == null) return _fail('unknownField');
    final spec = DiveFieldCatalog.spec(field);
    if (!spec.ops.contains(c.op)) return _fail('invalid');

    switch (spec.valueType) {
      case FieldValueType.number:
        return _lowerNumber(c, field, spec, f, units);
      case FieldValueType.flag:
        return _lowerFlag(c, field, f);
      case FieldValueType.enumName:
        return _lowerEnum(c, field, spec, f);
    }
  }

  static _Lowered _lowerFlag(
    QueryClause c,
    ExploreDiveField field,
    DiveFilterState f,
  ) {
    final v = c.value;
    final on = v == true;
    final off = v == false;
    if (!on && !off) return _fail('invalid');
    DiveFilterState? next;
    switch (field) {
      case ExploreDiveField.favorite:
        if (on) next = f.copyWith(favoritesOnly: true);
      case ExploreDiveField.noBuddy:
        if (on) next = f.copyWith(noBuddyOnly: true);
      case ExploreDiveField.deco:
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
    ExploreDiveField field,
    FieldSpec spec,
    DiveFilterState f,
  ) {
    final raw = c.value;
    final values = raw is List
        ? raw.whereType<String>().toList()
        : [if (raw is String) raw];
    if (values.isEmpty) return _fail('invalid');
    final allowed = spec.enumValues;
    if (allowed == null) return _fail('noAxis');
    if (values.any((v) => !allowed.contains(v))) return _fail('invalid');
    final chosen = c.op == ClauseOp.not
        ? allowed.where((v) => !values.contains(v)).toList()
        : values;
    final chip = ClauseChip(
      field: field,
      op: c.op,
      value: values,
      dimension: FieldDimension.none,
    );
    switch (field) {
      case ExploreDiveField.waterType:
        final types = chosen.map((v) => WaterType.values.byName(v)).toList();
        return (
          filter: f.copyWith(waterTypes: [...f.waterTypes, ...types]),
          chip: chip,
          error: null,
        );
      case ExploreDiveField.weekday:
        final days = chosen.map((v) => _weekdayNumbers[v]!).toList();
        return (
          filter: f.copyWith(weekdays: [...f.weekdays, ...days]),
          chip: chip,
          error: null,
        );
      default:
        return _fail('noAxis');
    }
  }

  static _Lowered _lowerNumber(
    QueryClause c,
    ExploreDiveField field,
    FieldSpec spec,
    DiveFilterState f,
    UnitPrefs units,
  ) {
    double ground(num v) => double.parse(
      groundToMetric(v, c.unit, spec.dimension, units).toStringAsFixed(2),
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
      lo = a;
      hi = b;
      chipValue = [a, b];
    } else {
      final raw = c.value;
      if (raw is! num) return _fail('invalid');
      final v = ground(raw);
      chipValue = v;
      switch (c.op) {
        case ClauseOp.lt:
        case ClauseOp.lte:
          hi = v;
        case ClauseOp.gt:
        case ClauseOp.gte:
          lo = v;
        case ClauseOp.eq:
          lo = v;
          hi = v;
        default:
          return _fail('invalid');
      }
    }
    if (!_inRange(field, lo) || !_inRange(field, hi)) {
      return _fail('outOfRange');
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
      dimension: spec.dimension,
    );
    switch (field) {
      case ExploreDiveField.depth:
        return (
          filter: f.copyWith(minDepth: lo, maxDepth: hi),
          chip: chip,
          error: null,
        );
      case ExploreDiveField.waterTemp:
        return (
          filter: f.copyWith(minWaterTemp: lo, maxWaterTemp: hi),
          chip: chip,
          error: null,
        );
      case ExploreDiveField.visibility:
        return (
          filter: f.copyWith(minVisibility: lo, maxVisibility: hi),
          chip: chip,
          error: null,
        );
      case ExploreDiveField.o2:
        return (
          filter: f.copyWith(minO2Percent: lo, maxO2Percent: hi),
          chip: chip,
          error: null,
        );
      case ExploreDiveField.bottomTime:
        return (
          filter: f.copyWith(
            minBottomTimeMinutes: lo?.round(),
            maxBottomTimeMinutes: hi?.round(),
          ),
          chip: chip,
          error: null,
        );
      case ExploreDiveField.rating:
        if (lo == null) return _fail('invalid');
        return (
          filter: f.copyWith(minRating: lo.round()),
          chip: chip,
          error: null,
        );
      default:
        return _fail('noAxis');
    }
  }

  static bool _inRange(ExploreDiveField field, double? v) {
    if (v == null) return true;
    return switch (field) {
      ExploreDiveField.depth || ExploreDiveField.avgDepth => v >= 0 && v <= 350,
      ExploreDiveField.waterTemp ||
      ExploreDiveField.airTemp => v >= -5 && v <= 45,
      ExploreDiveField.visibility => v >= 0 && v <= 200,
      ExploreDiveField.rating => v >= 1 && v <= 5,
      ExploreDiveField.o2 => v >= 1 && v <= 100,
      ExploreDiveField.bottomTime => v >= 0 && v <= 24 * 60,
      _ => v >= 0,
    };
  }

  static DiveFilterState _lowerMention(
    NameEntry e,
    DiveFilterState f,
    List<String> buddyLabels,
  ) {
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
      case NameTarget.buddyId:
        if (f.buddyId == null && buddyLabels.isEmpty) {
          buddyLabels.add(e.label);
          return f.copyWith(buddyId: e.ids.single);
        }
        buddyLabels.add(e.label);
        return f.copyWith(buddyNameFilter: buddyLabels.join(', '));
      case NameTarget.legacyBuddyName:
        buddyLabels.add(e.label);
        return f.copyWith(buddyNameFilter: buddyLabels.join(', '));
      case NameTarget.tagId:
        return f.copyWith(tagIds: [...f.tagIds, ...e.ids]);
      case NameTarget.centerId:
        return f.copyWith(diveCenterId: e.ids.single);
      case NameTarget.tripId:
        return f.copyWith(tripId: e.ids.single);
      case NameTarget.computerId:
        return f.copyWith(computerId: e.ids.single);
    }
  }
}
