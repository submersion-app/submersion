import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Drives the real [SettingsNotifier]: since v262 the certification and
/// course list view modes are saved on the diver's settings row (issue
/// #2948), so they survive a restart and sync.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'd1'});
    final prefs = await SharedPreferences.getInstance();
    final db = await setUpTestDatabase();
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
    await DiverSettingsRepository().createSettingsForDiver('d1');
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await container.read(settingsProvider.notifier).settingsLoaded;
  });

  tearDown(() {
    container.dispose();
    DatabaseService.instance.resetForTesting();
  });

  test('the certification list view mode saves to the diver row', () async {
    await container
        .read(settingsProvider.notifier)
        .setCertificationListViewMode(ListViewMode.table);

    expect(
      container.read(settingsProvider).certificationListViewMode,
      ListViewMode.table,
    );
    final stored = await DiverSettingsRepository().getSettingsForDiver('d1');
    expect(stored!.certificationListViewMode, ListViewMode.table);
    expect(stored.courseListViewMode, ListViewMode.detailed);
  });

  test('the course list view mode saves to the diver row', () async {
    await container
        .read(settingsProvider.notifier)
        .setCourseListViewMode(ListViewMode.table);

    expect(
      container.read(settingsProvider).courseListViewMode,
      ListViewMode.table,
    );
    final stored = await DiverSettingsRepository().getSettingsForDiver('d1');
    expect(stored!.courseListViewMode, ListViewMode.table);
    expect(stored.certificationListViewMode, ListViewMode.detailed);
  });
}
