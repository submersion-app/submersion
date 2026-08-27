import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Covers the new-dive auto-apply seam: when a diver has a default equipment
/// set and the form opens empty, its items are silently pre-selected
/// (`_applyEquipmentDefaultsOnEmpty`).
void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });
  tearDown(tearDownTestDatabase);

  testWidgets('a new dive auto-applies the default set on an empty form', (
    tester,
  ) async {
    const regulator = EquipmentItem(
      id: 'eq-1',
      name: 'Apeks XTX50',
      type: EquipmentType.regulator,
    );
    final defaultSet = EquipmentSet(
      id: 'set-1',
      diverId: 'diver-1',
      name: 'Tropical',
      equipmentIds: const ['eq-1'],
      items: const [regulator],
      isDefault: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final repository = DiveRepository();
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
          equipmentSetSelectionInputsProvider.overrideWith(
            (ref) async => EquipmentSetSelectionInputs(
              sets: [defaultSet],
              geofences: const [],
            ),
          ),
        ].cast(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(embedded: true)),
        ),
      ),
    );
    // The page runs continuous animations, so pumpAndSettle never returns;
    // pump a bounded number of frames to let the post-frame auto-apply and its
    // awaited provider resolve.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The default set's item is now selected. The v2 header is a toggle, so
    // only tap it when the section is actually collapsed (its body absent).
    if (find.text('Apeks XTX50').evaluate().isEmpty) {
      final gasGear = find.textContaining('Gas & Gear');
      await tester.ensureVisible(gasGear.first);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(gasGear.first, warnIfMissed: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    expect(find.text('Apeks XTX50'), findsWidgets);
  });
}
