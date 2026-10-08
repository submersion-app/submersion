import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The muted Insights observation rules (#2381) persist per diver, keep
/// rule ids this build does not know, and store null for none.
void main() {
  test('defaults to none muted and copyWith carries the set', () {
    const settings = AppSettings();
    expect(settings.insightsMutedObservationRules, isEmpty);
    final updated = settings.copyWith(
      insightsMutedObservationRules: const {'diveGap'},
    );
    expect(updated.insightsMutedObservationRules, {'diveGap'});
    expect(updated.depthUnit, settings.depthUnit);
  });

  group('DiverSettingsRepository muted observation rules', () {
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

    Future<String?> storedRaw() async {
      final row = await db
          .customSelect(
            'SELECT insights_muted_observation_rules AS m FROM diver_settings '
            "WHERE diver_id = 'd1'",
          )
          .getSingle();
      return row.readNullable<String>('m');
    }

    test('new settings store null and read none muted', () async {
      await repository.createSettingsForDiver('d1');
      expect(await storedRaw(), isNull);
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.insightsMutedObservationRules, isEmpty);
    });

    test('round-trips known and unknown rule ids', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          insightsMutedObservationRules: {'rmvTrend', 'fromANewerBuild'},
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.insightsMutedObservationRules, {
        'rmvTrend',
        'fromANewerBuild',
      });
    });

    test('a raw stored list decodes', () async {
      await repository.createSettingsForDiver('d1');
      await db.customUpdate(
        'UPDATE diver_settings SET insights_muted_observation_rules = ? '
        "WHERE diver_id = 'd1'",
        variables: [const Variable<String>('["diveGap"]')],
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.insightsMutedObservationRules, {'diveGap'});
    });
  });
}
