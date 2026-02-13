import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';

void main() {
  group('BackupRecord', () {
    final timestamp = DateTime(2025, 6, 15, 14, 30, 0);

    final record = BackupRecord(
      id: 'test-id-123',
      filename: 'submersion_backup_2025-06-15_143000.sqlite',
      timestamp: timestamp,
      sizeBytes: 2500000,
      location: BackupLocation.both,
      diveCount: 42,
      siteCount: 15,
      cloudFileId: 'cloud-file-abc',
      localPath: '/path/to/backup.sqlite',
      isAutomatic: true,
    );

    group('JSON serialization', () {
      test('toJson produces correct map', () {
        final json = record.toJson();

        expect(json['id'], 'test-id-123');
        expect(json['filename'], 'submersion_backup_2025-06-15_143000.sqlite');
        expect(json['timestamp'], timestamp.millisecondsSinceEpoch);
        expect(json['sizeBytes'], 2500000);
        expect(json['location'], 'both');
        expect(json['diveCount'], 42);
        expect(json['siteCount'], 15);
        expect(json['cloudFileId'], 'cloud-file-abc');
        expect(json['localPath'], '/path/to/backup.sqlite');
        expect(json['isAutomatic'], true);
      });

      test('fromJson round-trips correctly', () {
        final json = record.toJson();
        final restored = BackupRecord.fromJson(json);

        expect(restored, equals(record));
      });

      test('fromJson handles null optional fields', () {
        final json = {
          'id': 'minimal-id',
          'filename': 'backup.sqlite',
          'timestamp': timestamp.millisecondsSinceEpoch,
          'sizeBytes': 1000,
          'location': 'local',
          'diveCount': 5,
          'siteCount': 2,
        };

        final restored = BackupRecord.fromJson(json);

        expect(restored.cloudFileId, isNull);
        expect(restored.localPath, isNull);
        expect(restored.isAutomatic, false);
      });

      test('fromJson handles missing isAutomatic field', () {
        final json = record.toJson();
        json.remove('isAutomatic');

        final restored = BackupRecord.fromJson(json);

        expect(restored.isAutomatic, false);
      });
    });

    group('copyWith', () {
      test('preserves all fields when no arguments given', () {
        final copy = record.copyWith();

        expect(copy, equals(record));
      });

      test('updates specified fields', () {
        final copy = record.copyWith(
          diveCount: 100,
          location: BackupLocation.local,
        );

        expect(copy.diveCount, 100);
        expect(copy.location, BackupLocation.local);
        expect(copy.id, record.id);
        expect(copy.filename, record.filename);
        expect(copy.siteCount, record.siteCount);
      });
    });

    group('formattedSize', () {
      test('formats bytes', () {
        final small = record.copyWith(sizeBytes: 512);
        expect(small.formattedSize, '512 B');
      });

      test('formats kilobytes', () {
        final kb = record.copyWith(sizeBytes: 1536);
        expect(kb.formattedSize, '1.5 KB');
      });

      test('formats megabytes', () {
        expect(record.formattedSize, '2.4 MB');
      });
    });

    group('Equatable', () {
      test('equal records are equal', () {
        final copy = BackupRecord(
          id: record.id,
          filename: record.filename,
          timestamp: record.timestamp,
          sizeBytes: record.sizeBytes,
          location: record.location,
          diveCount: record.diveCount,
          siteCount: record.siteCount,
          cloudFileId: record.cloudFileId,
          localPath: record.localPath,
          isAutomatic: record.isAutomatic,
        );

        expect(copy, equals(record));
        expect(copy.hashCode, equals(record.hashCode));
      });

      test('different records are not equal', () {
        final different = record.copyWith(id: 'different-id');

        expect(different, isNot(equals(record)));
      });
    });
  });

  group('BackupLocation', () {
    test('has expected values', () {
      expect(BackupLocation.values, hasLength(3));
      expect(BackupLocation.values, contains(BackupLocation.local));
      expect(BackupLocation.values, contains(BackupLocation.cloud));
      expect(BackupLocation.values, contains(BackupLocation.both));
    });
  });
}
