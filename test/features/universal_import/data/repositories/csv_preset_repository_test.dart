import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/repositories/csv_preset_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late CsvPresetRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = CsvPresetRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  CsvPreset makePreset(String id) =>
      CsvPreset(id: id, name: 'Preset $id', source: PresetSource.userSaved);

  group('CsvPresetRepository', () {
    test('savePreset then getAllPresets round-trips saved presets', () async {
      await repository.savePreset(makePreset('p1'));
      await repository.savePreset(makePreset('p2'));

      final all = await repository.getAllPresets();
      expect(all.map((p) => p.id), containsAll(<String>['p1', 'p2']));
    });

    test('savePreset upserts when the id already exists', () async {
      await repository.savePreset(makePreset('p1'));
      await repository.savePreset(
        const CsvPreset(
          id: 'p1',
          name: 'Renamed',
          source: PresetSource.userSaved,
        ),
      );

      final all = await repository.getAllPresets();
      expect(all.where((p) => p.id == 'p1'), hasLength(1));
      expect(all.firstWhere((p) => p.id == 'p1').name, 'Renamed');
    });

    test('deletePreset removes the row', () async {
      await repository.savePreset(makePreset('p1'));
      await repository.deletePreset('p1');
      expect(await repository.getAllPresets(), isEmpty);
    });

    // Regression for the missing on-change auto-sync trigger: marking a record
    // pending only stages it; the bus is what schedules the actual sync.
    test('savePreset notifies the sync change bus', () async {
      var fired = false;
      final sub = SyncEventBus.changes.listen((_) => fired = true);
      addTearDown(sub.cancel);

      await repository.savePreset(makePreset('p1'));
      await pumpEventQueue();

      expect(
        fired,
        isTrue,
        reason: 'on-change auto-sync depends on the bus firing',
      );
    });

    test('deletePreset notifies the sync change bus', () async {
      await repository.savePreset(makePreset('p1'));

      var fired = false;
      final sub = SyncEventBus.changes.listen((_) => fired = true);
      addTearDown(sub.cancel);

      await repository.deletePreset('p1');
      await pumpEventQueue();

      expect(fired, isTrue);
    });
  });
}
