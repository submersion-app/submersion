import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/global_search/data/global_search_plan.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';

/// Reads one source's matches (#3882): its total and the records to show.
class GlobalSearchRepository {
  /// [database] is for tests. The app reads the live instance on every call,
  /// as the repositories do, because moving the database replaces it.
  GlobalSearchRepository([AppDatabase? database]) : _override = database;

  final AppDatabase? _override;

  AppDatabase get _db => _override ?? DatabaseService.instance.database;

  Future<GlobalSearchSection> search(
    GlobalSearchRun run, {
    String? diverId,
  }) async {
    final source = run.source;
    final compiled = run.compiled;
    final scope = source.scope(diverId);
    final from =
        'FROM ${compiled.table} ${compiled.rootAlias} '
        'WHERE ${compiled.isEmpty ? '1' : compiled.where}${scope.whereClause}';
    final variables = <Variable<Object>>[
      for (final p in compiled.params) Variable<Object>(p as Object),
      ...scope.variables,
    ];
    final limit = source.previewLimit;

    // The window counts every match before LIMIT applies, so one scan answers
    // both the total and the preview.
    final rows = await _db
        .customSelect(
          'SELECT r0.id AS id, COUNT(*) OVER () AS total $from '
          'ORDER BY ${source.orderBy}'
          '${limit == null ? '' : ' LIMIT $limit'}',
          variables: variables,
        )
        .get();
    return GlobalSearchSection(
      kind: source.kind,
      total: rows.isEmpty ? 0 : rows.first.read<int>('total'),
      ids: [for (final row in rows) row.read<String>('id')],
      query: run.query,
      hasList: source.hasList,
    );
  }
}
