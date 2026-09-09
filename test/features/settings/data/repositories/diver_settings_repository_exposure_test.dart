import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
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
  tearDown(() => DatabaseService.instance.resetForTesting());

  test('defaults are 10 C, 30 m and 40 percent', () async {
    await repository.createSettingsForDiver('d1');
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.coldWaterThresholdC, 10.0);
    expect(loaded.deepDiveThresholdM, 30.0);
    expect(loaded.highO2ThresholdPercent, 40.0);
  });

  test('thresholds round-trip through update', () async {
    await repository.createSettingsForDiver('d1');
    await repository.updateSettingsForDiver(
      'd1',
      const AppSettings(
        coldWaterThresholdC: 12.5,
        deepDiveThresholdM: 40,
        highO2ThresholdPercent: 32,
      ),
    );
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.coldWaterThresholdC, 12.5);
    expect(loaded.deepDiveThresholdM, 40.0);
    expect(loaded.highO2ThresholdPercent, 32.0);
  });
}
