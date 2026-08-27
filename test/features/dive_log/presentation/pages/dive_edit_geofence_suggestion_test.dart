import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Covers the site-change geofence suggestion seam on an existing dive that
/// already has gear: selecting a site inside a geofence surfaces a dismissible
/// banner (never auto-overwriting), and Apply merges the suggested items.
void main() {
  late DiveRepository repository;

  const monterey = GeoPoint(36.62, -121.90);
  const mask = EquipmentItem(
    id: 'mask',
    name: 'Mask',
    type: EquipmentType.mask,
  );
  const regulator = EquipmentItem(
    id: 'reg',
    name: 'Apeks XTX50',
    type: EquipmentType.regulator,
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Widget> buildEditor() async {
    await EquipmentRepository().createEquipment(mask);
    await EquipmentRepository().createEquipment(regulator);
    final dive = await repository.createDive(
      Dive(
        id: 'dive-1',
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        notes: '',
        equipment: const [mask],
      ),
    );

    final coldSet = EquipmentSet(
      id: 'cold',
      diverId: 'diver-1',
      name: 'Cold Water',
      equipmentIds: const ['reg'],
      items: const [regulator],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final fence = EquipmentSetGeofence(
      id: 'g1',
      setId: 'cold',
      latitude: monterey.latitude,
      longitude: monterey.longitude,
      radiusMeters: 25000,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final base = await getBaseOverrides();
    return ProviderScope(
      overrides: [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith(
          (ref) => DiveListNotifier(repository, ref),
        ),
        customTankPresetsProvider.overrideWith((ref) async => []),
        sitesProvider.overrideWith(
          (ref) async => const [
            DiveSite(id: 'site-1', name: 'Breakwater', location: monterey),
          ],
        ),
        equipmentSetSelectionInputsProvider.overrideWith(
          (ref) async =>
              EquipmentSetSelectionInputs(sets: [coldSet], geofences: [fence]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DiveEditPage(diveId: dive.id, embedded: true)),
      ),
    );
  }

  // The equipment section (and its suggestion banner) lives inside the
  // Gas & Gear group, which starts collapsed when editing an existing dive.
  Future<void> expandGasGear(WidgetTester tester) async {
    // The FormSection toggles on its collapsed summary row (tapping the
    // uppercased label alone does not fire onToggle).
    final summary = find.textContaining('1 item');
    await tester.ensureVisible(summary.first);
    await tester.pumpAndSettle();
    await tester.tap(summary.first);
    await tester.pumpAndSettle();
  }

  Future<void> selectBreakwater(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Add site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breakwater').last);
    await tester.pumpAndSettle();
  }

  testWidgets('selecting a geofenced site suggests the set; Apply merges it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildEditor());
    await tester.pumpAndSettle();

    await expandGasGear(tester);
    await selectBreakwater(tester);

    // The suggestion banner (never an overwrite) offers to apply the set.
    expect(find.text('Apply'), findsOneWidget);

    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // Banner dismissed after applying, and the suggested regulator was merged
    // alongside the pre-existing mask.
    expect(find.text('Apply'), findsNothing);
    expect(find.text('Apeks XTX50'), findsWidgets);
  });

  testWidgets('dismissing the suggestion hides it and does not re-nag', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildEditor());
    await tester.pumpAndSettle();

    await expandGasGear(tester);
    await selectBreakwater(tester);
    expect(find.text('Apply'), findsOneWidget);

    await tester.ensureVisible(find.text('Dismiss'));
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Apply'), findsNothing);

    // Re-selecting the same (now dismissed) site must not resurface the banner.
    // The site is already chosen, so reopen the picker via its selected row.
    await tester.tap(find.text('Breakwater').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breakwater').last);
    await tester.pumpAndSettle();
    expect(find.text('Apply'), findsNothing);
  });
}
