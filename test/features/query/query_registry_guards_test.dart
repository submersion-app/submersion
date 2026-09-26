import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/sql_templates.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../helpers/test_database.dart';

/// The registry is hand-written SQL. These guards make a renamed column, a
/// misspelled table, a missing label or a template without ESCAPE fail the
/// build instead of a query at runtime.
void main() {
  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  TableInfo tableNamed(String name) => db.allTables.firstWhere(
    (t) => t.actualTableName == name,
    orElse: () => throw StateError('no table $name'),
  );

  test('every entity names a real table with a real id column', () {
    for (final e in appQueryRegistry.entities) {
      final t = tableNamed(e.table);
      final columns = t.$columns.map((c) => c.$name);
      expect(columns, contains(e.idColumn), reason: e.table);
      if (e.diverScopeColumn != null) {
        expect(columns, contains(e.diverScopeColumn), reason: e.table);
      }
    }
  });

  test('every field sql and emptySql compiles against its table', () async {
    for (final e in appQueryRegistry.entities) {
      for (final f in e.fields) {
        final fragments = [
          if (f.boolSql == null) '${substituteRow(f.sql, 'r0')} IS NOT NULL',
          substituteRow(f.emptySql, 'r0'),
          if (f.boolSql != null) substituteRow(f.boolSql!.whenTrue, 'r0'),
          if (f.boolSql != null) substituteRow(f.boolSql!.whenFalse, 'r0'),
        ];
        for (final fragment in fragments) {
          final sql = 'SELECT 1 FROM ${e.table} r0 WHERE $fragment';
          await expectLater(
            db.customSelect(sql).get(),
            completes,
            reason: '${e.subject}.${f.key}: $sql',
          );
        }
      }
    }
  });

  test(
    'every relation joinSql and emptySql compiles, and hop columns exist',
    () async {
      for (final e in appQueryRegistry.entities) {
        for (final r in e.relations) {
          final target = appQueryRegistry.entityFor(r.target);
          final join = substituteJoin(r.joinSql, 'r0', 'r1');
          final sql =
              'SELECT 1 FROM ${e.table} r0 WHERE EXISTS '
              '(SELECT 1 FROM ${target.table} r1 WHERE $join)';
          await expectLater(
            db.customSelect(sql).get(),
            completes,
            reason: '${e.subject}.${r.key}: $sql',
          );
          if (r.emptySql != null) {
            final empty =
                'SELECT 1 FROM ${e.table} r0 WHERE '
                '${substituteJoin(r.emptySql!, 'r0', 'r1')}';
            await expectLater(
              db.customSelect(empty).get(),
              completes,
              reason: '${e.subject}.${r.key} emptySql',
            );
          }
          final refs = RegExp(r'\{(to|from)\}\.(\w+)').allMatches(r.joinSql);
          for (final m in refs) {
            final table = m[1] == 'to' ? target.table : e.table;
            expect(
              tableNamed(table).$columns.map((c) => c.$name),
              contains(m[2]),
              reason: '${e.subject}.${r.key} names ${m[2]} on $table',
            );
          }
          if (r.shape == RelationShape.fk || r.shape == RelationShape.child) {
            expect(
              refs.length,
              2,
              reason:
                  '${e.subject}.${r.key}: an fk or child hop is one '
                  'equality',
            );
          }
        }
      }
    },
  );

  test('every declared extra table exists', () {
    for (final e in appQueryRegistry.entities) {
      for (final t in [
        ...e.textSearchTables,
        for (final f in e.fields) ...f.tables,
        for (final r in e.relations) ...r.tables,
      ]) {
        tableNamed(t);
      }
    }
  });

  test('text search templates escape LIKE and compile', () async {
    for (final e in appQueryRegistry.entities) {
      for (final t in e.textSearchSql) {
        expect(t, contains("ESCAPE '\\'"), reason: '${e.subject}: $t');
        final n = countPlaceholders(t);
        final sql =
            'SELECT 1 FROM ${e.table} r0 WHERE ${substituteRow(t, 'r0')}';
        await expectLater(
          db
              .customSelect(
                sql,
                variables: [
                  for (var i = 0; i < n; i++) const Variable<String>('%x%'),
                ],
              )
              .get(),
          completes,
          reason: '${e.subject}: $sql',
        );
      }
    }
  });

  test('every label key exists in every locale', () {
    final dir = p.join('lib', 'l10n', 'arb');
    final files = Directory(
      dir,
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.arb'));
    final expected = <String>{
      for (final e in appQueryRegistry.entities) ...[
        'query_entity_${e.subject.name}',
        for (final f in e.fields) f.labelKey,
        for (final r in e.relations) r.labelKey,
      ],
    };
    for (final f in files) {
      final keys = (jsonDecode(f.readAsStringSync()) as Map<String, Object?>)
          .keys
          .toSet();
      final missing = expected.difference(keys);
      expect(missing, isEmpty, reason: '${p.basename(f.path)} lacks $missing');
    }
  });

  test('enum fields list the stored names', () {
    for (final e in appQueryRegistry.entities) {
      for (final f in e.fields) {
        if (f.enumValues != null) {
          expect(f.enumValues, isNotEmpty, reason: '${e.subject}.${f.key}');
          expect(f.enumValues!.toSet().length, f.enumValues!.length);
        }
      }
    }
  });

  test('every table a fragment reads is declared, for the change ticks', () {
    final fromOrJoin = RegExp(r'\b(?:FROM|JOIN)\s+(\w+)');
    for (final e in appQueryRegistry.entities) {
      Set<String> read(String sql) =>
          fromOrJoin.allMatches(sql).map((m) => m[1]!).toSet();
      for (final f in e.fields) {
        final declared = {e.table, ...f.tables};
        final used = {
          ...read(f.sql),
          ...read(f.emptySql),
          if (f.boolSql != null) ...read(f.boolSql!.whenTrue),
          if (f.boolSql != null) ...read(f.boolSql!.whenFalse),
        };
        expect(
          used.difference(declared),
          isEmpty,
          reason: '${e.subject}.${f.key} reads undeclared tables',
        );
      }
      for (final r in e.relations) {
        final target = appQueryRegistry.entityFor(r.target).table;
        final declared = {e.table, target, ...r.tables};
        final used = {
          ...read(r.joinSql),
          if (r.emptySql != null) ...read(r.emptySql!),
        };
        expect(
          used.difference(declared),
          isEmpty,
          reason: '${e.subject}.${r.key} reads undeclared tables',
        );
      }
      final textUsed = {for (final t in e.textSearchSql) ...read(t)};
      expect(
        textUsed.difference({e.table, ...e.textSearchTables}),
        isEmpty,
        reason: '${e.subject} text search reads undeclared tables',
      );
    }
  });

  test('only text search templates carry bind placeholders', () {
    for (final e in appQueryRegistry.entities) {
      for (final f in e.fields) {
        for (final sql in [
          f.sql,
          f.emptySql,
          if (f.boolSql != null) f.boolSql!.whenTrue,
          if (f.boolSql != null) f.boolSql!.whenFalse,
        ]) {
          expect(
            countPlaceholders(sql),
            0,
            reason: '${e.subject}.${f.key} would misorder bind params',
          );
        }
      }
      for (final r in e.relations) {
        expect(
          countPlaceholders(r.joinSql),
          0,
          reason: '${e.subject}.${r.key}',
        );
        expect(
          countPlaceholders(r.emptySql ?? ''),
          0,
          reason: '${e.subject}.${r.key} emptySql',
        );
      }
    }
  });
}
