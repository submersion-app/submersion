import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/downgrade_restore_candidates.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

BackupRecord record({
  required String id,
  required DateTime timestamp,
  int? fromSchemaVersion,
  int? toSchemaVersion,
  BackupType type = BackupType.preMigration,
  String? localPath = '/backups/copy.db',
  BackupLocation location = BackupLocation.local,
}) {
  return BackupRecord(
    id: id,
    filename: 'copy.db',
    timestamp: timestamp,
    sizeBytes: 1024,
    location: location,
    localPath: localPath,
    type: type,
    fromSchemaVersion: fromSchemaVersion,
    toSchemaVersion: toSchemaVersion,
  );
}

void main() {
  group('downgradeRestoreCandidates', () {
    test('offers the newest copy this build could still open', () {
      final candidates = downgradeRestoreCandidates([
        record(
          id: 'older',
          timestamp: DateTime.utc(2026, 8, 1),
          fromSchemaVersion: 170,
          toSchemaVersion: 175,
        ),
        record(
          id: 'newer',
          timestamp: DateTime.utc(2026, 9, 1),
          fromSchemaVersion: 175,
          toSchemaVersion: 191,
        ),
      ], supportedSchemaVersion: 175);

      expect(candidates.map((r) => r.id), ['newer', 'older']);
    });

    test('rejects a copy whose own schema is already too new', () {
      // The whole point of the screen: a copy taken at 191 is unreadable by
      // the very build being offered the restore.
      final candidates = downgradeRestoreCandidates([
        record(
          id: 'too-new',
          timestamp: DateTime.utc(2026, 9, 1),
          fromSchemaVersion: 191,
          toSchemaVersion: 195,
        ),
      ], supportedSchemaVersion: 175);

      expect(candidates, isEmpty);
    });

    test('rejects a record that does not say what schema it holds', () {
      // Without fromSchemaVersion there is nothing to check the claim
      // against, and offering an unopenable file is worse than offering none.
      final candidates = downgradeRestoreCandidates([
        record(id: 'unknown', timestamp: DateTime.utc(2026, 9, 1)),
      ], supportedSchemaVersion: 175);

      expect(candidates, isEmpty);
    });

    test('rejects manual backups, which carry no schema stamp', () {
      final candidates = downgradeRestoreCandidates([
        record(
          id: 'manual',
          timestamp: DateTime.utc(2026, 9, 1),
          type: BackupType.manual,
          fromSchemaVersion: 170,
          toSchemaVersion: 175,
        ),
      ], supportedSchemaVersion: 175);

      expect(candidates, isEmpty);
    });

    test('rejects records with no local file to copy', () {
      final candidates = downgradeRestoreCandidates([
        record(
          id: 'cloud',
          timestamp: DateTime.utc(2026, 9, 1),
          fromSchemaVersion: 170,
          toSchemaVersion: 175,
          localPath: null,
          location: BackupLocation.cloud,
        ),
        record(
          id: 'saf',
          timestamp: DateTime.utc(2026, 9, 2),
          fromSchemaVersion: 170,
          toSchemaVersion: 175,
          localPath: 'content://com.android.providers/tree/backup.db',
        ),
      ], supportedSchemaVersion: 175);

      expect(candidates, isEmpty);
    });

    test('an equal schema version is openable and is offered', () {
      final candidates = downgradeRestoreCandidates([
        record(
          id: 'equal',
          timestamp: DateTime.utc(2026, 9, 1),
          fromSchemaVersion: 175,
          toSchemaVersion: 191,
        ),
      ], supportedSchemaVersion: 175);

      expect(candidates.single.id, 'equal');
    });
  });
}
