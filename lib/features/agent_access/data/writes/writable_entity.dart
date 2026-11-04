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
  const ChildOf({required this.entity, required this.field, String? column})
    : _column = column;

  final String entity;
  final String field;
  final String? _column;

  /// The child's column naming the parent, when the table calls it other
  /// than the document does: a gear note's `center_id` is `dive_center_id`.
  String get column => _column ?? field;
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
  const RecordUpdate({
    this.values = const {},
    this.relations = const {},
    this.soFar = const SetSoFar(),
  });

  final Map<String, Object?> values;
  final Map<String, RelationDelta> relations;

  /// What the changes before this one in the set do, as the plan made it, so
  /// [WritableEntry.sideEffects] reads other records as the apply will find
  /// them. Empty at apply, where those changes have already run.
  final SetSoFar soFar;
}

/// What an entity is asked to judge before a change is planned.
class WriteCheck {
  const WriteCheck({
    required this.kind,
    this.id,
    this.ownerId,
    this.values = const {},
    this.relations = const {},
    this.document,
    this.soFar = const SetSoFar(),
  });

  final ChangeKind kind;
  final String? id;
  final String? ownerId;

  /// What the rest of the set does before this change, for a rule that
  /// reads stored rows the set changes first.
  final SetSoFar soFar;

  /// The fields this change sets, parsed.
  final Map<String, Object?> values;

  /// The links an update adds and removes, against the current ones.
  final Map<String, RelationDelta> relations;

  /// The record as it stands. Null for a create.
  final Map<String, Object?>? document;
}

/// A key a change claims, such as a folded name. A [shared] claim holds the
/// key for every profile, as a shared certification agency's name does, so
/// it clashes with any other claim on the key; an unshared one clashes with
/// a shared claim or one of the same owner.
class UniqueClaim {
  const UniqueClaim(this.key, {this.shared = false});

  final String key;
  final bool shared;
}

/// What a change set does around the change a [WriteCheck] asks about. A set
/// applies in order, so a rule that reads stored rows counts these too.
class SetSoFar {
  const SetSoFar({
    this.deleted = const {},
    this.values = const {},
    this.unlinked = const {},
    this.created = const {},
  });

  /// The records deletes earlier in the set take away, by entity, counting
  /// only those the plan keeps.
  final Map<String, Set<String>> deleted;

  /// The fields earlier updates in the set write, parsed, by entity and id.
  final Map<(String, String), Map<String, Object?>> values;

  /// The records earlier updates take off a linked record, by the linked
  /// record's entity and id, then by the updated entity.
  final Map<(String, String), Map<String, Set<String>>> unlinked;

  /// The fields of the records creates earlier in the set add, parsed, by
  /// entity, counting only those the plan keeps.
  final Map<String, List<Map<String, Object?>>> created;
}

/// A change the applier wrote, for [WritableEntry.afterApply]: [id] is the
/// record's (a create's new id), [parentId] the record it belongs to, and
/// [changed] the document keys an update changed or a create named.
class AppliedChange {
  const AppliedChange({
    required this.kind,
    required this.id,
    this.parentId,
    this.changed = const {},
  });

  final ChangeKind kind;
  final String id;
  final String? parentId;
  final Set<String> changed;
}

/// One apply, as every entity's [WritableEntry.afterApply] sees it.
class ApplyRun {
  final _done = <Object>{};

  /// Whether [key] is asked for the first time in this apply, so follow-up
  /// work for one item, such as re-arming its reminders, runs once.
  bool once(Object key) => _done.add(key);
}

/// What an update does beyond what it names, through a repository's own
/// rules. The planner lists these, so a diver sees everything a plan does.
class SideEffects {
  const SideEffects({
    this.fields = const {},
    this.relations = const {},
    this.lost = const {},
    this.parts = const {},
    this.detached = const {},
    this.touched = const {},
    this.created = const {},
  });

  /// Document key to the value it will hold, as a document would read.
  final Map<String, Object?> fields;

  /// Relation name to the ids it gains.
  final Map<String, Set<String>> relations;

  /// Relation name to the ids it loses, such as the parts that leave a
  /// dive with their assembly.
  final Map<String, Set<String>> lost;

  /// Rows the update deletes, by table, as a delete's parts are counted:
  /// the annotations a Notes edit unlinks.
  final Map<String, int> parts;

  /// Records of other entities that lose their link to this one, by entity
  /// name, such as the sites a tag leaves when its site scope closes. A later
  /// change in the set reads those links as gone.
  final Map<String, Set<String>> detached;

  /// Rows of other records the update rewrites, by table, such as the dive
  /// computer a gear item's rename renames.
  final Map<String, int> touched;

  /// Rows the update adds, by table, as a create's [WritableEntry.alsoCreates]
  /// lists them: the items a template brings to a checklist.
  final Map<String, int> created;

  bool get isEmpty =>
      fields.isEmpty &&
      relations.isEmpty &&
      lost.isEmpty &&
      parts.isEmpty &&
      detached.isEmpty &&
      touched.isEmpty &&
      created.isEmpty;

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
    'lost': _sorted({
      for (final MapEntry(:key, :value) in lost.entries)
        key: (value.toList()..sort()),
    }),
    'parts': _sorted(parts),
    'detached': _sorted({
      for (final MapEntry(:key, :value) in detached.entries)
        key: (value.toList()..sort()),
    }),
    'touched': _sorted(touched),
    'created': _sorted(created),
  });
}

/// What a delete takes with it, for the diver to weigh.
class DeleteReach {
  const DeleteReach({
    this.linkedDives = const {},
    this.records = const {},
    this.parts = const {},
    this.unlinked = const {},
    this.moved = const {},
    this.survivor = const {},
    this.touched = const {},
    this.basis = '',
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

  /// Links a merge moves to the surviving record, by table.
  final Map<String, int> moved;

  /// What a merge changes on the surviving record itself: document key to
  /// the value it will hold, as a document would read.
  final Map<String, Object?> survivor;

  /// Rows of other records the delete rewrites, by table, as
  /// [SideEffects.touched] lists them for an update.
  final Map<String, int> touched;

  /// What the reach was worked out from, such as the exact links a merge
  /// moves, when the counts alone would not show a change. The plan compares
  /// it at apply and never shows it.
  final String basis;

  bool get isEmpty =>
      linkedDives.isEmpty &&
      records.isEmpty &&
      parts.isEmpty &&
      unlinked.isEmpty &&
      moved.isEmpty &&
      survivor.isEmpty &&
      touched.isEmpty;

  /// The same text for the same reach, to compare a preview with a later
  /// read.
  String get footprint => jsonEncode({
    'dives': _sorted(linkedDives),
    'records': _sorted(records),
    'parts': _sorted(parts),
    'unlinked': _sorted(unlinked),
    'moved': _sorted(moved),
    'survivor': _sorted({
      for (final MapEntry(:key, :value) in survivor.entries) key: '$value',
    }),
    'touched': _sorted(touched),
    'basis': basis,
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

  /// The column of [table] naming the profile a record belongs to: a
  /// profile belongs to itself.
  String get ownerColumn => 'diver_id';

  /// The profile a row of [table] aliased [alias] belongs to, as SQL: its
  /// [ownerColumn], unless the owner lives elsewhere, as a buddy's card
  /// belongs to the buddy's profile.
  String ownerOf(String alias) => '$alias.$ownerColumn';

  /// The record this one belongs to. A child takes its parent's owner,
  /// names it in [ChildOf.field] when it is created, and stays on it.
  ChildOf? get parent => null;

  /// What an agent needs to know about writing this entity beyond its
  /// fields, for the tool description. Null when nothing.
  String? get note => null;

  /// The kinds of change to this record that also write its parent, as an
  /// annotation's create and delete rewrite its dive's Notes. Such a change
  /// cannot share a set with an update of that parent that names one of
  /// [parentFieldsWritten]: whichever ran second would undo the other.
  Set<ChangeKind> get writesParent => const {};

  /// The parent's document keys a [writesParent] change writes, `notes`
  /// for an annotation.
  Set<String> get parentFieldsWritten => const {};

  /// Fields a create sets and an update may not change. A child's
  /// [ChildOf.field] is always one.
  Set<String> get createOnly => const {};

  /// Document keys a reader needs to show a change to this record that the
  /// change may leave alone, such as the working pressure that says what a
  /// tank's size holds.
  Set<String> get displayContext => const {};

  /// Fields whose write does something even when it equals the row, so a
  /// plan cannot drop one as unchanged.
  Set<String> get effectFields => const {};

  /// The ids [relation] holds now.
  Future<Set<String>> currentRelation(String id, String relation) async =>
      const {};

  /// A block when this change may not happen, null when it may.
  Future<PlanBlock?> refuse(WriteCheck check) async => null;

  /// Work the app does after saves of these records, run once the apply has
  /// committed and outside its transaction, where a scheduled scan can read
  /// the saved rows. [changes] are every change of this entity the apply
  /// wrote, in order; [run] is shared by every entity of the apply, so work
  /// two entities would both ask for runs once. A failure here cannot undo
  /// the apply, so it is logged.
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async {}

  /// Values a create of [values] for [diverId] fills in that it does not
  /// name, as the page's form prefills them, in the form [fields] parse to.
  /// The plan lists them and the apply writes them as listed.
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => const {};

  /// Rows of other records a create of [values] for [diverId] rewrites, by
  /// table, as [SideEffects.touched] lists them for an update: the item
  /// whose last service date a new record moves.
  Future<Map<String, int>> createTouched(
    String diverId,
    Map<String, Object?> values,
  ) async => const {};

  /// Rows of other tables a create of [values] for [diverId] adds alongside
  /// the record, by table, such as the service clocks a gear item gets.
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async => const {};

  /// What this change claims that no other record of its owner may hold, such
  /// as a tag's name as the name index keys it, or null when it claims
  /// nothing. [refuse] checks the stored records; the planner blocks a second
  /// claim on one key within the same set, which the database cannot see yet.
  UniqueClaim? uniqueKey(WriteCheck check) => null;

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

  /// Whether a delete may name `merge_into`: a record that takes over this
  /// one's links, as the app merges these records.
  bool get mergeable => false;

  /// What merging [id] into [intoId] does to their links, and to the
  /// survivor in [DeleteReach.survivor]. [mergedBefore] are the records the
  /// same set merges into [intoId] first, whose links it holds by then.
  Future<DeleteReach> mergeReach(
    String id,
    String intoId, {
    Set<String> mergedBefore = const {},
  }) async => const DeleteReach();

  /// Merges [id] into [intoId], through the app's own merge, and deletes
  /// [id]. Only asked of a [mergeable] entity.
  Future<void> merge(String id, String intoId, String? ownerId) =>
      throw UnsupportedError('$name does not merge');

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
