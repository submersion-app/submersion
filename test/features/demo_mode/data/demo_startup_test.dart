import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_startup.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/data/prefs_snapshot.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

import '../../../helpers/global_test_defaults.dart';

/// A store whose demo directory cannot be removed, as when another process
/// still holds the sample logbook open.
class _UndeletableStore extends DemoStateStore {
  const _UndeletableStore(super.paths);

  @override
  Future<void> deleteAll() async =>
      throw const FileSystemException('directory in use');
}

/// A store whose preference snapshot cannot be applied.
class _UnrestorableStore extends DemoStateStore {
  const _UnrestorableStore(super.paths);

  @override
  Future<bool> restorePrefs(SharedPreferences prefs) async =>
      throw const FileSystemException('snapshot unreadable');
}

void main() {
  late Directory root;
  late DemoPaths paths;
  late DemoStateStore store;
  late SharedPreferences prefs;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('demo_startup');
    paths = DemoPaths(root.path);
    store = DemoStateStore(paths);
    SharedPreferences.setMockInitialValues({'current_diver_id': 'real'});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    applyGlobalTestDefaults();
    root.deleteSync(recursive: true);
  });

  Future<void> writeState(DemoPhase phase) => store.write(
    DemoState(
      phase: phase,
      fromFirstRun: false,
      enteredAt: DateTime.utc(2026, 10, 26),
    ),
  );

  Future<DemoStartupDecision> resolve() =>
      DemoStartup.resolve(store: store, prefs: prefs);

  test('no state opens the real logbook', () async {
    expect((await resolve()).demoDatabasePath, isNull);
    expect(DemoModeGate.instance.isActive, isFalse);
  });

  test('entering cleans up and opens the real logbook', () async {
    await writeState(DemoPhase.entering);
    File(paths.packageFile).writeAsStringSync('partial');

    final decision = await resolve();

    expect(decision.demoDatabasePath, isNull);
    expect(Directory(paths.root).existsSync(), isFalse);
    expect(DemoModeGate.instance.isActive, isFalse);
  });

  test('entering after the switch restores the preferences snapshot', () async {
    await PrefsSnapshot.capture(prefs, File(paths.prefsSnapshotFile));
    await prefs.setString('current_diver_id', 'demo-diver');
    await writeState(DemoPhase.entering);

    final decision = await resolve();

    expect(decision.demoDatabasePath, isNull);
    expect(prefs.getString('current_diver_id'), 'real');
    expect(Directory(paths.root).existsSync(), isFalse);
  });

  test('active opens the demo database', () async {
    await writeState(DemoPhase.active);
    File(paths.databaseFile).writeAsStringSync('db');

    final decision = await resolve();

    expect(decision.demoDatabasePath, paths.databaseFile);
    expect(DemoModeGate.instance.isActive, isTrue);
  });

  test('exiting finishes the exit and opens the real logbook', () async {
    await PrefsSnapshot.capture(prefs, File(paths.prefsSnapshotFile));
    await prefs.setString('current_diver_id', 'demo-diver');
    await writeState(DemoPhase.exiting);
    File(paths.databaseFile).writeAsStringSync('db');

    final decision = await resolve();

    expect(decision.demoDatabasePath, isNull);
    expect(prefs.getString('current_diver_id'), 'real');
    expect(Directory(paths.root).existsSync(), isFalse);
    expect(DemoModeGate.instance.isActive, isFalse);
  });

  test('active with a missing demo file finishes the exit', () async {
    await PrefsSnapshot.capture(prefs, File(paths.prefsSnapshotFile));
    await prefs.setString('current_diver_id', 'demo-diver');
    await writeState(DemoPhase.active);

    final decision = await resolve();

    expect(decision.demoDatabasePath, isNull);
    expect(prefs.getString('current_diver_id'), 'real');
    expect(Directory(paths.root).existsSync(), isFalse);
  });

  test('exiting without a snapshot still cleans up', () async {
    await writeState(DemoPhase.exiting);

    final decision = await resolve();

    expect(decision.demoDatabasePath, isNull);
    expect(prefs.getString('current_diver_id'), 'real');
    expect(Directory(paths.root).existsSync(), isFalse);
  });

  test('a demo directory with unreadable state is cleared', () async {
    Directory(paths.root).createSync(recursive: true);
    File(paths.stateFile).writeAsStringSync('{not json');

    final decision = await resolve();

    expect(decision.demoDatabasePath, isNull);
    expect(Directory(paths.root).existsSync(), isFalse);
    expect(DemoModeGate.instance.isActive, isFalse);
  });

  test('an exit with an unreadable snapshot still finishes', () async {
    await writeState(DemoPhase.exiting);
    File(paths.prefsSnapshotFile).writeAsStringSync('not a snapshot');

    final decision = await resolve();

    expect(decision.demoDatabasePath, isNull);
    // Left as it was rather than wiped by a snapshot that cannot be read.
    expect(prefs.getString('current_diver_id'), 'real');
    expect(Directory(paths.root).existsSync(), isFalse);
  });

  test('abandon leaves a sample logbook this build cannot open', () async {
    await PrefsSnapshot.capture(prefs, File(paths.prefsSnapshotFile));
    await prefs.setString('current_diver_id', 'demo-diver');
    await writeState(DemoPhase.active);
    File(paths.databaseFile).writeAsStringSync('db');
    DemoModeGate.instance.markActive(true);

    await DemoStartup.abandon(store: store, prefs: prefs);

    expect(prefs.getString('current_diver_id'), 'real');
    expect(Directory(paths.root).existsSync(), isFalse);
    expect(DemoModeGate.instance.isActive, isFalse);
    // The next launch opens the user's own logbook.
    expect((await resolve()).demoDatabasePath, isNull);
  });

  test('abandon still leaves when the demo directory cannot be removed, and '
      'the next launch finishes the exit', () async {
    await PrefsSnapshot.capture(prefs, File(paths.prefsSnapshotFile));
    await prefs.setString('current_diver_id', 'demo-diver');
    await writeState(DemoPhase.active);
    DemoModeGate.instance.markActive(true);

    await DemoStartup.abandon(store: _UndeletableStore(paths), prefs: prefs);

    expect(prefs.getString('current_diver_id'), 'real');
    expect(DemoModeGate.instance.isActive, isFalse);
    expect((await store.read())?.phase, DemoPhase.exiting);
  });

  test('abandon fails and keeps demo mode on when the preferences cannot be '
      'restored', () async {
    await writeState(DemoPhase.active);
    DemoModeGate.instance.markActive(true);

    await expectLater(
      DemoStartup.abandon(store: _UnrestorableStore(paths), prefs: prefs),
      throwsA(isA<FileSystemException>()),
    );

    expect(DemoModeGate.instance.isActive, isTrue);
    expect(Directory(paths.root).existsSync(), isTrue);
  });

  test('the demo directory sits under the support directory', () {
    expect(p.isWithin(root.path, paths.databaseFile), isTrue);
  });
}
