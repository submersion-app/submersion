import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Planner Setup-accordion global defaults (issue #3552): round-trip
/// persistence through DiverSettingsRepository for every new field.
void main() {
  group('DiverSettingsRepository planner defaults persistence (#3552)', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('new settings start with the documented defaults', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.plannerDescentRate, 18.0);
      expect(loaded.plannerSacBottom, 15.0);
      expect(loaded.plannerSacDeco, 15.0);
      expect(loaded.plannerDeviationTimeMinutes, 5);
      expect(loaded.plannerBatteryReserveFraction, closeTo(1 / 3, 0.0001));
    });

    test('changing every field round-trips independently', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          plannerDescentRate: 20.0,
          plannerAscentRate: 10.0,
          plannerIntermediateAscentRate: 7.0,
          plannerShallowAscentRate: 4.0,
          plannerFinalAscentRate: 2.0,
          plannerGasSwitchStopSeconds: 30,
          plannerSacBottom: 18.0,
          plannerSacDeco: 16.0,
          plannerSacStressedFactor: 3.0,
          plannerBuddyFactor: 2.5,
          plannerProblemSolvingMinutes: 3,
          plannerBestMixEndMeters: 33.0,
          plannerDeviationDepthDelta: 6.0,
          plannerDeviationTimeMinutes: 7,
          plannerBatteryReserveFraction: 0.4,
          plannerWalkSpeedMps: 1.0,
          plannerReservePressure: 60.0,
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.plannerDescentRate, 20.0);
      expect(loaded.plannerAscentRate, 10.0);
      expect(loaded.plannerIntermediateAscentRate, 7.0);
      expect(loaded.plannerShallowAscentRate, 4.0);
      expect(loaded.plannerFinalAscentRate, 2.0);
      expect(loaded.plannerGasSwitchStopSeconds, 30);
      expect(loaded.plannerSacBottom, 18.0);
      expect(loaded.plannerSacDeco, 16.0);
      expect(loaded.plannerSacStressedFactor, 3.0);
      expect(loaded.plannerBuddyFactor, 2.5);
      expect(loaded.plannerProblemSolvingMinutes, 3);
      expect(loaded.plannerBestMixEndMeters, 33.0);
      expect(loaded.plannerDeviationDepthDelta, 6.0);
      expect(loaded.plannerDeviationTimeMinutes, 7);
      expect(loaded.plannerBatteryReserveFraction, 0.4);
      expect(loaded.plannerWalkSpeedMps, 1.0);
      expect(loaded.plannerReservePressure, 60.0);
    });

    test('sacDeco and sacBottom persist as independent columns', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(plannerSacBottom: 22.0),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.plannerSacBottom, 22.0);
      expect(
        loaded.plannerSacDeco,
        15.0,
        reason: 'sacDeco must not move when only sacBottom is changed',
      );
    });
  });
}
