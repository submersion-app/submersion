import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// Sensor summaries are device-local, so dives a sync pulls in have none
/// until the stale sweep builds them. A first sync can land after the
/// launch sweep has run; the sync itself must ask for another.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SensorSummaryScheduler.instance.staleSweepRequestListener = null;
    return DatabaseService.instance.resetForTesting();
  });

  test('a successful sync queues the summary stale sweep', () async {
    var sweeps = 0;
    SensorSummaryScheduler.instance.staleSweepRequestListener = () => sweeps++;
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(
          FakeCloudStorageProvider(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(syncStateProvider.notifier);
    await notifier.refreshState();

    await notifier.performSync();

    // The success path ran (the notifier settles back to idle after).
    expect(container.read(syncStateProvider).lastSync, isNotNull);
    expect(sweeps, 1);
  });
}
