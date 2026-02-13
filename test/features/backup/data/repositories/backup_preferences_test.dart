import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';

void main() {
  late BackupPreferences backupPreferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    backupPreferences = BackupPreferences(prefs);
  });

  group('BackupPreferences settings', () {
    test('getSettings returns defaults when empty', () {
      final settings = backupPreferences.getSettings();

      expect(settings.enabled, false);
      expect(settings.frequency, BackupFrequency.weekly);
      expect(settings.retentionCount, 10);
      expect(settings.lastBackupTime, isNull);
      expect(settings.cloudBackupEnabled, true);
    });

    test('setEnabled persists value', () async {
      await backupPreferences.setEnabled(true);

      final settings = backupPreferences.getSettings();
      expect(settings.enabled, true);
    });

    test('setFrequency persists value', () async {
      await backupPreferences.setFrequency(BackupFrequency.daily);

      final settings = backupPreferences.getSettings();
      expect(settings.frequency, BackupFrequency.daily);
    });

    test('setFrequency persists monthly', () async {
      await backupPreferences.setFrequency(BackupFrequency.monthly);

      final settings = backupPreferences.getSettings();
      expect(settings.frequency, BackupFrequency.monthly);
    });

    test('setRetentionCount persists value', () async {
      await backupPreferences.setRetentionCount(5);

      final settings = backupPreferences.getSettings();
      expect(settings.retentionCount, 5);
    });

    test('setLastBackupTime persists value', () async {
      final time = DateTime(2025, 6, 15, 10, 30);
      await backupPreferences.setLastBackupTime(time);

      final settings = backupPreferences.getSettings();
      expect(
        settings.lastBackupTime?.millisecondsSinceEpoch,
        time.millisecondsSinceEpoch,
      );
    });

    test('setCloudBackupEnabled persists value', () async {
      await backupPreferences.setCloudBackupEnabled(false);

      final settings = backupPreferences.getSettings();
      expect(settings.cloudBackupEnabled, false);
    });

    test('invalid frequency string falls back to weekly', () async {
      // Directly set an invalid value in SharedPreferences
      SharedPreferences.setMockInitialValues({'backup_frequency': 'invalid'});
      final prefs = await SharedPreferences.getInstance();
      final bp = BackupPreferences(prefs);

      final settings = bp.getSettings();
      expect(settings.frequency, BackupFrequency.weekly);
    });
  });

  group('BackupPreferences history', () {
    BackupRecord createRecord(String id, {int diveCount = 10}) {
      return BackupRecord(
        id: id,
        filename: 'submersion_backup_$id.sqlite',
        timestamp: DateTime(2025, 6, 15),
        sizeBytes: 1000,
        location: BackupLocation.local,
        diveCount: diveCount,
        siteCount: 3,
      );
    }

    test('getHistory returns empty list when no history', () {
      final history = backupPreferences.getHistory();
      expect(history, isEmpty);
    });

    test('addRecord adds to history', () async {
      final record = createRecord('r1');
      await backupPreferences.addRecord(record);

      final history = backupPreferences.getHistory();
      expect(history, hasLength(1));
      expect(history.first.id, 'r1');
    });

    test('addRecord prepends new records', () async {
      await backupPreferences.addRecord(createRecord('r1'));
      await backupPreferences.addRecord(createRecord('r2'));

      final history = backupPreferences.getHistory();
      expect(history, hasLength(2));
      expect(history[0].id, 'r2');
      expect(history[1].id, 'r1');
    });

    test('removeRecord removes by id', () async {
      await backupPreferences.addRecord(createRecord('r1'));
      await backupPreferences.addRecord(createRecord('r2'));
      await backupPreferences.addRecord(createRecord('r3'));

      await backupPreferences.removeRecord('r2');

      final history = backupPreferences.getHistory();
      expect(history, hasLength(2));
      expect(history.map((r) => r.id), containsAll(['r1', 'r3']));
      expect(history.map((r) => r.id), isNot(contains('r2')));
    });

    test('removeRecord with nonexistent id does nothing', () async {
      await backupPreferences.addRecord(createRecord('r1'));

      await backupPreferences.removeRecord('nonexistent');

      final history = backupPreferences.getHistory();
      expect(history, hasLength(1));
    });

    test('updateRecord replaces matching record', () async {
      await backupPreferences.addRecord(createRecord('r1', diveCount: 10));

      final updated = createRecord('r1', diveCount: 99);
      await backupPreferences.updateRecord(updated);

      final history = backupPreferences.getHistory();
      expect(history, hasLength(1));
      expect(history.first.diveCount, 99);
    });

    test('setHistory replaces entire history', () async {
      await backupPreferences.addRecord(createRecord('r1'));
      await backupPreferences.addRecord(createRecord('r2'));

      await backupPreferences.setHistory([createRecord('r3')]);

      final history = backupPreferences.getHistory();
      expect(history, hasLength(1));
      expect(history.first.id, 'r3');
    });
  });
}
