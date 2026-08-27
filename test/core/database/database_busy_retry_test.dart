import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database_connection_setup.dart';
import 'package:submersion/core/services/security/database_locked_exception.dart';

sqlite3.SqliteException _sqliteError(int extendedResultCode, String message) {
  return sqlite3.SqliteException(
    extendedResultCode: extendedResultCode,
    message: message,
  );
}

void main() {
  group('isDatabaseBusyError', () {
    test('recognises SQLITE_BUSY and SQLITE_LOCKED by result code', () {
      expect(
        isDatabaseBusyError(_sqliteError(5, 'database is locked')),
        isTrue,
      );
      expect(
        isDatabaseBusyError(_sqliteError(6, 'database table is locked')),
        isTrue,
      );
    });

    test('recognises a lock through a wrapper that loses the type', () {
      // Drift's remote executor and the isolate boundary both re-wrap some
      // failures, so the result code is not always reachable.
      expect(
        isDatabaseBusyError(
          Exception(
            'SqliteException(5): while executing, database is locked, '
            'database is locked (code 5)',
          ),
        ),
        isTrue,
      );
    });

    test('does not claim other SQLite failures', () {
      expect(
        isDatabaseBusyError(
          _sqliteError(11, 'database disk image is malformed'),
        ),
        isFalse,
      );
      expect(
        isDatabaseBusyError(_sqliteError(26, 'file is not a database')),
        isFalse,
      );
      expect(
        isDatabaseBusyError(Exception('database or disk is full')),
        isFalse,
      );
    });

    test('does not mistake the encrypted-database exception for a lock', () {
      // Two unrelated senses of "locked" live in this codebase, and routing an
      // encrypted database to the retry would burn the attempts and then
      // report the wrong thing. Guarded here as well as in the classifier
      // because both now share this one predicate.
      expect(
        isDatabaseBusyError(const DatabaseLockedException('/tmp/x.db')),
        isFalse,
      );
    });
  });

  group('retryWhileDatabaseBusy', () {
    test('returns the first success without waiting', () async {
      var calls = 0;
      final waits = <Duration>[];

      final result = await retryWhileDatabaseBusy<int>(() async {
        calls++;
        return 42;
      }, delay: (d) async => waits.add(d));

      expect(result, 42);
      expect(calls, 1);
      expect(waits, isEmpty);
    });

    test('retries a lock and returns the eventual success', () async {
      var calls = 0;
      final waits = <Duration>[];

      final result = await retryWhileDatabaseBusy<String>(() async {
        calls++;
        if (calls < 3) throw _sqliteError(5, 'database is locked');
        return 'opened';
      }, delay: (d) async => waits.add(d));

      expect(result, 'opened');
      expect(calls, 3);
      // Backoff grows with the attempt so a holder that needs a moment gets
      // one, rather than being hammered at a fixed interval.
      expect(waits, [kDatabaseBusyOpenBackoff, kDatabaseBusyOpenBackoff * 2]);
    });

    test('gives up after the attempt budget and rethrows the lock', () async {
      var calls = 0;

      await expectLater(
        retryWhileDatabaseBusy<void>(() async {
          calls++;
          throw _sqliteError(5, 'database is locked');
        }, delay: (_) async {}),
        throwsA(isA<sqlite3.SqliteException>()),
      );

      expect(calls, kDatabaseBusyOpenAttempts);
    });

    test('does not retry a failure that is not a lock', () async {
      var calls = 0;

      await expectLater(
        retryWhileDatabaseBusy<void>(() async {
          calls++;
          throw _sqliteError(11, 'database disk image is malformed');
        }, delay: (_) async {}),
        throwsA(isA<sqlite3.SqliteException>()),
      );

      // Corruption does not heal by waiting, and retrying it would delay the
      // recovery screen the diver actually needs.
      expect(calls, 1);
    });
  });
}
