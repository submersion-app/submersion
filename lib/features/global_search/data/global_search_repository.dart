import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/global_search/data/global_search_plan.dart';
import 'package:submersion/features/global_search/data/global_search_sources.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';

/// Reads one source's matches (#3882): its total and the rows it shows.
class GlobalSearchRepository {
  GlobalSearchRepository(this._db);

  final AppDatabase _db;

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
          'SELECT ${_columns(source)}, COUNT(*) OVER () AS total $from '
          'ORDER BY ${source.orderBy}'
          '${limit == null ? '' : ' LIMIT $limit'}',
          variables: variables,
        )
        .get();
    return GlobalSearchSection(
      kind: source.kind,
      total: rows.isEmpty ? 0 : rows.first.read<int>('total'),
      hits: rows.map((row) => _hit(source, row)).toList(),
      query: run.query,
      hasList: source.hasList,
    );
  }

  String _columns(GlobalSearchSource source) => [
    'r0.id AS id',
    '${source.titleSql} AS title',
    for (final (i, sql) in source.detailSql.indexed) '$sql AS detail$i',
    if (source.dateSql case final sql?) '$sql AS hit_date',
    if (source.depthSql case final sql?) '$sql AS hit_depth',
    if (source.numberSql case final sql?) '$sql AS hit_number',
  ].join(', ');

  GlobalSearchHit _hit(GlobalSearchSource source, QueryRow row) {
    final millis = source.dateSql == null
        ? null
        : row.readNullable<int>('hit_date');
    return GlobalSearchHit(
      kind: source.kind,
      id: row.read<String>('id'),
      title: _text(row.readNullable<String>('title')),
      details: [
        for (var i = 0; i < source.detailSql.length; i++)
          ?_text(row.readNullable<String>('detail$i')),
      ],
      date: millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              millis,
              isUtc: source.dateFrame == GlobalSearchDateFrame.wallClockUtc,
            ),
      depthMeters: source.depthSql == null
          ? null
          : row.readNullable<double>('hit_depth'),
      number: source.numberSql == null
          ? null
          : row.readNullable<int>('hit_number'),
    );
  }

  /// [value] trimmed, or null when nothing remains of it.
  String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
