import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/query/equipment_attr_condition_query.dart';

/// The resolved mentions as query nodes, grouped by kind (#2365 PR 5).
/// Sites and places OR into one node; species, gear items, tags, centers,
/// trips and computers each OR into one membership; every buddy, legacy
/// buddy name and attribute choice is its own condition, ANDed.
List<QueryNode> lowerMentions(List<NameEntry> resolved, NameIndex names) {
  // A ref prints the row's primary name; an index without one (built by
  // hand) falls back to the label the mention resolved to, never the id.
  final spoken = <String, String>{
    for (final e in resolved)
      if (e.target.isRow) e.ids.single: e.label,
  };
  RefValue ref(QuerySubject s, String id) =>
      RefValue(id, names.labelOf(s, id) ?? spoken[id] ?? id);
  ListValue refs(QuerySubject s, Iterable<String> ids) => ListValue([
    for (final id in {...ids}) ref(s, id),
  ]);
  final out = <QueryNode>[];

  // A place with no recorded columns (an index built by hand) falls back to
  // its site ids, so it narrows the dives instead of vanishing.
  final siteIds = [
    for (final e in resolved)
      if (e.target == NameTarget.siteId ||
          (e.target == NameTarget.sitePlace && e.placeFields.isEmpty))
        ...e.ids,
  ];
  final places = [
    for (final e in resolved)
      if (e.target == NameTarget.sitePlace && e.placeFields.isNotEmpty) e,
  ];
  final siteParts = <QueryNode>[
    if (siteIds.isNotEmpty)
      ConditionNode(
        FieldPath(['site']),
        QueryOp.inList,
        refs(QuerySubject.sites, siteIds),
      ),
    for (final p in places)
      for (final column in p.placeFields)
        ConditionNode(
          FieldPath(['site', column]),
          QueryOp.eq,
          StringValue(p.label),
        ),
  ];
  if (siteParts.isNotEmpty) {
    out.add(siteParts.length == 1 ? siteParts.single : OrNode(siteParts));
  }

  void membership(NameTarget target, QuerySubject subject, List<String> path) {
    final ids = [
      for (final e in resolved)
        if (e.target == target) ...e.ids,
    ];
    if (ids.isEmpty) return;
    out.add(ConditionNode(FieldPath(path), QueryOp.inList, refs(subject, ids)));
  }

  membership(NameTarget.speciesId, QuerySubject.species, [
    'sightings',
    'species',
  ]);
  membership(NameTarget.equipmentId, QuerySubject.equipment, ['gear']);
  membership(NameTarget.tagId, QuerySubject.tags, ['tags']);
  membership(NameTarget.centerId, QuerySubject.centers, ['center']);
  membership(NameTarget.tripId, QuerySubject.trips, ['trip']);
  membership(NameTarget.computerId, QuerySubject.computers, ['computer']);

  for (final e in resolved) {
    switch (e.target) {
      case NameTarget.attrChoice:
        out.add(
          ScopedNode(
            FieldPath(['gear']),
            equipmentAttrConditionNode(
              EquipmentAttrCondition(key: e.attrKey!, choices: {e.attrChoice!}),
            ),
          ),
        );
      case NameTarget.buddyId:
        out.add(
          ConditionNode(
            FieldPath(['buddies']),
            QueryOp.eq,
            ref(QuerySubject.buddies, e.ids.single),
          ),
        );
      case NameTarget.legacyBuddyName:
        out.add(
          ConditionNode(
            FieldPath(['legacyBuddy']),
            QueryOp.eq,
            StringValue(e.label),
          ),
        );
      default:
        break;
    }
  }
  return out;
}

/// A time phrase's bounds, as the date filter lowered them.
List<QueryNode> lowerTime(DateTime? start, DateTime? end) => [
  if (start != null)
    ConditionNode(FieldPath(['date']), QueryOp.gte, DateValue(start)),
  if (end != null)
    ConditionNode(FieldPath(['date']), QueryOp.lte, DateValue(end)),
];
