import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/backup_copy_guard.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

BackupRecord _record({String? cloudFileId, String? cloudAccountId}) =>
    BackupRecord(
      id: 'r',
      filename: 'submersion_backup_x.db',
      timestamp: DateTime(2026, 10, 19),
      sizeBytes: 1,
      location: BackupLocation.both,
      cloudFileId: cloudFileId,
      cloudAccountId: cloudAccountId,
    );

void main() {
  group('cloudCopyReachable', () {
    bool reach(
      BackupRecord r, {
      String? copy = 'acct-b',
      bool followsSync = false,
      String? sync = 'acct-sync',
    }) => cloudCopyReachable(
      r,
      copyAccountId: copy,
      followsSync: followsSync,
      syncAccountId: sync,
    );

    test('a copy in the account the copy goes to now is reachable', () {
      expect(
        reach(_record(cloudFileId: 'f', cloudAccountId: 'acct-b')),
        isTrue,
      );
    });

    test('a copy in another account is not', () {
      expect(
        reach(_record(cloudFileId: 'f', cloudAccountId: 'acct-a')),
        isFalse,
      );
    });

    test('a legacy copy is reachable while the copy follows sync', () {
      expect(
        reach(_record(cloudFileId: 'f'), followsSync: true, sync: null),
        isTrue,
      );
    });

    test('pinned, a legacy copy is reachable only in the sync account', () {
      final legacy = _record(cloudFileId: 'f');
      expect(reach(legacy), isFalse);
      expect(reach(legacy, copy: 'acct-sync'), isTrue);
      expect(reach(legacy, sync: null), isFalse);
    });

    test('a record with no cloud file is not', () {
      expect(reach(_record(), followsSync: true), isFalse);
    });
  });

  test('a record round-trips its cloud account through JSON', () {
    final r = _record(cloudFileId: 'f', cloudAccountId: 'acct-a');
    expect(BackupRecord.fromJson(r.toJson()).cloudAccountId, 'acct-a');
    final legacy = r.toJson()..remove('cloudAccountId');
    expect(BackupRecord.fromJson(legacy).cloudAccountId, isNull);
  });
}
