import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Deleting a computer's item deletes the computer (issue #3676), and with it
/// the computer's installation-local clock sync choice (issue #1216).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'gear',
            diverId: const Value('d1'),
            name: 'Teric',
            type: 'computer',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'c1',
            diverId: const Value('d1'),
            name: 'Teric',
            equipmentId: const Value('gear'),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test(
    'deleting a computer item forgets its clock sync choice (review)',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(clockSyncSettingsNotifierProvider.notifier)
          .setOverride('c1', ClockSyncOverride.always);

      final deleted = await container
          .read(equipmentListNotifierProvider.notifier)
          .deleteEquipment('gear');

      expect(deleted, isTrue);
      expect(
        container.read(clockSyncSettingsNotifierProvider).overrideFor('c1'),
        ClockSyncOverride.inherit,
      );
    },
  );
}
