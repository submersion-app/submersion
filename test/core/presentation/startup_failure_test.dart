import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database_engine_preflight.dart';
import 'package:submersion/core/presentation/startup_failure.dart';
import 'package:submersion/core/services/security/database_locked_exception.dart';

/// Builds a [sqlite3.SqliteException] carrying [extendedResultCode]. The
/// primary `resultCode` the classifier reads is its low byte.
sqlite3.SqliteException _sqliteError(int extendedResultCode, String message) {
  return sqlite3.SqliteException(
    extendedResultCode: extendedResultCode,
    message: message,
  );
}

void main() {
  group('classifyStartupFailure - engine unavailable', () {
    test('the typed preflight exception is always an engine failure', () {
      for (final phase in StartupPhase.values) {
        expect(
          classifyStartupFailure(
            const DatabaseEngineUnavailableException('missing library'),
            phase,
          ),
          StartupFailureKind.engineUnavailable,
          reason: 'phase $phase must not reclassify a typed engine failure',
        );
      }
    });

    test('the #1129 FFI symbol-resolution ArgumentError is an engine '
        'failure even mid-migration', () {
      // The verbatim message from the Windows build that shipped without
      // sqlcipher.dll (issue #1129). It reached the generic catch and was
      // reported as "Database upgrade failed".
      final error = ArgumentError(
        "Couldn't resolve native function 'sqlite3_initialize'",
      );

      expect(
        classifyStartupFailure(error, StartupPhase.upgrading),
        StartupFailureKind.engineUnavailable,
      );
    });

    test('a failed dynamic-library load is an engine failure', () {
      final error = ArgumentError(
        'Failed to load dynamic library (libsqlcipher.so: cannot open '
        'shared object file)',
      );

      expect(
        classifyStartupFailure(error, StartupPhase.preflight),
        StartupFailureKind.engineUnavailable,
      );
    });

    test('the DatabaseService "SQLCipher is not linked" StateError is an '
        'engine failure', () {
      final error = StateError(
        'SQLCipher is not linked: PRAGMA cipher_version returned nothing. '
        'The app was built against a non-SQLCipher sqlite3 library.',
      );

      expect(
        classifyStartupFailure(error, StartupPhase.opening),
        StartupFailureKind.engineUnavailable,
      );
    });

    test('a failed symbol lookup is an engine failure', () {
      final error = ArgumentError(
        'Failed to lookup symbol sqlite3_key_v2: undefined symbol',
      );

      expect(
        classifyStartupFailure(error, StartupPhase.opening),
        StartupFailureKind.engineUnavailable,
      );
    });
  });

  group('classifyStartupFailure - data unreadable', () {
    test('SQLITE_CORRUPT is unreadable data, not a failed upgrade', () {
      // Extended code 267 (SQLITE_CORRUPT_VTAB), with a message that matches
      // no text marker, so only the result-code branch can classify it.
      final error = _sqliteError(267, 'something went wrong');

      expect(
        classifyStartupFailure(error, StartupPhase.upgrading),
        StartupFailureKind.dataUnreadable,
      );
    });

    test('SQLITE_NOTADB is unreadable data', () {
      final error = _sqliteError(26, 'something went wrong');

      expect(
        classifyStartupFailure(error, StartupPhase.opening),
        StartupFailureKind.dataUnreadable,
      );
    });

    test('a malformed-image message without a SqliteException still reads '
        'as unreadable data', () {
      // Drift wraps some failures, so the result code is not always reachable.
      final error = StateError('database disk image is malformed');

      expect(
        classifyStartupFailure(error, StartupPhase.opening),
        StartupFailureKind.dataUnreadable,
      );
    });

    test('an unrelated SqliteException is not classified as unreadable', () {
      final error = _sqliteError(13, 'database or disk is full');

      expect(
        classifyStartupFailure(error, StartupPhase.opening),
        StartupFailureKind.unknown,
      );
    });
  });

  group('classifyStartupFailure - database busy', () {
    test('a locked database mid-upgrade is not a failed migration', () {
      // The field report this class exists for: an INSERT in the v128 seed
      // met a lock another isolate held. SQLite refused to START the write,
      // so the ladder changed nothing -- calling it a failed upgrade told the
      // diver their data was at risk and offered to overwrite an intact
      // database with an older backup.
      final error = _sqliteError(5, 'database is locked');

      expect(
        classifyStartupFailure(error, StartupPhase.upgrading),
        StartupFailureKind.databaseBusy,
      );
    });

    test('SQLITE_LOCKED classifies the same way as SQLITE_BUSY', () {
      expect(
        classifyStartupFailure(
          _sqliteError(6, 'database table is locked'),
          StartupPhase.opening,
        ),
        StartupFailureKind.databaseBusy,
      );
    });

    test('a lock is recognised in every phase', () {
      for (final phase in StartupPhase.values) {
        expect(
          classifyStartupFailure(_sqliteError(5, 'database is locked'), phase),
          StartupFailureKind.databaseBusy,
          reason: 'phase $phase must not reclassify a lock',
        );
      }
    });

    test('a lock is recognised through a wrapper that loses the type', () {
      // Drift and the isolate boundary both re-wrap some failures, so the
      // result code is not always reachable.
      expect(
        classifyStartupFailure(
          Exception(
            'SqliteException(5): while executing, database is locked, '
            'database is locked (code 5)',
          ),
          StartupPhase.upgrading,
        ),
        StartupFailureKind.databaseBusy,
      );
    });

    test('the encrypted-database exception is not mistaken for a lock', () {
      // Two unrelated senses of "locked" live in this codebase. The unlock
      // exception never reaches the classifier (startup routes it to the
      // password screen), but the message markers must not claim it either:
      // telling a diver to relaunch would strand them short of the prompt.
      expect(
        classifyStartupFailure(
          const DatabaseLockedException('/tmp/submersion.db'),
          StartupPhase.preflight,
        ),
        isNot(StartupFailureKind.databaseBusy),
      );
    });

    test('an engine failure still outranks a lock', () {
      expect(
        classifyStartupFailure(
          const DatabaseEngineUnavailableException('database is locked'),
          StartupPhase.upgrading,
        ),
        StartupFailureKind.engineUnavailable,
      );
    });
  });

  group('classifyStartupFailure - phase decides the rest', () {
    test('an unrecognised error during the upgrade is a failed migration', () {
      expect(
        classifyStartupFailure(
          Exception('Disk is full'),
          StartupPhase.upgrading,
        ),
        StartupFailureKind.migrationFailed,
      );
    });

    test('the same error outside the upgrade is not a failed migration', () {
      // The whole point of #1134: no migration was attempted, so the app must
      // not claim the upgrade failed.
      expect(
        classifyStartupFailure(Exception('Disk is full'), StartupPhase.opening),
        StartupFailureKind.unknown,
      );
      expect(
        classifyStartupFailure(
          Exception('Disk is full'),
          StartupPhase.preflight,
        ),
        StartupFailureKind.unknown,
      );
    });
  });

  group('StartupFailureKind.dataIsAtRisk', () {
    test('an engine failure never puts data at risk', () {
      expect(StartupFailureKind.engineUnavailable.dataIsAtRisk, isFalse);
    });

    test('the classes that touched the file do', () {
      expect(StartupFailureKind.migrationFailed.dataIsAtRisk, isTrue);
      expect(StartupFailureKind.dataUnreadable.dataIsAtRisk, isTrue);
    });

    test('a lock never puts data at risk', () {
      // SQLITE_BUSY is refusal, not damage: the write never started. Offering
      // a restore here would invite a diver to overwrite an intact database.
      expect(StartupFailureKind.databaseBusy.dataIsAtRisk, isFalse);
    });

    test('an unclassified failure is treated as touching the file', () {
      // Conservative: an unknown failure has to be assumed to have reached the
      // database, so the recovery routes stay on offer.
      expect(StartupFailureKind.unknown.dataIsAtRisk, isTrue);
    });
  });
}
