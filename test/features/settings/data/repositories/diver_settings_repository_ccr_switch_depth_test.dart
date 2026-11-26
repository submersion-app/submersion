import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('the CCR switch depth is 10 m by default and copyWith carries it', () {
    const settings = AppSettings();
    expect(settings.ccrSetpointSwitchDepth, 10.0);
    expect(
      settings.copyWith(ccrSetpointSwitchDepth: 6.5).ccrSetpointSwitchDepth,
      6.5,
    );
    expect(settings.copyWith(ccrSetpointLow: 0.8).ccrSetpointSwitchDepth, 10.0);
  });

  group('DiverSettingsRepository CCR switch depth persistence', () {
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

    test('new settings start at 10 m', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.ccrSetpointSwitchDepth, 10.0);
    });

    test('a changed switch depth round-trips', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(ccrSetpointSwitchDepth: 22.5),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.ccrSetpointSwitchDepth, 22.5);
    });
  });
}
