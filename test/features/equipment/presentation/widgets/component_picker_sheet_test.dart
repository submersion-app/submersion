import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_components_sitting.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/folded_groups.dart';
import '../../../../helpers/test_database.dart';

/// Records what Save writes through it.
class _FakeComponentRepository extends EquipmentComponentRepository {
  final added = <(String, String)>[];
  final replaced = <(String, String)>[];

  @override
  Future<EquipmentComponent> addComponent({
    required String parentId,
    required String componentId,
    String role = '',
    String? id,
  }) async {
    added.add((parentId, componentId));
    return EquipmentComponent(
      id: 'new-$componentId',
      parentEquipmentId: parentId,
      componentEquipmentId: componentId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<EquipmentComponent> replaceComponent(
    String id,
    String newComponentId,
  ) async {
    replaced.add((id, newComponentId));
    return EquipmentComponent(
      id: id,
      parentEquipmentId: 'reg',
      componentEquipmentId: newComponentId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }
}

/// How many logged dives carry the assembly, as the history dialog reads it
/// from the dive repository. The real one logs and rethrows on a failure.
class _DiveCount {
  int diveCount = 0;
  Object? throwOnCount;

  /// When set, the count waits on it, so a test can act while it is read.
  Completer<int>? gate;
}

/// Stands in for anything else that reads the equipment repository.
class _FakeEquipmentRepository extends EquipmentRepository {}

/// DiveRepository only has a factory, so a Fake stands in for it.
class _FakeDiveRepository extends Fake implements DiveRepository {
  final rewrites = <(String, List<GearHistoryRewrite>, bool)>[];
  _DiveCount count = _DiveCount();

  @override
  Future<int> countLoggedDivesWithAssembly(String assemblyId) async {
    if (count.throwOnCount != null) throw count.throwOnCount!;
    if (count.gate != null) return count.gate!.future;
    return count.diveCount;
  }

  @override
  Future<List<String>> rewriteAssemblyOnDives(
    String assemblyId,
    List<GearHistoryRewrite> rewrites_, {
    required bool alsoLogged,
    bool notify = true,
  }) async {
    rewrites.add((assemblyId, rewrites_, alsoLogged));
    return const ['dive'];
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

  // Issue #4527, phase 3: the picker opens in the assembly's sitting, holds
  // its choice there with the answer to Update past dives?, and writes
  // nothing. Its parts are reg's, first among them.
  late EditSession<EquipmentItem> session;
  setUp(() {
    session = EditSession(item('reg', EquipmentType.regulator));
    addTearDown(session.dispose);
    gearItemComponentsList
      ..loadNone(session)
      ..set(session, [edges[1]]);
  });

  /// The parts the sitting holds for reg, by the item each one is.
  List<String> heldParts() => [
    for (final p in gearItemComponentsList.current(session)!)
      p.componentEquipmentId,
  ];

  Widget build(
    _FakeComponentRepository repo, {
    Future<ComponentsIndex>? index,
    List<EquipmentItem>? gear,
    EquipmentComponent? replacing,
    _DiveCount? count,
    _FakeDiveRepository? dives,
  }) => ProviderScope(
    overrides: [
      equipmentComponentRepositoryProvider.overrideWithValue(repo),
      equipmentRepositoryProvider.overrideWithValue(_FakeEquipmentRepository()),
      diveRepositoryProvider.overrideWithValue(
        (dives ?? _FakeDiveRepository())..count = count ?? _DiveCount(),
      ),
      activeEquipmentProvider.overrideWith((ref) async => gear ?? active),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
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
          replacing: replacing,
          editing: session,
        ),
      ),
    ),
  );

  testWidgets('identical candidates are told apart (#1549)', (tester) async {
    EquipmentItem hose(String id, String serial) => EquipmentItem(
      id: id,
      name: 'Hose',
      type: EquipmentType.hose,
      brand: 'Miflex',
      model: 'XT',
      serialNumber: serial,
    );
    // Descending serial order, so input order cannot produce the result.
    await tester.pumpWidget(
      build(
        _FakeComponentRepository(),
        gear: [
          item('reg', EquipmentType.regulator),
          hose('b', 'X2'),
          hose('a', 'X1'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await openFoldedGroups(tester);
    expect(find.text('Miflex XT · S/N X1'), findsOneWidget);
    expect(find.text('Miflex XT · S/N X2'), findsOneWidget);
  });

  testWidgets('hides self, ancestors, and current parts', (tester) async {
    await tester.pumpWidget(build(_FakeComponentRepository()));
    await tester.pumpAndSettle();
    await openFoldedGroups(tester);
    expect(find.text('Name hose'), findsOneWidget);
    expect(find.text('Name fins'), findsOneWidget);
    expect(find.text('Name reg'), findsNothing);
    expect(find.text('Name kit'), findsNothing);
    expect(find.text('Name first'), findsNothing);
  });

  testWidgets('confirm holds every checked item under the parent', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    final dives = _FakeDiveRepository();
    await tester.pumpWidget(build(repo, dives: dives));
    await tester.pumpAndSettle();
    await openFoldedGroups(tester);
    expect(find.text('Add'), findsOneWidget);
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    expect(find.text('Add 1'), findsOneWidget);
    await tester.tap(find.text('Name fins'));
    await tester.pump();
    await tester.tap(find.text('Add 2'));
    await tester.pumpAndSettle();
    expect(heldParts(), unorderedEquals(['first', 'hose', 'fins']));
    final added = gearItemComponentsList.current(session)!.skip(1);
    expect(added.map((p) => p.parentEquipmentId), ['reg', 'reg']);
    expect(
      added.map((p) => p.component?.name),
      unorderedEquals(['Name hose', 'Name fins']),
    );
    expect(repo.added, isEmpty);
    expect(dives.rewrites, isEmpty);
  });

  testWidgets('a failed dive count is reported, and holds nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        _FakeComponentRepository(),
        count: _DiveCount()..throwOnCount = StateError('no database'),
      ),
    );
    await tester.pumpAndSettle();
    await openFoldedGroups(tester);
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    expect(find.text('Update past dives?'), findsNothing);
    expect(find.textContaining('no database'), findsOneWidget);
    expect(heldParts(), ['first']);
    expect(tester.takeException(), isNull);
    // The sheet is still usable: the selection and the button survive.
    expect(find.text('Add 1'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('cancelling the question keeps the sheet open, nothing held', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(_FakeComponentRepository(), count: _DiveCount()..diveCount = 3),
    );
    await tester.pumpAndSettle();
    await openFoldedGroups(tester);
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(heldParts(), ['first']);
    expect(find.byType(ComponentPickerSheet), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
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
    await openFoldedGroups(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Name hose'), findsOneWidget);
    expect(find.text('Name reg'), findsNothing);
  });

  testWidgets('a sheet dismissed while the dive count is read does not pop '
      'the page beneath', (tester) async {
    final count = _DiveCount()..gate = Completer<int>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentComponentRepositoryProvider.overrideWithValue(
            _FakeComponentRepository(),
          ),
          equipmentRepositoryProvider.overrideWithValue(
            _FakeEquipmentRepository(),
          ),
          diveRepositoryProvider.overrideWithValue(
            _FakeDiveRepository()..count = count,
          ),
          activeEquipmentProvider.overrideWith((ref) async => active),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
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
                onPressed: () => showComponentPicker(
                  context,
                  parentId: 'reg',
                  editing: session,
                ),
                child: const Text('PAGE BENEATH'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('PAGE BENEATH'));
    await tester.pumpAndSettle();
    await openFoldedGroups(tester);
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pump();
    // Dismiss the sheet by tapping the barrier while the count is read.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(ComponentPickerSheet), findsNothing);
    count.gate!.complete(0);
    await tester.pumpAndSettle();
    // The dismissed sheet holds nothing, and the page under it is still
    // there.
    expect(heldParts(), ['first']);
    expect(find.text('PAGE BENEATH'), findsOneWidget);
  });

  // The parts as stored, read into the sitting: Save writes what the picker
  // held, through the fakes here, with each part under its answer.
  group('saved from the sitting', () {
    late _FakeComponentRepository repo;
    late _FakeDiveRepository dives;
    late EquipmentComponent stored;

    setUp(() async {
      await setUpTestDatabase();
      addTearDown(SyncCoordinator.reset);
      repo = _FakeComponentRepository();
      dives = _FakeDiveRepository();
      final items = EquipmentRepository();
      for (final id in ['reg', 'first']) {
        await items.createEquipment(active.firstWhere((i) => i.id == id));
      }
      await EquipmentComponentRepository().addComponent(
        parentId: 'reg',
        componentId: 'first',
      );
      session = EditSession(item('reg', EquipmentType.regulator));
      addTearDown(session.dispose);
      T read<T>(ProviderListenable<T> provider) =>
          (identical(provider, equipmentComponentRepositoryProvider)
                  ? repo
                  : identical(provider, diveRepositoryProvider)
                  ? dives
                  : throw ArgumentError('$provider'))
              as T;
      holdGearItemComponents(session, read);
      await gearItemComponentsList.currentOrRead(session);
      stored = gearItemComponentsList.loaded(session)!.single;
    });
    tearDown(tearDownTestDatabase);

    testWidgets('adding on an assembly with past dives asks once, and Save '
        'replays both parts in one pass', (tester) async {
      await tester.pumpWidget(
        build(repo, count: _DiveCount()..diveCount = 3, dives: dives),
      );
      await tester.pumpAndSettle();
      await openFoldedGroups(tester);
      await tester.tap(find.text('Name hose'));
      await tester.pump();
      await tester.tap(find.text('Name fins'));
      await tester.pump();
      await tester.tap(find.text('Add 2'));
      await tester.pumpAndSettle();
      expect(find.text('Update past dives?'), findsOneWidget);
      expect(find.textContaining('Add the new part'), findsOneWidget);
      await tester.tap(find.text('Also update 3 dives'));
      await tester.pumpAndSettle();
      expect(find.text('Update past dives?'), findsNothing);
      expect(heldParts(), unorderedEquals(['first', 'hose', 'fins']));
      expect(repo.added, isEmpty);
      expect(dives.rewrites, isEmpty);

      await session.runHeldWrites();

      expect(repo.added, unorderedEquals([('reg', 'hose'), ('reg', 'fins')]));
      // Both parts in the one pass over the logged dives, compared field by
      // field: a record holding a List compares that field by identity.
      expect(dives.rewrites.map((r) => (r.$1, r.$3)), [
        ('reg', true),
        ('reg', false),
      ]);
      expect(
        dives.rewrites.first.$2,
        unorderedEquals([
          const GearPartAdded('hose'),
          const GearPartAdded('fins'),
        ]),
      );
      expect(dives.rewrites.last.$2, isEmpty);
    });

    testWidgets('From now on holds the part, and Save rewrites the planned '
        'dives only', (tester) async {
      await tester.pumpWidget(
        build(repo, count: _DiveCount()..diveCount = 3, dives: dives),
      );
      await tester.pumpAndSettle();
      await openFoldedGroups(tester);
      await tester.tap(find.text('Name hose'));
      await tester.pump();
      await tester.tap(find.text('Add 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From now on'));
      await tester.pumpAndSettle();
      expect(heldParts(), ['first', 'hose']);
      expect(repo.added, isEmpty);

      await session.runHeldWrites();

      expect(repo.added, [('reg', 'hose')]);
      expect(dives.rewrites.map((r) => r.$3), [true, false]);
      expect(dives.rewrites.first.$2, isEmpty);
      expect(dives.rewrites.last.$2, const [GearPartAdded('hose')]);
    });

    testWidgets('replace mode selects one, swaps the part on its row, and '
        'Save replays the swap', (tester) async {
      await tester.pumpWidget(
        build(
          repo,
          replacing: stored,
          count: _DiveCount()..diveCount = 1,
          dives: dives,
        ),
      );
      await tester.pumpAndSettle();
      await openFoldedGroups(tester);
      expect(find.text('Replace with'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      await tester.tap(find.text('Name hose'));
      await tester.pump();
      // Single select: the second tap moves the selection.
      await tester.tap(find.text('Name fins'));
      await tester.pump();
      final checked = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .where((t) => t.value == true)
          .length;
      expect(checked, 1);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Swap the part'), findsOneWidget);
      await tester.tap(find.text('Also update 1 dive'));
      await tester.pumpAndSettle();
      final held = gearItemComponentsList.current(session)!;
      expect(held.single.id, stored.id);
      expect(held.single.componentEquipmentId, 'fins');
      expect(held.single.component?.name, 'Name fins');
      expect(repo.replaced, isEmpty);
      expect(dives.rewrites, isEmpty);

      await session.runHeldWrites();

      expect(repo.replaced, [(stored.id, 'fins')]);
      expect(repo.added, isEmpty);
      expect(dives.rewrites.map((r) => (r.$1, r.$3)), [
        ('reg', true),
        ('reg', false),
      ]);
      expect(dives.rewrites.first.$2, const [
        GearPartReplaced(oldPartId: 'first', newPartId: 'fins'),
      ]);
    });
  });

  testWidgets('groups follow the type label, not the enum (#2937)', (
    tester,
  ) async {
    // Hose arrives first and is declared first in the enum; alphabetically
    // it follows Fins, so neither order can produce the result.
    await tester.pumpWidget(build(_FakeComponentRepository()));
    await tester.pumpAndSettle();
    await openFoldedGroups(tester);

    expect(
      tester.getTopLeft(find.text('Fins')).dy,
      lessThan(tester.getTopLeft(find.text('Hose')).dy),
    );
  });

  group('foldable groups (#3364)', () {
    Finder typeHeader(EquipmentType type) =>
        find.byKey(ValueKey('equipment-type-fold-type:${type.name}'));

    testWidgets('several types start closed', (tester) async {
      await tester.pumpWidget(build(_FakeComponentRepository()));
      await tester.pumpAndSettle();
      expect(typeHeader(EquipmentType.hose), findsOneWidget);
      expect(typeHeader(EquipmentType.fins), findsOneWidget);
      expect(find.text('Name hose'), findsNothing);
      expect(find.text('Name fins'), findsNothing);
    });

    testWidgets('one type starts open', (tester) async {
      await tester.pumpWidget(
        build(
          _FakeComponentRepository(),
          gear: [
            item('reg', EquipmentType.regulator),
            item('hose', EquipmentType.hose),
          ],
          index: Future.value(ComponentsIndex.empty),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Name hose'), findsOneWidget);
    });

    testWidgets('ticking then folding shows 1 of N selected', (tester) async {
      await tester.pumpWidget(build(_FakeComponentRepository()));
      await tester.pumpAndSettle();
      await tester.tap(typeHeader(EquipmentType.hose));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name hose'));
      await tester.pumpAndSettle();
      await tester.tap(typeHeader(EquipmentType.hose));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 selected'), findsOneWidget);
      // The tick survives the fold.
      expect(find.text('Add 1'), findsOneWidget);
    });
  });
}
