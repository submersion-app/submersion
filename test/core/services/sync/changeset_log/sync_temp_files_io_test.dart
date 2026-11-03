import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_files.dart';

/// The native sync temp files, in a private directory so the test is not
/// the hazard the shared directory's sweep covers.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sync_temp_files_io');
    SyncTempFiles.directory = () async => dir;
  });

  tearDown(() {
    SyncTempFiles.directory = resolveSyncTempDir;
    dir.deleteSync(recursive: true);
  });

  test('create, add, writeAt, close, read back and delete', () async {
    final sink = await SyncTempFiles.create('ssv1_base_test.json');
    expect(sink.path, p.join(dir.path, 'ssv1_base_test.json'));
    await sink.add([1, 2, 3, 4]);
    expect(sink.length, 4);
    await sink.add(Uint8List.fromList([5, 6]));
    await sink.writeAt(1, [9, 9]);
    final path = await sink.close();
    expect(path, p.join(dir.path, 'ssv1_base_test.json'));
    expect(await SyncTempFiles.exists(path), isTrue);
    expect(await SyncTempFiles.length(path), 6);
    expect(await SyncTempFiles.read(path, 1, 3), [9, 9, 4]);
    expect(await SyncTempFiles.read(path, 4, 10), [5, 6]);
    final all = <int>[];
    await for (final chunk in SyncTempFiles.openRead(path)) {
      all.addAll(chunk);
    }
    expect(all, [1, 9, 9, 4, 5, 6]);
    final head = <int>[];
    await for (final chunk in SyncTempFiles.openRead(path, 0, 2)) {
      head.addAll(chunk);
    }
    expect(head, [1, 9]);
    await SyncTempFiles.delete(path);
    expect(await SyncTempFiles.exists(path), isFalse);
    await SyncTempFiles.delete(path);
  });

  test('writeAt refuses to write past what was written', () async {
    final sink = await SyncTempFiles.create('short.json');
    await sink.add([1, 2]);
    expect(() => sink.writeAt(1, [1, 2]), throwsRangeError);
    await sink.close();
  });
}
