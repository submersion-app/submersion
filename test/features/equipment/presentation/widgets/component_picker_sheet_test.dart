import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_picker_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeComponentRepository extends EquipmentComponentRepository {
  final added = <(String, String)>[];
  bool throwCycle = false;
  Object? throwOther;

  /// When set, every add waits on it, so a test can act mid-save.
  Completer<void>? gate;

  @override
  Future<EquipmentComponent> addComponent({
    required String parentId,
    required String componentId,
    String role = '',
  }) async {
    if (throwCycle) {
      throw EquipmentComponentCycleException(parentId, componentId);
    }
    if (throwOther != null) throw throwOther!;
    if (gate != null) await gate!.future;
    added.add((parentId, componentId));
    return EquipmentComponent(
      id: 'new-$componentId',
      parentEquipmentId: parentId,
      componentEquipmentId: componentId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }
}

void main() {
  final t0 = DateTime(2026, 1, 1);
  EquipmentItem item(String id, EquipmentType type) =>
      EquipmentItem(id: id, name: 'Name $id', type: type);
  var seq = 0;
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: 'c${seq++}',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );

  final active = [
    item('kit', EquipmentType.other),
    item('reg', EquipmentType.regulator),
    item('first', EquipmentType.firstStage),
    item('hose', EquipmentType.hose),
    item('fins', EquipmentType.fins),
  ];
  // kit > reg > first; the picker for reg must hide kit (ancestor), reg
  // (self), first (already a part), and offer hose and fins.
  final edges = [edge('kit', 'reg'), edge('reg', 'first')];

  Widget build(
    _FakeComponentRepository repo, {
    Future<ComponentsIndex>? index,
    List<EquipmentItem>? gear,
  }) => ProviderScope(
    overrides: [
      equipmentComponentRepositoryProvider.overrideWithValue(repo),
      activeEquipmentProvider.overrideWith((ref) async => gear ?? active),
      equipmentComponentsIndexProvider.overrideWith(
        (ref) => index ?? Future.value(ComponentsIndex.fromRows(edges)),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ComponentPickerSheet(
          parentId: 'reg',
          scrollController: ScrollController(),
        ),
      ),
    ),
  );

  testWidgets('hides self, ancestors, and current parts', (tester) async {
    await tester.pumpWidget(build(_FakeComponentRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Name hose'), findsOneWidget);
    expect(find.text('Name fins'), findsOneWidget);
    expect(find.text('Name reg'), findsNothing);
    expect(find.text('Name kit'), findsNothing);
    expect(find.text('Name first'), findsNothing);
  });

  testWidgets('confirm adds every checked item under the parent', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(build(repo));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsOneWidget);
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    expect(find.text('Add 1'), findsOneWidget);
    await tester.tap(find.text('Name fins'));
    await tester.pump();
    await tester.tap(find.text('Add 2'));
    await tester.pumpAndSettle();
    expect(repo.added, unorderedEquals([('reg', 'hose'), ('reg', 'fins')]));
  });

  testWidgets('type groups follow the declared enum order', (tester) async {
    // Fins arrive first, but Hose is declared earlier in EquipmentType, so
    // its group renders above Fins, matching the type dropdown.
    await tester.pumpWidget(
      build(
        _FakeComponentRepository(),
        gear: [
          item('reg', EquipmentType.regulator),
          item('fins', EquipmentType.fins),
          item('hose', EquipmentType.hose),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Hose')).dy,
      lessThan(tester.getTopLeft(find.text('Fins')).dy),
    );
  });

  testWidgets('offers nothing while the index is still loading', (
    tester,
  ) async {
    // An empty stand-in index would list the parent and its relatives as
    // candidates until the real one arrived.
    final pending = Completer<ComponentsIndex>();
    await tester.pumpWidget(
      build(_FakeComponentRepository(), index: pending.future),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    pending.complete(ComponentsIndex.fromRows(edges));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Name hose'), findsOneWidget);
    expect(find.text('Name reg'), findsNothing);
  });

  testWidgets('a non-cycle failure reports itself and re-enables the sheet', (
    tester,
  ) async {
    final repo = _FakeComponentRepository()..throwOther = StateError('boom');
    await tester.pumpWidget(build(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('checkboxes are frozen while the adds run', (tester) async {
    final repo = _FakeComponentRepository()..gate = Completer<void>();
    await tester.pumpWidget(build(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pump();
    for (final tile in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(tile.onChanged, isNull);
    }
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(repo.added, [('reg', 'hose')]);
  });

  testWidgets('a sheet dismissed mid-save does not pop the page beneath', (
    tester,
  ) async {
    final repo = _FakeComponentRepository()..gate = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentComponentRepositoryProvider.overrideWithValue(repo),
          activeEquipmentProvider.overrideWith((ref) async => active),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => ComponentsIndex.fromRows(edges),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showComponentPicker(context, parentId: 'reg'),
                child: const Text('PAGE BENEATH'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('PAGE BENEATH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pump();
    // Dismiss the sheet by tapping the barrier while the add is pending.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(ComponentPickerSheet), findsNothing);
    repo.gate!.complete();
    await tester.pumpAndSettle();
    // The save finished, and the page under the sheet is still there.
    expect(repo.added, [('reg', 'hose')]);
    expect(find.text('PAGE BENEATH'), findsOneWidget);
  });

  testWidgets('a cycle refused by the repository shows the explanation', (
    tester,
  ) async {
    final repo = _FakeComponentRepository()..throwCycle = true;
    await tester.pumpWidget(build(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('cannot be added as a component'),
      findsOneWidget,
    );
  });
}
