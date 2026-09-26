import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
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

Future<void> _dive(
  db.AppDatabase d, {
  required String id,
  required DateTime at,
}) async {
  final ms = at.millisecondsSinceEpoch;
  await d
      .into(d.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diverId: const Value('me'),
          diveDateTime: Value(ms),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _link(db.AppDatabase d, String diveId, String buddyId) async {
  await d
      .into(d.diveBuddies)
      .insert(
        db.DiveBuddiesCompanion(
          id: Value('$diveId-$buddyId'),
          diveId: Value(diveId),
          buddyId: Value(buddyId),
          role: const Value('buddy'),
          createdAt: Value(DateTime(2024, 1, 1).millisecondsSinceEpoch),
        ),
      );
}

void main() {
  late db.AppDatabase d;
  late ProviderContainer c;

  setUp(() async {
    await setUpTestDatabase();
    d = DatabaseService.instance.database;
    await _diver(d, 'me');
    await _buddy(d, 'jane');
    await _buddy(d, 'ken');
    await _dive(d, id: 'd1', at: DateTime.utc(2024, 1, 10));
    await _link(d, 'd1', 'jane');
    await _link(d, 'd1', 'ken');
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..setCurrentDiver('me').ignore(),
        ),
      ],
    );
    addTearDown(c.dispose);
  });

  tearDown(() async => tearDownTestDatabase());

  test(
    'the graph provider loads the active lens for the current diver',
    () async {
      final sub = c.listen(connectionGraphProvider(80), (_, _) {});
      addTearDown(sub.close);
      final g = await c.read(connectionGraphProvider(80).future);
      expect(g.nodes.length, 2);
      expect(g.edges.single.weight, 1);
    },
  );

  test('changing the filter or lens reloads', () async {
    final sub = c.listen(connectionGraphProvider(80), (_, _) {});
    addTearDown(sub.close);
    await c.read(connectionGraphProvider(80).future);
    c.read(connectionsFilterProvider.notifier).state = const DiveFilterState(
      siteId: 'nowhere',
    );
    final filtered = await c.read(connectionGraphProvider(80).future);
    expect(filtered.isEmpty, isTrue);
    c.read(connectionsFilterProvider.notifier).state = const DiveFilterState();
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applyPreset(ConnectionPresets.byId('where')!));
    final where = await c.read(connectionGraphProvider(80).future);
    expect(
      where.nodes.every(
        (n) =>
            n.ref.kind == ConnectionKind.buddy ||
            n.ref.kind == ConnectionKind.site,
      ),
      isTrue,
    );
    expect(where.edges, isEmpty, reason: 'no dive has a site');
  });

  test('a focus switches to the ego graph', () async {
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.centreOn(const NodeRef(ConnectionKind.buddy, 'jane')));
    final sub = c.listen(connectionGraphProvider(80), (_, _) {});
    addTearDown(sub.close);
    final g = await c.read(connectionGraphProvider(80).future);
    expect(g.edges.single.source.id, 'jane');
  });

  test('the graph reloads after a junction write', () async {
    final sub = c.listen(connectionGraphProvider(80), (_, _) {});
    addTearDown(sub.close);
    final before = await c.read(connectionGraphProvider(80).future);
    expect(before.edges.single.weight, 1);
    await _dive(d, id: 'd2', at: DateTime.utc(2024, 2, 1));
    await _link(d, 'd2', 'jane');
    await _link(d, 'd2', 'ken');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final after = await c.read(connectionGraphProvider(80).future);
    expect(after.edges.single.weight, 2);
  });

  test('year span and selection dive ids', () async {
    final sub1 = c.listen(connectionsYearSpanProvider, (_, _) {});
    addTearDown(sub1.close);
    expect(await c.read(connectionsYearSpanProvider.future), (
      first: 2024,
      last: 2024,
    ));
    const sel = NodeSelection(NodeRef(ConnectionKind.buddy, 'jane'));
    final sub2 = c.listen(connectionsSelectionDiveIdsProvider(sel), (_, _) {});
    addTearDown(sub2.close);
    expect(await c.read(connectionsSelectionDiveIdsProvider(sel).future), [
      'd1',
    ]);
    expect(c.read(connectionsSelectionProvider), isNull);
  });
}
