import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/data/connections_edge_sql.dart';
import 'package:submersion/features/connections/data/connections_membership_sql.dart';
import 'package:submersion/features/connections/data/connections_node_sql.dart';
import 'package:submersion/features/connections/data/connections_scope_sql.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

void main() {
  group('membershipSql', () {
    test('every kind yields dive_id and entity_id columns', () {
      for (final kind in ConnectionKind.values) {
        final sql = membershipSql(kind);
        expect(sql, contains('dive_id'));
        expect(sql, contains('AS entity_id'));
        expect(sql.trim(), startsWith('SELECT'));
      }
    });

    test('column kinds exclude null links', () {
      expect(
        membershipSql(ConnectionKind.site),
        contains('site_id IS NOT NULL'),
      );
      expect(
        membershipSql(ConnectionKind.course),
        contains('course_id IS NOT NULL'),
      );
    });
  });

  group('buildEdgeSql', () {
    test('self-join dedupes unordered pairs and scopes to the diver', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(r.sql, contains('a.entity_id < b.entity_id'));
      expect(r.sql, contains('d.diver_id = ?'));
      expect(r.sql, contains('d.excluded_from_stats = 0'));
      expect(r.sql, contains('d.is_planned = 0'));
      expect(r.sql, contains('COUNT(DISTINCT d.id) AS weight'));
      expect(r.params, ['me']);
    });

    test('mixed kinds do not dedupe and a null diver adds no clause', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.site,
        diverId: null,
        filter: const DiveFilterState(),
      );
      expect(r.sql, isNot(contains('a.entity_id < b.entity_id')));
      expect(r.sql, isNot(contains('diver_id')));
      expect(r.params, isEmpty);
    });

    test('restricting only side A spokes out without self pairs', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: 'me',
        filter: const DiveFilterState(),
        restrictA: ['jane'],
      );
      expect(r.sql, contains('a.entity_id IN (?)'));
      expect(r.sql, contains('b.entity_id <> a.entity_id'));
      expect(r.sql, isNot(contains('a.entity_id < b.entity_id')));
      expect(r.params, ['me', 'jane']);
    });

    test('restricting both sides of a same-kind pair dedupes', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: null,
        filter: const DiveFilterState(),
        restrictA: ['x', 'y'],
        restrictB: ['x', 'y'],
      );
      expect(r.sql, contains('a.entity_id IN (?, ?)'));
      expect(r.sql, contains('b.entity_id IN (?, ?)'));
      expect(r.sql, contains('a.entity_id < b.entity_id'));
      expect(r.params, ['x', 'y', 'x', 'y']);
    });

    test('excludeB and minShared bind after the restrictions', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.site,
        diverId: 'me',
        filter: const DiveFilterState(),
        restrictA: ['jane'],
        excludeB: ['s1', 's2'],
        minShared: 3,
      );
      expect(r.sql, contains('b.entity_id NOT IN (?, ?)'));
      expect(r.sql, contains('HAVING COUNT(DISTINCT d.id) >= ?'));
      expect(r.params, ['me', 'jane', 's1', 's2', 3]);
    });

    test('empty restrictions match nothing; empty exclusions add nothing', () {
      final nothing = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.site,
        diverId: null,
        filter: const DiveFilterState(),
        restrictB: const [],
      );
      expect(nothing.sql, contains('0 = 1'));
      final open = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.site,
        diverId: null,
        filter: const DiveFilterState(),
        excludeB: const [],
      );
      expect(open.sql, isNot(contains('NOT IN')));
      expect(open.sql, isNot(contains('HAVING')));
    });

    test(
      'an active filter appends the id subquery and its params after the diver',
      () {
        final r = buildEdgeSql(
          kindA: ConnectionKind.buddy,
          kindB: ConnectionKind.buddy,
          diverId: 'me',
          filter: const DiveFilterState(siteId: 's1'),
        );
        expect(r.sql, contains('d.id IN (SELECT'));
        expect(r.params.first, 'me');
        expect(r.params, contains('s1'));
      },
    );
  });

  group('buildNodeSql', () {
    test('joins counts to the label table and selects extra columns', () {
      final r = buildNodeSql(
        kind: ConnectionKind.site,
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(r.sql, contains('JOIN dive_sites t ON t.id = c.entity_id'));
      expect(r.sql, contains('t.name AS label'));
      expect(r.sql, contains('t.region AS region'));
      expect(r.sql, contains('t.country AS country'));
      expect(r.sql, contains('COUNT(DISTINCT d.id) AS dive_count'));
      expect(r.params, ['me']);
    });

    test('onlyIds narrows the entity set', () {
      final r = buildNodeSql(
        kind: ConnectionKind.buddy,
        diverId: null,
        filter: const DiveFilterState(),
        onlyIds: ['a', 'b'],
      );
      expect(r.sql, contains('m.entity_id IN (?, ?)'));
      expect(r.params, ['a', 'b']);
    });

    test('labelLike and limit bind after onlyIds', () {
      final r = buildNodeSql(
        kind: ConnectionKind.species,
        diverId: 'me',
        filter: const DiveFilterState(),
        onlyIds: ['sp1'],
        labelLike: '%tur%',
        limit: 5,
      );
      expect(r.sql, contains("t.common_name LIKE ? ESCAPE '\\'"));
      expect(r.sql, contains('LIMIT ?'));
      expect(r.params, ['me', 'sp1', '%tur%', 5]);
    });

    test('escapeLike escapes the LIKE metacharacters', () {
      expect(escapeLike(r'50%_off\'), r'50\%\_off\\');
      expect(escapeLike('plain'), 'plain');
    });

    test('the buddy role query returns every in-scope link (#1221)', () {
      // The reader resolves each link's role set; the SQL no longer decides
      // unanimity on the primary role alone.
      final r = buildBuddyRoleSql(
        diverId: 'me',
        filter: const DiveFilterState(),
        buddyIds: ['a'],
      );
      expect(r.sql, contains('db.dive_id AS dive_id'));
      expect(r.sql, isNot(contains('HAVING')));
      expect(r.params, ['me', 'a']);
    });
  });
}
