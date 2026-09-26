import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/backup/domain/entities/quarantined_database.dart';

void main() {
  final path = p.join('db', 'submersion.db.pre-restore.20260926T134501Z');
  final original = QuarantinedDatabase(
    path: path,
    kind: QuarantineKind.preRestore,
    quarantinedAt: DateTime.utc(2026, 9, 26, 13, 45, 1),
    files: [path, '$path-wal'],
    sizeBytes: 2048,
    status: QuarantinedDatabaseStatus.restorable,
    schemaVersion: 70,
  );

  test('filename is the database file name', () {
    expect(original.filename, 'submersion.db.pre-restore.20260926T134501Z');
  });

  test('only a restorable copy is restorable', () {
    expect(original.isRestorable, isTrue);
    for (final status in QuarantinedDatabaseStatus.values) {
      expect(
        original.copyWith(status: status).isRestorable,
        status == QuarantinedDatabaseStatus.restorable,
        reason: status.name,
      );
    }
  });

  test('copyWith with no arguments keeps every field', () {
    final copy = original.copyWith();

    expect(copy.path, original.path);
    expect(copy.kind, original.kind);
    expect(copy.quarantinedAt, original.quarantinedAt);
    expect(copy.files, original.files);
    expect(copy.sizeBytes, original.sizeBytes);
    expect(copy.status, original.status);
    expect(copy.schemaVersion, original.schemaVersion);
  });

  test('copyWith replaces each field it is given', () {
    final otherPath = p.join('db', 'submersion.db.restore-rejected.x');
    final copy = original.copyWith(
      path: otherPath,
      kind: QuarantineKind.restoreRejected,
      quarantinedAt: DateTime.utc(2025),
      files: [otherPath],
      sizeBytes: 1,
      status: QuarantinedDatabaseStatus.needsNewerApp,
      schemaVersion: 999,
    );

    expect(copy.path, otherPath);
    expect(copy.kind, QuarantineKind.restoreRejected);
    expect(copy.quarantinedAt, DateTime.utc(2025));
    expect(copy.files, [otherPath]);
    expect(copy.sizeBytes, 1);
    expect(copy.status, QuarantinedDatabaseStatus.needsNewerApp);
    expect(copy.schemaVersion, 999);
  });
}
