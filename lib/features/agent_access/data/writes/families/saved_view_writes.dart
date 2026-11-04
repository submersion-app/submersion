import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/checklist_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/saved_query_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/json_object_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

/// Saved queries, through the repository the query bar saves with. A query
/// is the stored tree a read shows, checked as the query bar checks one and
/// stored as it re-reads, a group of one printed without its group.
class SavedQueryWrites extends WritableEntry {
  SavedQueryWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'saved_queries';

  @override
  String get table => 'saved_queries';

  @override
  String get note =>
      'query is a stored query, {"version": 1, "node": ...}, as a read '
      'shows one. sort_order is the place among the profile\'s saved '
      'queries of the subject.';

  @override
  late final Map<String, FieldCodec> fields = {
    'subject': const FieldCodec.text(maxLength: 60),
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'query': const JsonObjectCodec(shape: 'a stored query object'),
    'sort_order': const FieldCodec.integer(min: 0, max: 999),
  };

  @override
  Set<String> get requiredOnCreate => const {'subject', 'name', 'query'};

  @override
  Set<String> get createOnly => const {'subject'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final subject =
        (check.values['subject'] ?? check.document!['subject'])! as String;
    if (check.values['sort_order'] case final int at
        when at >= (await _order(subject, check.ownerId)).length) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'sort_order: past the last of this subject\'s saved queries.',
      );
    }
    final query = check.values['query'];
    if (query is! String) return null;
    return (await checkedQuery(
      _r,
      key: 'query',
      subject: subject,
      query: JsonObjectCodec.decoded(query),
      diverId: check.ownerId,
    )).problem;
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final subject = values['subject']! as String;
    final saved = await _r.savedQueries.create(
      subject: QuerySubject.values.byName(subject),
      name: values['name']! as String,
      node: await _node(subject, values['query'], diverId),
      diverId: diverId,
    );
    return saved.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final repo = _r.savedQueries;
    if (v['name'] case final String name) await repo.rename(id, name);
    final current = await repo.getById(id);
    if (current == null) return;
    if (v.containsKey('query')) {
      await repo.updateQuery(
        id,
        await _node(current.subject, v['query'], ownerId),
      );
    }
    if (v['sort_order'] case final int at) {
      await repo.reorder(
        placed(await _order(current.subject, ownerId), id, at),
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.savedQueries.delete(id);

  Future<QueryNode> _node(
    String subject,
    Object? query,
    String? diverId,
  ) async {
    final checked = await checkedQuery(
      _r,
      key: 'query',
      subject: subject,
      query: JsonObjectCodec.decoded(query),
      diverId: diverId,
    );
    return flattenOneChildGroups(checked.load.node!);
  }

  /// The profile's saved queries of [subject], in order.
  Future<List<String>> _order(String subject, String? ownerId) async => [
    for (final q in await _r.savedQueries.getAll(
      subject: subject,
      diverId: ownerId,
    ))
      if (q.diverId == ownerId) q.id,
  ];
}

/// A connection map's spec as the store keeps it: links between kinds it
/// does not show dropped and the shared-dive minimum held to 1 to 10, as the
/// map's own constructor keeps them.
Map<String, Object?> _spec(Map<String, Object?> raw) =>
    (MapSpec.fromJson(raw) ??
            (throw const FieldRefusal(
              'This spec names a kind or link this app does not know.',
            )))
        .toJson();

/// Saved connection maps, through the repository the connections page
/// saves with.
class ConnectionMapWrites extends WritableEntry {
  ConnectionMapWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'connection_maps';

  @override
  String get table => 'connection_maps';

  @override
  String get note =>
      'spec is {"kinds": [...], "links": ["kind-kind", ...], "min": n}: the '
      'kinds shown, the links between them, and the dives two records must '
      'share, 1 to 10. A link between kinds not shown is dropped.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'spec': const JsonObjectCodec(shape: 'a map spec', normalize: _spec),
  };

  @override
  Set<String> get requiredOnCreate => const {'name', 'spec'};

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.connectionMaps.create(
        diverId: diverId,
        name: values['name']! as String,
        spec: MapSpec.fromJson(JsonObjectCodec.decoded(values['spec']))!,
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    if (v['name'] case final String name) {
      await _r.connectionMaps.rename(id, name);
    }
    if (v['spec'] case final String spec) {
      await _r.connectionMaps.updateSpec(
        id,
        MapSpec.fromJson(JsonObjectCodec.decoded(spec))!,
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.connectionMaps.delete(id);
}
