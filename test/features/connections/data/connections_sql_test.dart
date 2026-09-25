import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/data/connections_edge_sql.dart';
import 'package:submersion/features/connections/data/connections_membership_sql.dart';
import 'package:submersion/features/connections/data/connections_node_sql.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
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

    test('a focus pins side a and excludes the focus from side b', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: 'me',
        filter: const DiveFilterState(),
        focus: const NodeRef(ConnectionKind.buddy, 'jane'),
      );
      expect(r.sql, contains('a.entity_id = ?'));
      expect(r.sql, contains('b.entity_id <> a.entity_id'));
      expect(r.sql, isNot(contains('a.entity_id < b.entity_id')));
      expect(r.params, ['me', 'jane']);
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
        expect(r.sql, contains('d.id IN (SELECT id FROM dives WHERE'));
        expect(r.params, ['me', 's1']);
      },
    );

    test('restrictTo limits both ends', () {
      final r = buildEdgeSql(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        diverId: null,
        filter: const DiveFilterState(),
        restrictTo: ['x', 'y'],
      );
      expect(r.sql, contains('a.entity_id IN (?, ?)'));
      expect(r.sql, contains('b.entity_id IN (?, ?)'));
      expect(r.params, ['x', 'y', 'x', 'y']);
    });
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

    test('the buddy role query keeps only unanimous roles', () {
      final r = buildBuddyRoleSql(
        diverId: 'me',
        filter: const DiveFilterState(),
        buddyIds: ['a'],
      );
      expect(r.sql, contains('HAVING COUNT(DISTINCT db.role) = 1'));
      expect(r.params, ['me', 'a']);
    });
  });
}
