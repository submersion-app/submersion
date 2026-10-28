import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Each list's saved arrangement (issue #3748) must survive a real write and
/// read through SQLite, or the list would come back as left only until the
/// next launch.
void main() {
  group('DiverSettingsRepository listArrangements persistence', () {
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

    const saved = ListArrangements(
      diveSort: 'maxDepth:ascending',
      divePlanSort: 'name:ascending',
      tripSort: 'name:descending',
      courseSort: 'name:ascending',
      buddySort: 'diveCount:descending',
      diveCenterSort: 'name:ascending',
      siteSort: 'rating:descending',
      certificationSort: 'name:ascending',
      equipmentSort: 'type:ascending',
      siteGroupBy: 'country',
      certificationGroupBy: 'agency',
      equipmentArrangement: '{"typeOrder":"headToToe"}',
      equipmentGroupByLocation: true,
    );

    test('new settings hold no saved arrangement', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.listArrangements, ListArrangements.none);
    });

    test('listArrangements round-trips through a save and a read', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(listArrangements: saved),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.listArrangements, saved);
    });

    test('create persists the arrangement it is given', () async {
      await repository.createSettingsForDiver(
        'd1',
        settings: const AppSettings(listArrangements: saved),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.listArrangements, saved);
    });

    test('unknown value round-trips', () async {
      // A value a newer build wrote: this build cannot decode it, and an
      // unrelated save must not erase it.
      const fromNewer = ListArrangements(diveSort: 'bogus:ascending');
      await repository.createSettingsForDiver(
        'd1',
        settings: const AppSettings(listArrangements: fromNewer),
      );
      final before = (await repository.getSettingsForDiver('d1'))!;
      await repository.updateSettingsForDiver(
        'd1',
        before.copyWith(depthUnit: DepthUnit.feet),
        previous: before,
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.depthUnit, DepthUnit.feet);
      expect(loaded.listArrangements.diveSort, 'bogus:ascending');
    });
  });
}
