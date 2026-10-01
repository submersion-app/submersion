import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/query/equipment_attr_condition_query.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// Whether a mention resolved to [target] names the subject's own rows,
/// lowering onto the subject itself. Every other mention is about the
/// subject's dives. A place names a site's location under sites, and a
/// center's location under centers.
bool ownsTarget(ParsedSubject subject, NameTarget target) => switch (subject) {
  ParsedSubject.dives => false,
  ParsedSubject.sites =>
    target == NameTarget.siteId || target == NameTarget.sitePlace,
  ParsedSubject.equipment =>
    target == NameTarget.equipmentId || target == NameTarget.attrChoice,
  ParsedSubject.buddies => target == NameTarget.buddyId,
  ParsedSubject.species => target == NameTarget.speciesId,
  ParsedSubject.trips => target == NameTarget.tripId,
  ParsedSubject.centers =>
    target == NameTarget.centerId || target == NameTarget.sitePlace,
};

/// The subject's own mentions as conditions on its rows. A named row is
/// matched by its stored name (no registry entity has an id field), so two
/// rows sharing a name both match. Rows and places OR together, as a
/// dive's sites and places do; an attribute choice is its own condition.
List<QueryNode> lowerOwnMentions(
  ParsedSubject subject,
  List<NameEntry> entries,
  NameIndex names,
) {
  final out = <QueryNode>[];
  final rowNames = <String>{};
  final places = <QueryNode>[];
  for (final e in entries) {
    switch (e.target) {
      case NameTarget.sitePlace when subject == ParsedSubject.centers:
        for (final column in const ['country', 'city', 'stateProvince']) {
          places.add(
            ConditionNode(
              FieldPath([column]),
              QueryOp.eq,
              StringValue(e.label),
            ),
          );
        }
      case NameTarget.sitePlace when e.placeFields.isNotEmpty:
        for (final column in e.placeFields) {
          places.add(
            ConditionNode(
              FieldPath([column]),
              QueryOp.eq,
              StringValue(e.label),
            ),
          );
        }
      case NameTarget.attrChoice:
        out.add(
          equipmentAttrConditionNode(
            EquipmentAttrCondition(key: e.attrKey!, choices: {e.attrChoice!}),
          ),
        );
      default:
        // A row of the subject's kind, or a place with no recorded columns
        // (an index built by hand): its rows by their stored names.
        for (final id in e.ids) {
          rowNames.add(names.labelOf(e.subject, id) ?? e.label);
        }
    }
  }
  final parts = <QueryNode>[
    if (rowNames.isNotEmpty)
      ConditionNode(
        FieldPath(['name']),
        QueryOp.inList,
        ListValue([for (final n in rowNames) StringValue(n)]),
      ),
    ...places,
  ];
  if (parts.isNotEmpty) {
    out.add(parts.length == 1 ? parts.single : OrNode(parts));
  }
  return out;
}

/// The trips a period touches: starting on or before its last day and
/// ending on or after its first.
List<QueryNode> lowerTripTime(DateTime? start, DateTime? end) => [
  if (end != null)
    ConditionNode(FieldPath(['startDate']), QueryOp.lte, DateValue(end)),
  if (start != null)
    ConditionNode(FieldPath(['endDate']), QueryOp.gte, DateValue(start)),
];

/// The subject's counted dives matching [parts]: neither planned nor
/// excluded from statistics, as the dive counts and the site list's own
/// "has dives" are.
QueryNode countedDives(List<QueryNode> parts) => ScopedNode(
  FieldPath(['dives']),
  AndNode([
    ConditionNode(FieldPath(['planned']), QueryOp.eq, const BoolValue(false)),
    ConditionNode(
      FieldPath(['excludedFromStats']),
      QueryOp.eq,
      const BoolValue(false),
    ),
    ...parts,
  ]),
);
