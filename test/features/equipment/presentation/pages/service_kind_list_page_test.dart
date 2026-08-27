import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/pages/service_kind_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/bulk_delete_contract.dart';
import '../../../../helpers/selection_contract.dart';
import '../../../../helpers/test_database.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);

  ServiceKind builtIn(String id, String name) => ServiceKind(
    id: id,
    name: name,
    applicableTypes: const [EquipmentType.tank],
    defaultIntervalDays: 365,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  Widget buildPage(List<ServiceKind> kinds) {
    return ProviderScope(
      overrides: [serviceKindsProvider.overrideWith((ref) async => kinds)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ServiceKindListPage(),
      ),
    );
  }

  ServiceKind custom(String id, String name) => ServiceKind(
    id: id,
    name: name,
    applicableTypes: const [EquipmentType.tank],
    defaultIntervalDays: 180,
    isBuiltIn: false,
    createdAt: t0,
    updatedAt: t0,
  );

  group('selection', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      final all = [
        custom('c1', 'Aaa custom'),
        custom('c2', 'Bbb custom'),
        custom('c3', 'Ccc custom'),
      ];
      var visible = all;

      await verifySelectionContract(
        tester,
        build: () => ProviderScope(
          overrides: [
            serviceKindsProvider.overrideWith((ref) async => visible),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ServiceKindListPage(),
          ),
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        // Built-in kinds render isSelectable: false and so have no checkbox at
        // all, which makes ListTile.first the wrong anchor. Pin to the custom
        // row that is actually selectable.
        rowRoot: find.ancestor(
          of: find.text('Aaa custom'),
          matching: find.byType(ListTile),
        ),
        firstRow: find.text('Aaa custom'),
        applyFilter: (tester) async {
          visible = [all.first];
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ServiceKindListPage)),
          );
          container.invalidate(serviceKindsProvider);
          await tester.pumpAndSettle();
        },
        visibleAfterFilter: 1,
      );
    });

    testWidgets('selection mode hides the per-row delete action', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage([custom('c1', 'Custom kind')]));
      await tester.pumpAndSettle();

      // Normal mode offers the row's own trash.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      // In selection mode the only delete is the bulk one, which the shared
      // bar keeps behind its overflow menu.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byKey(const ValueKey('selection_overflow')), findsOneWidget);
    });

    testWidgets('built-in kinds render no checkbox and are excluded from '
        'select-all', (tester) async {
      await tester.pumpWidget(
        buildPage([
          builtIn('hydro', 'Hydrostatic test'),
          custom('c1', 'Custom kind'),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      // Only the custom kind gets a checkbox; the built-in keeps its lock.
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();

      expect(
        find.text('1 selected'),
        findsOneWidget,
        reason: 'select-all must skip rows the repository refuses to delete',
      );
    });
  });

  testWidgets('built-ins render locked without delete action', (tester) async {
    await tester.pumpWidget(
      buildPage([
        builtIn('hydro', 'Hydrostatic test'),
        builtIn('vip', 'Visual inspection (VIP)'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hydrostatic test'), findsOneWidget);
    expect(find.text('Visual inspection (VIP)'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('No custom service types yet'), findsOneWidget);
  });

  testWidgets('custom kind renders in Custom section with delete action', (
    tester,
  ) async {
    final custom = ServiceKind(
      id: 'c1',
      name: 'Scrubber repack',
      defaultIntervalHours: 5.0,
      createdAt: t0,
      updatedAt: t0,
    );
    await tester.pumpWidget(
      buildPage([builtIn('hydro', 'Hydrostatic test'), custom]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scrubber repack'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.textContaining('every 5.0 hours'), findsOneWidget);
  });

  testWidgets('add dialog opens from FAB', (tester) async {
    await tester.pumpWidget(buildPage([builtIn('hydro', 'Hydrostatic test')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add service type'), findsOneWidget);
    expect(find.text('Attach automatically to new gear'), findsOneWidget);
  });

  group('bulk delete against the database', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await setUpTestDatabase();
    });

    tearDown(() async => tearDownTestDatabase());

    testWidgets('removes the checked custom kinds and reports the count', (
      tester,
    ) async {
      final repo = ServiceKindRepository();
      final a = await repo.createKind(custom('c1', 'Aaa custom'));
      final b = await repo.createKind(custom('c2', 'Bbb custom'));

      await verifyBulkDelete(
        tester,
        build: () => ProviderScope(
          overrides: [
            serviceKindsProvider.overrideWith((ref) async => [a, b]),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ServiceKindListPage(),
          ),
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        expectedDeletedCount: 2,
      );

      expect(find.text('2 deleted'), findsOneWidget);
      final remaining = await repo.getAllKinds();
      expect(
        remaining.where((k) => !k.isBuiltIn),
        isEmpty,
        reason: 'both custom kinds must be gone from the database',
      );
    });
  });

  group('database-backed CRUD flows', () {
    late SharedPreferences prefs;
    late String diverId;
    late ServiceKindRepository kindRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await setUpTestDatabase();
      kindRepo = ServiceKindRepository();
      final diver = await DiverRepository().createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      diverId = diver.id;
      await prefs.setString(currentDiverIdKey, diver.id);
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    Widget buildDbPage() {
      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServiceKindListPage(),
        ),
      );
    }

    testWidgets('creating a custom kind stamps the active diver', (
      tester,
    ) async {
      await tester.pumpWidget(buildDbPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Scrubber repack',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Interval (hours)'),
        '5.0',
      );
      await tester.ensureVisible(find.text('Other'));
      await tester.tap(find.text('Other'));
      await tester.ensureVisible(find.text('Attach automatically to new gear'));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The Custom section sits below the 9 built-ins; scroll it into view
      // (ListView builds lazily, so off-screen rows do not exist yet).
      await tester.scrollUntilVisible(find.text('Scrubber repack'), 200);
      expect(find.text('Scrubber repack'), findsOneWidget);
      final kinds = await tester.runAsync(() => kindRepo.getAllKinds());
      final custom = kinds!.firstWhere((k) => !k.isBuiltIn);
      expect(custom.name, 'Scrubber repack');
      expect(custom.diverId, diverId); // scoped to the active diver
      expect(custom.defaultIntervalHours, 5.0);
      expect(custom.applicableTypes, [EquipmentType.other]);
      expect(custom.autoAttach, isTrue);
    });

    testWidgets('a default price round-trips through the editor', (
      tester,
    ) async {
      await tester.pumpWidget(buildDbPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Disinfect',
      );
      await tester.ensureVisible(
        find.byKey(const Key('service-kind-default-cost')),
      );
      await tester.enterText(
        find.byKey(const Key('service-kind-default-cost')),
        '12.5',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final kinds = await tester.runAsync(() => kindRepo.getAllKinds());
      final custom = kinds!.firstWhere((k) => k.name == 'Disinfect');
      expect(custom.defaultCost, 12.5);
    });

    testWidgets('a default currency can be cleared back to inherit', (
      tester,
    ) async {
      // Review of #829: without a null entry in the dropdown there was no way
      // back to "use the diver's default" once a currency had been picked.
      await tester.runAsync(
        () => kindRepo.createKind(
          ServiceKind(
            id: '',
            diverId: diverId,
            name: 'Priced kind',
            defaultCost: 12.5,
            defaultCurrency: 'EUR',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );

      // The edit dialog is taller than the default 800x600 test surface, and a
      // clipped DropdownButton never opens on tap.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDbPage());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Priced kind'), 200);
      await tester.tap(find.text('Priced kind'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('service-kind-default-currency')),
      );
      // Tap the rendered value rather than the form field: the field's centre
      // lands on the decoration, not the dropdown button.
      await tester.tap(find.text('EUR').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use default currency').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final kinds = await tester.runAsync(() => kindRepo.getAllKinds());
      final updated = kinds!.firstWhere((k) => k.name == 'Priced kind');
      expect(updated.defaultCurrency, isNull);
      // Clearing the currency must not disturb the price.
      expect(updated.defaultCost, 12.5);
    });

    testWidgets('editing a custom kind persists changes', (tester) async {
      await tester.runAsync(
        () => kindRepo.createKind(
          ServiceKind(
            id: '',
            diverId: diverId,
            name: 'Cell check',
            defaultIntervalDays: 365,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );
      await tester.pumpWidget(buildDbPage());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Cell check'), 200);
      await tester.ensureVisible(find.text('Cell check'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cell check'));
      await tester.pumpAndSettle();
      expect(find.text('Edit service type'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'O2 cell check',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Interval (days)'),
        '540',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('O2 cell check'), 200);
      expect(find.text('O2 cell check'), findsOneWidget);
      final kinds = await tester.runAsync(() => kindRepo.getAllKinds());
      final custom = kinds!.firstWhere((k) => !k.isBuiltIn);
      expect(custom.name, 'O2 cell check');
      expect(custom.defaultIntervalDays, 540);
    });

    testWidgets('delete flow removes the custom kind after confirmation', (
      tester,
    ) async {
      await tester.runAsync(
        () => kindRepo.createKind(
          ServiceKind(
            id: '',
            diverId: diverId,
            name: 'Doomed kind',
            defaultIntervalDays: 30,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );
      await tester.pumpWidget(buildDbPage());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.byIcon(Icons.delete_outline), 200);
      await tester.ensureVisible(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Delete service type?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Doomed kind'), findsNothing);
      final kinds = await tester.runAsync(() => kindRepo.getAllKinds());
      expect(kinds!.where((k) => !k.isBuiltIn), isEmpty);
    });

    testWidgets('empty name fails validation and keeps the dialog open', (
      tester,
    ) async {
      await tester.pumpWidget(buildDbPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('A name is required'), findsOneWidget);
      expect(find.text('Add service type'), findsOneWidget); // still open
    });
  });
}
