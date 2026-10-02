import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

Future<void> _diver(db.AppDatabase d, String id) async {
  final ms = DateTime(2024, 1, 1).millisecondsSinceEpoch;
  await d
      .into(d.divers)
      .insert(
        db.DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _buddy(db.AppDatabase d, String id) async {
  final ms = DateTime(2024, 1, 1).millisecondsSinceEpoch;
  await d
      .into(d.buddies)
      .insert(
        db.BuddiesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _site(db.AppDatabase d, String id, {String? country}) async {
  final ms = DateTime(2024, 1, 1).millisecondsSinceEpoch;
  await d
      .into(d.diveSites)
      .insert(
        db.DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          country: Value(country),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _dive(
  db.AppDatabase d, {
  required String id,
  required DateTime at,
  String? diverId = 'me',
  String? siteId,
  bool planned = false,
  bool excluded = false,
}) async {
  final ms = at.millisecondsSinceEpoch;
  await d
      .into(d.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          siteId: Value(siteId),
          diveDateTime: Value(ms),
          isPlanned: Value(planned),
          excludedFromStats: Value(excluded),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _link(
  db.AppDatabase d,
  String diveId,
  String buddyId, {
  String role = 'buddy',
  String? rowId,
}) async {
  await d
      .into(d.diveBuddies)
      .insert(
        db.DiveBuddiesCompanion(
          id: Value(rowId ?? '$diveId-$buddyId'),
          diveId: Value(diveId),
          buddyId: Value(buddyId),
          role: Value(role),
          createdAt: Value(DateTime(2024, 1, 1).millisecondsSinceEpoch),
        ),
      );
}

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);
const _bs = {ConnectionKind.buddy, ConnectionKind.site};

void main() {
  late ConnectionsRepository repo;
  late db.AppDatabase d;

  setUp(() async {
    await setUpTestDatabase();
    d = DatabaseService.instance.database;
    repo = ConnectionsRepository();
    await _diver(d, 'me');
    await _diver(d, 'other');
    for (final b in ['jane', 'ken', 'lou', 'mo']) {
      await _buddy(d, b);
    }
    await _site(d, 's1', country: 'Bonaire');
    await _site(d, 's2');
    await _site(d, 's9');
    // d1, d2: jane + ken at s1. d3: jane + lou at s2.
    // d6: ken + mo at s9 (reachable from jane only through ken).
    // d7..d9: mo alone at s9, so mo out-dives every hop-1 entity.
    await _dive(d, id: 'd1', at: DateTime.utc(2024, 1, 10), siteId: 's1');
    await _dive(d, id: 'd2', at: DateTime.utc(2024, 3, 5), siteId: 's1');
    await _dive(d, id: 'd3', at: DateTime.utc(2024, 6, 1), siteId: 's2');
    await _dive(d, id: 'd6', at: DateTime.utc(2024, 7, 1), siteId: 's9');
    for (final id in ['d7', 'd8', 'd9']) {
      await _dive(d, id: id, at: DateTime.utc(2024, 8, 1), siteId: 's9');
      await _link(d, id, 'mo');
    }
    await _link(d, 'd1', 'jane');
    await _link(d, 'd1', 'ken');
    await _link(d, 'd2', 'jane');
    await _link(d, 'd2', 'ken');
    await _link(d, 'd3', 'jane');
    await _link(d, 'd3', 'lou', role: 'instructor');
    await _link(d, 'd6', 'ken');
    await _link(d, 'd6', 'mo');
  });

  tearDown(() async => tearDownTestDatabase());

  group('loadMap', () {
    test('one kind, same-kind link: the dive circle', () async {
      final g = await repo.loadMap(
        MapSpec.of(
          {ConnectionKind.buddy},
          {KindLink(ConnectionKind.buddy, ConnectionKind.buddy)},
        ),
        diverId: 'me',
      );
      final janeKen = g.edges.singleWhere(
        (e) => e.touches(_b('jane')) && e.touches(_b('ken')),
      );
      expect(janeKen.weight, 2);
      expect(janeKen.firstDiveAt, DateTime.utc(2024, 1, 10));
      expect(g.nodes.every((n) => n.hop == null), isTrue);
    });

    test('two kinds, both links, and the minimum thins weak lines', () async {
      final spec = MapSpec.of(_bs, {
        KindLink(ConnectionKind.buddy, ConnectionKind.site),
        KindLink(ConnectionKind.buddy, ConnectionKind.buddy),
      });
      final all = await repo.loadMap(spec, diverId: 'me');
      expect(all.edges.any((e) => e.touches(_s('s2'))), isTrue);
      final strong = await repo.loadMap(spec.withMinimum(2), diverId: 'me');
      expect(strong.edges.every((e) => e.weight >= 2), isTrue);
      expect(strong.edges.any((e) => e.touches(_s('s2'))), isFalse);
      expect(
        strong.nodeFor(_s('s2')),
        isNotNull,
        reason: 'an entity with no surviving line stays as an island',
      );
    });

    test('a kind with no link contributes nodes only', () async {
      final g = await repo.loadMap(
        MapSpec.of(_bs, {KindLink(ConnectionKind.buddy, ConnectionKind.buddy)}),
        diverId: 'me',
      );
      expect(g.nodeFor(_s('s1')), isNotNull);
      expect(g.edges.any((e) => e.touches(_s('s1'))), isFalse);
    });

    test('planned dives and other divers are out of scope', () async {
      await _dive(d, id: 'p1', at: DateTime.utc(2025), planned: true);
      await _link(d, 'p1', 'lou');
      await _link(d, 'p1', 'ken');
      await _dive(d, id: 'o1', at: DateTime.utc(2025), diverId: 'other');
      await _link(d, 'o1', 'lou');
      await _link(d, 'o1', 'ken');
      final g = await repo.loadMap(
        MapSpec.of(
          {ConnectionKind.buddy},
          {KindLink(ConnectionKind.buddy, ConnectionKind.buddy)},
        ),
        diverId: 'me',
      );
      expect(
        g.edges.any((e) => e.touches(_b('lou')) && e.touches(_b('ken'))),
        isFalse,
      );
    });
  });

  group('loadAround', () {
    test(
      'one hop: every enabled kind, spokes and chords, hop 0 and 1',
      () async {
        final g = await repo.loadAround(
          focus: _b('jane'),
          kinds: _bs,
          hops: 1,
          diverId: 'me',
        );
        expect(g.nodes.map((n) => n.ref).toSet(), {
          _b('jane'),
          _b('ken'),
          _b('lou'),
          _s('s1'),
          _s('s2'),
        });
        expect(g.nodeFor(_b('jane'))!.hop, 0);
        expect(g.nodeFor(_s('s1'))!.hop, 1);
        expect(
          g.edges.any((e) => e.touches(_b('ken')) && e.touches(_s('s1'))),
          isTrue,
          reason: 'lines among neighbours are drawn too',
        );
        expect(g.nodeFor(_b('mo')), isNull);
      },
    );

    test(
      'two hops reach entities only a neighbour shares dives with',
      () async {
        final g = await repo.loadAround(
          focus: _b('jane'),
          kinds: _bs,
          hops: 2,
          diverId: 'me',
        );
        expect(g.nodeFor(_b('mo'))!.hop, 2);
        expect(g.nodeFor(_s('s9'))!.hop, 2);
        expect(g.nodeFor(_b('ken'))!.hop, 1);
      },
    );

    test('disabled kinds are left out', () async {
      final g = await repo.loadAround(
        focus: _b('jane'),
        kinds: {ConnectionKind.buddy},
        hops: 1,
        diverId: 'me',
      );
      expect(g.nodes.every((n) => n.ref.kind == ConnectionKind.buddy), isTrue);
    });

    test('the budget keeps nearer hops over busier far ones', () async {
      final g = await repo.loadAround(
        focus: _b('jane'),
        kinds: _bs,
        hops: 2,
        diverId: 'me',
        nodeBudget: 3,
      );
      expect(g.nodes.map((n) => n.ref).toSet(), {
        _b('jane'),
        _b('ken'),
        _s('s1'),
      });
      expect(g.hiddenNodeCount, greaterThan(0));
    });

    test('a focus with no dives in scope stands alone', () async {
      await _buddy(d, 'newbie');
      final g = await repo.loadAround(
        focus: _b('newbie'),
        kinds: _bs,
        hops: 2,
        diverId: 'me',
      );
      expect(g.nodes.single.ref, _b('newbie'));
      expect(g.nodes.single.diveCount, 0);
      expect(g.nodes.single.hop, 0);
      expect(g.edges, isEmpty);
    });

    test('a focus with no row throws FocusNotFoundException', () async {
      expect(
        () => repo.loadAround(
          focus: _b('ghost'),
          kinds: _bs,
          hops: 1,
          diverId: 'me',
        ),
        throwsA(isA<FocusNotFoundException>()),
      );
    });

    test('the focus kind is included even when its chip is off', () async {
      final g = await repo.loadAround(
        focus: _s('s1'),
        kinds: {ConnectionKind.buddy},
        hops: 1,
        diverId: 'me',
      );
      expect(g.nodeFor(_s('s1'))!.hop, 0);
      expect(g.nodes.where((n) => n.ref.kind == ConnectionKind.site).length, 1);
      expect(g.nodeFor(_b('jane'))!.hop, 1);
    });
  });

  group('searchEntities', () {
    test('matches labels across kinds, busiest first', () async {
      final hits = await repo.searchEntities('s', diverId: 'me');
      expect(hits.map((n) => n.ref), containsAll([_s('s1'), _s('s9')]));
      final jan = await repo.searchEntities('JAN', diverId: 'me');
      expect(jan.map((n) => n.ref), [_b('jane')]);
    });

    test('blank text finds nothing and LIKE characters are literal', () async {
      expect(await repo.searchEntities('   ', diverId: 'me'), isEmpty);
      expect(await repo.searchEntities('%', diverId: 'me'), isEmpty);
      expect(await repo.searchEntities('_', diverId: 'me'), isEmpty);
    });
  });

  group('unchanged helpers', () {
    test('diveYearSpan and diveIdsFor', () async {
      expect(await repo.diveYearSpan(diverId: 'me'), (first: 2024, last: 2024));
      final pair = await repo.diveIdsFor(
        EdgeSelection(_b('jane'), _b('ken')),
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(pair.toSet(), {'d1', 'd2'});
    });

    test('watchConnectionsChanges fires on a junction write', () async {
      final events = <void>[];
      final sub = repo.watchConnectionsChanges().listen(events.add);
      await _link(d, 'd3', 'ken');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await sub.cancel();
      expect(events, isNotEmpty);
    });
  });
}
