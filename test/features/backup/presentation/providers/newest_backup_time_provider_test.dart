import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/newest_backup_time_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

BackupRecord _record(
  String id,
  DateTime at, {
  BackupType type = BackupType.manual,
}) => BackupRecord(
  id: id,
  filename: '$id.db',
  timestamp: at,
  sizeBytes: 1,
  location: BackupLocation.local,
  isAutomatic: type != BackupType.manual,
  type: type,
);

void main() {
  final regular = DateTime(2026, 10, 20, 9);
  final upgrade = DateTime(2026, 11, 3, 8);

  group('newestBackupTime', () {
    test('is the last backup time when no upgrade copy is newer', () {
      expect(
        newestBackupTime(
          lastBackupTime: upgrade,
          history: [_record('m', regular, type: BackupType.preMigration)],
        ),
        upgrade,
      );
    });

    // Issue #4204: the copy taken before an upgrade is in history but never
    // set the last backup time, so the home chip read the older backup.
    test('is a newer pre-upgrade copy', () {
      expect(
        newestBackupTime(
          lastBackupTime: regular,
          history: [
            _record('a', regular),
            _record('m', upgrade, type: BackupType.preMigration),
          ],
        ),
        upgrade,
      );
    });

    test('is the pre-upgrade copy when no regular backup was ever made', () {
      expect(
        newestBackupTime(
          lastBackupTime: null,
          history: [_record('m', upgrade, type: BackupType.preMigration)],
        ),
        upgrade,
      );
    });

    // A pre-downgrade copy holds a newer schema than this build can open, so
    // it is no backup the diver could restore here.
    test('ignores a pre-downgrade copy', () {
      expect(
        newestBackupTime(
          lastBackupTime: regular,
          history: [_record('d', upgrade, type: BackupType.preDowngrade)],
        ),
        regular,
      );
    });

    // Regular backups set the last backup time themselves when they are made,
    // and that time stays the authority for them.
    test('ignores regular history records', () {
      expect(
        newestBackupTime(
          lastBackupTime: regular,
          history: [_record('a', upgrade)],
        ),
        regular,
      );
    });

    test('is null with no backups at all', () {
      expect(newestBackupTime(lastBackupTime: null, history: const []), isNull);
    });
  });

  group('newestBackupTimeProvider', () {
    test('reads the pre-upgrade copy from the stored history', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await BackupPreferences(
        prefs,
      ).addRecord(_record('m', upgrade, type: BackupType.preMigration));

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          lastBackupTimeProvider.overrideWithValue(regular),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(newestBackupTimeProvider), upgrade);
    });
  });
}
