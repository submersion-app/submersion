import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Saving gear the list's current view hides says so and offers the view
/// that shows it (#3068): a new Wanted item saved from the default view,
/// which leaves out wishlist gear, looked as if it had never been saved.
void main() {
  late EquipmentRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpApp(
    WidgetTester tester,
    Widget page, {
    List<Object> extraOverrides = const [],
  }) async {
    // Tall viewport so the whole (lazy ListView) form materializes.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentRepositoryProvider.overrideWithValue(repository),
          ...extraOverrides,
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpCreator(WidgetTester tester) =>
      pumpApp(tester, const EquipmentEditPage(embedded: true));

  Future<void> saveNew(WidgetTester tester, {String? status}) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name *'),
      'Dream Fins',
    );
    if (status != null) {
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(status).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(EquipmentEditPage)));

  testWidgets('a Wanted item saved under the default view offers the Wanted '
      'view', (tester) async {
    await pumpCreator(tester);
    await saveNew(tester, status: 'Wanted');

    final saved = (await repository.getAllEquipment()).single;
    expect(saved.status, EquipmentStatus.wanted);
    expect(find.text('Saved, but the current list view hides it'), findsOne);

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    final container = containerOf(tester);
    expect(
      container.read(equipmentFilterProvider),
      const EquipmentFilterState(status: EquipmentStatus.wanted),
    );
    expect(container.read(highlightedEquipmentIdProvider), saved.id);
  });

  testWidgets('an Active item the default view shows gets no hint', (
    tester,
  ) async {
    await pumpCreator(tester);
    await saveNew(tester);

    expect((await repository.getAllEquipment()).single.name, 'Dream Fins');
    expect(
      find.text('Saved, but the current list view hides it'),
      findsNothing,
    );
    expect(
      containerOf(tester).read(equipmentFilterProvider),
      const EquipmentFilterState(),
    );
  });

  Future<String> activeFins() async => (await repository.createEquipment(
    const EquipmentItem(id: '', name: 'Fins', type: EquipmentType.fins),
  )).id;

  Future<void> pickWantedAndSave(WidgetTester tester) async {
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wanted').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('a master-detail edit to Wanted offers the Wanted view', (
    tester,
  ) async {
    final id = await activeFins();
    await pumpApp(tester, EquipmentEditPage(equipmentId: id, embedded: true));
    await pickWantedAndSave(tester);

    expect(find.text('Saved, but the current list view hides it'), findsOne);
  });

  testWidgets('a routed edit returns to the item, so it just confirms', (
    tester,
  ) async {
    final id = await activeFins();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('item page')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => EquipmentEditPage(equipmentId: id),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentRepositoryProvider.overrideWithValue(repository),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/edit');
    await tester.pumpAndSettle();
    await pickWantedAndSave(tester);

    expect(find.text('item page'), findsOne);
    expect(find.text('Equipment updated'), findsOne);
    expect(
      find.text('Saved, but the current list view hides it'),
      findsNothing,
    );
  });

  testWidgets('a failed visibility check still saves and confirms', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const EquipmentEditPage(embedded: true),
      extraOverrides: [
        queryIdSetRunnerProvider.overrideWithValue(
          _FailingRunner(DatabaseService.instance.database),
        ),
      ],
    );
    await saveNew(tester, status: 'Wanted');

    expect((await repository.getAllEquipment()).single.name, 'Dream Fins');
    expect(find.text('Equipment added'), findsOne);
    expect(
      find.text('Saved, but the current list view hides it'),
      findsNothing,
    );
  });
}

/// A runner whose every query fails, as a locked or closed database would.
class _FailingRunner extends QueryIdSetRunner {
  _FailingRunner(super.db);

  @override
  Future<Set<String>> ids(CompiledQuery compiled, {QueryScope? scope}) =>
      Future.error(StateError('query failed'));
}
