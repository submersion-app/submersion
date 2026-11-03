import 'dart:collection';
import 'dart:convert';

import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner;

enum ChangeKind { create, update, delete }

/// Why a preview cannot become a plan, as the agent reads it.
enum BlockReason {
  recordNotFound('record_not_found'),
  notWritable('not_writable'),
  unknownField('unknown_field'),
  invalidValue('invalid_value'),
  missingField('missing_field'),
  unknownReference('unknown_reference'),
  otherProfileReference('other_profile_reference'),
  duplicateRecord('duplicate_record'),
  referenceDeleted('reference_deleted'),
  referenceChanged('reference_changed'),
  notPermitted('not_permitted');

  const BlockReason(this.wire);

  final String wire;
}

/// A [BlockReason] with the words that explain this case.
class PlanBlock {
  const PlanBlock(this.reason, this.detail);

  final BlockReason reason;
  final String detail;
}

/// The record a child entry belongs to, such as a tank's dive. [entity] is
/// the parent's write and read name, and [field] names the parent on the
/// child, as the document key and the column.
class ChildOf {
  const ChildOf({required this.entity, required this.field});

  final String entity;
  final String field;
}

/// One link a record can hold. [refEntity] is the read catalogue's name for
/// what it points at, so a reference passes that entity's own visibility
/// rule: shared sites and built-in types count, another profile's do not.
class RelationSpec {
  const RelationSpec({
    required this.refEntity,
    this.single = false,
    this.copiesTarget = false,
  });

  final String refEntity;

  /// At most one link, such as a dive's site.
  final bool single;

  /// The link copies values from what it points at, as a dive takes a site's
  /// water type, so it cannot follow a change to that record in the same set:
  /// the plan would list the values the write no longer copies.
  final bool copiesTarget;
}

/// The links an update adds and removes. A requested `set` arrives here
/// already compared with the current links, so a link that stays is left
/// alone and keeps what it carries, such as a buddy's role.
class RelationDelta {
  const RelationDelta({this.add = const {}, this.remove = const {}});

  final Set<String> add;
  final Set<String> remove;

  bool get isEmpty => add.isEmpty && remove.isEmpty;
}

/// What an update changes: parsed field values, keyed as in the document.
class RecordUpdate {
  const RecordUpdate({this.values = const {}, this.relations = const {}});

  final Map<String, Object?> values;
  final Map<String, RelationDelta> relations;
}

/// What an entity is asked to judge before a change is planned.
class WriteCheck {
  const WriteCheck({
    required this.kind,
    this.id,
    this.ownerId,
    this.values = const {},
    this.document,
  });

  final ChangeKind kind;
  final String? id;
  final String? ownerId;

  /// The fields this change sets, parsed.
  final Map<String, Object?> values;

  /// The record as it stands. Null for a create.
  final Map<String, Object?>? document;
}

/// What an update does beyond what it names, through a repository's own
/// rules. The planner lists these, so a diver sees everything a plan does.
class SideEffects {
  const SideEffects({this.fields = const {}, this.relations = const {}});

  /// Document key to the value it will hold, as a document would read.
  final Map<String, Object?> fields;

  /// Relation name to the ids it gains.
  final Map<String, Set<String>> relations;

  bool get isEmpty => fields.isEmpty && relations.isEmpty;

  /// The same text for the same effects, to compare a preview with a later
  /// read.
  String get footprint => jsonEncode({
    'fields': _sorted({
      for (final MapEntry(:key, :value) in fields.entries) key: '$value',
    }),
    'relations': _sorted({
      for (final MapEntry(:key, :value) in relations.entries)
        key: (value.toList()..sort()),
    }),
  });
}

/// What a delete takes with it, for the diver to weigh.
class DeleteReach {
  const DeleteReach({
    this.linkedDives = const {},
    this.records = const {},
    this.parts = const {},
    this.unlinked = const {},
  });

  /// Dives that lose a link to this record, by owner. These can belong to
  /// profiles other than the record's own.
  final Map<String, int> linkedDives;

  /// Records with a life of their own deleted with it, by table.
  final Map<String, int> records;

  /// Rows that only exist as part of it, such as a dive's tanks, by table.
  final Map<String, int> parts;

  /// Records that stay but lose their link to it, by table.
  final Map<String, int> unlinked;

  bool get isEmpty =>
      linkedDives.isEmpty &&
      records.isEmpty &&
      parts.isEmpty &&
      unlinked.isEmpty;

  /// The same text for the same reach, to compare a preview with a later
  /// read.
  String get footprint => jsonEncode({
    'dives': _sorted(linkedDives),
    'records': _sorted(records),
    'parts': _sorted(parts),
    'unlinked': _sorted(unlinked),
  });
}

Map<String, V> _sorted<V>(Map<String, V> map) => SplayTreeMap.of(map);

/// One entity an agent can change. Its [name], and the keys of [fields], are
/// those of the read catalogue, so a document can be edited and sent back.
/// Writes go through a repository or service, never a table.
abstract class WritableEntry {
  String get name;

  /// The table `id` and `updated_at` are read from.
  String get table;

  /// The fields a change may set. A document key not listed here is
  /// read-only, usually because it is derived or owned by a device.
  Map<String, FieldCodec> get fields;
  Map<String, RelationSpec> get relations => const {};

  /// Fields a create must carry.
  Set<String> get requiredOnCreate;

  /// The record this one belongs to. A child takes its parent's owner,
  /// names it in [ChildOf.field] when it is created, and stays on it.
  ChildOf? get parent => null;

  /// Fields a create sets and an update may not change. A child's
  /// [ChildOf.field] is always one.
  Set<String> get createOnly => const {};

  /// Fields whose write does something even when it equals the row, so a
  /// plan cannot drop one as unchanged.
  Set<String> get effectFields => const {};

  /// The ids [relation] holds now.
  Future<Set<String>> currentRelation(String id, String relation) async =>
      const {};

  /// A block when this change may not happen, null when it may.
  Future<PlanBlock?> refuse(WriteCheck check) async => null;

  /// [document] with stored values where a read shows a derived one, so a
  /// plan compares against what the row holds.
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async => document;

  /// What [update] also changes. Only asked of an update that can run.
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => const SideEffects();

  /// What deleting [id] takes with it. [alongside] holds every record the
  /// change set deletes, by entity, [id] included: some records go only once
  /// everything holding them goes, and each such record is counted on one
  /// item, so a plan's totals add up.
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => const DeleteReach();

  /// What a diver knows this record by.
  String? titleOf(Map<String, Object?> document) => document['name'] as String?;

  /// Every owner whose documents go with a delete of this record.
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) async =>
      const [];

  /// Creates a record for [diverId] and returns its id.
  Future<String> create(String diverId, Map<String, Object?> values);

  Future<void> update(String id, String? ownerId, RecordUpdate update);

  Future<void> delete(String id, String? ownerId);
}
