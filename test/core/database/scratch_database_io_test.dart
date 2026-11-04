import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/scratch_database.dart';

/// A scratch SQLite database is, natively, a file in a temporary folder that
/// is gone once its bytes have been read (issue #4121).
void main() {
  Future<int> scratchFolders() => Directory.systemTemp
      .list()
      .where((entry) => p.basename(entry.path).startsWith('submersion-image-'))
      .length;

  test('returns the file the fill built and removes it', () async {
    final before = await scratchFolders();
    final bytes = await withScratchDatabase((scratch) async {
      scratch.execute('CREATE TABLE t (v TEXT)');
      scratch.execute("INSERT INTO t VALUES ('kept')");
      scratch.execute('PRAGMA user_version = 7');
    });
    expect(await scratchFolders(), before);

    final dir = await Directory.systemTemp.createTemp('scratch_database_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'copy.db'));
    await file.writeAsBytes(bytes);
    final reopened = sqlite3.sqlite3.open(file.path);
    addTearDown(reopened.close);
    expect(reopened.select('SELECT v FROM t').single['v'], 'kept');
    expect(reopened.select('PRAGMA user_version').single.columnAt(0), 7);
  });

  test('removes the file when the fill throws', () async {
    final before = await scratchFolders();
    await expectLater(
      withScratchDatabase((scratch) async => throw StateError('no image')),
      throwsStateError,
    );
    expect(await scratchFolders(), before);
  });
}
