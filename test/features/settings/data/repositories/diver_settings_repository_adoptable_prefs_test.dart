import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/test_database.dart';

/// v262 (issue #2948): pSCR ratio and "metrics follow viewport" moved from
/// device-local prefs into nullable diver_settings columns.
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

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<DiverSetting> row() => (db.select(
    db.diverSettings,
  )..where((t) => t.diverId.equals('d1'))).getSingle();

  test('a new row leaves both columns unset and reads the defaults', () async {
    final created = await repository.createSettingsForDiver('d1');
    expect(created.pscrRatio, 100.0);
    expect(created.profileMetricsFollowViewport, isFalse);
    expect((await row()).pscrRatio, isNull);
    expect((await row()).profileMetricsFollowViewport, isNull);
    final unset = await repository.unsetAdoptableColumns('d1');
    expect(unset.pscrRatio, isTrue);
    expect(unset.profileMetricsFollowViewport, isTrue);
  });

  test('a missing row counts as unset', () async {
    final unset = await repository.unsetAdoptableColumns('d1');
    expect(unset.pscrRatio, isTrue);
    expect(unset.profileMetricsFollowViewport, isTrue);
  });

  test('adopting writes values equal to the defaults too', () async {
    await repository.createSettingsForDiver('d1');
    final adopted = await repository.adoptDeviceLocalValues(
      'd1',
      pscrRatio: 100.0,
      profileMetricsFollowViewport: false,
    );
    expect(adopted, isTrue);
    expect((await row()).pscrRatio, 100.0);
    expect((await row()).profileMetricsFollowViewport, isFalse);
    final unset = await repository.unsetAdoptableColumns('d1');
    expect(unset.pscrRatio, isFalse);
    expect(unset.profileMetricsFollowViewport, isFalse);
  });

  test('adopting one value leaves the other unset', () async {
    await repository.createSettingsForDiver('d1');
    await repository.adoptDeviceLocalValues('d1', pscrRatio: 40.0);
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.pscrRatio, 40.0);
    expect((await row()).profileMetricsFollowViewport, isNull);
  });

  test('adopting never overwrites a value the row already holds', () async {
    // A sync can land between the load's probe and its adoption write; the
    // synced value must win over this device's pref.
    await repository.createSettingsForDiver('d1');
    await db.customStatement(
      'UPDATE diver_settings SET pscr_ratio = 15.0, '
      'profile_metrics_follow_viewport = 0',
    );
    final before = (await row()).updatedAt;

    final adopted = await repository.adoptDeviceLocalValues(
      'd1',
      pscrRatio: 40.0,
      profileMetricsFollowViewport: true,
    );

    expect(adopted, isFalse);
    expect((await row()).pscrRatio, 15.0);
    expect((await row()).profileMetricsFollowViewport, isFalse);
    expect((await row()).updatedAt, before);
  });

  test('adopting queues the row for sync', () async {
    await repository.createSettingsForDiver('d1');
    final before = (await row()).updatedAt;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repository.adoptDeviceLocalValues('d1', pscrRatio: 40.0);
    expect((await row()).updatedAt, greaterThan(before));
  });

  test('a changed value round-trips through a partial write', () async {
    final created = await repository.createSettingsForDiver('d1');
    await repository.updateSettingsForDiver(
      'd1',
      created.copyWith(pscrRatio: 25.0, profileMetricsFollowViewport: true),
      previous: created,
    );
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.pscrRatio, 25.0);
    expect(loaded.profileMetricsFollowViewport, isTrue);
  });
}
