import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('both view modes default to detailed and copyWith carries them', () {
    const settings = AppSettings();
    expect(settings.certificationListViewMode, ListViewMode.detailed);
    expect(settings.courseListViewMode, ListViewMode.detailed);
    final changed = settings.copyWith(
      certificationListViewMode: ListViewMode.table,
      courseListViewMode: ListViewMode.table,
    );
    expect(changed.certificationListViewMode, ListViewMode.table);
    expect(changed.courseListViewMode, ListViewMode.table);
  });

  group('DiverSettingsRepository certification/course view modes', () {
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

    test('new settings start detailed', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.certificationListViewMode, ListViewMode.detailed);
      expect(loaded.courseListViewMode, ListViewMode.detailed);
    });

    test('table round-trips through a partial write', () async {
      final created = await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        created.copyWith(
          certificationListViewMode: ListViewMode.table,
          courseListViewMode: ListViewMode.table,
        ),
        previous: created,
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.certificationListViewMode, ListViewMode.table);
      expect(loaded.courseListViewMode, ListViewMode.table);
    });
  });
}
