import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// How long a diver and agent have between a preview and its apply.
const kWritePlanLifetime = Duration(minutes: 15);

/// One field a plan changes. Both values are as the agent would read them.
class FieldChange {
  const FieldChange(this.oldValue, this.newValue, {this.indirect = false});

  final Object? oldValue;
  final Object? newValue;

  /// Follows from another change in the plan rather than being asked for.
  final bool indirect;

  Map<String, Object?> toJson() => {
    'old': oldValue,
    'new': newValue,
    if (indirect) 'indirect': true,
  };
}

/// One record a plan touches, or would touch but for [block].
class PlanItem {
  const PlanItem({
    required this.operation,
    required this.kind,
    required this.entity,
    this.id,
    this.diverId,
    this.title,
    this.fields = const {},
    this.values = const {},
    this.relations = const {},
    this.indirectRelations = const {},
    this.names = const {},
    this.date,
    this.reach = const DeleteReach(),
    this.block,
  });

  /// The request's index for this change.
  final int operation;
  final ChangeKind kind;
  final String entity;

  /// Null for a record that does not exist yet.
  final String? id;
  final String? diverId;

  /// The record's own name, for the diver to recognise it.
  final String? title;
  final Map<String, FieldChange> fields;

  /// The parsed new values, which the write uses.
  final Map<String, Object?> values;
  final Map<String, RelationDelta> relations;

  /// Links a repository adds because of another change. Listed, not written:
  /// the write that causes them makes them.
  final Map<String, Set<String>> indirectRelations;

  /// The names of the records [relations] refers to, by id.
  final Map<String, String> names;

  /// The record's date, when it has one, as a document writes it.
  final String? date;

  /// What a delete takes with it.
  final DeleteReach reach;
  final PlanBlock? block;

  Map<String, Object?> toJson() => {
    'operation': operation,
    'kind': kind.name,
    'entity': entity,
    'id': id ?? 'new',
    'diver_id': diverId,
    'title': ?title,
    if (fields.isNotEmpty)
      'fields': {
        for (final MapEntry(:key, :value) in fields.entries)
          key: value.toJson(),
      },
    if (relations.isNotEmpty)
      'relations': {
        for (final MapEntry(:key, :value) in relations.entries)
          key: {'add': value.add.toList(), 'remove': value.remove.toList()},
      },
    if (indirectRelations.isNotEmpty)
      'indirect_relations': {
        for (final MapEntry(:key, :value) in indirectRelations.entries)
          key: {'add': value.toList()},
      },
    if (!reach.isEmpty)
      'also_reaches': {
        'linked_dives_by_diver': reach.linkedDives,
        'deleted_records': {...reach.records, ...reach.parts},
        'unlinked_records': reach.unlinked,
      },
    if (block case final block?)
      'blocked': {'reason': block.reason.wire, 'detail': block.detail},
  };
}

/// A record a change set named and would not change.
class UnchangedRecord {
  const UnchangedRecord({
    required this.operation,
    required this.entity,
    required this.id,
  });

  final int operation;
  final String entity;
  final String id;

  Map<String, Object?> toJson() => {
    'operation': operation,
    'entity': entity,
    'id': id,
  };
}

/// What a referenced record looked like to the preview, so apply can tell
/// whether it changed since.
class RecordMarker {
  const RecordMarker({
    required this.table,
    required this.id,
    required this.updatedAt,
    this.relations = const {},
    this.readRelation,
    this.footprint,
    this.readFootprint,
  });

  final String table;
  final String id;

  /// Null when the row has gone.
  final int? updatedAt;

  /// The links this plan changes, by relation.
  final Map<String, Set<String>> relations;

  /// Reads a relation's links again.
  final Future<Set<String>> Function(String relation)? readRelation;

  /// What the plan worked out from rows with no version of their own, such
  /// as a delete's children or a site's types. Any of them can change without
  /// touching [updatedAt].
  final String? footprint;

  /// Works [footprint] out again.
  final Future<String> Function()? readFootprint;
}

/// A previewed change set, held until it is applied or expires.
class WritePlan {
  const WritePlan({
    required this.id,
    required this.label,
    required this.expiresAt,
    required this.items,
    required this.unchanged,
    required this.markers,
    this.clientName,
  });

  final String id;
  final String label;
  final String? clientName;
  final DateTime expiresAt;
  final List<PlanItem> items;
  final List<UnchangedRecord> unchanged;
  final List<RecordMarker> markers;

  /// Whether it can be applied: something changes and nothing is blocked. A
  /// diver is never asked to confirm what cannot run.
  bool get applicable =>
      items.isNotEmpty && items.every((item) => item.block == null);

  Map<String, int> get countsByEntity => _counts((item) => item.entity);

  /// Keyed by owner. A record with no owner, such as a shared site, is
  /// counted under an empty key.
  Map<String, int> get countsByDiver => _counts((item) => item.diverId ?? '');

  /// Changes of each kind, per entity: a diver allowing 40 changes should
  /// know that they are deletes.
  Map<String, Map<String, int>> get countsByChange => countChanges(items);

  /// Dives that would lose a link, by owner, across the plan. These can be
  /// another profile's, even when the record deleted is not.
  Map<String, int> get linkedDivesByDiver => countLinkedDives(items);

  static Map<String, Map<String, int>> countChanges(List<PlanItem> items) {
    final counts = <String, Map<String, int>>{};
    for (final item in items) {
      if (item.block != null) continue;
      (counts[item.entity] ??= {}).update(
        item.kind.name,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  static Map<String, int> countLinkedDives(List<PlanItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      for (final MapEntry(:key, :value) in item.reach.linkedDives.entries) {
        counts.update(key, (n) => n + value, ifAbsent: () => value);
      }
    }
    return counts;
  }

  Map<String, int> _counts(String Function(PlanItem) keyOf) {
    final counts = <String, int>{};
    for (final item in items) {
      if (item.block != null) continue;
      counts.update(keyOf(item), (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, Object?> toJson() => {
    'applicable': applicable,
    if (applicable) 'plan_id': id,
    if (applicable) 'expires_at': expiresAt.toUtc().toIso8601String(),
    'label': label,
    'items': [for (final item in items) item.toJson()],
    'unchanged': [for (final record in unchanged) record.toJson()],
    'counts': {
      'by_entity': countsByEntity,
      'by_change': countsByChange,
      'by_diver': countsByDiver,
      if (linkedDivesByDiver.isNotEmpty)
        'linked_dives_by_diver': linkedDivesByDiver,
    },
  };
}
