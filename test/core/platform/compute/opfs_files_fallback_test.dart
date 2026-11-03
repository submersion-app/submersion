import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/compute/opfs_files.dart';
import 'package:submersion/core/platform/compute/opfs_files_fallback.dart';

/// Stands in for a browser with no origin private file system.
class _NoFileSystem extends UnavailableOpfsFiles {
  const _NoFileSystem();

  @override
  Future<List<String>> list() async =>
      throw StateError('UnknownError: the operation failed');
}

class _WorkingFileSystem extends UnavailableOpfsFiles {
  const _WorkingFileSystem();

  @override
  Future<List<String>> list() async => const ['kept'];
}

/// Safari's private windows and some embedded browsers refuse the origin
/// private file system. Sync's temp files then live in the worker's memory
/// rather than failing the first sync (issue #4121).
void main() {
  Uint8List bytes(List<int> values) => Uint8List.fromList(values);

  group('MemoryOpfsFiles', () {
    test('a file written in chunks reads back and patches in place', () async {
      final files = MemoryOpfsFiles();
      final handle = await files.create('a.base');
      await files.append(handle, bytes([1, 2]));
      await files.append(handle, bytes([3, 4, 5]));
      await files.writeAt(handle, 1, bytes([9]));
      final path = await files.close(handle);
      expect(path, OpfsFiles.pathOf('a.base'));
      expect(await files.length(path), 5);
      expect(await files.exists(path), isTrue);
      expect(await files.read(path, 1, 2), [9, 3]);
      expect(await files.read(path, 4, 10), [5], reason: 'short at the end');
    });

    test('create truncates, and delete and list agree', () async {
      final files = MemoryOpfsFiles();
      await files.close(await files.create('a'));
      final handle = await files.create('a');
      await files.append(handle, bytes([7]));
      final path = await files.close(handle);
      expect(await files.length(path), 1);
      expect(await files.list(), ['a']);
      await files.delete(path);
      await files.delete(path);
      expect(await files.exists(path), isFalse);
      expect(await files.list(), isEmpty);
    });

    test('a file still open stays out of a sweep, like a locked one', () async {
      final files = MemoryOpfsFiles();
      await files.create('open');
      await expectLater(
        files.delete(OpfsFiles.pathOf('open')),
        throwsStateError,
      );
    });

    test('a write past the end of the file is refused', () async {
      final files = MemoryOpfsFiles();
      final handle = await files.create('a');
      await expectLater(files.writeAt(handle, 0, bytes([1])), throwsRangeError);
    });
  });

  group('FallbackOpfsFiles', () {
    test('uses memory when the file system refuses', () async {
      final files = FallbackOpfsFiles(const _NoFileSystem());
      final handle = await files.create('a');
      await files.append(handle, bytes([1, 2, 3]));
      final path = await files.close(handle);
      expect(await files.read(path, 0, 3), [1, 2, 3]);
    });

    test('keeps the file system when it answers', () async {
      final files = FallbackOpfsFiles(const _WorkingFileSystem());
      expect(await files.list(), ['kept']);
    });
  });
}
