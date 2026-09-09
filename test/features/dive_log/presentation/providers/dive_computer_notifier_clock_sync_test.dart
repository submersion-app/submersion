import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertComputer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Computer $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  test('delete forgets the clock sync keys for that computer only', () async {
    await insertComputer('computer-1');
    await insertComputer('computer-2');
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final clockSync = container.read(
      clockSyncSettingsNotifierProvider.notifier,
    );
    await clockSync.setOverride('computer-1', ClockSyncOverride.always);
    await clockSync.recordSupport('computer-1', ClockSyncStatus.synced);
    await clockSync.setOverride('computer-2', ClockSyncOverride.never);

    await container
        .read(diveComputerNotifierProvider.notifier)
        .delete('computer-1');

    final settings = container.read(clockSyncSettingsNotifierProvider);
    expect(settings.overrideFor('computer-1'), ClockSyncOverride.inherit);
    expect(settings.supportFor('computer-1'), ClockSyncSupport.unknown);
    expect(settings.overrideFor('computer-2'), ClockSyncOverride.never);
  });
}
