import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiverSettingsRepository deco stop persistence', () {
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

    test('new settings default to visible and calculated', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded, isNotNull);
      expect(loaded!.showDecoStopsOnProfile, isTrue);
      expect(loaded.defaultDecoStopSource, MetricDataSource.calculated);
    });

    test('round-trips deco stop settings through update without disturbing '
        'the ceiling settings', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          showDecoStopsOnProfile: false,
          defaultDecoStopSource: MetricDataSource.computer,
          showCeilingOnProfile: true,
          defaultCeilingSource: MetricDataSource.calculated,
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded, isNotNull);
      expect(loaded!.showDecoStopsOnProfile, isFalse);
      expect(loaded.defaultDecoStopSource, MetricDataSource.computer);
      // The ceiling settings must survive unchanged: this catches a
      // copy-paste error where the deco stop fields were accidentally
      // wired to the ceiling column (or vice versa).
      expect(loaded.showCeilingOnProfile, isTrue);
      expect(loaded.defaultCeilingSource, MetricDataSource.calculated);
    });

    test(
      'round-trips the ceiling settings independently of deco stop settings',
      () async {
        await repository.createSettingsForDiver('d1');
        await repository.updateSettingsForDiver(
          'd1',
          const AppSettings(
            showCeilingOnProfile: false,
            defaultCeilingSource: MetricDataSource.computer,
            showDecoStopsOnProfile: true,
            defaultDecoStopSource: MetricDataSource.calculated,
          ),
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded, isNotNull);
        expect(loaded!.showCeilingOnProfile, isFalse);
        expect(loaded.defaultCeilingSource, MetricDataSource.computer);
        expect(loaded.showDecoStopsOnProfile, isTrue);
        expect(loaded.defaultDecoStopSource, MetricDataSource.calculated);
      },
    );
  });
}
