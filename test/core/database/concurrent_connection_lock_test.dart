import 'dart:io';
import 'dart:isolate';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_connection_setup.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';

/// How long the other isolate holds the write lock in the behavioural tests.
///
/// Deliberately a small fraction of [kDatabaseBusyTimeout]. These tests are
/// inherently timing-based -- proving a wait happened means something has to
/// wait -- so the only defence is margin. An earlier version held for 1500ms
/// against the 5s timeout, a margin of 3.3x, and that failed on a contended
/// CI runner: a machine slow enough to stretch the hold past the timeout
/// turns the test red for reasons that have nothing to do with the code under
/// test. At 250ms the margin is 20x.
///
/// The deterministic half of this file -- the busy timeout being present on
/// every connection path -- is what actually guards the fix, and it has no
/// timing dependency at all.
const Duration _lockHold = Duration(milliseconds: 250);

/// Opens [path] in a second isolate, takes the write lock, holds it for
/// [_lockHold], then commits and closes.
///
/// A second ISOLATE is load-bearing: `busy_timeout` blocks the calling isolate
/// inside sqlite3, so a lock released by a `Timer` on the main isolate could
/// never fire. This also mirrors production, where the lock holder is the
/// Workmanager headless isolate.
///
/// Message: [SendPort, path, holdMillis].
void _holdWriteLock(List<Object> message) {
  final port = message[0] as SendPort;
  final path = message[1] as String;
  final holdMillis = message[2] as int;

  final db = sqlite3.sqlite3.open(path);
  try {
    db.execute('PRAGMA busy_timeout = 10000');
    // IMMEDIATE takes the RESERVED lock straight away, so other connections
    // can still read but none of them can write -- exactly the state the
    // failing device was in.
    db.execute('BEGIN IMMEDIATE');
    db.execute('CREATE TABLE IF NOT EXISTS lock_probe (id INTEGER)');
    port.send('locked');
    sleep(Duration(milliseconds: holdMillis));
    db.execute('COMMIT');
  } finally {
    db.close();
  }
  port.send('released');
}

class _FakeLocation implements DatabaseLocationService {
  _FakeLocation(this.path);
  final String path;

  @override
  Future<String> getDatabasePath() async => path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('db-lock-test');
    dbPath = p.join(tempDir.path, 'submersion.db');
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    try {
      await DatabaseService.instance.close(strict: true);
    } finally {
      DatabaseService.instance.resetForTesting();
      await tempDir.delete(recursive: true);
    }
  });

  /// Brings the file to the current schema and closes it: the state a
  /// returning user's database is in when the app launches.
  Future<void> seedDatabaseFile() async {
    final seeded = AppDatabase(NativeDatabase(File(dbPath)));
    await seeded.customSelect('SELECT 1').get();
    await seeded.close();
  }

  /// Spawns the holder, returns once it actually holds the lock, and returns a
  /// future that completes when it has committed and closed.
  ///
  /// The caller must await that future before the test ends. Killing the
  /// holder mid-transaction would abandon an open sqlite3 handle whose locks
  /// live as long as the process, which would poison whatever ran next.
  Future<void> holdWriteLock() async {
    final events = ReceivePort();
    final stream = events.asBroadcastStream();
    final isolate = await Isolate.spawn(_holdWriteLock, <Object>[
      events.sendPort,
      dbPath,
      _lockHold.inMilliseconds,
    ]);
    final released = stream.firstWhere((e) => e == 'released');
    addTearDown(() async {
      await released;
      events.close();
      isolate.kill(priority: Isolate.immediate);
    });
    await stream.firstWhere((e) => e == 'locked');
  }

  group('every main-database connection carries the busy timeout', () {
    // The deterministic guard. SQLite defaults busy_timeout to zero, so a
    // connection path that misses applyMainDatabaseSetup fails instantly on
    // any contention -- which is the whole bug. No timing involved: each of
    // these just asks the connection what it is configured with.

    test('a raw open does', () async {
      await seedDatabaseFile();

      final db = DatabaseService.openRaw(dbPath);
      addTearDown(db.close);

      expect(
        db.select('PRAGMA busy_timeout').single.values.first,
        kDatabaseBusyTimeout.inMilliseconds,
      );
    });

    test('the drift worker isolate does', () async {
      await seedDatabaseFile();
      await DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
      );
      expect(
        DatabaseService.instance.lastOpenMode,
        DatabaseOpenMode.background,
      );

      // Asked THROUGH the drift connection, so it reports what the worker
      // isolate's own sqlite3 handle is set to, not the main isolate's.
      final row = await DatabaseService.instance.database
          .customSelect('PRAGMA busy_timeout')
          .getSingle();
      expect(row.data.values.first, kDatabaseBusyTimeout.inMilliseconds);
    });

    test('the synchronous migrator connection does', () async {
      await seedDatabaseFile();
      final rollback = DatabaseService.openRaw(dbPath);
      rollback.execute(
        'PRAGMA user_version = ${AppDatabase.currentSchemaVersion - 1}',
      );
      rollback.close();

      await DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
      );

      // The migrator runs the ladder and closes, so it cannot be interrogated
      // directly. That it ran at all is the assertion available here; the
      // ladder completing proves the connection was usable.
      expect(
        DatabaseService.instance.lastOpenMode,
        DatabaseOpenMode.migrationThenBackground,
      );
      final version = await DatabaseService.instance.database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.first, AppDatabase.currentSchemaVersion);
    });
  });

  test('initialize opens the database rather than deferring it', () async {
    // Drift opens lazily and _assertCipherAvailable's PRAGMA short-circuits
    // under FLUTTER_TEST, so initialize() used to return in about a
    // millisecond having touched nothing: beforeOpen, and every write it
    // makes, ran later on whatever query happened first. That put a lock
    // failure an arbitrary distance from the open that caused it, out of
    // reach of both the retry and the startup screen's classifier.
    await seedDatabaseFile();
    final probe = DatabaseService.openRaw(dbPath);
    probe.execute('DELETE FROM pre_dive_checklist_templates');
    probe.close();

    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(dbPath),
    );

    // Read on a SEPARATE raw connection, so nothing here can be what forces
    // the drift connection open.
    final after = DatabaseService.openRaw(dbPath);
    addTearDown(after.close);
    final seeded = after
        .select('SELECT COUNT(*) AS c FROM pre_dive_checklist_templates')
        .single
        .values
        .first;
    expect(seeded, greaterThan(0));
  });

  group('an open survives a lock another isolate holds', () {
    test('a normal open waits rather than failing', () async {
      await seedDatabaseFile();
      await holdWriteLock();

      // beforeOpen re-asserts schema and re-seeds the built-in reference data
      // (pre_dive_checklist_templates among it) on EVERY open, so the open
      // writes while the other isolate holds the lock. Unprotected, the first
      // of those writes throws SqliteException(5), which is the reported
      // crash.
      final elapsed = Stopwatch()..start();
      await DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
      );
      elapsed.stop();

      final seeds = await DatabaseService.instance.database
          .customSelect(
            'SELECT COUNT(*) AS c FROM pre_dive_checklist_templates '
            'WHERE is_built_in = 1',
          )
          .getSingle();
      expect(seeds.read<int>('c'), greaterThan(0));
      // Proves the open genuinely met the lock rather than racing past it
      // before the holder acquired one, which would make this vacuous.
      expect(elapsed.elapsed, greaterThanOrEqualTo(_lockHold));
    });

    test('the upgrade ladder waits rather than failing', () async {
      await seedDatabaseFile();

      // Roll the stored version back one step so the launch has a pending
      // upgrade, the situation the field report came from. The ladder's steps
      // are idempotent by contract, so replaying the last one is safe.
      final rollback = DatabaseService.openRaw(dbPath);
      rollback.execute(
        'PRAGMA user_version = ${AppDatabase.currentSchemaVersion - 1}',
      );
      rollback.close();

      await holdWriteLock();

      // Unlike the plain open above, this one really does run inside
      // initialize(): _openDatabase forces the ladder to completion with its
      // own `SELECT 1` before it will switch executors.
      final elapsed = Stopwatch()..start();
      await DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
      );
      elapsed.stop();

      expect(
        DatabaseService.instance.lastOpenMode,
        DatabaseOpenMode.migrationThenBackground,
      );
      expect(elapsed.elapsed, greaterThanOrEqualTo(_lockHold));
      final version = await DatabaseService.instance.database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.first, AppDatabase.currentSchemaVersion);
    });
  });
}
