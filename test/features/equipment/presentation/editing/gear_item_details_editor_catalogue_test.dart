import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_details_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_catalogue_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The gear editor with the built-in equipment catalogue (issue #5118).
void main() {
  final l = AppLocalizationsEn();
  final catalogue = EquipmentCatalogue(
    EquipmentCatalogueFile(
      format: 1,
      generatedAt: DateTime.utc(2026, 11, 27),
      records: const [
        EquipmentCatalogueRecord(
          id: 'shearwater-perdix-2',
          manufacturer: 'Shearwater',
          model: 'Perdix 2',
          type: EquipmentType.computer,
          attributes: {'connectivity': 'ble'},
        ),
        EquipmentCatalogueRecord(
          id: 'maker-loop',
          manufacturer: 'Maker',
          model: 'Loop',
          type: EquipmentType.rebreather,
          attributes: {'depth_rating_m': 120},
        ),
      ],
    ),
  );

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  Future<EditSession<EquipmentItem>> pump(
    WidgetTester tester, {
    EquipmentItem item = const EquipmentItem(
      id: 'e1',
      name: 'Perdix',
      type: EquipmentType.computer,
      brand: 'Shearwater',
      model: 'Perdix 2',
    ),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2600);
    addTearDown(tester.view.reset);
    final session = EditSession(item);
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          activeEquipmentProvider.overrideWith((ref) async => const []),
          equipmentDiveCountProvider('e1').overrideWith((ref) async => 0),
          equipmentTripCountProvider('e1').overrideWith((ref) async => 0),
          equipmentCatalogueProvider.overrideWith((ref) async => catalogue),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: GearItemDetailsEditor(session: session),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('an applied review shows in the attribute inputs', (
    tester,
  ) async {
    final session = await pump(tester);
    final bluetooth = attributeChoiceLabel(l, 'connectivity', 'ble');
    expect(find.text(bluetooth), findsNothing);
    await tester.tap(find.byKey(const ValueKey('gear-catalogue-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply 1'));
    await tester.pumpAndSettle();
    expect(session.valueOf(gearCatalogueIdField), 'shearwater-perdix-2');
    expect(find.text(bluetooth), findsOneWidget);
    expect(
      find.text('Built-in equipment catalogue has details for this model'),
      findsNothing,
    );
  });

  testWidgets('an applied number shows in its text input', (tester) async {
    await pump(
      tester,
      item: const EquipmentItem(
        id: 'e1',
        name: 'Loop',
        type: EquipmentType.rebreather,
        brand: 'Maker',
        model: 'Loop',
      ),
    );
    final input = find.descendant(
      of: find.byKey(const ValueKey('attr-number-depth_rating_m')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(input).controller.text, isEmpty);
    await tester.tap(find.byKey(const ValueKey('gear-catalogue-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply 1'));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(input).controller.text, '120');
  });
}
