import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/connections/data/connections_node_sql.dart';
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

  /// How many neighbour reads ran: one for each kind on each hop.
  int neighbourReads = 0;

  /// Every row every edge query returned.
  int edgeRowCount = 0;

  @override
  Future<List<ConnectionNode>> nodes(
    ConnectionKind kind, {
    required String? diverId,
    required DiveFilterState filter,
    Iterable<String>? onlyIds,
    String? labelLike,
    int? limit,
    bool byRank = false,
    ConnectionKind? sharedWith,
    NeighboursOf? neighboursOf,
  }) async {
    if (neighboursOf != null) neighbourReads++;
    final rows = await super.nodes(
      kind,
      diverId: diverId,
      filter: filter,
      onlyIds: onlyIds,
      labelLike: labelLike,
      limit: limit,
      byRank: byRank,
      sharedWith: sharedWith,
      neighboursOf: neighboursOf,
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
  }) async {
    edgeCalls.add((restrictA?.length, restrictB?.length));
    final rows = await super.edges(
      kindA,
      kindB,
      diverId: diverId,
      filter: filter,
      restrictA: restrictA,
      restrictB: restrictB,
      excludeB: excludeB,
      minShared: minShared,
    );
    edgeRowCount += rows.length;
    return rows;
  }

  @override
  Future<List<ConnectionEdge>> edgesAmong(
    ConnectionKind kind,
    Iterable<String> ids, {
    required String? diverId,
    required DiveFilterState filter,
    int minShared = 1,
  }) async {
    edgeCalls.add((ids.length, ids.length));
    final rows = await super.edgesAmong(
      kind,
      ids,
      diverId: diverId,
      filter: filter,
      minShared: minShared,
    );
    edgeRowCount += rows.length;
    return rows;
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

/// Buddy `f` dives once with each of `b01` to `b20`, and every one of them
/// dives twice in all: one tie class on hop and dive count. `b03` and `b04`
/// share their second dive, as do `b19` and `b20`, so those pairs have the
/// most weighted degree; the rest dive it alone.
Future<void> seedTiedStar(db.AppDatabase d) async {
  await _diver(d);
  String id(int i) => 'b${i.toString().padLeft(2, '0')}';
  const paired = {3, 4, 19, 20};
  await _buddiesAndDives(
    d,
    ['f', for (var i = 1; i <= 20; i++) id(i)],
    [
      for (var i = 1; i <= 20; i++) ['f', id(i)],
      for (var i = 1; i <= 20; i++)
        if (!paired.contains(i)) [id(i)],
      [id(3), id(4)],
      [id(19), id(20)],
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

/// Buddy `b` dives at sites `s1` and `s2`, and `s1` once more alone; `s3`
/// is dived only alone. With [withBuddy] false no dive has a buddy.
Future<void> seedSites(db.AppDatabase d, {bool withBuddy = true}) async {
  await _diver(d);
  final dives = [
    ('d0', 's1', withBuddy),
    ('d1', 's2', withBuddy),
    ('d2', 's3', false),
    ('d3', 's1', false),
  ];
  await d.batch((b) {
    for (final id in ['s1', 's2', 's3']) {
      b.insert(
        d.diveSites,
        db.DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
    }
    b.insert(
      d.buddies,
      const db.BuddiesCompanion(
        id: Value('b'),
        name: Value('b'),
        createdAt: Value(_ms),
        updatedAt: Value(_ms),
      ),
    );
    for (var i = 0; i < dives.length; i++) {
      final (diveId, site, buddy) = dives[i];
      b.insert(
        d.dives,
        db.DivesCompanion(
          id: Value(diveId),
          diverId: const Value('me'),
          siteId: Value(site),
          diveDateTime: Value(_ms + i * 86400000),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
      if (buddy) {
        b.insert(
          d.diveBuddies,
          db.DiveBuddiesCompanion(
            id: Value('$diveId-b'),
            diveId: Value(diveId),
            buddyId: const Value('b'),
            role: const Value('buddy'),
            createdAt: const Value(_ms),
          ),
        );
      }
    }
  });
}

/// A log with every shape the around and map reads must agree on: a repeated
/// kit with odd pieces swapped in, a species sighted twice on one dive, a
/// tag, a second diver's dives, and dives the statistics scope leaves out.
/// Buddy `lonely` has no dive at all.
Future<void> seedMixedLog(db.AppDatabase d, int seed, {int dives = 120}) async {
  const buddies = 25, sites = 12, species = 30, gear = 14, tags = 6;
  final rng = math.Random(seed);
  await _diver(d);
  await d
      .into(d.divers)
      .insert(
        const db.DiversCompanion(
          id: Value('other'),
          name: Value('other'),
          createdAt: Value(_ms),
          updatedAt: Value(_ms),
        ),
      );
  await d.batch((b) {
    for (final id in ['lonely', for (var i = 0; i < buddies; i++) 'b$i']) {
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
    for (var i = 0; i < sites; i++) {
      b.insert(
        d.diveSites,
        db.DiveSitesCompanion(
          id: Value('s$i'),
          name: Value('s$i'),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
    }
    for (var i = 0; i < species; i++) {
      b.insert(
        d.species,
        db.SpeciesCompanion(
          id: Value('sp$i'),
          commonName: Value('sp$i'),
          category: const Value('fish'),
        ),
      );
    }
    for (var i = 0; i < gear; i++) {
      b.insert(
        d.equipment,
        db.EquipmentCompanion(
          id: Value('e$i'),
          name: Value('e$i'),
          type: const Value('regulator'),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
    }
    for (var i = 0; i < tags; i++) {
      b.insert(
        d.tags,
        db.TagsCompanion(
          id: Value('t$i'),
          name: Value('t$i'),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
    }
  });
  await d.batch((b) {
    for (var i = 0; i < dives; i++) {
      final diveId = 'd$i';
      final roll = rng.nextInt(20);
      b.insert(
        d.dives,
        db.DivesCompanion(
          id: Value(diveId),
          diverId: Value(roll == 0 ? 'other' : 'me'),
          siteId: Value('s${rng.nextInt(sites)}'),
          diveDateTime: Value(_ms + i * 86400000),
          excludedFromStats: Value(roll == 1),
          isPlanned: Value(roll == 2),
          createdAt: const Value(_ms),
          updatedAt: const Value(_ms),
        ),
      );
      final set = rng.nextInt(3) * 3;
      for (final g in {set, set + 1, set + 2, 9 + rng.nextInt(gear - 9)}) {
        b.insert(
          d.diveEquipment,
          db.DiveEquipmentCompanion(
            diveId: Value(diveId),
            equipmentId: Value('e$g'),
          ),
        );
      }
      for (final who in {rng.nextInt(buddies), rng.nextInt(buddies)}) {
        b.insert(
          d.diveBuddies,
          db.DiveBuddiesCompanion(
            id: Value('$diveId-b$who'),
            diveId: Value(diveId),
            buddyId: Value('b$who'),
            role: const Value('buddy'),
            createdAt: const Value(_ms),
          ),
        );
      }
      final seen = rng.nextInt(species);
      for (final (n, sp) in [seen, seen, rng.nextInt(species)].indexed) {
        b.insert(
          d.sightings,
          db.SightingsCompanion(
            id: Value('$diveId-s$n'),
            diveId: Value(diveId),
            speciesId: Value('sp$sp'),
          ),
        );
      }
      if (rng.nextBool()) {
        b.insert(
          d.diveTags,
          db.DiveTagsCompanion(
            id: Value('$diveId-t'),
            diveId: Value(diveId),
            tagId: Value('t${rng.nextInt(tags)}'),
            createdAt: const Value(_ms),
          ),
        );
      }
    }
  });
}
