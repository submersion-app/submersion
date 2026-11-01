import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/documents/dive_document.dart'
    show kProfileDefaultLimit;
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// What one read asked for.
class RecordLoad {
  const RecordLoad({
    required this.include,
    required this.diverId,
    this.profileOffset = 0,
    this.profileLimit = kProfileDefaultLimit,
  });

  /// The child blocks named by the caller.
  final Set<String> include;

  /// The profile the read acts as.
  final String diverId;

  /// The window over a long child series (dive samples, track points).
  final int profileOffset;
  final int profileLimit;
}

/// Loads one child block of [record]. The result goes in the document under
/// the block's name.
typedef BlockLoader<T> = Future<Object?> Function(T record, RecordLoad load);

/// The face the tools use, free of the record type: calling these methods
/// never reads a typed field through a wider static type, so a list of mixed
/// entities cannot fail a covariance check.
abstract interface class RecordEntry {
  /// The wire name, as an agent passes it in `entity`.
  String get name;

  /// The table `id` and the scope refer to.
  String get table;
  RecordScope get scope;

  /// The column `parent_id` filters on, when the entity has one.
  String? get parentColumn;

  /// SQL over alias `r0`, ahead of the `r0.id` tie break.
  String get orderBy;

  Set<String> get blocks;

  /// A full document per id that loaded, in the order of [ids].
  Future<Map<String, Map<String, Object?>>> read(
    List<String> ids,
    RecordLoad load,
  );

  /// A compact row per id that loaded, in the order of [ids].
  Future<List<Map<String, Object?>>> summaries(
    List<String> ids,
    RecordLoad load,
  );
}

/// One readable entity: how to find its rows, load them through their
/// repository and map them to a document.
class RecordEntity<T> implements RecordEntry {
  const RecordEntity({
    required this.name,
    required this.table,
    required this.scope,
    required Future<Map<String, T>> Function(List<String>, RecordLoad) load,
    required Map<String, Object?> Function(T) document,
    required List<String> summaryKeys,
    this.parentColumn,
    this.orderBy = 'r0.id',
    Map<String, BlockLoader<T>> blocks = const {},
    Future<List<Map<String, Object?>>> Function(List<String>, RecordLoad)?
    summarize,
  }) : _load = load,
       _document = document,
       _summaryKeys = summaryKeys,
       _blocks = blocks,
       _summarize = summarize;

  @override
  final String name;
  @override
  final String table;
  @override
  final RecordScope scope;
  @override
  final String? parentColumn;
  @override
  final String orderBy;

  final Future<Map<String, T>> Function(List<String>, RecordLoad) _load;
  final Map<String, Object?> Function(T) _document;
  final List<String> _summaryKeys;
  final Map<String, BlockLoader<T>> _blocks;
  final Future<List<Map<String, Object?>>> Function(List<String>, RecordLoad)?
  _summarize;

  @override
  Set<String> get blocks => _blocks.keys.toSet();

  @override
  Future<Map<String, Map<String, Object?>>> read(
    List<String> ids,
    RecordLoad load,
  ) async {
    final records = await _load(ids, load);
    final documents = <String, Map<String, Object?>>{};
    for (final id in ids) {
      final record = records[id];
      if (record == null) continue;
      final document = _document(record);
      for (final entry in _blocks.entries) {
        if (load.include.contains(entry.key)) {
          document[entry.key] = await entry.value(record, load);
        }
      }
      documents[id] = document;
    }
    return documents;
  }

  @override
  Future<List<Map<String, Object?>>> summaries(
    List<String> ids,
    RecordLoad load,
  ) async {
    final summarize = _summarize;
    if (summarize != null) return summarize(ids, load);
    final documents = await read(
      ids,
      RecordLoad(include: const {}, diverId: load.diverId),
    );
    return [
      for (final id in ids)
        if (documents[id] case final document?)
          {'id': id, for (final key in _summaryKeys) key: document[key]},
    ];
  }
}

/// Keys [records] by [idOf].
Map<String, T> byId<T>(Iterable<T> records, String Function(T) idOf) => {
  for (final record in records) idOf(record): record,
};

/// One read per id, for a repository with no batch method. A read tool is
/// bounded by its page size, and these reads are local.
Future<Map<String, T>> loadEach<T>(
  List<String> ids,
  Future<T?> Function(String) read,
) async {
  final loaded = <String, T>{};
  for (final id in ids) {
    final record = await read(id);
    if (record != null) loaded[id] = record;
  }
  return loaded;
}

/// One read per parent, for [loadChildren] over a repository with no batch
/// method.
Future<Map<String, List<T>>> eachParent<T>(
  List<String> parents,
  Future<List<T>> Function(String) read,
) async => {for (final id in parents) id: await read(id)};

/// Loads children by id through a repository that only reads by parent: finds
/// each child's parent, reads those parents' children once, and keeps the
/// ones asked for.
Future<Map<String, T>> loadChildren<T>(
  AppDatabase db, {
  required String table,
  required String parentColumn,
  required List<String> ids,
  required String Function(T) idOf,
  required Future<Map<String, List<T>>> Function(List<String>) byParents,
}) async {
  final parents = <String>{};
  for (final chunk in seriesIdChunks(ids)) {
    final marks = List.filled(chunk.length, '?').join(', ');
    final rows = await db
        .customSelect(
          'SELECT DISTINCT $parentColumn AS parent FROM $table '
          'WHERE id IN ($marks) AND $parentColumn IS NOT NULL',
          variables: [for (final id in chunk) Variable<String>(id)],
        )
        .get();
    parents.addAll(rows.map((r) => r.read<String>('parent')));
  }
  if (parents.isEmpty) return const {};
  final wanted = ids.toSet();
  return {
    for (final children in (await byParents(parents.toList())).values)
      for (final child in children)
        if (wanted.contains(idOf(child))) idOf(child): child,
  };
}
