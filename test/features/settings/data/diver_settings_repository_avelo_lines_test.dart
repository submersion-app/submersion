import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_database.dart';

/// Issue #4664: the default visibility of the three Avelo profile lines is
/// stored per diver, off by default.
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

  tearDown(tearDownTestDatabase);

  test('new settings hide the three Avelo lines', () async {
    await repository.createSettingsForDiver('d1');
    final loaded = (await repository.getSettingsForDiver('d1'))!;
    expect(loaded.defaultShowAveloBuoyancy, isFalse);
    expect(loaded.defaultShowAveloGasRemaining, isFalse);
    expect(loaded.defaultShowComputerRmv, isFalse);
  });

  test('each default round-trips on its own', () async {
    await repository.createSettingsForDiver('d1');
    for (final settings in const [
      AppSettings(defaultShowAveloBuoyancy: true),
      AppSettings(defaultShowAveloGasRemaining: true),
      AppSettings(defaultShowComputerRmv: true),
    ]) {
      await repository.updateSettingsForDiver('d1', settings);
      final loaded = (await repository.getSettingsForDiver('d1'))!;
      expect(
        loaded.defaultShowAveloBuoyancy,
        settings.defaultShowAveloBuoyancy,
      );
      expect(
        loaded.defaultShowAveloGasRemaining,
        settings.defaultShowAveloGasRemaining,
      );
      expect(loaded.defaultShowComputerRmv, settings.defaultShowComputerRmv);
    }
  });
}
