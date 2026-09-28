import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('the dive figure is off by default and copyWith carries it', () {
    const settings = AppSettings();
    expect(settings.showDiveFigure, isFalse);
    expect(settings.copyWith(showDiveFigure: true).showDiveFigure, isTrue);
  });

  group('DiverSettingsRepository dive figure persistence', () {
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

    test('new settings start with the dive figure off', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.showDiveFigure, isFalse);
    });

    test('turning it on round-trips', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(showDiveFigure: true),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.showDiveFigure, isTrue);
    });
  });
}
