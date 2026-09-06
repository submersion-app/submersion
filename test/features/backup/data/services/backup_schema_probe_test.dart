import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/backup_schema_probe.dart';

void main() {
  group('probeBackupSchemaVersion', () {
    test('reports the version a keyed open returns', () {
      String? seenKey;
      final version = probeBackupSchemaVersion(
        '/backups/copy.db',
        keyHex: 'deadbeef',
        read: (path, {keyHex}) {
          seenKey = keyHex;
          return 170;
        },
      );

      expect(version, 170);
      expect(seenKey, 'deadbeef', reason: 'the live key is tried first');
    });

    test('retries without the key when the keyed open fails', () {
      // The install that turned protection ON after this copy was taken: the
      // file on disk is still plaintext, so the key is what breaks the open.
      final attempts = <String?>[];
      final version = probeBackupSchemaVersion(
        '/backups/copy.db',
        keyHex: 'deadbeef',
        read: (path, {keyHex}) {
          attempts.add(keyHex);
          if (keyHex != null) throw StateError('file is not encrypted');
          return 170;
        },
      );

      expect(version, 170);
      expect(attempts, ['deadbeef', null]);
    });

    test('does not retry when there was no key to fail with', () {
      // Without a key the second attempt would be byte-for-byte the first.
      var calls = 0;
      final version = probeBackupSchemaVersion(
        '/backups/copy.db',
        keyHex: null,
        read: (path, {keyHex}) {
          calls++;
          throw StateError('not a database');
        },
      );

      expect(version, isNull);
      expect(calls, 1);
    });

    test('reports null when neither open works', () {
      final version = probeBackupSchemaVersion(
        '/backups/copy.db',
        keyHex: 'deadbeef',
        read: (path, {keyHex}) => throw StateError('corrupt'),
      );

      expect(version, isNull);
    });

    test('a null from the reader is a missing file, not a failure', () {
      // getStoredSchemaVersion returns null for a file that is not there,
      // which must not trigger the unkeyed retry.
      var calls = 0;
      final version = probeBackupSchemaVersion(
        '/backups/gone.db',
        keyHex: 'deadbeef',
        read: (path, {keyHex}) {
          calls++;
          return null;
        },
      );

      expect(version, isNull);
      expect(calls, 1);
    });

    test('narrates both failures for the log', () {
      final messages = <String>[];
      probeBackupSchemaVersion(
        '/backups/copy.db',
        keyHex: 'deadbeef',
        read: (path, {keyHex}) => throw StateError('corrupt'),
        onDiagnostic: messages.add,
      );

      expect(messages, hasLength(2));
      expect(messages.first, contains('live key'));
      expect(messages.last, contains('unkeyed'));
    });
  });
}
