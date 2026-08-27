import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database_engine_preflight.dart';

/// A probe with a canned `PRAGMA cipher_version` answer that records its close.
class _FakeProbe implements DatabaseEngineProbe {
  _FakeProbe({this.cipherVersion = const ['4.5.6'], this.closeError});

  final List<String> cipherVersion;
  final Object? closeError;
  bool closed = false;

  @override
  List<String> readCipherVersion() => cipherVersion;

  @override
  void close() {
    closed = true;
    if (closeError != null) throw closeError!;
  }
}

/// A probe that opens fine but fails the `PRAGMA` itself, as a library with
/// resolvable symbols but a broken initialisation would.
class _ThrowingProbe implements DatabaseEngineProbe {
  bool closed = false;

  @override
  List<String> readCipherVersion() => throw StateError('pragma exploded');

  @override
  void close() => closed = true;
}

void main() {
  group('assertDatabaseEngineAvailable', () {
    test('passes against the engine this build actually links', () {
      // The build hook selects SQLCipher (`hooks: user_defines: sqlite3:
      // source: sqlcipher` in pubspec.yaml), so the real engine must satisfy
      // the preflight. This is the runtime twin of the build-time invariant
      // asserted in sqlcipher_setup_test.dart.
      expect(assertDatabaseEngineAvailable, returnsNormally);
    });

    test('throws when the native library cannot be loaded at all', () {
      // The verbatim failure from the Windows build that shipped without
      // sqlcipher.dll (#1129), which the app reported as a failed upgrade.
      expect(
        () => assertDatabaseEngineAvailable(
          openProbe: () => throw ArgumentError(
            "Couldn't resolve native function 'sqlite3_initialize'",
          ),
        ),
        throwsA(
          isA<DatabaseEngineUnavailableException>()
              .having(
                (e) => e.reason,
                'reason',
                contains('could not be loaded'),
              )
              .having((e) => '$e', 'toString', contains('sqlite3_initialize')),
        ),
      );
    });

    test('throws when the library loads but is not a SQLCipher build', () {
      final probe = _FakeProbe(cipherVersion: const []);

      expect(
        () => assertDatabaseEngineAvailable(openProbe: () => probe),
        throwsA(
          isA<DatabaseEngineUnavailableException>().having(
            (e) => e.reason,
            'reason',
            contains('SQLCipher'),
          ),
        ),
      );
      expect(probe.closed, isTrue, reason: 'the probe must not be leaked');
    });

    test('throws when the cipher_version read itself fails', () {
      final probe = _ThrowingProbe();

      expect(
        () => assertDatabaseEngineAvailable(openProbe: () => probe),
        throwsA(
          isA<DatabaseEngineUnavailableException>().having(
            (e) => '$e',
            'toString',
            contains('pragma exploded'),
          ),
        ),
      );
      expect(probe.closed, isTrue);
    });

    test('closes the probe on the success path', () {
      final probe = _FakeProbe();

      assertDatabaseEngineAvailable(openProbe: () => probe);

      expect(probe.closed, isTrue);
    });

    test('a probe that fails to close does not fail a passing check', () {
      // Closing a throwaway in-memory handle is housekeeping. Letting it turn
      // a healthy engine into a terminal startup error would be the same
      // misdiagnosis this preflight exists to prevent.
      final probe = _FakeProbe(closeError: StateError('close blew up'));

      expect(
        () => assertDatabaseEngineAvailable(openProbe: () => probe),
        returnsNormally,
      );
    });
  });

  group('DatabaseEngineUnavailableException', () {
    test('toString carries the reason on its own when there is no cause', () {
      const e = DatabaseEngineUnavailableException('no library');

      expect('$e', 'DatabaseEngineUnavailableException: no library');
    });

    test('toString carries the underlying cause when there is one', () {
      final e = DatabaseEngineUnavailableException(
        'no library',
        cause: ArgumentError('symbol missing'),
      );

      expect('$e', contains('no library'));
      expect('$e', contains('symbol missing'));
    });
  });
}
