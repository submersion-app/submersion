import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

part 'write_planner_children.dart';
part 'write_planner_merge.dart';
part 'write_planner_references.dart';

/// Turns a change set into a plan by reading, and only reading. It opens no
/// transaction and writes nothing, because the spec forbids even one that is
/// rolled back: a trigger would fire and a stream would tick.
class WritePlanner {
  WritePlanner({
    required WriteCatalog writes,
    required RecordCatalog records,
    DateTime Function()? clock,
  }) : _writes = writes,
       _records = records,
       _clock = clock ?? DateTime.now;

  final WriteCatalog _writes;
  final RecordCatalog _records;
  final DateTime Function() _clock;

  Future<WritePlan> preview(
    AppDatabase db,
    ChangeSet set, {
    required Future<String> Function(String? requested) resolveDiver,
    String? clientName,
  }) async {
    final pass = _Pass(db, _writes, _records, resolveDiver, set);
    await pass.loadRows();
    for (final op in set.operations) {
      await pass.plan(op);
    }
    return WritePlan(
      id: const Uuid().v4(),
      label: set.label,
      clientName: clientName,
      expiresAt: _clock().add(kWritePlanLifetime),
      items: pass.items,
      unchanged: pass.unchanged,
      markers: pass.markers,
      previewedOn: WeakReference(db),
    );
  }
}

/// A record's owner and version. A child has neither of its own, so these are
/// its parent's, and [parentId] names the parent.
typedef _Row = ({String? ownerId, int updatedAt, String? parentId});

/// The state of one preview.
class _Pass {
  _Pass(this.db, this.writes, this.records, this.resolveDiver, this.set);

  final AppDatabase db;
  final WriteCatalog writes;
  final RecordCatalog records;
  final Future<String> Function(String?) resolveDiver;
  final ChangeSet set;

  final items = <PlanItem>[];
  final unchanged = <UnchangedRecord>[];
  final markers = <RecordMarker>[];

  final _rows = <String, Map<String, _Row>>{};
  final _seen = <(String, String)>{};
  final _referenced = <(String, String)>{};
  final _tableColumns = <String, Set<String>>{};

  /// The fields each update in the set names, by record, wherever it sits.
  late final _updatedFields = {
    for (final op in set.operations)
      if (op is UpdateOp) (op.entity, op.id): op.fields.keys.toSet(),
  };

  late final _deleted = {
    for (final op in set.operations)
      if (op is DeleteOp) (op.entity, op.id),
  };

  /// [_deleted] by entity, for a delete's reach.
  late final _deletedByEntity = () {
    final byEntity = <String, Set<String>>{};
    for (final (entity, id) in _deleted) {
      (byEntity[entity] ??= {}).add(id);
    }
    return byEntity;
  }();

  /// Records an update earlier in the set changes, as each is planned.
  final _changedSoFar = <(String, String)>{};

  /// The records each survivor takes in by an earlier merge in the set, by
  /// entity and survivor.
  final _mergedInto = <(String, String?), Set<String>>{};

  /// Each unique key a change in the set claims, by entity and owner, to the
  /// operation that claimed it first.
  final _claims = <(String, String?, String), int>{};

  /// A block when an earlier change in the set claims [check]'s unique key,
  /// otherwise null, after claiming it for [op].
  PlanBlock? _claimUnique(ChangeOp op, WritableEntry entry, WriteCheck check) {
    final key = entry.uniqueKey(check);
    if (key == null) return null;
    final earlier = _claims.putIfAbsent((
      entry.name,
      check.ownerId,
      key,
    ), () => op.index);
    if (earlier == op.index) return null;
    return PlanBlock(
      BlockReason.duplicateRecord,
      'operation $earlier of this set already claims "$key" for a '
      '${entry.name} record; two records of one owner cannot share it.',
    );
  }

  /// Reads the owner and version of every record the set names, by table.
  Future<void> loadRows() async {
    final ids = <String, Set<String>>{};
    for (final op in set.operations) {
      final id = switch (op) {
        UpdateOp(:final id) || DeleteOp(:final id) => id,
        CreateOp() => null,
      };
      if (id == null) continue;
      if (writes.named(op.entity) case final entry?) {
        (ids[entry.name] ??= {}).add(id);
        // A merge's survivor, whose owner the merge must share.
        if (op case DeleteOp(:final mergeInto?)) {
          ids[entry.name]!.add(mergeInto);
        }
      }
    }
    for (final MapEntry(key: entity, value: wanted) in ids.entries) {
      final entry = writes.named(entity)!;
      final rows = _rows[entity] = {};
      for (final chunk in seriesIdChunks(wanted.toList())) {
        final marks = List.filled(chunk.length, '?').join(', ');
        final found = await db
            .customSelect(
              '${await _rowSelect(entry)} WHERE r.id IN ($marks)',
              variables: [for (final id in chunk) Variable.withString(id)],
            )
            .get();
        for (final row in found) {
          rows[row.read<String>('id')] = (
            ownerId: row.readNullable<String>('diver_id'),
            updatedAt: row.read<int>('updated_at'),
            parentId: row.readNullable<String>('parent_id'),
          );
        }
      }
    }
  }

  Future<void> plan(ChangeOp op) async {
    final entry = writes.named(op.entity);
    if (entry == null) {
      final names = [for (final e in writes.all) e.name].join(', ');
      return _blocked(
        op,
        BlockReason.notWritable,
        '${op.entity} cannot be changed yet; these can: $names.',
      );
    }
    switch (op) {
      case CreateOp():
        await _create(op, entry);
      case UpdateOp():
        final before = items.length;
        await _update(op, entry);
        // An update that changes nothing leaves the record as it was.
        if (items.length > before) _changedSoFar.add((op.entity, op.id));
      case DeleteOp():
        await _delete(op, entry);
    }
  }

  Future<void> _create(CreateOp op, WritableEntry entry) async {
    final parsed = _parse(op.index, entry, op.fields, const {});
    if (parsed.block case final block?) {
      return _add(op, entry, kind: ChangeKind.create, block: block);
    }
    final missing = {
      ...entry.requiredOnCreate,
      ?entry.parent?.field,
    }.where((key) => !op.fields.containsKey(key));
    if (missing.isNotEmpty) {
      return _add(
        op,
        entry,
        kind: ChangeKind.create,
        block: PlanBlock(
          BlockReason.missingField,
          'A new ${op.entity} record needs ${missing.join(', ')}.',
        ),
      );
    }
    final owner = await _owner(op, entry, parsed.values);
    if (owner.block ?? _parentWritten(entry, owner.parentId, ChangeKind.create)
        case final block?) {
      return _add(op, entry, kind: ChangeKind.create, block: block);
    }
    final diverId = owner.diverId!;
    final check = WriteCheck(
      kind: ChangeKind.create,
      ownerId: diverId,
      values: parsed.values,
    );
    final block =
        await _checkFieldRefs(entry, parsed.values, diverId) ??
        await entry.refuse(check) ??
        _claimUnique(op, entry, check);
    if (block == null) await _markFieldRefs(entry, parsed.values);
    final parent = await _parentContext(entry, owner.parentId, diverId);
    _add(
      op,
      entry,
      kind: ChangeKind.create,
      diverId: diverId,
      parentId: owner.parentId,
      parentTitle: parent.title,
      date: parent.date,
      fields: parsed.changes,
      values: parsed.values,
      names: await _referenceNames(entry, parsed.changes, diverId),
      block: block,
    );
  }

  Future<void> _update(UpdateOp op, WritableEntry entry) async {
    final row = _claim(op, op.id, entry, ChangeKind.update);
    if (row == null) return;
    if (_orphaned(op, entry, row, ChangeKind.update)) return;
    final read = await _document(entry, op.id, row.ownerId);
    final document = await entry.stored(op.id, read);
    final parsed = _parse(op.index, entry, op.fields, document);
    final links = await _relations(op, entry, row.ownerId);
    final check = WriteCheck(
      kind: ChangeKind.update,
      id: op.id,
      ownerId: row.ownerId,
      values: parsed.values,
      relations: links.deltas,
      document: document,
    );
    final block =
        parsed.block ??
        links.block ??
        _fixed(entry, parsed) ??
        await _checkFieldRefs(entry, parsed.values, row.ownerId) ??
        await entry.refuse(check) ??
        _claimUnique(op, entry, check);
    final update = RecordUpdate(values: parsed.values, relations: links.deltas);
    Future<SideEffects> readEffects() =>
        entry.sideEffects(op.id, row.ownerId, update, document);
    final effects = block != null ? const SideEffects() : await readEffects();
    if (block == null &&
        parsed.changes.isEmpty &&
        links.deltas.isEmpty &&
        effects.isEmpty) {
      unchanged.add(
        UnchangedRecord(operation: op.index, entity: op.entity, id: op.id),
      );
      return;
    }
    final fields = {...parsed.changes};
    final values = {...parsed.values};
    for (final MapEntry(key: key, value: value) in effects.fields.entries) {
      if (parsed.named.containsKey(key)) {
        // The set names this field, so its value is written after the effect
        // and wins, even when it equals what the row holds now.
        values[key] = parsed.named[key];
      } else {
        fields[key] = FieldChange(document[key], value, indirect: true);
      }
    }
    if (block == null) {
      markers.add(
        await _marker(
          entry,
          op.id,
          row,
          read,
          relations: links.current,
          footprint: effects.footprint,
          readFootprint: () async => (await readEffects()).footprint,
        ),
      );
      await _markReferences(entry, links.deltas);
      await _markFieldRefs(entry, parsed.values);
    }
    final parent = await _parentContext(entry, row.parentId, row.ownerId);
    _add(
      op,
      entry,
      kind: ChangeKind.update,
      id: op.id,
      diverId: row.ownerId,
      parentId: row.parentId,
      parentTitle: parent.title,
      title: entry.titleOf(document),
      date: document['date_time'] as String? ?? parent.date,
      context: _context(entry, document),
      fields: fields,
      values: values,
      relations: links.deltas,
      indirectRelations: effects.relations,
      indirectLost: effects.lost,
      reach: DeleteReach(parts: effects.parts),
      names: {
        ...await _names(entry, links.deltas, {
          ...effects.relations,
          for (final MapEntry(:key, :value) in effects.lost.entries)
            key: {...?effects.relations[key], ...value},
        }),
        ...await _referenceNames(entry, fields, row.ownerId),
      },
      block: block,
    );
  }

  Future<void> _delete(DeleteOp op, WritableEntry entry) async {
    final row = _claim(op, op.id, entry, ChangeKind.delete);
    if (row == null) return;
    if (_orphaned(op, entry, row, ChangeKind.delete)) return;
    final document = await _document(entry, op.id, row.ownerId);
    final into = op.mergeInto;
    final refused =
        (into == null ? null : _mergeBlock(op, entry, row)) ??
        _parentWritten(entry, row.parentId, ChangeKind.delete) ??
        await entry.refuse(
          WriteCheck(
            kind: ChangeKind.delete,
            id: op.id,
            ownerId: row.ownerId,
            document: document,
          ),
        );
    // Held as locals, so the closure a marker keeps holds these and not this
    // pass, whose database a plan must not keep alive.
    final alongside = _deletedByEntity;
    final mergedBefore = {...?_mergedInto[(op.entity, into)]};
    Future<DeleteReach> readReach() => into == null
        ? entry.deleteReach(op.id, alongside: alongside)
        : entry.mergeReach(op.id, into, mergedBefore: mergedBefore);
    final read = refused == null ? await readReach() : const DeleteReach();
    final block = refused ?? (into == null ? null : _survivorClash(op, read));
    final reach = block == null ? read : const DeleteReach();
    final parent = await _parentContext(entry, row.parentId, row.ownerId);
    final survivor = block == null && into != null
        ? await _survivorView(op, entry, reach)
        : null;
    if (block == null && into != null) {
      // A survivor changed after the preview may no longer be the record
      // the diver allowed the links to move to.
      await _markReference(entry.table, into);
      (_mergedInto[(op.entity, into)] ??= {}).add(op.id);
    }
    if (block == null) {
      markers.add(
        await _marker(
          entry,
          op.id,
          row,
          document,
          footprint: reach.footprint,
          readFootprint: () async => (await readReach()).footprint,
        ),
      );
    }
    _add(
      op,
      entry,
      kind: ChangeKind.delete,
      id: op.id,
      diverId: row.ownerId,
      parentId: row.parentId,
      parentTitle: parent.title,
      title: entry.titleOf(document),
      date: document['date_time'] as String? ?? parent.date,
      context: _context(entry, document),
      reach: reach,
      fields: survivor?.fields ?? const {},
      mergeInto: block == null ? into : null,
      mergeTitle: survivor?.title,
      block: block,
    );
  }

  /// The row for a record the set may change, or null after blocking it.
  _Row? _claim(ChangeOp op, String id, WritableEntry entry, ChangeKind kind) {
    if (!_seen.add((op.entity, id))) {
      _add(
        op,
        entry,
        kind: kind,
        id: id,
        block: const PlanBlock(
          BlockReason.duplicateRecord,
          'This record appears twice; put its changes in one operation.',
        ),
      );
      return null;
    }
    final row = _rows[op.entity]?[id];
    if (row != null) return row;
    _add(
      op,
      entry,
      kind: kind,
      id: id,
      block: const PlanBlock(
        BlockReason.recordNotFound,
        'No record has this id.',
      ),
    );
    return null;
  }

  Future<Map<String, Object?>> _document(
    WritableEntry entry,
    String id,
    String? ownerId,
  ) async => _readDocument(
    records.named(entry.name),
    id,
    ownerId ?? await resolveDiver(null),
  );

  /// The values [entry] asks a reader to show a change with.
  Map<String, Object?> _context(
    WritableEntry entry,
    Map<String, Object?> document,
  ) => {for (final key in entry.displayContext) key: document[key]};

  _Parsed _parse(
    int index,
    WritableEntry entry,
    Map<String, Object?> requested,
    Map<String, Object?> document,
  ) {
    final changes = <String, FieldChange>{};
    final values = <String, Object?>{};
    final named = <String, Object?>{};
    final problems = <String>[];
    final unknown = <String>[];
    for (final MapEntry(key: key, value: raw) in requested.entries) {
      final codec = entry.fields[key];
      if (codec == null) {
        unknown.add(key);
        continue;
      }
      try {
        final next = codec.parse(raw);
        named[key] = next;
        final current = codec.canonical(document[key]);
        if (next == current) {
          if (entry.effectFields.contains(key)) values[key] = next;
          continue;
        }
        values[key] = next;
        changes[key] = FieldChange(codec.wire(current), codec.wire(next));
      } on FieldRefusal catch (refusal) {
        problems.add('$key: ${refusal.reason}');
      }
    }
    if (unknown.isNotEmpty) {
      return _Parsed.blocked(
        PlanBlock(
          BlockReason.unknownField,
          '${unknown.join(', ')} cannot be set on ${entry.name}. '
          'These can: ${entry.fields.keys.join(', ')}.',
        ),
      );
    }
    if (problems.isNotEmpty) {
      return _Parsed.blocked(
        PlanBlock(BlockReason.invalidValue, problems.join(' ')),
      );
    }
    return _Parsed(changes: changes, values: values, named: named);
  }

  Future<_Links> _relations(
    UpdateOp op,
    WritableEntry entry,
    String? ownerId,
  ) async {
    final deltas = <String, RelationDelta>{};
    final current = <String, Set<String>>{};
    for (final MapEntry(key: name, value: change) in op.relations.entries) {
      final spec = entry.relations[name];
      if (spec == null) {
        return _Links.blocked(
          PlanBlock(
            BlockReason.unknownField,
            '$name is not a relation of ${entry.name}. '
            'These are: ${entry.relations.keys.join(', ')}.',
          ),
        );
      }
      final links = current[name] = await entry.currentRelation(op.id, name);
      final delta = _delta(change, links, spec);
      if (delta == null) {
        return _Links.blocked(
          PlanBlock(BlockReason.invalidValue, '$name takes one id.'),
        );
      }
      final block = await _checkRefs(
        name,
        spec.refEntity,
        delta.add,
        ownerId,
        copiesTarget: spec.copiesTarget,
      );
      if (block != null) return _Links.blocked(block);
      if (!delta.isEmpty) deltas[name] = delta;
    }
    return _Links(deltas: deltas, current: current);
  }

  /// What [change] means against [links], or null when a single relation is
  /// handed more than one id.
  RelationDelta? _delta(
    RelationChange change,
    Set<String> links,
    RelationSpec spec,
  ) {
    final wanted = change.set?.toSet();
    final add = (wanted ?? change.add.toSet()).difference(links);
    if (spec.single && (wanted ?? add).length > 1) return null;
    final remove = wanted != null
        ? links.difference(wanted)
        : change.remove.toSet().intersection(links);
    return RelationDelta(
      add: add,
      // A single link has one place, so a new one takes the old one's.
      remove: spec.single && add.isNotEmpty ? links : remove,
    );
  }

  /// Whether [ids], which [name] points at records of [refEntity] with, may
  /// be used by [ownerId]. [copiesTarget] as [RelationSpec.copiesTarget].
  Future<PlanBlock?> _checkRefs(
    String name,
    String refEntity,
    Set<String> ids,
    String? ownerId, {
    bool copiesTarget = false,
  }) async {
    if (ids.isEmpty) return null;
    final deleted = ids.where((id) => _deleted.contains((refEntity, id)));
    if (deleted.isNotEmpty) {
      return PlanBlock(
        BlockReason.referenceDeleted,
        '$name refers to ${deleted.join(', ')}, which this set deletes.',
      );
    }
    final changed = copiesTarget
        ? ids.where((id) => _changedSoFar.contains((refEntity, id)))
        : const <String>[];
    if (changed.isNotEmpty) {
      return PlanBlock(
        BlockReason.referenceChanged,
        '$name copies values from ${changed.join(', ')}, which an earlier '
        'operation in this set changes. Link it in a change set of its own.',
      );
    }
    final ref = records.named(refEntity);
    final diverId = ownerId ?? await resolveDiver(null);
    final visible = await RecordReader(
      db,
    ).visibleIds(ref, ids.toList(), diverId);
    final hidden = ids.difference(visible.toSet());
    if (hidden.isEmpty) return null;
    final existing = await _existing(ref, hidden);
    final strangers = hidden.intersection(existing);
    if (strangers.isNotEmpty) {
      return PlanBlock(
        BlockReason.otherProfileReference,
        '$name: ${strangers.join(', ')} belongs to another profile.',
      );
    }
    return PlanBlock(
      BlockReason.unknownReference,
      '$name: nothing has the id ${hidden.join(', ')}.',
    );
  }

  Future<Set<String>> _existing(RecordEntry ref, Set<String> ids) async {
    final found = <String>{};
    for (final chunk in seriesIdChunks(ids.toList())) {
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await db
          .customSelect(
            'SELECT id FROM ${ref.table} WHERE id IN ($marks)',
            variables: [for (final id in chunk) Variable.withString(id)],
          )
          .get();
      found.addAll(rows.map((row) => row.read<String>('id')));
    }
    return found;
  }

  void _blocked(ChangeOp op, BlockReason reason, String detail) => items.add(
    PlanItem(
      operation: op.index,
      kind: switch (op) {
        CreateOp() => ChangeKind.create,
        UpdateOp() => ChangeKind.update,
        DeleteOp() => ChangeKind.delete,
      },
      entity: op.entity,
      id: switch (op) {
        UpdateOp(:final id) || DeleteOp(:final id) => id,
        CreateOp() => null,
      },
      block: PlanBlock(reason, detail),
    ),
  );

  void _add(
    ChangeOp op,
    WritableEntry entry, {
    required ChangeKind kind,
    String? id,
    String? diverId,
    String? parentId,
    String? parentTitle,
    String? title,
    String? date,
    Map<String, Object?> context = const {},
    Map<String, FieldChange> fields = const {},
    Map<String, Object?> values = const {},
    Map<String, RelationDelta> relations = const {},
    Map<String, Set<String>> indirectRelations = const {},
    Map<String, Set<String>> indirectLost = const {},
    Map<String, String> names = const {},
    DeleteReach reach = const DeleteReach(),
    String? mergeInto,
    String? mergeTitle,
    PlanBlock? block,
  }) => items.add(
    PlanItem(
      operation: op.index,
      kind: kind,
      entity: entry.name,
      id: id,
      diverId: diverId,
      parentId: parentId,
      parentTitle: parentTitle,
      title: title,
      date: date,
      context: context,
      fields: fields,
      values: values,
      relations: relations,
      indirectRelations: indirectRelations,
      indirectLost: indirectLost,
      names: names,
      reach: reach,
      mergeInto: mergeInto,
      mergeTitle: mergeTitle,
      block: block,
    ),
  );
}

class _Parsed {
  const _Parsed({
    this.changes = const {},
    this.values = const {},
    this.named = const {},
  }) : block = null;

  const _Parsed.blocked(PlanBlock this.block)
    : changes = const {},
      values = const {},
      named = const {};

  final Map<String, FieldChange> changes;
  final Map<String, Object?> values;

  /// Every field the set named, whether or not it differs from the row.
  final Map<String, Object?> named;
  final PlanBlock? block;
}

class _Links {
  const _Links({this.deltas = const {}, this.current = const {}})
    : block = null;

  const _Links.blocked(PlanBlock this.block)
    : deltas = const {},
      current = const {};

  final Map<String, RelationDelta> deltas;
  final Map<String, Set<String>> current;
  final PlanBlock? block;
}
