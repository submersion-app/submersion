import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/connection_query.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
NodeRef _s(String id) => NodeRef(ConnectionKind.site, id);

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

const _circle = ConnectionQuery(
  kindA: ConnectionKind.buddy,
  kindB: ConnectionKind.buddy,
);
const _where = ConnectionQuery(
  kindA: ConnectionKind.buddy,
  kindB: ConnectionKind.site,
);

void main() {
  late ConnectionsRepository repo;
  late db.AppDatabase d;

  setUp(() async {
    await setUpTestDatabase();
    d = DatabaseService.instance.database;
    repo = ConnectionsRepository();
    await _diver(d, 'me');
    await _diver(d, 'other');
    for (final b in ['jane', 'ken', 'lou']) {
      await _buddy(d, b);
    }
    await _site(d, 's1', country: 'Bonaire');
    await _site(d, 's2');
    // d1: jane + ken at s1. d2: jane + ken at s1. d3: jane + lou at s2.
    await _dive(d, id: 'd1', at: DateTime.utc(2024, 1, 10), siteId: 's1');
    await _dive(d, id: 'd2', at: DateTime.utc(2024, 3, 5), siteId: 's1');
    await _dive(d, id: 'd3', at: DateTime.utc(2024, 6, 1), siteId: 's2');
    await _link(d, 'd1', 'jane');
    await _link(d, 'd1', 'ken');
    await _link(d, 'd2', 'jane');
    await _link(d, 'd2', 'ken');
    await _link(d, 'd3', 'jane');
    await _link(d, 'd3', 'lou', role: 'instructor');
  });

  tearDown(() async => tearDownTestDatabase());

  group('whole web', () {
    test('buddy to buddy edges carry distinct dive counts and dates', () async {
      final g = await repo.loadGraph(_circle, diverId: 'me');
      final janeKen = g.edges.singleWhere(
        (e) => e.source == _b('jane') && e.target == _b('ken'),
      );
      expect(janeKen.weight, 2);
      expect(janeKen.firstDiveAt, DateTime.utc(2024, 1, 10));
      expect(janeKen.lastDiveAt, DateTime.utc(2024, 3, 5));
      final janeLou = g.edges.singleWhere(
        (e) => e.source == _b('jane') && e.target == _b('lou'),
      );
      expect(janeLou.weight, 1);
      expect(g.edges.length, 2, reason: 'ken and lou never dived together');
    });

    test('nodes come from membership with their own dive counts', () async {
      final g = await repo.loadGraph(_circle, diverId: 'me');
      final counts = {for (final n in g.nodes) n.ref.id: n.diveCount};
      expect(counts, {'jane': 3, 'ken': 2, 'lou': 1});
      expect(g.hiddenNodeCount, 0);
    });

    test(
      'a buddy with one role gets a RoleSubtitle, mixed roles none',
      () async {
        await _link(d, 'd1', 'lou', role: 'buddy', rowId: 'extra-lou');
        final g = await repo.loadGraph(_circle, diverId: 'me');
        final jane = g.nodeFor(_b('jane'))!;
        final lou = g.nodeFor(_b('lou'))!;
        expect(jane.subtitle, const RoleSubtitle('buddy'));
        expect(lou.subtitle, isNull);
      },
    );

    test('duplicate junction rows count a dive once', () async {
      await _link(d, 'd1', 'jane', rowId: 'dup');
      final g = await repo.loadGraph(_circle, diverId: 'me');
      final janeKen = g.edges.singleWhere((e) => e.touches(_b('ken')));
      expect(janeKen.weight, 2);
      expect(g.nodeFor(_b('jane'))!.diveCount, 3);
    });

    test(
      'planned and excluded dives form no edge and add to no count',
      () async {
        await _dive(d, id: 'p1', at: DateTime.utc(2025, 1, 1), planned: true);
        await _dive(d, id: 'x1', at: DateTime.utc(2025, 1, 2), excluded: true);
        await _link(d, 'p1', 'ken');
        await _link(d, 'p1', 'lou');
        await _link(d, 'x1', 'ken');
        await _link(d, 'x1', 'lou');
        final g = await repo.loadGraph(_circle, diverId: 'me');
        expect(
          g.edges.any((e) => e.touches(_b('ken')) && e.touches(_b('lou'))),
          isFalse,
        );
        expect(g.nodeFor(_b('ken'))!.diveCount, 2);
      },
    );

    test(
      "another diver's dives are ignored, a null diver sees them all",
      () async {
        await _dive(
          d,
          id: 'o1',
          at: DateTime.utc(2025, 2, 1),
          diverId: 'other',
        );
        await _link(d, 'o1', 'ken');
        await _link(d, 'o1', 'lou');
        final mine = await repo.loadGraph(_circle, diverId: 'me');
        expect(
          mine.edges.any((e) => e.touches(_b('lou')) && e.touches(_b('ken'))),
          isFalse,
        );
        final all = await repo.loadGraph(_circle, diverId: null);
        expect(
          all.edges.any((e) => e.touches(_b('lou')) && e.touches(_b('ken'))),
          isTrue,
        );
      },
    );

    test('the view filter narrows edges and counts', () async {
      final q = ConnectionQuery(
        kindA: ConnectionKind.buddy,
        kindB: ConnectionKind.buddy,
        filter: const DiveFilterState(siteId: 's2'),
      );
      final g = await repo.loadGraph(q, diverId: 'me');
      expect(g.edges.length, 1);
      expect(g.edges.single.touches(_b('lou')), isTrue);
      expect(g.nodeFor(_b('jane'))!.diveCount, 1);
      expect(g.nodeFor(_b('ken')), isNull, reason: 'no dives at s2');
    });

    test(
      'mixed lens keeps kind A as source and includes isolated sites',
      () async {
        await _site(d, 's3');
        await _dive(d, id: 'd4', at: DateTime.utc(2024, 7, 1), siteId: 's3');
        final g = await repo.loadGraph(_where, diverId: 'me');
        for (final e in g.edges) {
          expect(e.source.kind, ConnectionKind.buddy);
          expect(e.target.kind, ConnectionKind.site);
        }
        final janeS1 = g.edges.singleWhere(
          (e) => e.source == _b('jane') && e.target == _s('s1'),
        );
        expect(janeS1.weight, 2);
        final s3 = g.nodeFor(_s('s3'))!;
        expect(s3.diveCount, 1, reason: 'a site dived alone is an island');
        expect(g.nodeFor(_s('s1'))!.subtitle, const TextSubtitle('Bonaire'));
        expect(g.nodeFor(_s('s2'))!.subtitle, isNull);
      },
    );

    test('the budget trims and reports hidden nodes', () async {
      final g = await repo.loadGraph(
        _circle.copyWith(nodeBudget: 2),
        diverId: 'me',
      );
      expect(g.nodes.map((n) => n.ref.id).toSet(), {'jane', 'ken'});
      expect(g.hiddenNodeCount, 1);
    });
  });

  group('ego', () {
    test('spokes, neighbours and chords around the focus', () async {
      // ken and lou share d5 so a chord exists between two of jane's
      // neighbours.
      await _dive(d, id: 'd5', at: DateTime.utc(2024, 8, 1));
      await _link(d, 'd5', 'ken');
      await _link(d, 'd5', 'lou');
      final g = await repo.loadGraph(
        _circle.copyWith(focus: _b('jane')),
        diverId: 'me',
      );
      expect(g.nodes.map((n) => n.ref.id).toSet(), {'jane', 'ken', 'lou'});
      final spokes = g.edges.where((e) => e.touches(_b('jane'))).toList();
      expect(spokes.length, 2);
      expect(spokes.every((e) => e.source == _b('jane')), isTrue);
      final chord = g.edges.singleWhere((e) => !e.touches(_b('jane')));
      expect({chord.source.id, chord.target.id}, {'ken', 'lou'});
    });

    test('a mixed-lens focus on kind B swaps sides', () async {
      final g = await repo.loadGraph(
        _where.copyWith(focus: _s('s1')),
        diverId: 'me',
      );
      expect(g.nodes.map((n) => n.ref).toSet(), {
        _s('s1'),
        _b('jane'),
        _b('ken'),
      });
      expect(g.edges.every((e) => e.source == _s('s1')), isTrue);
    });

    test('a focus with no row throws FocusNotFoundException', () async {
      expect(
        () => repo.loadGraph(
          _circle.copyWith(focus: _b('ghost')),
          diverId: 'me',
        ),
        throwsA(isA<FocusNotFoundException>()),
      );
    });

    test('a focus with no dives in scope is still returned alone', () async {
      await _buddy(d, 'newbie');
      final g = await repo.loadGraph(
        _circle.copyWith(focus: _b('newbie')),
        diverId: 'me',
      );
      expect(g.nodes.single.ref, _b('newbie'));
      expect(g.nodes.single.diveCount, 0);
      expect(g.edges, isEmpty);
    });

    test('an invalid focus kind is an ArgumentError', () async {
      expect(
        () => repo.loadGraph(_circle.copyWith(focus: _s('s1')), diverId: 'me'),
        throwsArgumentError,
      );
    });
  });

  group('helpers', () {
    test('diveYearSpan spans the scoped dives', () async {
      await _dive(d, id: 'old', at: DateTime.utc(2019, 5, 5));
      await _dive(
        d,
        id: 'planned',
        at: DateTime.utc(2031, 1, 1),
        planned: true,
      );
      final span = await repo.diveYearSpan(diverId: 'me');
      expect(span, (first: 2019, last: 2024));
      expect(await repo.diveYearSpan(diverId: 'nobody'), isNull);
    });

    test('diveIdsFor a node and an edge', () async {
      final jane = await repo.diveIdsFor(
        const NodeSelection(NodeRef(ConnectionKind.buddy, 'jane')),
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(jane.toSet(), {'d1', 'd2', 'd3'});
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
