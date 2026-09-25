import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// Lowers the sheet's filter model to the query tree the compiler reads.
///
/// This is the ONLY evaluator of a DiveFilterState (#2365): the paginated
/// list, its count, Statistics and the entity views all compile the tree
/// this returns. A field added to DiveFilterState and not named here fails
/// `dive_filter_query_census_test`.
extension DiveFilterQuery on DiveFilterState {
  QueryNode? toQuery() {
    final parts = <QueryNode>[];
    QueryNode c(String key, QueryOp op, QueryValue? v) =>
        ConditionNode(FieldPath([key]), op, v);
    RefValue ref(String id) => RefValue(id, id);
    ListValue refs(List<String> ids) =>
        ListValue([for (final id in ids) ref(id)]);

    if (startDate != null) {
      parts.add(c('date', QueryOp.gte, DateValue(startDate!)));
    }
    if (endDate != null) {
      parts.add(c('date', QueryOp.lte, DateValue(endDate!)));
    }
    if (weekdays.isNotEmpty) {
      const names = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      parts.add(
        c(
          'weekday',
          QueryOp.inList,
          ListValue([for (final w in weekdays) EnumValue(names[w - 1])]),
        ),
      );
    }
    if (diveTypeId != null) parts.add(c('types', QueryOp.eq, ref(diveTypeId!)));
    if (siteId != null) parts.add(c('site', QueryOp.eq, ref(siteId!)));
    if (tripId != null) parts.add(c('trip', QueryOp.eq, ref(tripId!)));
    if (diveCenterId != null) {
      parts.add(c('center', QueryOp.eq, ref(diveCenterId!)));
    }
    if (computerId != null) {
      parts.add(c('computer', QueryOp.eq, ref(computerId!)));
    }
    if (minDepth != null) {
      parts.add(c('depth', QueryOp.gte, NumberValue(minDepth!, null)));
    }
    if (maxDepth != null) {
      parts.add(c('depth', QueryOp.lte, NumberValue(maxDepth!, null)));
    }
    if (minO2Percent != null || maxO2Percent != null) {
      parts.add(
        ScopedNode(
          const FieldPath(['tanks']),
          AndNode([
            if (minO2Percent != null)
              c('o2', QueryOp.gte, NumberValue(minO2Percent!, null)),
            if (maxO2Percent != null)
              c('o2', QueryOp.lte, NumberValue(maxO2Percent!, null)),
          ]),
        ),
      );
    }
    if (minRating != null) {
      parts.add(
        c('rating', QueryOp.gte, NumberValue(minRating!.toDouble(), null)),
      );
    }
    if (minBottomTimeMinutes != null) {
      parts.add(
        c(
          'bottomTime',
          QueryOp.gte,
          NumberValue(minBottomTimeMinutes!.toDouble(), null),
        ),
      );
    }
    if (maxBottomTimeMinutes != null) {
      parts.add(
        c(
          'bottomTime',
          QueryOp.lte,
          NumberValue(maxBottomTimeMinutes!.toDouble(), null),
        ),
      );
    }
    if (favoritesOnly == true) {
      parts.add(c('favorite', QueryOp.eq, const BoolValue(true)));
    }
    if (excludedFromStatsOnly == true) {
      parts.add(c('excludedFromStats', QueryOp.eq, const BoolValue(true)));
    }
    if (decoOnly != null) {
      parts.add(c('deco', QueryOp.eq, BoolValue(decoOnly!)));
    }
    if (noBuddyOnly == true) parts.add(c('buddies', QueryOp.isEmpty, null));
    if (tagIds.isNotEmpty) parts.add(c('tags', QueryOp.inList, refs(tagIds)));
    if (equipmentIds.isNotEmpty) {
      parts.add(c('gear', QueryOp.inList, refs(equipmentIds)));
    }
    if (diveIds.isNotEmpty) {
      parts.add(
        c(
          'id',
          QueryOp.inList,
          ListValue([for (final id in diveIds) StringValue(id)]),
        ),
      );
    }
    if (buddyId != null) parts.add(c('buddies', QueryOp.eq, ref(buddyId!)));
    final names = (buddyNameFilter ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final name in names) {
      parts.add(
        OrNode([
          ScopedNode(
            const FieldPath(['buddies']),
            c('name', QueryOp.contains, StringValue(name)),
          ),
          c('legacyBuddy', QueryOp.contains, StringValue(name)),
        ]),
      );
    }
    if (customFieldKey != null && customFieldKey!.isNotEmpty) {
      parts.add(
        ScopedNode(
          const FieldPath(['customFields']),
          AndNode([
            c('key', QueryOp.eq, StringValue(customFieldKey!)),
            if (customFieldValue != null && customFieldValue!.isNotEmpty)
              c('value', QueryOp.contains, StringValue(customFieldValue!)),
          ]),
        ),
      );
    }
    for (final cond in equipmentAttrConditions) {
      parts.add(_attrCondition(cond));
    }
    if (query != null) parts.add(query!);
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : AndNode(parts);
  }
}

/// One curated attribute condition: a linked item (or transmitter-matched
/// cylinder) of one of [EquipmentAttrCondition.types] carrying a curated
/// row for the key whose text is one of the choices and whose number is in
/// range. Same rules as the retired `equipmentAttrConditionSql`.
QueryNode _attrCondition(EquipmentAttrCondition cond) {
  QueryNode c(String key, QueryOp op, QueryValue v) =>
      ConditionNode(FieldPath([key]), op, v);
  final types = cond.types.map((t) => t.name).toList()..sort();
  final choices = cond.choices.toList()..sort();
  return ScopedNode(
    const FieldPath(['gear']),
    AndNode([
      if (types.isNotEmpty)
        c(
          'type',
          QueryOp.inList,
          ListValue([for (final t in types) EnumValue(t)]),
        ),
      ScopedNode(
        const FieldPath(['attributes']),
        AndNode([
          c('key', QueryOp.eq, StringValue(cond.key)),
          c('custom', QueryOp.eq, const BoolValue(false)),
          if (choices.isNotEmpty)
            c(
              'valueText',
              QueryOp.inList,
              ListValue([for (final ch in choices) StringValue(ch)]),
            ),
          if (cond.min != null)
            c('valueNum', QueryOp.gte, NumberValue(cond.min!, null)),
          if (cond.max != null)
            c('valueNum', QueryOp.lte, NumberValue(cond.max!, null)),
        ]),
      ),
    ]),
  );
}

/// The one compile call every dive path shares.
CompiledQuery compileDiveFilter(
  DiveFilterState filter, {
  String rootAlias = 'r0',
}) => compileQuery(
  filter.toQuery(),
  diveQueryEntity,
  appQueryRegistry,
  rootAlias: rootAlias,
);

Set<String> diveFilterTablesTouched(DiveFilterState filter) =>
    compileDiveFilter(filter).tablesTouched;
