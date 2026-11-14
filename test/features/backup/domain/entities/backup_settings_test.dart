import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';

void main() {
  group('BackupSettings', () {
    test('defaults backupLocation to null', () {
      const settings = BackupSettings();
      expect(settings.backupLocation, isNull);
    });

    test('copyWith preserves backupLocation', () {
      const settings = BackupSettings(backupLocation: '/custom/path');
      final copied = settings.copyWith(enabled: true);
      expect(copied.backupLocation, '/custom/path');
    });

    test('copyWith overrides backupLocation', () {
      const settings = BackupSettings(backupLocation: '/old/path');
      final copied = settings.copyWith(backupLocation: '/new/path');
      expect(copied.backupLocation, '/new/path');
    });

    group('keepsAll (issue #4535)', () {
      test('is false for any count a diver can type', () {
        expect(const BackupSettings(retentionCount: 10).keepsAll, isFalse);
        expect(
          const BackupSettings(
            retentionCount: BackupSettings.maxCustomRetentionCount,
          ).keepsAll,
          isFalse,
        );
      });

      test('is true for the sentinel and anything above the maximum', () {
        expect(
          const BackupSettings(
            retentionCount: BackupSettings.keepAllRetentionCount,
          ).keepsAll,
          isTrue,
        );
        expect(
          const BackupSettings(
            retentionCount: BackupSettings.maxCustomRetentionCount + 1,
          ).keepsAll,
          isTrue,
        );
      });

      test('the sentinel is a huge positive count, never 0', () {
        // An older build reads it as a count: it must keep everything.
        expect(BackupSettings.keepAllRetentionCount, 1 << 30);
        expect(BackupSettings.maxCustomRetentionCount, 9999);
      });
    });

    test('includes backupLocation in Equatable props', () {
      const a = BackupSettings(backupLocation: '/path/a');
      const b = BackupSettings(backupLocation: '/path/b');
      const c = BackupSettings(backupLocation: '/path/a');
      expect(a, isNot(equals(b)));
      expect(a, equals(c));
    });
  });
}
