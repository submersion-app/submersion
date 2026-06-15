import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart'
    as vfc;
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart'
    as domain;
import 'package:submersion/features/universal_import/data/repositories/csv_preset_repository.dart';

import '../../../helpers/test_database.dart';

/// The three config tables (csvPresets, viewConfigs, settings) whose write
/// paths bypass the markRecordPending choke point must still get an HLC
/// stamped on write, so cross-device config edits resolve by HLC like every
/// other conflict-capable entity.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 1000);
  });

  tearDown(() {
    SyncClock.instance.reset();
    DatabaseService.instance.resetForTesting();
  });

  Future<String?> hlcOf(String table, String pkCol, String pk) async {
    final row = await db
        .customSelect(
          'SELECT hlc FROM "$table" WHERE "$pkCol" = ?',
          variables: [Variable.withString(pk)],
        )
        .getSingleOrNull();
    return row?.read<String?>('hlc');
  }

  test('CsvPresetRepository.savePreset stamps an hlc', () async {
    await CsvPresetRepository().savePreset(
      const domain.CsvPreset(id: 'csv-x', name: 'My Preset'),
    );
    expect(await hlcOf('csv_presets', 'id', 'csv-x'), isNotNull);
  });

  test('ViewConfigRepository.saveRawConfig stamps an hlc', () async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver-x',
            name: 'Test',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    final repo = ViewConfigRepository(db);
    await repo.saveRawConfig('diver-x', 'table', '{"k":1}');

    final row = await (db.select(
      db.viewConfigs,
    )..where((t) => t.diverId.equals('diver-x'))).getSingle();
    expect(row.hlc, isNotNull);
  });

  test('ViewConfigRepository.savePreset stamps an hlc', () async {
    // field_presets is an HLC-filtered changeset entity, so a saved preset that
    // never stamps hlc would be silently dropped from every incremental sync
    // after the base watermark is established.
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver-x',
            name: 'Test',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await ViewConfigRepository(db).savePreset(
      'diver-x',
      const vfc.FieldPreset(
        id: 'fp-x',
        name: 'My Preset',
        viewMode: ListViewMode.table,
        configJson: {'k': 1},
      ),
    );
    expect(await hlcOf('field_presets', 'id', 'fp-x'), isNotNull);
  });

  test('AppSettingsRepository.setShareByDefault stamps an hlc', () async {
    await AppSettingsRepository().setShareByDefault(true);
    expect(
      await hlcOf('settings', 'key', 'share_new_records_by_default'),
      isNotNull,
    );
  });
}
