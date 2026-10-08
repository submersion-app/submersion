import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/sync/changeset_log/sync_temp_sweep.dart';

/// [sweepLeftoverSyncTempFiles] reaps `ssv1_` temp files from the sync temp
/// directory.
///
/// Under `flutter test` that directory is `Directory.systemTemp` -- machine
/// wide -- because `getTemporaryDirectory()` throws `MissingPluginException`
/// with no plugin host. Every concurrent test process therefore shares it, and
/// a base export in flight in one process sits right next to the sweep running
/// in another. The `ssv1_` prefix keeps the sweep off UNRELATED files, but the
/// files it is most likely to hit are another run's, which is why the age
/// guard, not the prefix, is what makes this safe.
///
/// No database, sync repository or provider is set up anywhere in this file:
/// the sweep runs at every launch, including on a device that has signed out
/// of sync (issue #1931), so it must need none of them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('base_temp_sweep_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  File write(String name, {Duration? age}) {
    final file = File(p.join(tempDir.path, name))..writeAsStringSync('x');
    if (age != null) {
      file.setLastModifiedSync(DateTime.now().subtract(age));
    }
    return file;
  }

  test('spares a base export that is still being written', () async {
    // The regression: a sibling test process publishing a base has its
    // ssv1_base_*.json open in this same directory. Sweeping it kills that
    // publish, the sync returns non-success, and every assertion downstream
    // of "a successful sync" fails in a file that touched no sync code.
    final live = write('ssv1_base_device-a_1.abc123.json');

    await sweepLeftoverSyncTempFiles(tempDir: () async => tempDir);

    expect(
      live.existsSync(),
      isTrue,
      reason: 'a file written seconds ago is in flight, not a leftover',
    );
  });

  test('deletes a leftover from an earlier run', () async {
    // The case the sweep exists for: a crash left an export behind. It is old
    // by definition, since a live one is being written right now.
    final stale = write(
      'ssv1_base_device-a_1.def456.json',
      age: const Duration(hours: 2),
    );

    await sweepLeftoverSyncTempFiles(tempDir: () async => tempDir);

    expect(stale.existsSync(), isFalse);
  });

  test('deletes each kind of leftover sync temp file', () async {
    // Base exports, assembled peer bases and adopt parts all share the
    // ssv1_ prefix, and a sync interrupted at any stage can strand any one.
    final leftovers = [
      write('ssv1_base_device-a_3.aaa.json', age: const Duration(hours: 1)),
      write('ssv1_peer-b_7', age: const Duration(hours: 1)),
      write('ssv1_adopt_device-a_4', age: const Duration(hours: 1)),
    ];

    await sweepLeftoverSyncTempFiles(tempDir: () async => tempDir);

    for (final file in leftovers) {
      expect(file.existsSync(), isFalse, reason: file.path);
    }
  });

  test('spares a file just inside the grace period', () async {
    final young = write(
      'ssv1_adopt_device-a_5',
      age: syncTempFileGrace - const Duration(minutes: 1),
    );

    await sweepLeftoverSyncTempFiles(tempDir: () async => tempDir);

    expect(young.existsSync(), isTrue);
  });

  test('never touches a file without the ssv1_ prefix, at any age', () async {
    final unrelated = write('someone_elses.json', age: const Duration(days: 3));

    await sweepLeftoverSyncTempFiles(tempDir: () async => tempDir);

    expect(unrelated.existsSync(), isTrue);
  });

  test('sweeps the stale ones and spares the live ones in one pass', () async {
    final live = write('ssv1_adopt_live.base');
    final stale = write('ssv1_adopt_old.base', age: const Duration(days: 1));

    await sweepLeftoverSyncTempFiles(tempDir: () async => tempDir);

    expect(live.existsSync(), isTrue);
    expect(stale.existsSync(), isFalse);
  });

  test('swallows a failure to resolve the temp directory', () async {
    // It runs unawaited at startup; a throw here must never reach the zone.
    await expectLater(
      sweepLeftoverSyncTempFiles(
        tempDir: () async => throw const FileSystemException('denied'),
      ),
      completes,
    );
  });

  test('swallows a temp directory that does not exist', () async {
    final missing = Directory(p.join(tempDir.path, 'gone'));

    await expectLater(
      sweepLeftoverSyncTempFiles(tempDir: () async => missing),
      completes,
    );
  });
}
