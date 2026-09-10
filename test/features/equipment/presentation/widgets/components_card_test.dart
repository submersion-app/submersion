import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeComponentRepository extends EquipmentComponentRepository {
  final removed = <String>[];
  final roles = <String, String>{};
  final reorders = <List<String>>[];

  @override
  Future<void> removeComponent(String id) async => removed.add(id);

  @override
  Future<void> updateRole(String id, String role) async => roles[id] = role;

  @override
  Future<void> reorder(String parentId, List<String> orderedIds) async =>
      reorders.add(orderedIds);

  @override
  Future<List<String>> distinctRoles() async => const ['Necklace', 'Primary'];
}

/// How many logged dives carry the assembly, as the history dialog sees it.
/// The real one logs and rethrows on a query failure.
class _FakeEquipmentRepository extends EquipmentRepository {
  int diveCount = 0;
  Object? throwOnCount;

  @override
  Future<int> getDiveCountForEquipment(String equipmentId) async {
    if (throwOnCount != null) throw throwOnCount!;
    return diveCount;
  }
}

/// DiveRepository only has a factory, so a Fake stands in for it.
class _FakeDiveRepository extends Fake implements DiveRepository {
  final rewrites = <(String, List<GearHistoryRewrite>)>[];
  Object? throwOnRewrite;

  @override
  Future<int> rewriteAssemblyOnPastDives(
    String assemblyId,
    List<GearHistoryRewrite> rewrites_,
  ) async {
    if (throwOnRewrite != null) throw throwOnRewrite!;
    rewrites.add((assemblyId, rewrites_));
    return 1;
  }
}

void main() {
  final t0 = DateTime(2026, 1, 1);

  const first = EquipmentItem(
    id: 'first',
    name: 'DGX first stage',
    type: EquipmentType.firstStage,
  );
  const hose = EquipmentItem(
    id: 'hose',
    name: 'Long hose',
    type: EquipmentType.hose,
    status: EquipmentStatus.retired,
    isActive: false,
  );
  const spare = EquipmentItem(
    id: 'spare',
    name: 'Spare first stage',
    type: EquipmentType.firstStage,
  );

  EquipmentComponent part(
    String id,
    EquipmentItem item, {
    String role = '',
    int order = 0,
  }) => EquipmentComponent(
    id: id,
    parentEquipmentId: 'reg',
    componentEquipmentId: item.id,
    role: role,
    sortOrder: order,
    createdAt: t0,
    updatedAt: t0,
    component: item,
  );

  Widget build(
    List<EquipmentComponent> parts,
    _FakeComponentRepository repo, {
    _FakeEquipmentRepository? equipment,
    _FakeDiveRepository? dives,
  }) {
    return ProviderScope(
      overrides: [
        equipmentComponentRepositoryProvider.overrideWithValue(repo),
        equipmentRepositoryProvider.overrideWithValue(
          equipment ?? _FakeEquipmentRepository(),
        ),
        diveRepositoryProvider.overrideWithValue(
          dives ?? _FakeDiveRepository(),
        ),
        equipmentComponentsProvider('reg').overrideWith((ref) async => parts),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.fromRows(parts),
        ),
        equipmentWorstClockProvider.overrideWith((ref) async => {}),
        activeEquipmentProvider.overrideWith(
          (ref) async => const [first, hose, spare],
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ComponentsCard(equipmentId: 'reg'),
          ),
        ),
      ),
    );
  }

  testWidgets('empty state shows the prompt and the add button', (
    tester,
  ) async {
    await tester.pumpWidget(build(const [], _FakeComponentRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Components'), findsOneWidget);
    expect(find.textContaining('No components'), findsOneWidget);
    expect(find.text('Add component'), findsOneWidget);
  });

  testWidgets('renders one row per part with role, and a retired badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      build([
        part('c1', first, role: 'Primary', order: 0),
        part('c2', hose, order: 1),
      ], _FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('DGX first stage'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Long hose'), findsOneWidget);
    // A part with no role falls back to its type label.
    expect(find.text('Hose'), findsOneWidget);
    expect(find.text('Retired'), findsOneWidget);
  });

  testWidgets('a drag reorders the rows at once and persists the order', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(
      build([
        part('c1', first, role: 'Primary', order: 0),
        part('c2', hose, order: 1),
      ], repo),
    );
    await tester.pumpAndSettle();
    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    final firstBefore = tester.getTopLeft(find.text('DGX first stage')).dy;
    final hoseBefore = tester.getTopLeft(find.text('Long hose')).dy;
    expect(firstBefore, lessThan(hoseBefore));

    // Drag the first row's handle below the second row. The handle is a
    // ReorderableDragStartListener, so the drag starts on touch-down.
    final drag = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump();
    // A row is about 72 px tall; the dragged row must travel past the next
    // row's midpoint before the list commits the swap, so go well beyond.
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();

    // The rows swapped without waiting for the provider to refresh (the
    // override never changes), and the new order was persisted once.
    expect(
      tester.getTopLeft(find.text('Long hose')).dy,
      lessThan(tester.getTopLeft(find.text('DGX first stage')).dy),
    );
    expect(repo.reorders, [
      ['c2', 'c1'],
    ]);
  });

  testWidgets('with no past dives the remove icon removes at once', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    final dives = _FakeDiveRepository();
    await tester.pumpWidget(build([part('c1', first)], repo, dives: dives));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Update past dives?'), findsNothing);
    expect(repo.removed, ['c1']);
    expect(dives.rewrites, isEmpty);
  });

  testWidgets(
    'removing on an assembly with past dives asks, also past replays',
    (tester) async {
      final repo = _FakeComponentRepository();
      final dives = _FakeDiveRepository();
      await tester.pumpWidget(
        build(
          [part('c1', first)],
          repo,
          equipment: _FakeEquipmentRepository()..diveCount = 2,
          dives: dives,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Update past dives?'), findsOneWidget);
      expect(find.textContaining('Remove the part'), findsOneWidget);
      await tester.tap(find.text('Also update 2 dives'));
      await tester.pumpAndSettle();
      expect(repo.removed, ['c1']);
      // Compared field by field: a record holding a List compares that
      // field by identity, so two equal lists never match as one record.
      expect(dives.rewrites, hasLength(1));
      expect(dives.rewrites.single.$1, 'reg');
      expect(dives.rewrites.single.$2, const [GearPartRemoved('first')]);
    },
  );

  testWidgets('a failed dive count is reported, and removes nothing', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    final dives = _FakeDiveRepository();
    await tester.pumpWidget(
      build(
        [part('c1', first)],
        repo,
        equipment: _FakeEquipmentRepository()
          ..throwOnCount = StateError('no database'),
        dives: dives,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Update past dives?'), findsNothing);
    expect(find.textContaining('no database'), findsOneWidget);
    expect(repo.removed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed replay is reported instead of going unhandled', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    final dives = _FakeDiveRepository()..throwOnRewrite = StateError('boom');
    await tester.pumpWidget(
      build(
        [part('c1', first)],
        repo,
        equipment: _FakeEquipmentRepository()..diveCount = 2,
        dives: dives,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Also update 2 dives'));
    await tester.pumpAndSettle();
    expect(repo.removed, ['c1']);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('from now on removes the part and leaves past dives alone', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    final dives = _FakeDiveRepository();
    await tester.pumpWidget(
      build(
        [part('c1', first)],
        repo,
        equipment: _FakeEquipmentRepository()..diveCount = 2,
        dives: dives,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From now on'));
    await tester.pumpAndSettle();
    expect(repo.removed, ['c1']);
    expect(dives.rewrites, isEmpty);
  });

  testWidgets('cancelling the question changes nothing', (tester) async {
    final repo = _FakeComponentRepository();
    final dives = _FakeDiveRepository();
    await tester.pumpWidget(
      build(
        [part('c1', first)],
        repo,
        equipment: _FakeEquipmentRepository()..diveCount = 2,
        dives: dives,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.removed, isEmpty);
    expect(dives.rewrites, isEmpty);
  });

  testWidgets('the replace icon opens the picker in single-select mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      build([part('c1', first)], _FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Replace component'));
    await tester.pumpAndSettle();
    expect(find.text('Replace with'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Replace'), findsOneWidget);
    // The row being replaced is a current part, so it is not a candidate,
    // while the spare of the same type is.
    expect(find.text('Spare first stage'), findsOneWidget);
    expect(find.text('DGX first stage'), findsOneWidget);
  });

  testWidgets('the edit icon opens the role dialog and saves the new role', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(build([part('c1', first, role: 'Primary')], repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Component role'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Backup');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.roles, {'c1': 'Backup'});
  });
}
