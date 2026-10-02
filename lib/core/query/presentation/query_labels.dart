import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

/// What the editor widgets need to show a registry item to a person. The
/// core widgets never touch AppLocalizations; the feature layer implements
/// this over it (AppQueryLabels), tests over maps.
abstract class QueryLabels {
  String field(QueryField field);

  String relation(QueryRelation relation);

  /// The label for an entity, used for breadcrumbs in the field picker.
  String entity(QuerySubject subject);

  String op(QueryOp op);

  /// The label for one stored enum value of [field]; the stored name when
  /// the value is unknown.
  String enumValue(QueryField field, String value);
}

/// A [QueryLabels] over maps, for tests and previews. Keyed by field and
/// relation KEY (not label key), so a fixture whose label keys are all the
/// same can still name its fields; an unmapped item shows its key.
class MapQueryLabels implements QueryLabels {
  const MapQueryLabels({
    this.fields = const {},
    this.relations = const {},
    this.entities = const {},
    this.ops = const {},
    this.enums = const {},
  });

  final Map<String, String> fields;
  final Map<String, String> relations;
  final Map<QuerySubject, String> entities;
  final Map<QueryOp, String> ops;

  /// field key -> stored value -> label.
  final Map<String, Map<String, String>> enums;

  @override
  String field(QueryField field) => fields[field.key] ?? field.key;

  @override
  String relation(QueryRelation relation) =>
      relations[relation.key] ?? relation.key;

  @override
  String entity(QuerySubject subject) => entities[subject] ?? subject.name;

  @override
  String op(QueryOp op) => ops[op] ?? op.name;

  @override
  String enumValue(QueryField field, String value) =>
      enums[field.key]?[value] ?? value;
}
