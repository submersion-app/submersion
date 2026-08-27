import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Widget-level regression for issue #276:
/// "SAC rate disappears after edit dive (setting dive location, trip, operator)"
///
/// Reproduces the real edit flow: open the edit page for an air-integrated dive
/// that has a per-tank pressure time-series (the SAC source), save, and confirm
/// the pressure data is still keyed to a tank that the dive actually has. If the
/// edit re-keys/replaces the tank, the SAC join breaks even though the rows
/// remain in the table.
void main() {
  late DiveRepository repository;
  late TankPressureRepository tankPressures;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    tankPressures = TankPressureRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    void Function(String)? onSaved,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saving an edited dive keeps tank pressure keyed to a real tank', (
    tester,
  ) async {
    // Air-integrated dive: a single tank with no configured volume (a Perdix
    // logs pressure but not cylinder size) plus a pressure time-series.
    const tank = DiveTank(
      id: 'tank-orig',
      startPressure: 230.0,
      endPressure: 70.0,
      gasMix: GasMix(o2: 32),
    );
    final dive = await repository.createDive(
      Dive(
        id: 'dive-276',
        dateTime: DateTime.utc(2026, 5, 1, 10),
        maxDepth: 30.0,
        tanks: const [tank],
      ),
    );
    await tankPressures.insertTankPressures('dive-276', {
      'tank-orig': const [
        (timestamp: 0, pressure: 230.0),
        (timestamp: 60, pressure: 205.0),
        (timestamp: 120, pressure: 180.0),
      ],
    });

    String? savedId;
    await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);

    // Tap Save (loading a dive with tanks marks the form dirty, so it is enabled).
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedId, isNotNull, reason: 'save should complete');

    // The pressure rows must still be keyed to a tank the dive actually has,
    // otherwise the SAC computation silently drops them.
    final reloaded = (await repository.getDiveById(dive.id))!;
    final currentTankIds = reloaded.tanks.map((t) => t.id).toSet();
    final pressureByTank = await tankPressures.getTankPressuresForDive(dive.id);

    expect(
      pressureByTank.keys,
      isNotEmpty,
      reason: 'pressure rows should still exist after edit',
    );
    for (final pressureTankId in pressureByTank.keys) {
      expect(
        currentTankIds,
        contains(pressureTankId),
        reason:
            'pressure tank_id $pressureTankId must match a current tank '
            '($currentTankIds) so SAC can still be computed',
      );
    }
  });
}
