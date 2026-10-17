import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3343: `diver_settings` has no unique index on `diver_id`, and sync
/// merges its rows by id. Two devices that each create a settings row for
/// the same diver before a sync both keep both rows, and every read keyed
/// on the diver alone then threw "Bad state: Too many elements".
void main() {
  late AppDatabase db;
  late DiverSettingsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverSettingsRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Test Diver',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    // The row this device made, then a peer's row for the same diver,
    // edited later and so the one the diver last saw.
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'settings-mac',
            diverId: 'd1',
            depthUnit: const Value('meters'),
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'settings-iphone',
            diverId: 'd1',
            depthUnit: const Value('feet'),
            createdAt: 1500,
            updatedAt: 2000,
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<List<DiverSetting>> rows() =>
      (db.select(db.diverSettings)..where((t) => t.diverId.equals('d1'))).get();

  group('reads keyed on the diver tolerate a duplicate row', () {
    test('getSettingsForDiver reads the most recently updated row', () async {
      final settings = await repository.getSettingsForDiver('d1');

      expect(settings?.depthUnit, DepthUnit.feet);
    });

    test('the later sync clock wins over a later updatedAt', () async {
      // The mac row's clock is newer though its updatedAt is older: the HLC
      // decides, as it does in the sync merge.
      await (db.update(
        db.diverSettings,
      )..where((t) => t.id.equals('settings-mac'))).write(
        const DiverSettingsCompanion(hlc: Value('000000000002000:000000:mac')),
      );
      await (db.update(
        db.diverSettings,
      )..where((t) => t.id.equals('settings-iphone'))).write(
        const DiverSettingsCompanion(
          hlc: Value('000000000001000:000000:iphone'),
        ),
      );

      final settings = await repository.getSettingsForDiver('d1');

      expect(settings?.depthUnit, DepthUnit.meters);
    });

    test('hasSeascapeAppearance reads the most recently updated row', () async {
      await (db.update(db.diverSettings)
            ..where((t) => t.id.equals('settings-iphone')))
          .write(const DiverSettingsCompanion(seascapeAppearance: Value('{}')));

      expect(await repository.hasSeascapeAppearance('d1'), isTrue);
    });

    test('unsetAdoptableColumns does not throw', () async {
      final unset = await repository.unsetAdoptableColumns('d1');

      expect(unset.pscrRatio, isTrue);
    });

    test('updateSettingsForDiver collapses the twins before it writes, so '
        'the write lands on one row', () async {
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(depthUnit: DepthUnit.meters),
      );

      expect((await rows()).map((r) => r.id), ['settings-iphone']);
    });

    test(
      'adoptDeviceLocalValues collapses the twins before it writes',
      () async {
        await repository.adoptDeviceLocalValues('d1', pscrRatio: 80.0);

        expect((await rows()).map((r) => r.id), ['settings-iphone']);
      },
    );

    test('updateSettingsForDiver saves without throwing', () async {
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(depthUnit: DepthUnit.meters),
      );

      final settings = await repository.getSettingsForDiver('d1');
      expect(settings?.depthUnit, DepthUnit.meters);
    });
  });

  group('getOrCreateSettingsForDiver', () {
    test('keeps the most recently updated row and drops the other', () async {
      final settings = await repository.getOrCreateSettingsForDiver('d1');

      expect(settings.depthUnit, DepthUnit.feet);
      expect((await rows()).map((r) => r.id), ['settings-iphone']);
    });

    test('tombstones the dropped row so peers drop it too', () async {
      await repository.getOrCreateSettingsForDiver('d1');

      final deletions = await SyncRepository().getAllDeletions();
      expect(
        deletions
            .where((d) => d.entityType == 'diverSettings')
            .map((d) => d.recordId),
        ['settings-mac'],
      );
    });

    test('breaks an updatedAt tie on id, so every device keeps the same '
        'row', () async {
      await (db.update(db.diverSettings)
            ..where((t) => t.id.equals('settings-mac')))
          .write(const DiverSettingsCompanion(updatedAt: Value(2000)));

      await repository.getOrCreateSettingsForDiver('d1');

      expect((await rows()).map((r) => r.id), ['settings-iphone']);
    });

    test('a failed collapse is logged, not thrown, and the newest row is '
        'still read', () async {
      await db.customStatement('''
        CREATE TRIGGER block_settings_delete BEFORE DELETE ON diver_settings
        BEGIN SELECT RAISE(ABORT, 'blocked'); END
      ''');

      final settings = await repository.getOrCreateSettingsForDiver('d1');

      expect(settings.depthUnit, DepthUnit.feet);
      expect(await rows(), hasLength(2));
    });

    test('leaves a single row alone', () async {
      await (db.delete(
        db.diverSettings,
      )..where((t) => t.id.equals('settings-mac'))).go();

      await repository.getOrCreateSettingsForDiver('d1');

      expect((await rows()).map((r) => r.id), ['settings-iphone']);
      final deletions = await SyncRepository().getAllDeletions();
      expect(deletions.where((d) => d.entityType == 'diverSettings'), isEmpty);
    });
  });
}
