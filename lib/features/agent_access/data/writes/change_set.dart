import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Keeps one apply's transaction short enough for the UI and sync.
const kMaxChangeSetOperations = 500;

/// What an agent asks to change, as `preview_changes` receives it. Field
/// names and units are those of the `get_records` documents, so an agent can
/// read a record, edit the JSON and send it back.
class ChangeSet {
  const ChangeSet({required this.label, required this.operations});

  /// Written by the agent in the diver's language; the change log shows it.
  final String label;
  final List<ChangeOp> operations;

  /// Throws [AgentToolException] naming the first thing it cannot read.
  static ChangeSet parse(Map<String, Object?> args) {
    final label = args['label'];
    if (label is! String || label.trim().isEmpty) {
      throw const AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'label is required: a short description in the diver\'s language.',
      );
    }
    final operations = args['operations'];
    if (operations is! List || operations.isEmpty) {
      throw const AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'operations must be a non-empty list.',
      );
    }
    if (operations.length > kMaxChangeSetOperations) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'A change set holds at most $kMaxChangeSetOperations operations; '
        'split this one.',
        details: {'operations': operations.length},
      );
    }
    return ChangeSet(
      label: label.trim(),
      operations: [
        for (final (index, raw) in operations.indexed) _op(index, raw),
      ],
    );
  }
}

/// One step of a [ChangeSet]. [index] is its place in the request, which
/// every refusal names.
sealed class ChangeOp {
  const ChangeOp({required this.index, required this.entity});

  final int index;
  final String entity;
}

class CreateOp extends ChangeOp {
  const CreateOp({
    required super.index,
    required super.entity,
    required this.diverId,
    required this.fields,
  });

  /// The profile that owns the new record. Null means the active profile.
  final String? diverId;
  final Map<String, Object?> fields;
}

class UpdateOp extends ChangeOp {
  const UpdateOp({
    required super.index,
    required super.entity,
    required this.id,
    required this.fields,
    required this.relations,
  });

  final String id;

  /// A key present with null clears the field; a key left out is untouched.
  final Map<String, Object?> fields;
  final Map<String, RelationChange> relations;
}

class DeleteOp extends ChangeOp {
  const DeleteOp({
    required super.index,
    required super.entity,
    required this.id,
  });

  final String id;
}

/// A change to what a record is linked to: either [set], the whole new list,
/// or [add] and [remove].
class RelationChange {
  const RelationChange({this.add = const [], this.remove = const [], this.set});

  final List<String> add;
  final List<String> remove;
  final List<String>? set;
}

const _createKeys = {'op', 'entity', 'diver_id', 'fields'};
const _updateKeys = {'op', 'entity', 'id', 'fields', 'relations'};
const _deleteKeys = {'op', 'entity', 'id'};

ChangeOp _op(int index, Object? raw) {
  if (raw is! Map) throw _refused(index, 'must be an object.');
  final op = Map<String, Object?>.from(raw);
  final entity = op['entity'];
  if (entity is! String || entity.isEmpty) {
    throw _refused(index, 'needs an entity.');
  }
  switch (op['op']) {
    case 'create':
      _onlyKeys(index, op, _createKeys);
      final diverId = op['diver_id'];
      if (diverId != null && diverId is! String) {
        throw _refused(index, 'diver_id must be a string.');
      }
      return CreateOp(
        index: index,
        entity: entity,
        diverId: diverId as String?,
        fields: _fields(index, op['fields']),
      );
    case 'update':
      _onlyKeys(index, op, _updateKeys);
      final fields = _fields(index, op['fields']);
      final relations = _relations(index, op['relations']);
      if (fields.isEmpty && relations.isEmpty) {
        throw _refused(index, 'has nothing to change.');
      }
      return UpdateOp(
        index: index,
        entity: entity,
        id: _id(index, op['id']),
        fields: fields,
        relations: relations,
      );
    case 'delete':
      _onlyKeys(index, op, _deleteKeys);
      return DeleteOp(index: index, entity: entity, id: _id(index, op['id']));
  }
  throw _refused(index, 'op must be create, update or delete.');
}

void _onlyKeys(int index, Map<String, Object?> op, Set<String> allowed) {
  final extra = op.keys.where((key) => !allowed.contains(key)).toList();
  if (extra.isNotEmpty) {
    throw _refused(index, 'a ${op['op']} does not take ${extra.join(', ')}.');
  }
}

String _id(int index, Object? raw) {
  if (raw is String && raw.isNotEmpty) return raw;
  throw _refused(index, 'needs an id.');
}

Map<String, Object?> _fields(int index, Object? raw) {
  if (raw == null) return const {};
  if (raw is Map) return Map<String, Object?>.from(raw);
  throw _refused(index, 'fields must be an object.');
}

Map<String, RelationChange> _relations(int index, Object? raw) {
  if (raw == null) return const {};
  if (raw is! Map) throw _refused(index, 'relations must be an object.');
  return {
    for (final entry in raw.entries)
      '${entry.key}': _relation(index, '${entry.key}', entry.value),
  };
}

RelationChange _relation(int index, String name, Object? raw) {
  if (raw is! Map) throw _refused(index, 'relation $name must be an object.');
  final add = _ids(index, name, raw['add']);
  final remove = _ids(index, name, raw['remove']);
  final set = raw.containsKey('set') ? _ids(index, name, raw['set']) : null;
  if (set != null && (add.isNotEmpty || remove.isNotEmpty)) {
    throw _refused(index, 'relation $name takes set, or add and remove.');
  }
  return RelationChange(add: add, remove: remove, set: set);
}

List<String> _ids(int index, String name, Object? raw) {
  if (raw == null) return const [];
  if (raw is List && raw.every((id) => id is String)) {
    return raw.cast<String>();
  }
  throw _refused(index, 'relation $name takes lists of ids.');
}

AgentToolException _refused(int index, String problem) => AgentToolException(
  AgentToolErrorCode.invalidArgument,
  'operations[$index] $problem',
  details: {'operation': index},
);
