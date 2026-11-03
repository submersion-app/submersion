import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

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
    );
  }
}

typedef _Row = ({String? ownerId, int updatedAt});

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
  late final _deleted = {
    for (final op in set.operations)
      if (op is DeleteOp) (op.entity, op.id),
  };

  /// [_deleted] by entity, for a delete's reach.
  late final _deletedByEntity = <String, Set<String>>{
    for (final (entity, _) in _deleted)
      entity: {
        for (final (other, id) in _deleted)
          if (other == entity) id,
      },
  };

  /// Records an update earlier in the set changes, as each is planned.
  final _changedSoFar = <(String, String)>{};

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
      }
    }
    for (final MapEntry(key: entity, value: wanted) in ids.entries) {
      final table = writes.named(entity)!.table;
      final rows = _rows[entity] = {};
      for (final chunk in seriesIdChunks(wanted.toList())) {
        final marks = List.filled(chunk.length, '?').join(', ');
        final found = await db
            .customSelect(
              'SELECT id, diver_id, updated_at FROM $table '
              'WHERE id IN ($marks)',
              variables: [for (final id in chunk) Variable.withString(id)],
            )
            .get();
        for (final row in found) {
          rows[row.read<String>('id')] = (
            ownerId: row.readNullable<String>('diver_id'),
            updatedAt: row.read<int>('updated_at'),
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
    final diverId = await resolveDiver(op.diverId);
    final parsed = _parse(op.index, entry, op.fields, const {});
    if (parsed.block case final block?) {
      return _add(op, entry, kind: ChangeKind.create, block: block);
    }
    final missing = entry.requiredOnCreate.where(
      (key) => !op.fields.containsKey(key),
    );
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
    final block = await entry.refuse(
      WriteCheck(
        kind: ChangeKind.create,
        ownerId: diverId,
        values: parsed.values,
      ),
    );
    _add(
      op,
      entry,
      kind: ChangeKind.create,
      diverId: diverId,
      fields: parsed.changes,
      values: parsed.values,
      block: block,
    );
  }

  Future<void> _update(UpdateOp op, WritableEntry entry) async {
    final row = _claim(op, op.id, entry, ChangeKind.update);
    if (row == null) return;
    final document = await entry.stored(
      op.id,
      await _document(entry, op.id, row.ownerId),
    );
    final parsed = _parse(op.index, entry, op.fields, document);
    final links = await _relations(op, entry, row.ownerId);
    final block =
        parsed.block ??
        links.block ??
        await entry.refuse(
          WriteCheck(
            kind: ChangeKind.update,
            id: op.id,
            ownerId: row.ownerId,
            values: parsed.values,
            document: document,
          ),
        );
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
        RecordMarker(
          table: entry.table,
          id: op.id,
          updatedAt: row.updatedAt,
          relations: links.current,
          readRelation: (relation) => entry.currentRelation(op.id, relation),
          footprint: effects.footprint,
          readFootprint: () async => (await readEffects()).footprint,
        ),
      );
      await _markReferences(entry, links.deltas);
    }
    _add(
      op,
      entry,
      kind: ChangeKind.update,
      id: op.id,
      diverId: row.ownerId,
      title: entry.titleOf(document),
      date: document['date_time'] as String?,
      fields: fields,
      values: values,
      relations: links.deltas,
      indirectRelations: effects.relations,
      names: await _names(entry, links.deltas, effects.relations),
      block: block,
    );
  }

  Future<void> _delete(DeleteOp op, WritableEntry entry) async {
    final row = _claim(op, op.id, entry, ChangeKind.delete);
    if (row == null) return;
    final document = await _document(entry, op.id, row.ownerId);
    final block = await entry.refuse(
      WriteCheck(
        kind: ChangeKind.delete,
        id: op.id,
        ownerId: row.ownerId,
        document: document,
      ),
    );
    Future<DeleteReach> readReach() =>
        entry.deleteReach(op.id, alongside: _deletedByEntity);
    final reach = block == null ? await readReach() : const DeleteReach();
    if (block == null) {
      markers.add(
        RecordMarker(
          table: entry.table,
          id: op.id,
          updatedAt: row.updatedAt,
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
      title: entry.titleOf(document),
      date: document['date_time'] as String?,
      reach: reach,
      block: block,
    );
  }

  /// Adds a marker for each record a plan links to, so one that goes away
  /// after the preview refuses the plan instead of quietly not linking.
  Future<void> _markReferences(
    WritableEntry entry,
    Map<String, RelationDelta> deltas,
  ) async {
    for (final MapEntry(key: name, value: delta) in deltas.entries) {
      final table = records.named(entry.relations[name]!.refEntity).table;
      for (final id in delta.add) {
        if (!_referenced.add((table, id))) continue;
        final row = await db
            .customSelect(
              'SELECT updated_at FROM $table WHERE id = ?',
              variables: [Variable.withString(id)],
            )
            .getSingleOrNull();
        markers.add(
          RecordMarker(
            table: table,
            id: id,
            updatedAt: row?.read<int>('updated_at'),
          ),
        );
      }
    }
  }

  /// The names of what a change links, so a diver reads names, not ids.
  Future<Map<String, String>> _names(
    WritableEntry entry,
    Map<String, RelationDelta> deltas,
    Map<String, Set<String>> indirect,
  ) async {
    final names = <String, String>{};
    for (final relation in {...deltas.keys, ...indirect.keys}) {
      final delta = deltas[relation];
      final ids = {...?delta?.add, ...?delta?.remove, ...?indirect[relation]};
      if (ids.isEmpty) continue;
      final table = records.named(entry.relations[relation]!.refEntity).table;
      for (final chunk in seriesIdChunks(ids.toList())) {
        final marks = List.filled(chunk.length, '?').join(', ');
        final rows = await db
            .customSelect(
              'SELECT id, name FROM $table WHERE id IN ($marks)',
              variables: [for (final id in chunk) Variable.withString(id)],
            )
            .get();
        for (final row in rows) {
          names[row.read<String>('id')] = row.read<String>('name');
        }
      }
    }
    return names;
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
  ) async {
    final documents = await records.named(entry.name).read(
      [id],
      RecordLoad(
        include: const {},
        diverId: ownerId ?? await resolveDiver(null),
      ),
    );
    return documents[id] ?? const {};
  }

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
      final block = await _checkRefs(name, spec, delta.add, ownerId);
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

  Future<PlanBlock?> _checkRefs(
    String name,
    RelationSpec spec,
    Set<String> ids,
    String? ownerId,
  ) async {
    if (ids.isEmpty) return null;
    final deleted = ids.where((id) => _deleted.contains((spec.refEntity, id)));
    if (deleted.isNotEmpty) {
      return PlanBlock(
        BlockReason.referenceDeleted,
        '$name refers to ${deleted.join(', ')}, which this set deletes.',
      );
    }
    final changed = spec.copiesTarget
        ? ids.where((id) => _changedSoFar.contains((spec.refEntity, id)))
        : const <String>[];
    if (changed.isNotEmpty) {
      return PlanBlock(
        BlockReason.referenceChanged,
        '$name copies values from ${changed.join(', ')}, which an earlier '
        'operation in this set changes. Link it in a change set of its own.',
      );
    }
    final ref = records.named(spec.refEntity);
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
    String? title,
    String? date,
    Map<String, FieldChange> fields = const {},
    Map<String, Object?> values = const {},
    Map<String, RelationDelta> relations = const {},
    Map<String, Set<String>> indirectRelations = const {},
    Map<String, String> names = const {},
    DeleteReach reach = const DeleteReach(),
    PlanBlock? block,
  }) => items.add(
    PlanItem(
      operation: op.index,
      kind: kind,
      entity: entry.name,
      id: id,
      diverId: diverId,
      title: title,
      date: date,
      fields: fields,
      values: values,
      relations: relations,
      indirectRelations: indirectRelations,
      names: names,
      reach: reach,
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
