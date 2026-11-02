import 'package:submersion/features/agent_access/data/writes/field_codec.dart';

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

/// One link a record can hold. [refEntity] is the read catalogue's name for
/// what it points at, so a reference passes that entity's own visibility
/// rule: shared sites and built-in types count, another profile's do not.
class RelationSpec {
  const RelationSpec({required this.refEntity, this.single = false});

  final String refEntity;

  /// At most one link, such as a dive's site.
  final bool single;
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

/// One entity an agent can change. Its [name], and the keys of [fields], are
/// those of the read catalogue, so a document can be edited and sent back.
/// Writes go through a repository or service, never a table.
abstract interface class WritableEntry {
  String get name;

  /// The table `id` and `updated_at` are read from.
  String get table;

  /// The fields a change may set. A document key not listed here is
  /// read-only, usually because it is derived or owned by a device.
  Map<String, FieldCodec> get fields;
  Map<String, RelationSpec> get relations;

  /// Fields a create must carry.
  Set<String> get requiredOnCreate;

  /// The ids [relation] holds now.
  Future<Set<String>> currentRelation(String id, String relation);

  /// A block when this change may not happen, null when it may.
  Future<PlanBlock?> refuse(WriteCheck check);

  /// Creates a record for [diverId] and returns its id.
  Future<String> create(String diverId, Map<String, Object?> values);

  Future<void> update(String id, String? ownerId, RecordUpdate update);

  Future<void> delete(String id, String? ownerId);
}
