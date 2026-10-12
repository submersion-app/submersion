import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #2175: the single-dive editor's Add opens the picker in
/// multi-select mode, and every item ticked there joins the dive's gear in
/// one pass. The bulk editor's path is in bulk_membership_wiring_test.dart.
void main() {
  late DiveRepository repository;
  const regulator = EquipmentItem(
    id: 'eq-reg',
    name: 'Apeks XTX50',
    type: EquipmentType.regulator,
  );
  const mask = EquipmentItem(
    id: 'eq-mask',
    name: 'Frameless Mask',
    type: EquipmentType.mask,
  );
  const fins = EquipmentItem(
    id: 'eq-fins',
    name: 'Jet Fins',
    type: EquipmentType.fins,
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    // Seed without FK enforcement so we don't need a full divers row graph.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
    final equipment = EquipmentRepository();
    for (final item in [regulator, mask, fins]) {
      await equipment.createEquipment(item);
    }
    await repository.createDive(
      Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 1),
        notes: '',
        gear: looseGear(const [regulator]),
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  /// Pumps the editor for d1, opens Gas & Gear and then the equipment
  /// picker from the Equipment section's Add.
  Future<AppLocalizations> openPicker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => 'diver-1',
          ),
          activeEquipmentProvider.overrideWith(
            (ref) async => [regulator, mask, fins],
          ),
        ].cast(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: 'd1', embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(DiveEditPage)));

    final header = find.descendant(
      of: find.byType(GasGearSection),
      matching: find.text(l10n.diveLog_edit_group_gasGear),
    );
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();

    final add = find.descendant(
      // Matched on the label property: the overline draws it upper-cased.
      of: find.byWidgetPredicate(
        (w) =>
            w is FormOverline && w.label == l10n.diveLog_edit_section_equipment,
      ),
      matching: find.byIcon(Icons.add),
    );
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentPickerSheet), findsOneWidget);
    return l10n;
  }

  Finder inPicker(String text) => find.descendant(
    of: find.byType(EquipmentPickerSheet),
    matching: find.text(text),
  );

  testWidgets('every ticked item joins the dive gear when Add is pressed', (
    tester,
  ) async {
    await openPicker(tester);
    // Gear already on the dive is not offered again.
    expect(inPicker(regulator.name), findsNothing);
    expect(find.text(mask.name), findsOneWidget);
    expect(find.text(fins.name), findsOneWidget);

    await tester.tap(inPicker(mask.name));
    await tester.tap(inPicker(fins.name));
    await tester.pumpAndSettle();
    // Ticking alone adds nothing and leaves the sheet open.
    expect(find.byType(EquipmentPickerSheet), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add 2'));
    // The add expands assemblies against the database before it lands.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EquipmentPickerSheet), findsNothing);
    for (final item in [regulator, mask, fins]) {
      expect(find.text(item.name), findsOneWidget, reason: item.name);
    }
  });

  testWidgets('Cancel closes the picker and adds nothing', (tester) async {
    final l10n = await openPicker(tester);

    await tester.tap(inPicker(mask.name));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(TextButton, l10n.common_action_cancel),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EquipmentPickerSheet), findsNothing);
    expect(find.text(regulator.name), findsOneWidget);
    expect(find.text(mask.name), findsNothing);
  });
}
