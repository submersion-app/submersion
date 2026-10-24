import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_pack_spool.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_reader.dart';

import '../../../../helpers/git_cli.dart';

final _fixtures = p.join('test', 'fixtures', 'git');

Uint8List _fixture(String name) =>
    File(p.join(_fixtures, name)).readAsBytesSync();

/// [bytes] in pieces of [piece], as a network body arrives.
Stream<List<int>> _pieces(Uint8List bytes, int piece) async* {
  for (var i = 0; i < bytes.length; i += piece) {
    yield Uint8List.sublistView(bytes, i, min(i + piece, bytes.length));
  }
}

void main() {
  test('reads a pack from a stream and leaves no file behind', () async {
    final dir = tempDirForTest('git_spool_');
    final ids = await readSpooledPack(
      _pieces(_fixture('full.pack'), 333),
      MemoryGitObjectStore(),
      directory: dir,
    );
    expect(ids, await readPack(_fixture('full.pack'), MemoryGitObjectStore()));
    expect(dir.listSync(), isEmpty);
  });

  test('a stream that fails midway leaves no file behind', () async {
    final dir = tempDirForTest('git_spool_');
    Stream<List<int>> failing() async* {
      yield _fixture('full.pack').sublist(0, 100);
      throw GitException('dropped', code: GitErrorCode.unreachable);
    }

    await expectLater(
      readSpooledPack(failing(), MemoryGitObjectStore(), directory: dir),
      throwsA(
        isA<GitException>().having(
          (e) => e.code,
          'code',
          GitErrorCode.unreachable,
        ),
      ),
    );
    expect(dir.listSync(), isEmpty);
  });

  test('a corrupt pack leaves no file behind', () async {
    final dir = tempDirForTest('git_spool_');
    final pack = _fixture('full.pack');
    pack[pack.length - 1] ^= 0x01;
    await expectLater(
      readSpooledPack(
        _pieces(pack, 1000),
        MemoryGitObjectStore(),
        directory: dir,
      ),
      throwsA(isA<GitException>()),
    );
    expect(dir.listSync(), isEmpty);
  });

  test('is on disk while the stream is still arriving', () async {
    final dir = tempDirForTest('git_spool_');
    final pack = _fixture('full.pack');
    var sawFile = false;
    Stream<List<int>> watched() async* {
      for (var i = 0; i < pack.length; i += 64) {
        if (i > pack.length ~/ 2 && !sawFile) {
          // Let the pending write land, then look.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          final files = dir.listSync().whereType<File>();
          sawFile = files.any((f) => f.lengthSync() >= pack.length ~/ 4);
        }
        yield Uint8List.sublistView(pack, i, min(i + 64, pack.length));
      }
    }

    await readSpooledPack(watched(), MemoryGitObjectStore(), directory: dir);
    expect(sawFile, isTrue);
  });
}
