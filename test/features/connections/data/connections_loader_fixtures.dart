import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/connections/data/connections_reader.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Records the id restrictions of every edge query, so a test can bound the
/// work a loader does.
class SpyReader extends ConnectionsReader {
  SpyReader(super.db);

  /// One entry per edge query: the restrictA and restrictB sizes, or null
  /// for an unrestricted side.
  final List<(int?, int?)> edgeCalls = [];

  /// The calls that carry a restrictB: the chord and map passes (discovery
  /// passes an exclusion instead).
  Iterable<(int?, int?)> get restrictedCalls =>
      edgeCalls.where((c) => c.$2 != null);

  /// One entry per node query: how many rows it returned.
  final List<int> nodeRowCounts = [];

  @override
  Future<List<ConnectionNode>> nodes(
    ConnectionKind kind, {
    required String? diverId,
    required DiveFilterState filter,
    Iterable<String>? onlyIds,
    String? labelLike,
    int? limit,
    bool byRank = false,
  }) async {
    final rows = await super.nodes(
      kind,
      diverId: diverId,
      filter: filter,
      onlyIds: onlyIds,
      labelLike: labelLike,
      limit: limit,
      byRank: byRank,
    );
    nodeRowCounts.add(rows.length);
    return rows;
  }

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
    edgeCalls.add((restrictA?.length, restrictB?.length));
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

const _ms = 1700000000000;

Future<void> _diver(db.AppDatabase d) => d
    .into(d.divers)
    .insert(
      const db.DiversCompanion(
        id: Value('me'),
        name: Value('me'),
        createdAt: Value(_ms),
        updatedAt: Value(_ms),
      ),
    );

/// Inserts buddies [ids] and one dive per entry of [dives], each dive
/// joined by the buddies it lists.
Future<void> _buddiesAndDives(
  db.AppDatabase d,
  List<String> ids,
  List<List<String>> dives,
) async {
  await d.batch((b) {
    for (final id in ids) {
      b.insert(
        d.buddies,
        db.BuddiesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
    }
    for (var i = 0; i < dives.length; i++) {
      final diveId = 'd$i';
      b.insert(
        d.dives,
        db.DivesCompanion(
          id: Value(diveId),
          diverId: const Value('me'),
          diveDateTime: Value(_ms + i * 86400000),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
      for (final buddy in dives[i]) {
        b.insert(
          d.diveBuddies,
          db.DiveBuddiesCompanion(
            id: Value('$diveId-$buddy'),
            diveId: Value(diveId),
            buddyId: Value(buddy),
            role: const Value('buddy'),
            createdAt: const Value(_ms),
          ),
        );
      }
    }
  });
}

/// Buddy `f` dives with buddies `b1` to `bn`; `b<i>` shares `shared(i)` dives with
/// 'f'. Distinct counts give a trim without ties, equal counts a tie class.
Future<void> seedStar(
  db.AppDatabase d,
  int Function(int i) shared,
  int n,
) async {
  await _diver(d);
  await _buddiesAndDives(
    d,
    ['f', for (var i = 1; i <= n; i++) 'b$i'],
    [
      for (var i = 1; i <= n; i++)
        for (var k = 0; k < shared(i); k++) ['f', 'b$i'],
    ],
  );
}

/// Buddy `f` dives with `b1` to `bn` (b<i> on i dives), and each `b<i>`
/// dives once with its own `o<i>`, one hop further out.
Future<void> seedTwoRings(db.AppDatabase d, int n) async {
  await _diver(d);
  await _buddiesAndDives(
    d,
    [
      'f',
      for (var i = 1; i <= n; i++) 'b$i',
      for (var i = 1; i <= n; i++) 'o$i',
    ],
    [
      for (var i = 1; i <= n; i++)
        for (var k = 0; k < i; k++) ['f', 'b$i'],
      for (var i = 1; i <= n; i++) ['b$i', 'o$i'],
    ],
  );
}

/// A chain f, c1, c2, c3: each consecutive pair shares one dive, so `c<k>` is
/// exactly k hops from f.
Future<void> seedChain(db.AppDatabase d) async {
  await _diver(d);
  await _buddiesAndDives(
    d,
    ['f', 'c1', 'c2', 'c3'],
    [
      ['f', 'c1'],
      ['c1', 'c2'],
      ['c2', 'c3'],
    ],
  );
}
