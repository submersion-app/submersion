import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
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

  Future<void> pumpCreator(WidgetTester tester) async {
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
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: EquipmentEditPage(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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
}
