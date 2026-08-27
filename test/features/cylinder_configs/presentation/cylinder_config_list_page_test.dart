import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/pages/cylinder_config_list_page.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../helpers/bulk_delete_contract.dart';
import '../../../helpers/selection_contract.dart';
import '../../../helpers/test_app.dart';

/// Renders [CylinderConfigListPage] behind a real [GoRouter] so the FAB and
/// the per-tile tap (both `context.push`) actually navigate. The child routes
/// are placeholders rather than the real edit page: this test is about the
/// list's own grouping and routing, and the edit page has its own suite that
/// stands up a database for it.
void main() {
  final now = DateTime.utc(2026, 8, 5);

  CylinderConfigItem item(String id, TankRole role) => CylinderConfigItem(
    id: id,
    configId: 'c1',
    tankRole: role,
    createdAt: now,
    updatedAt: now,
  );

  CylinderConfig config({
    required String id,
    required String name,
    String? equipmentId,
    List<CylinderConfigItem> items = const [],
  }) => CylinderConfig(
    id: id,
    name: name,
    equipmentId: equipmentId,
    items: items,
    createdAt: now,
    updatedAt: now,
  );

  EquipmentItem unit(String id, String name) =>
      EquipmentItem(id: id, name: name, type: EquipmentType.rebreather);

  /// The location the router last landed on, so a tap can be asserted on the
  /// route it pushed rather than on whatever the placeholder happens to show.
  late String location;

  Widget host({
    required List<CylinderConfig> configs,
    List<EquipmentItem> equipment = const [],
    // A builder, not a Future: an eagerly constructed Future.error has no
    // listener at construction time and the test framework claims it before
    // Riverpod can route it to the widget's error arm.
    Future<List<CylinderConfig>> Function()? configsFuture,
    List<dynamic> extraOverrides = const [],
  }) {
    Widget probe(String label) => Builder(
      builder: (context) {
        location = GoRouterState.of(context).uri.toString();
        return Scaffold(body: Text(label));
      },
    );

    final router = GoRouter(
      initialLocation: '/equipment/cylinder-configs',
      routes: [
        GoRoute(
          path: '/equipment/cylinder-configs',
          builder: (context, state) => const CylinderConfigListPage(),
          routes: [
            GoRoute(path: 'new', builder: (context, state) => probe('new')),
            GoRoute(
              path: ':configId',
              builder: (context, state) => probe('detail'),
            ),
          ],
        ),
      ],
    );

    return testAppRouter(
      // Pinned: an unpinned locale makes text finders machine-dependent.
      locale: const Locale('en'),
      router: router,
      overrides: [
        cylinderConfigsProvider.overrideWith(
          (ref) => configsFuture?.call() ?? Future.value(configs),
        ),
        allEquipmentProvider.overrideWith((ref) async => equipment),
        ...extraOverrides,
      ],
    );
  }

  group('bulk delete', () {
    testWidgets('confirms before deleting the checked configurations', (
      tester,
    ) async {
      // This surface gained delete in this change: the repository method
      // existed with no callers. The confirmation is the whole guard.
      final repo = _CapturingConfigRepository();
      await verifyBulkDelete(
        tester,
        build: () => host(
          configs: [
            config(id: 'g1', name: 'Aaa plan'),
            config(id: 'g2', name: 'Bbb plan'),
          ],
          extraOverrides: [
            cylinderConfigRepositoryProvider.overrideWithValue(repo),
          ],
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        expectedDeletedCount: 2,
      );

      expect(repo.deleted, ['g1', 'g2']);
      expect(find.text('2 deleted'), findsOneWidget);
    });

    testWidgets('cancelling deletes nothing and keeps the selection', (
      tester,
    ) async {
      await verifyBulkDeleteCancels(
        tester,
        build: () => host(
          configs: [config(id: 'g1', name: 'Aaa plan')],
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
      );
    });
  });

  group('selection', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      final all = [
        config(id: 'g1', name: 'Aaa plan'),
        config(id: 'g2', name: 'Bbb plan'),
        config(id: 'g3', name: 'Ccc plan'),
      ];
      var visible = all;

      await verifySelectionContract(
        tester,
        // configsFuture is read on each provider rebuild, so invalidating
        // after reassigning `visible` actually narrows the list. Passing
        // `configs:` would capture the original list by value.
        build: () => host(configs: all, configsFuture: () async => visible),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        rowRoot: find.ancestor(
          of: find.text('Aaa plan'),
          matching: find.byType(ListTile),
        ),
        firstRow: find.text('Aaa plan'),
        applyFilter: (tester) async {
          visible = [all.first];
          final container = ProviderScope.containerOf(
            tester.element(find.byType(CylinderConfigListPage)),
          );
          container.invalidate(cylinderConfigsProvider);
          await tester.pumpAndSettle();
        },
        visibleAfterFilter: 1,
      );
    });
  });

  testWidgets('an empty list explains what a configuration is for', (
    tester,
  ) async {
    await tester.pumpWidget(host(configs: const []));
    await tester.pumpAndSettle();

    expect(find.text('No configurations yet'), findsOneWidget);
    expect(
      find.text(
        'Save a diluent and bailout setup once, then apply it to any dive.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('a pending load shows a spinner rather than the empty state', (
    tester,
  ) async {
    // A never-completing future: the empty state and "still loading" are
    // different answers, and showing "No configurations yet" while the read
    // is in flight would read as data loss.
    await tester.pumpWidget(
      host(
        configs: const [],
        configsFuture: () => Completer<List<CylinderConfig>>().future,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No configurations yet'), findsNothing);
  });

  testWidgets('a failed read surfaces the error instead of an empty list', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        configs: const [],
        configsFuture: () async => throw Exception('no database'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no database'), findsOneWidget);
  });

  testWidgets('configurations group under their owning unit, gas plans last', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        equipment: [unit('rb-1', 'JJ-CCR')],
        configs: [
          config(
            id: 'c1',
            name: 'JJ trimix',
            equipmentId: 'rb-1',
            items: [item('i1', TankRole.diluent), item('i2', TankRole.bailout)],
          ),
          config(id: 'c2', name: 'JJ air dil', equipmentId: 'rb-1'),
          config(
            id: 'c3',
            name: 'Doubles + 50',
            items: [item('i3', TankRole.backGas)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The owning unit's name heads its group; generic plans get their own.
    expect(find.text('JJ-CCR'), findsOneWidget);
    expect(find.text('Gas plans'), findsOneWidget);

    expect(find.text('JJ trimix'), findsOneWidget);
    expect(find.text('JJ air dil'), findsOneWidget);
    expect(find.text('Doubles + 50'), findsOneWidget);

    // Roles are the subtitle, cylinder count the trailing value.
    expect(find.text('Diluent, Bailout'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Generic plans sort after every owned group.
    final gasPlansY = tester.getTopLeft(find.text('Gas plans')).dy;
    expect(tester.getTopLeft(find.text('JJ-CCR')).dy, lessThan(gasPlansY));
    expect(
      tester.getTopLeft(find.text('Doubles + 50')).dy,
      greaterThan(gasPlansY),
    );
  });

  testWidgets('a config whose unit is gone still gets a header', (
    tester,
  ) async {
    // equipment_id is ON DELETE SET NULL, but a config can also be read
    // before allEquipmentProvider resolves, or reference a unit belonging to
    // another diver. Neither may drop the row off the page.
    await tester.pumpWidget(
      host(
        equipment: const [],
        configs: [config(id: 'c1', name: 'Orphaned', equipmentId: 'rb-gone')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('For unit'), findsOneWidget);
    expect(find.text('Orphaned'), findsOneWidget);
  });

  testWidgets('a configuration with no cylinders has no role subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        configs: [config(id: 'c1', name: 'Empty plan')],
      ),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.subtitle, isNull);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('tapping a configuration opens it by id', (tester) async {
    await tester.pumpWidget(
      host(
        configs: [config(id: 'c1', name: 'JJ trimix')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('JJ trimix'));
    await tester.pumpAndSettle();

    expect(location, '/equipment/cylinder-configs/c1');
  });

  testWidgets('the FAB opens a blank configuration', (tester) async {
    await tester.pumpWidget(host(configs: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New configuration'));
    await tester.pumpAndSettle();

    expect(location, '/equipment/cylinder-configs/new');
  });
}

/// Records the ids bulk delete reached the repository with, so the flow can
/// be exercised without standing up a database.
class _CapturingConfigRepository implements CylinderConfigRepository {
  final deleted = <String>[];

  @override
  Future<void> deleteConfig(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
