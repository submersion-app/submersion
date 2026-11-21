import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_members_editor.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_type_fold_header.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';

/// The Members card's editor on the set page (issue #4527, phase 3) keeps
/// the set form's picker: folding groups, an assembly's parts behind a
/// switch, members no longer shared listed and kept.
void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold Water Reg',
    type: EquipmentType.regulator,
  );
  const first = EquipmentItem(
    id: 'first',
    name: 'DIN First Stage',
    type: EquipmentType.firstStage,
  );
  const second = EquipmentItem(
    id: 'second',
    name: 'Primary Second Stage',
    type: EquipmentType.secondStage,
  );
  const zeagle = EquipmentItem(
    id: 'bcd',
    name: 'Zeagle',
    type: EquipmentType.bcd,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Jet fins',
    type: EquipmentType.fins,
  );
  const hidden = EquipmentItem(
    id: 'hidden',
    name: 'Borrowed light',
    type: EquipmentType.light,
  );
  const showLabel = 'Show components of assemblies';

  final t0 = DateTime(2026);
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: '$parent>$child',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );

  EquipmentSet setOf(List<EquipmentItem> members) => EquipmentSet(
    id: 'set-1',
    name: 'Cold set',
    equipmentIds: [for (final m in members) m.id],
    items: members,
    createdAt: t0,
    updatedAt: t0,
  );

  Future<EditSession<EquipmentSet>> pumpEditor(
    WidgetTester tester, {
    required List<EquipmentItem> members,
    List<EquipmentItem> gear = const [reg, first, second, zeagle, fins],
    bool grouped = false,
    EquipmentTypeOrder? typeOrder,
    List<EquipmentItem>? visible,
    bool gearFails = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final session = EditSession(setOf(members));
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          activeEquipmentProvider.overrideWith(
            (ref) async =>
                gearFails ? throw StateError('gear unreadable') : gear,
          ),
          allEquipmentProvider.overrideWith((ref) async => visible ?? gear),
          equipmentSetsProvider.overrideWith((ref) async => const []),
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(
              groupByType: grouped,
              typeOrder: typeOrder,
            ),
          ),
          equipmentComponentsIndexProvider.overrideWithValue(
            AsyncValue.data(
              ComponentsIndex.fromRows([
                edge('reg', 'first'),
                edge('reg', 'second'),
              ]),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: EquipmentSetMembersEditor(session: session),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  Finder row(String name) => find.descendant(
    of: find.byType(CheckboxListTile),
    matching: find.text(name),
  );

  bool ticked(WidgetTester tester, String name) => tester
      .widget<CheckboxListTile>(
        find.ancestor(of: row(name), matching: find.byType(CheckboxListTile)),
      )
      .value!;

  testWidgets('the Members editor tells identical items apart', (tester) async {
    EquipmentItem pouch(String id, String serial) => EquipmentItem(
      id: id,
      name: 'Pouches',
      type: EquipmentType.other,
      brand: 'Palantic',
      model: 'Drop-Bottom',
      serialNumber: serial,
    );
    await pumpEditor(
      tester,
      members: const [],
      gear: [pouch('b', 'X2'), pouch('a', 'X1')],
    );

    expect(find.text('Palantic Drop-Bottom · S/N X1'), findsOneWidget);
    expect(find.text('Palantic Drop-Bottom · S/N X2'), findsOneWidget);
  });

  testWidgets('a tick is held in the sitting', (tester) async {
    final session = await pumpEditor(tester, members: const [zeagle]);

    await tester.tap(row('Jet fins'));
    await tester.pumpAndSettle();

    expect(session.working.equipmentIds, unorderedEquals(['bcd', 'fins']));
    expect(session.changedCardIds, {'members'});
    expect(ticked(tester, 'Jet fins'), isTrue);
  });

  group('components of a listed assembly (#2514)', () {
    testWidgets('wait behind a switch', (tester) async {
      await pumpEditor(tester, members: const [zeagle]);

      expect(find.text('Cold Water Reg'), findsOneWidget);
      expect(find.text('DIN First Stage'), findsNothing);

      await tester.tap(find.text(showLabel));
      await tester.pumpAndSettle();

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsOneWidget);
    });

    testWidgets('stay listed when ticked, so they can be unticked', (
      tester,
    ) async {
      await pumpEditor(tester, members: const [first]);

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsNothing);
      expect(find.text(showLabel), findsOneWidget);
    });

    testWidgets('stay listed once unticked, so the untick can be undone', (
      tester,
    ) async {
      final session = await pumpEditor(tester, members: const [first]);

      await tester.tap(find.text('DIN First Stage'));
      await tester.pumpAndSettle();

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(ticked(tester, 'DIN First Stage'), isFalse);
      expect(session.working.equipmentIds, isEmpty);
    });
  });

  group('folding (#3364)', () {
    Finder typeHeader(EquipmentType type) =>
        find.byKey(ValueKey('equipment-type-fold-type:${type.name}'));

    testWidgets('groups holding members start open, others closed', (
      tester,
    ) async {
      await pumpEditor(tester, members: const [zeagle], grouped: true);

      expect(row('Zeagle'), findsOneWidget);
      expect(typeHeader(EquipmentType.fins), findsOneWidget);
      expect(row('Jet fins'), findsNothing);
    });

    testWidgets('folding keeps the ticks and says so', (tester) async {
      await pumpEditor(tester, members: const [zeagle], grouped: true);
      await tester.tap(typeHeader(EquipmentType.bcd));
      await tester.pumpAndSettle();
      expect(row('Zeagle'), findsNothing);
      expect(find.text('1 of 1 selected'), findsOneWidget);

      await tester.tap(typeHeader(EquipmentType.bcd));
      await tester.pumpAndSettle();
      expect(ticked(tester, 'Zeagle'), isTrue);
    });
  });

  // The groups follow the diver's type order, not the order the gear was
  // added in (#1486, #1576), and a tick is held by id across the reorder.
  testWidgets('the groups follow the type order, and a tick after the '
      'reorder is held by id', (tester) async {
    const tank = EquipmentItem(
      id: 'tank',
      name: 'Faber',
      type: EquipmentType.tank,
    );
    final session = await pumpEditor(
      tester,
      members: const [zeagle, tank, reg],
      gear: const [zeagle, tank, reg],
      grouped: true,
      typeOrder: EquipmentTypeOrder.headToToe,
    );

    expect(
      [
        for (final h in tester.widgetList<EquipmentTypeFoldHeader>(
          find.byType(EquipmentTypeFoldHeader),
        ))
          h.type,
      ],
      [EquipmentType.tank, EquipmentType.regulator, EquipmentType.bcd],
    );

    await tester.tap(row('Cold Water Reg'));
    await tester.pumpAndSettle();

    expect(session.working.equipmentIds, unorderedEquals(['bcd', 'tank']));
    expect(ticked(tester, 'Faber'), isTrue);
    expect(ticked(tester, 'Zeagle'), isTrue);
  });

  testWidgets('a member no longer shared is listed without a checkbox and '
      'kept', (tester) async {
    final session = await pumpEditor(
      tester,
      members: const [zeagle, hidden],
      visible: const [reg, first, second, zeagle, fins],
    );

    expect(find.text('Borrowed light'), findsOneWidget);
    expect(find.text('No longer shared'), findsOneWidget);
    expect(row('Borrowed light'), findsNothing);
    await tester.tap(row('Jet fins'));
    await tester.pumpAndSettle();

    expect(session.working.equipmentIds, contains('hidden'));
  });

  testWidgets("a member deleted underneath is not the diver's change", (
    tester,
  ) async {
    final session = await pumpEditor(tester, members: const [zeagle, fins]);

    session.rebase(setOf(const [zeagle]));
    await tester.pumpAndSettle();

    expect(session.isDirty, isFalse);
    expect(ticked(tester, 'Jet fins'), isFalse);
    expect(session.valueOf(setMembersField).held, {'bcd'});
  });

  testWidgets('with no gear it says to add some first', (tester) async {
    await pumpEditor(tester, members: const [], gear: const []);

    expect(find.text('No equipment available'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('a gear list that cannot be read says so', (tester) async {
    await pumpEditor(tester, members: const [zeagle], gearFails: true);

    expect(find.textContaining('gear unreadable'), findsOneWidget);
  });

  testWidgets('handed a new session, it edits that one', (tester) async {
    final first = await pumpEditor(tester, members: const [zeagle]);
    final second = EditSession(setOf(const [zeagle]));
    addTearDown(second.dispose);
    final scope = tester.widget<ProviderScope>(find.byType(ProviderScope));
    await tester.pumpWidget(
      ProviderScope(
        overrides: scope.overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: EquipmentSetMembersEditor(session: second),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(row('Jet fins'));
    await tester.pumpAndSettle();
    second.set(setNameField, 'Renamed');
    await tester.pumpAndSettle();

    expect(second.working.equipmentIds, contains('fins'));
    expect(first.isDirty, isFalse);
    expect(ticked(tester, 'Jet fins'), isTrue);
  });
}
