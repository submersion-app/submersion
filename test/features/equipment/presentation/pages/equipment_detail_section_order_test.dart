import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/equipment_detail_sections.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/presentation/widgets/exposure_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import 'equipment_detail_page_unlock_harness.dart';

/// The diver arranges a gear item's cards (issue #4975): the page follows
/// the saved order and visibility, locked and unlocked, and a hidden card
/// that can be edited waits on the strip while the page is unlocked.
void main() {
  final l = AppLocalizationsEn();

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  MockSettingsNotifier settingsWith(
    List<EquipmentDetailSectionConfig> sections,
  ) => MockSettingsNotifier(
    AppSettings(
      hasAcceptedPlanningDisclaimer: true,
      equipmentDetailSections: sections,
    ),
  );

  /// The default order with [id] moved to the top.
  List<EquipmentDetailSectionConfig> withFirst(EquipmentDetailSectionId id) => [
    EquipmentDetailSectionConfig(id: id, visible: true),
    for (final s in EquipmentDetailSectionConfig.defaultSections)
      if (s.id != id) s,
  ];

  /// The default order with [id] switched off.
  List<EquipmentDetailSectionConfig> without(EquipmentDetailSectionId id) => [
    for (final s in EquipmentDetailSectionConfig.defaultSections)
      s.id == id ? s.copyWith(visible: false) : s,
  ];

  double topOf(WidgetTester tester, String title) =>
      tester.getTopLeft(find.text(title).first).dy;

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  final details = l.equipment_detail_detailsTitle;
  final location = l.equipment_location_card_title;
  final serviceHistory = l.equipment_service_historyTitle;

  testWidgets('the default order is the order the page always had', (
    tester,
  ) async {
    await pumpGearPage(tester);

    expect(topOf(tester, details), lessThan(topOf(tester, location)));
    expect(topOf(tester, location), lessThan(topOf(tester, serviceHistory)));
  });

  testWidgets('a saved order is applied', (tester) async {
    await pumpGearPage(
      tester,
      settingsNotifier: settingsWith(
        withFirst(EquipmentDetailSectionId.serviceHistory),
      ),
    );

    expect(topOf(tester, serviceHistory), lessThan(topOf(tester, details)));
  });

  testWidgets('the saved order holds while the page is unlocked', (
    tester,
  ) async {
    await pumpGearPage(
      tester,
      settingsNotifier: settingsWith(
        withFirst(EquipmentDetailSectionId.serviceHistory),
      ),
    );
    await unlock(tester);

    expect(topOf(tester, serviceHistory), lessThan(topOf(tester, details)));
  });

  testWidgets('a calculated card shows by default', (tester) async {
    await pumpGearPage(tester);
    expect(find.byType(ExposureCard), findsOneWidget);
  });

  testWidgets('a calculated card switched off is gone, locked and unlocked', (
    tester,
  ) async {
    await pumpGearPage(
      tester,
      settingsNotifier: settingsWith(
        without(EquipmentDetailSectionId.exposure),
      ),
    );
    expect(find.byType(ExposureCard), findsNothing);

    await unlock(tester);
    expect(find.byType(ExposureCard), findsNothing);
  });

  testWidgets('a hidden card that can be edited waits on the strip', (
    tester,
  ) async {
    await pumpGearPage(
      tester,
      settingsNotifier: settingsWith(
        without(EquipmentDetailSectionId.location),
      ),
    );
    expect(find.text(location), findsNothing);

    await unlock(tester);
    final chip = find.descendant(
      of: find.byType(AddStrip),
      matching: find.text(location),
    );
    expect(chip, findsOneWidget);

    // Brought in, it joins the page where the order puts it.
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AddStrip), matching: find.text(location)),
      findsNothing,
    );
    expect(find.text(location), findsWidgets);
  });

  testWidgets('a card the item does not have is not offered on the strip', (
    tester,
  ) async {
    // The regulator has no dive computer controls, hidden or not.
    await pumpGearPage(
      tester,
      settingsNotifier: settingsWith(
        without(EquipmentDetailSectionId.diveComputer),
      ),
    );
    await unlock(tester);

    expect(
      find.descendant(
        of: find.byType(AddStrip),
        matching: find.text(l.diveComputer_title),
      ),
      findsNothing,
    );
  });
}
