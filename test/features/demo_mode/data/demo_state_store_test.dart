import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

void main() {
  late Directory support;
  late DemoPaths paths;
  late DemoStateStore store;

  setUp(() {
    support = Directory.systemTemp.createTempSync('demo_store');
    paths = DemoPaths(support.path);
    store = DemoStateStore(paths);
  });

  tearDown(() {
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  final state = DemoState(
    phase: DemoPhase.active,
    fromFirstRun: false,
    enteredAt: DateTime.utc(2026, 10, 26, 9),
  );

  test('paths all live under the demo_mode directory', () {
    expect(paths.root, p.join(support.path, 'demo_mode'));
    for (final path in [
      paths.stateFile,
      paths.prefsSnapshotFile,
      paths.packageFile,
      paths.databaseFile,
      paths.photosDir,
    ]) {
      expect(p.isWithin(paths.root, path), isTrue, reason: path);
    }
  });

  test('read returns null when there is no state', () async {
    expect(await store.read(), isNull);
  });

  test(
    'write then read returns the same state, and a half-written tmp file is ignored',
    () async {
      await store.write(state);
      File('${paths.stateFile}.tmp').writeAsStringSync('{"phase": "exi');

      expect(await store.read(), state);
    },
  );

  test('read returns null for a corrupt state file', () async {
    Directory(paths.root).createSync(recursive: true);
    File(paths.stateFile).writeAsStringSync('not json');

    expect(await store.read(), isNull);
  });

  test('deleteAll removes the whole demo directory', () async {
    await store.write(state);
    File(paths.databaseFile).writeAsStringSync('db');
    Directory(paths.photosDir).createSync();

    await store.deleteAll();

    expect(Directory(paths.root).existsSync(), isFalse);
    expect(await store.read(), isNull);
  });

  test('deleteAll is a no-op when there is nothing to delete', () async {
    await store.deleteAll();

    expect(Directory(paths.root).existsSync(), isFalse);
  });
}
