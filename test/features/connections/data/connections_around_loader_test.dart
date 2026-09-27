import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/connections_around_loader.dart';
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../helpers/test_database.dart';

/// Records the id sets every chord query (a query with [restrictB]) is
/// restricted to.
class _SpyReader extends ConnectionsReader {
  _SpyReader(super.db);

  final List<(int, int)> chordSizes = [];

  @override
  Future<List<ConnectionEdge>> edges(
    ConnectionKind kindA,
    ConnectionKind kindB, {
    required String? diverId,
    required DiveFilterState filter,
    Iterable<String>? restrictA,
    Iterable<String>? restrictB,
    Iterable<String>? excludeB,
    int minShared = 1,
  }) {
    if (restrictB != null) {
      chordSizes.add((restrictA?.length ?? 0, restrictB.length));
    }
    return super.edges(
      kindA,
      kindB,
      diverId: diverId,
      filter: filter,
      restrictA: restrictA,
      restrictB: restrictB,
      excludeB: excludeB,
      minShared: minShared,
    );
  }
}

const _focus = NodeRef(ConnectionKind.buddy, 'f');

/// The focus dives with ten buddies; buddy b<i> shares i dives with the
/// focus, so every buddy has a distinct dive count and trimming has no ties.
Future<void> _seed(db.AppDatabase d) async {
  const ms = 1700000000000;
  await d
      .into(d.divers)
      .insert(
        const db.DiversCompanion(
          id: Value('me'),
          name: Value('me'),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
  final buddyIds = ['f', for (var i = 1; i <= 10; i++) 'b$i'];
  await d.batch((b) {
    for (final id in buddyIds) {
      b.insert(
        d.buddies,
        db.BuddiesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(ms),
          updatedAt: const Value(ms),
        ),
      );
    }
    var dive = 0;
    for (var i = 1; i <= 10; i++) {
      for (var k = 0; k < i; k++) {
        final diveId = 'd${dive++}';
        b.insert(
          d.dives,
          db.DivesCompanion(
            id: Value(diveId),
            diverId: const Value('me'),
            diveDateTime: Value(ms + dive * 86400000),
            createdAt: const Value(ms),
            updatedAt: const Value(ms),
          ),
        );
        for (final buddy in ['f', 'b$i']) {
          b.insert(
            d.diveBuddies,
            db.DiveBuddiesCompanion(
              id: Value('$diveId-$buddy'),
              diveId: Value(diveId),
              buddyId: Value(buddy),
              role: const Value('buddy'),
              createdAt: const Value(ms),
            ),
          );
        }
      }
    }
  });
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('chords run only among the entities the budget keeps', () async {
    final d = DatabaseService.instance.database;
    await _seed(d);
    final spy = _SpyReader(d);
    final g = await AroundLoader(spy).load(
      focus: _focus,
      kinds: {ConnectionKind.buddy},
      hops: 1,
      diverId: 'me',
      filter: const DiveFilterState(),
      nodeBudget: 4,
    );
    expect(g.nodes, hasLength(4));
    expect(g.hiddenNodeCount, 7, reason: '11 discovered, 4 shown');
    expect(spy.chordSizes, isNotEmpty);
    for (final (a, b) in spy.chordSizes) {
      expect(a, lessThanOrEqualTo(4));
      expect(b, lessThanOrEqualTo(4));
    }
  });

  test('the kept set matches trimming the whole neighbourhood', () async {
    final d = DatabaseService.instance.database;
    await _seed(d);
    final reader = ConnectionsReader(d);
    Future<Set<NodeRef>> shown(int budget) async {
      final g = await AroundLoader(reader).load(
        focus: _focus,
        kinds: {ConnectionKind.buddy},
        hops: 1,
        diverId: 'me',
        filter: const DiveFilterState(),
        nodeBudget: budget,
      );
      return g.nodes.map((n) => n.ref).toSet();
    }

    final whole = await AroundLoader(reader).load(
      focus: _focus,
      kinds: {ConnectionKind.buddy},
      hops: 1,
      diverId: 'me',
      filter: const DiveFilterState(),
      nodeBudget: 1000,
    );
    final expected = whole
        .trimmed(4, keep: _focus)
        .nodes
        .map((n) => n.ref)
        .toSet();
    expect(await shown(4), expected);
    expect(
      expected,
      containsAll([_focus, const NodeRef(ConnectionKind.buddy, 'b10')]),
    );
  });
}
