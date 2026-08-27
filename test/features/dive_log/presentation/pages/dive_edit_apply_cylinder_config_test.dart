import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/apply_configuration_menu.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Applying a saved configuration is the payoff of the whole feature: it is
/// what spares a CCR diver from re-entering diluent and bailout every dive.
///
/// The merge deliberately targets the page's in-memory cylinder list, not
/// dive_tanks -- those cylinders are unsaved form state until Save, so writing
/// through would bypass dirty tracking and persist even a cancelled edit.
void main() {
  final now = DateTime.utc(2026, 8, 5);
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  CylinderConfigItem item(String id, TankRole role, {double o2 = 21}) =>
      CylinderConfigItem(
        id: id,
        configId: 'c1',
        tankRole: role,
        o2Percent: o2,
        createdAt: now,
        updatedAt: now,
      );

  Future<Widget> host({required List<CylinderConfigItem> items}) async {
    final dive = Dive(
      id: 'dive-1',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 28, 10, 0),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 30,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
    );
    await repository.createDive(dive);

    final base = await getBaseOverrides();
    return ProviderScope(
      overrides: [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith(
          (ref) => DiveListNotifier(repository, ref),
        ),
        customTankPresetsProvider.overrideWith((ref) async => []),
        allEquipmentProvider.overrideWith((ref) async => []),
        cylinderConfigsProvider.overrideWith(
          (ref) async => [
            CylinderConfig(
              id: 'c1',
              name: 'JJ trimix',
              items: items,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ].cast(),
      child: const MaterialApp(
        // Pinned: an unpinned locale makes text finders machine-dependent.
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DiveEditPage(diveId: 'dive-1', embedded: true)),
      ),
    );
  }

  /// Gas & Gear collapses by default when editing an existing dive, and the
  /// menu lives inside it.
  Future<void> openGasGear(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Gas & Gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gas & Gear'));
    await tester.pumpAndSettle();
  }

  Future<void> applyConfig(WidgetTester tester) async {
    // ensureVisible beats scrollUntilVisible here: the page has several
    // Scrollables and the default scrollable finder is ambiguous.
    final menu = find.byType(ApplyConfigurationMenu);
    expect(menu, findsOneWidget);
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('JJ trimix').last);
    await tester.pumpAndSettle();
  }

  testWidgets('applying a configuration adds its cylinders to the dive', (
    tester,
  ) async {
    await tester.pumpWidget(
      await host(
        items: [
          item('i1', TankRole.diluent),
          item('i2', TankRole.bailout, o2: 50),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await openGasGear(tester);
    await applyConfig(tester);

    expect(find.textContaining('Added 2 cylinders'), findsOneWidget);
    expect(find.textContaining('kept 0'), findsOneWidget);
  });

  testWidgets('applying the same configuration twice reports nothing to do', (
    tester,
  ) async {
    // The second apply matches every role and so reports a non-zero kept while
    // doing no work. Rebuilding then would mark the form dirty and raise an
    // unsaved-changes prompt for a merge that altered nothing.
    await tester.pumpWidget(await host(items: [item('i1', TankRole.diluent)]));
    await tester.pumpAndSettle();

    await openGasGear(tester);
    await applyConfig(tester);
    expect(find.textContaining('Added 1 cylinder'), findsOneWidget);

    // Let the first snackbar retire: ScaffoldMessenger queues, so a second
    // one raised while the first is still up would not be on screen to find.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await applyConfig(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('This dive already matches the configuration'),
      findsOneWidget,
    );
  });
}
