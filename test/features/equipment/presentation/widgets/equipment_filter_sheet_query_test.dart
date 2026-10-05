import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_filter_sheet.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The equipment filter sheet hosts the query editor and the Saved row
/// (#2365 PR 3).
class _SheetLauncher extends ConsumerWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => showEquipmentFilterSheet(context, ref),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  const now = 1735689600000;
  final bcd = ConditionNode(
    FieldPath(['type']),
    QueryOp.eq,
    const EnumValue('bcd'),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'wing',
            name: 'Wing',
            type: 'bcd',
            diverId: const Value('me'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<ProviderContainer> container({
    EquipmentFilterState filter = const EquipmentFilterState(),
  }) async {
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        equipmentFilterProvider.overrideWith((ref) => filter),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> open(WidgetTester tester, ProviderContainer c) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _SheetLauncher(),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
  }

  testWidgets('a save message shows inside the sheet, above its footer', (
    tester,
  ) async {
    // The page's ScaffoldMessenger renders under the modal sheet; the sheet
    // carries its own, scoped above the Cancel and Apply footer.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        equipmentFilterProvider.overrideWith(
          (ref) => EquipmentFilterState(query: bcd),
        ),
        // No diver profile: the save flow answers with a snackbar.
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    await open(tester, c);

    await tester.tap(find.text('Save query'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(EquipmentFilterSheet),
        matching: find.byType(SnackBar),
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('Apply Filters')).top),
    );
  });

  /// Names the query in the save dialog and returns what was stored.
  Future<QueryNode> saveAs(WidgetTester tester, String name) async {
    await tester.tap(find.text('Save query'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    // The dialog's field: the sheet has text fields of its own.
    final dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextFormField)),
      name,
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final rows = await tester.runAsync(() => db.select(db.savedQueries).get());
    return queryNodeFromJson(
      (jsonDecode(rows!.single.queryJson) as Map).cast<String, Object?>(),
    );
  }

  // #2989: the sheet's own controls, with nothing typed, save as a query.
  testWidgets('Save stores the sheet axes without a typed query', (
    tester,
  ) async {
    final c = await container(
      filter: const EquipmentFilterState(type: EquipmentType.bcd),
    );
    await open(tester, c);
    // The default status view is what every unfiltered list shows, so it
    // is not stored; the category the diver picked is.
    expect(await saveAs(tester, 'BCDs'), bcd);
  });

  testWidgets('a status the diver picked is stored', (tester) async {
    final c = await container(
      filter: const EquipmentFilterState(status: EquipmentStatus.sold),
    );
    await open(tester, c);
    expect(
      await saveAs(tester, 'Sold'),
      ConditionNode(FieldPath(['status']), QueryOp.eq, const EnumValue('sold')),
    );
  });

  testWidgets('Save is disabled while the sheet sets nothing', (tester) async {
    final c = await container();
    await open(tester, c);
    final save = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Save query'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(save.enabled, isFalse);
  });

  testWidgets('a typed query is applied with the other axes', (tester) async {
    final c = await container(
      filter: const EquipmentFilterState(status: EquipmentStatus.retired),
    );
    await open(tester, c);
    await tester.enterText(
      // The query section leads the sheet, so its field is the first.
      find.byType(TextField).first,
      'type = bcd',
    );
    await tester.pump();
    await apply(tester);
    final state = c.read(equipmentFilterProvider);
    expect(state.query, bcd);
    expect(state.status, EquipmentStatus.retired);
  });

  testWidgets('a saved equipment query applies on tap', (tester) async {
    await tester.runAsync(
      () => SavedQueryRepository().create(
        subject: QuerySubject.equipment,
        name: 'Wings',
        node: bcd,
        diverId: 'me',
      ),
    );
    final c = await container();
    await open(tester, c);
    await tester.tap(find.widgetWithText(ActionChip, 'Wings'));
    await tester.pumpAndSettle();
    await apply(tester);
    expect(c.read(equipmentFilterProvider).query, bcd);
  });

  // #2989: a saved status is the whole status axis; the default view
  // ANDed in would leave a saved Sold query with no rows.
  testWidgets('a saved query naming a status takes over the status axis', (
    tester,
  ) async {
    final sold = ConditionNode(
      FieldPath(['status']),
      QueryOp.eq,
      const EnumValue('sold'),
    );
    await tester.runAsync(
      () => SavedQueryRepository().create(
        subject: QuerySubject.equipment,
        name: 'Sold',
        node: sold,
        diverId: 'me',
      ),
    );
    final c = await container(
      filter: const EquipmentFilterState(serviceDue: ServiceDueFilter.any),
    );
    await open(tester, c);
    await tester.tap(find.widgetWithText(ActionChip, 'Sold'));
    await tester.pumpAndSettle();
    await apply(tester);
    final state = c.read(equipmentFilterProvider);
    expect(state.query, sold);
    expect(state.allStatuses, isTrue);
    expect(state.status, isNull);
    expect(state.serviceDue, isNull);
  });

  testWidgets('a saved query without a status resets the sheet controls', (
    tester,
  ) async {
    await tester.runAsync(
      () => SavedQueryRepository().create(
        subject: QuerySubject.equipment,
        name: 'Wings',
        node: bcd,
        diverId: 'me',
      ),
    );
    final c = await container(
      filter: const EquipmentFilterState(
        status: EquipmentStatus.retired,
        type: EquipmentType.regulator,
        tagIds: {'t1'},
        owner: EquipmentOwnerFilter.mine,
      ),
    );
    await open(tester, c);
    await tester.tap(find.widgetWithText(ActionChip, 'Wings'));
    await tester.pumpAndSettle();
    await apply(tester);
    // The whole saved search on the default status view; whose gear to
    // show is the diver's view, not part of a saved search, so it stays.
    expect(
      c.read(equipmentFilterProvider),
      EquipmentFilterState(query: bcd, owner: EquipmentOwnerFilter.mine),
    );
  });

  testWidgets('Apply keeps the query the sheet opened with', (tester) async {
    final c = await container(filter: EquipmentFilterState(query: bcd));
    await open(tester, c);
    await apply(tester);
    expect(c.read(equipmentFilterProvider).query, bcd);
  });

  testWidgets('Clear all clears the query', (tester) async {
    final c = await container(filter: EquipmentFilterState(query: bcd));
    await open(tester, c);
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await apply(tester);
    expect(c.read(equipmentFilterProvider).query, isNull);
  });
}
