import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart' show InputMemoryStream;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_delta_stream.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_inflater.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_reader.dart';

import '../../../../helpers/git_cli.dart';
import '../../../../helpers/git_recording_store.dart';

final _fixtures = p.join('test', 'fixtures', 'git');

Uint8List _fixture(String name) =>
    File(p.join(_fixtures, name)).readAsBytesSync();

Uint8List _random(int length, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
}

// ---- Hand-built deltas and packs --------------------------------------------

List<int> _varint(int value) {
  final out = <int>[];
  var v = value;
  while (v >= 0x80) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return out;
}

List<int> _copy(int offset, int size) {
  var cmd = 0x80;
  final args = <int>[];
  for (var i = 0; i < 4; i++) {
    final b = (offset >> (8 * i)) & 0xff;
    if (b != 0) {
      cmd |= 1 << i;
      args.add(b);
    }
  }
  // A size of 0x10000 is written as no size bytes at all.
  final encoded = size == 0x10000 ? 0 : size;
  for (var i = 0; i < 3; i++) {
    final b = (encoded >> (8 * i)) & 0xff;
    if (b != 0) {
      cmd |= 0x10 << i;
      args.add(b);
    }
  }
  return [cmd, ...args];
}

List<int> _insert(List<int> data) => [data.length, ...data];

Uint8List _delta(int baseSize, int targetSize, List<List<int>> commands) =>
    Uint8List.fromList([
      ..._varint(baseSize),
      ..._varint(targetSize),
      for (final c in commands) ...c,
    ]);

List<int> _entryHeader(int type, int size) {
  final out = <int>[];
  var rest = size >> 4;
  var byte = (type << 4) | (size & 0x0f);
  while (rest > 0) {
    out.add(byte | 0x80);
    byte = rest & 0x7f;
    rest >>= 7;
  }
  out.add(byte);
  return out;
}

List<int> _whole(GitObjectType type, List<int> body) => [
  ..._entryHeader(type.packCode, body.length),
  ...ZLibEncoder().convert(body),
];

List<int> _refDelta(GitObjectId base, List<int> delta) => [
  ..._entryHeader(7, delta.length),
  ...base.bytes,
  ...ZLibEncoder().convert(delta),
];

List<int> _ofsDelta(int distance, List<int> delta) {
  final offset = <int>[distance & 0x7f];
  var d = distance >> 7;
  while (d > 0) {
    d -= 1;
    offset.insert(0, 0x80 | (d & 0x7f));
    d >>= 7;
  }
  return [
    ..._entryHeader(6, delta.length),
    ...offset,
    ...ZLibEncoder().convert(delta),
  ];
}

Uint8List _pack(List<List<int>> entries) {
  final body = BytesBuilder()
    ..add(ascii.encode('PACK'))
    ..add([0, 0, 0, 2])
    ..add((ByteData(4)..setUint32(0, entries.length)).buffer.asUint8List());
  for (final e in entries) {
    body.add(e);
  }
  final bytes = body.takeBytes();
  return Uint8List.fromList([...bytes, ...sha1.convert(bytes).bytes]);
}

/// A pack whose first entry is a REF_DELTA against the blob after it, and
/// whose third is an OFS_DELTA against that first one.
({Uint8List pack, List<Uint8List> bodies}) _outOfOrderPack() {
  final base = _random(5000, 1);
  final baseId = hashGitObject(GitObjectType.blob, base);
  final first = Uint8List.fromList([
    ...Uint8List.sublistView(base, 0, 2000),
    ...utf8.encode('hello'),
  ]);
  final third = Uint8List.fromList([
    ...Uint8List.sublistView(first, 5, 2005),
    ...utf8.encode('!'),
  ]);
  final e1 = _refDelta(
    baseId,
    _delta(base.length, first.length, [
      _copy(0, 2000),
      _insert(utf8.encode('hello')),
    ]),
  );
  final e2 = _whole(GitObjectType.blob, base);
  final e3 = _ofsDelta(
    e1.length + e2.length,
    _delta(first.length, third.length, [
      _copy(5, 2000),
      _insert([0x21]),
    ]),
  );
  return (pack: _pack([e1, e2, e3]), bodies: [first, base, third]);
}

Future<Uint8List> _gitPackOf(Directory repo) async {
  final process = await Process.start(
    'git',
    ['pack-objects', '--stdout', '--revs', '--delta-base-offset', '-q'],
    workingDirectory: repo.path,
    environment: fixedGitEnv,
  );
  process.stdin.writeln('HEAD');
  await process.stdin.close();
  final out = BytesBuilder(copy: false);
  final drained = process.stdout.forEach(out.add);
  final err = process.stderr.transform(utf8.decoder).join();
  final code = await process.exitCode;
  await drained;
  expect(code, 0, reason: await err);
  return out.takeBytes();
}

void main() {
  group('inflateStreamAt', () {
    test('hands over the bytes in pieces and the exact stream length', () {
      final out = BytesBuilder();
      final starts = <int>[];
      final payloads = <Uint8List>[];
      for (var i = 0; i < 50; i++) {
        final body = _random(i * 997, i);
        starts.add(out.length);
        payloads.add(body);
        out.add(ZLibEncoder().convert(body));
      }
      final buf = out.takeBytes();
      final input = InputMemoryStream(buf);
      for (var i = 0; i < 50; i++) {
        final got = BytesBuilder();
        final r = inflateStreamAt(
          input,
          starts[i],
          expectedSize: payloads[i].length,
          onData: got.add,
        );
        expect(got.takeBytes(), payloads[i], reason: 'stream $i');
        expect(r.size, payloads[i].length);
        final end = i + 1 < 50 ? starts[i + 1] : buf.length;
        expect(r.consumed, end - starts[i], reason: 'stream $i');
      }
    });

    test('never hands over more than about a megabyte at once', () {
      // Compressible, so back-references reach across piece boundaries.
      final body = Uint8List.fromList([
        for (var i = 0; i < 5 * 1024 * 1024; i++) (i ~/ 3000) % 251,
      ]);
      final buf = Uint8List.fromList(ZLibEncoder().convert(body));
      var largest = 0;
      final got = BytesBuilder(copy: false);
      inflateStreamAt(
        InputMemoryStream(buf),
        0,
        expectedSize: body.length,
        onData: (chunk) {
          largest = max(largest, chunk.length);
          got.add(chunk);
        },
      );
      expect(sha1.convert(got.takeBytes()), sha1.convert(body));
      expect(largest, lessThanOrEqualTo(1024 * 1024));
    });

    test('an error from the receiver comes out as itself', () {
      final buf = Uint8List.fromList(ZLibEncoder().convert(_random(5000, 9)));
      expect(
        () => inflateStreamAt(
          InputMemoryStream(buf),
          0,
          onData: (_) => throw const FileSystemException('disk full'),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('a wrong declared size is a corrupt pack', () {
      final buf = Uint8List.fromList(ZLibEncoder().convert(_random(500, 9)));
      expect(
        () => inflateStreamAt(
          InputMemoryStream(buf),
          0,
          expectedSize: 501,
          onData: (_) {},
        ),
        throwsA(isA<GitException>()),
      );
    });
  });

  group('GitDeltaStream', () {
    final base = _random(200000, 3);
    final delta = _delta(base.length, 70000 + 100 + 0x10000 + 50000, [
      _copy(0, 70000),
      _insert(_random(100, 4)),
      _copy(100000, 0x10000),
      _copy(150000, 50000),
    ]);
    final expected = applyGitDelta(base, delta);

    Future<GitObjectId> run(GitObjectStore store, int piece) async {
      final baseId = hashGitObject(GitObjectType.blob, base);
      await store.put(
        GitStoredObject(id: baseId, type: GitObjectType.blob, body: base),
      );
      final reader = (await store.open(baseId))!;
      try {
        final stream = GitDeltaStream(reader, store.create);
        for (var i = 0; i < delta.length; i += piece) {
          stream.add(
            Uint8List.sublistView(delta, i, min(i + piece, delta.length)),
          );
        }
        return await stream.close();
      } finally {
        await reader.close();
      }
    }

    for (final piece in [1, 7, 1 << 20]) {
      test(
        'fed $piece bytes at a time gives what applyGitDelta gives',
        () async {
          final store = MemoryGitObjectStore();
          final id = await run(store, piece);
          expect(id, hashGitObject(GitObjectType.blob, expected));
          expect((await store.get(id))!.body, expected);
        },
      );
    }

    Future<void> expectCorrupt(Uint8List bad) async {
      final store = MemoryGitObjectStore();
      final baseId = hashGitObject(GitObjectType.blob, base);
      await store.put(
        GitStoredObject(id: baseId, type: GitObjectType.blob, body: base),
      );
      final reader = (await store.open(baseId))!;
      final stream = GitDeltaStream(reader, store.create);
      await expectLater(() async {
        stream.add(bad);
        await stream.close();
      }(), throwsA(isA<GitException>()));
      await stream.abort();
      await reader.close();
    }

    test('a delta for another base is a corrupt pack', () async {
      await expectCorrupt(_delta(base.length + 1, 10, [_copy(0, 10)]));
    });

    test('a delta cut short is a corrupt pack', () async {
      await expectCorrupt(Uint8List.sublistView(delta, 0, delta.length - 3));
    });

    test('a copy past the end of the base is a corrupt pack', () async {
      await expectCorrupt(
        _delta(base.length, 10, [_copy(base.length - 5, 10)]),
      );
    });

    test('the reserved opcode is a corrupt pack', () async {
      await expectCorrupt(
        _delta(base.length, 1, [
          [0],
        ]),
      );
    });

    test('an insert past the declared result is a corrupt pack', () async {
      await expectCorrupt(
        _delta(base.length, 2, [
          _insert([1, 2, 3]),
        ]),
      );
    });
  });

  group('readPack, streaming every object', () {
    test('stores what stock git packed, each self-hashing', () async {
      final store = MemoryGitObjectStore();
      final ids = await readPack(
        _fixture('full.pack'),
        store,
        inMemoryLimit: 0,
      );
      final inMemory = await readPack(
        _fixture('full.pack'),
        MemoryGitObjectStore(),
      );
      expect(ids, inMemory);
      for (final id in ids) {
        final object = (await store.get(id))!;
        expect(hashGitObject(object.type, object.body), id);
      }
    });

    test('resolves a thin pack against objects already stored', () async {
      final store = MemoryGitObjectStore();
      await readPack(_fixture('full.pack'), store, inMemoryLimit: 0);
      final ids = await readPack(
        _fixture('thin_refdelta.pack'),
        store,
        inMemoryLimit: 0,
      );
      final expected = MemoryGitObjectStore();
      await readPack(_fixture('full.pack'), expected);
      expect(ids, await readPack(_fixture('thin_refdelta.pack'), expected));
    });
  });

  group('readPack, deltas before their bases', () {
    for (final limit in [kGitInMemoryObjectLimit, 0]) {
      test('resolve in any order (in-memory limit $limit)', () async {
        final built = _outOfOrderPack();
        final store = MemoryGitObjectStore();
        final ids = await readPack(built.pack, store, inMemoryLimit: limit);
        expect(ids, [
          for (final b in built.bodies) hashGitObject(GitObjectType.blob, b),
        ]);
        for (var i = 0; i < ids.length; i++) {
          expect((await store.get(ids[i]))!.body, built.bodies[i]);
        }
      });
    }

    test('a delta against an object nobody has throws', () async {
      final absent = hashGitObject(GitObjectType.blob, [1, 2, 3]);
      final pack = _pack([
        _refDelta(absent, _delta(3, 1, [_copy(0, 1)])),
      ]);
      await expectLater(
        readPack(pack, MemoryGitObjectStore()),
        throwsA(isA<GitDeltaBaseMissingException>()),
      );
    });

    test('a delta against an offset that is no entry throws', () async {
      final pack = _pack([
        _whole(GitObjectType.blob, [1, 2, 3]),
        _ofsDelta(3, _delta(3, 1, [_copy(0, 1)])),
      ]);
      await expectLater(
        readPack(pack, MemoryGitObjectStore()),
        throwsA(isA<GitException>()),
      );
    });
  });

  test('readPackFile reads what readPack reads, from disk', () async {
    final dir = tempDirForTest('git_pack_file_');
    final file = File(p.join(dir.path, 'x.pack'))
      ..writeAsBytesSync(_fixture('full.pack'));
    final ids = await readPackFile(file, MemoryGitObjectStore());
    expect(ids, await readPack(_fixture('full.pack'), MemoryGitObjectStore()));
  });

  test(
    'large deltas from stock git resolve on disk, never whole in memory',
    () async {
      final repo = tempDirForTest('git_large_pack_');
      await runGit(repo, ['init', '-q', '-b', 'main', '.']);
      final a = _random(3 * 1024 * 1024, 11);
      final b = Uint8List.fromList(a)
        ..setRange(1500000, 1500100, _random(100, 12));
      Directory(p.join(repo.path, 'x')).createSync();
      Directory(p.join(repo.path, 'y')).createSync();
      File(p.join(repo.path, 'x', 'data.bin')).writeAsBytesSync(a);
      File(p.join(repo.path, 'y', 'data.bin')).writeAsBytesSync(b);
      await runGit(repo, ['add', '.']);
      await runGit(repo, ['commit', '-q', '-m', 'two similar files']);
      final dir = tempDirForTest('git_large_pack_');
      final packFile = File(p.join(dir.path, 'big.pack'))
        ..writeAsBytesSync(await _gitPackOf(repo));

      const limit = 64 * 1024;
      final store = RecordingGitObjectStore(
        FileGitObjectStore(tempDirForTest('git_large_store_')),
      );
      await readPackFile(packFile, store, inMemoryLimit: limit);

      final aId = hashGitObject(GitObjectType.blob, a);
      final bId = hashGitObject(GitObjectType.blob, b);
      expect(await store.has(aId), isTrue);
      expect(await store.has(bId), isTrue);
      // One of the two arrived as a delta whose base was read in pieces.
      expect(store.openedLengths, contains(a.length));
      expect(store.largestWholeBody, lessThanOrEqualTo(limit));
      expect(store.largestWriterChunk, lessThanOrEqualTo(1024 * 1024));
      expect(store.largestReaderChunk, lessThanOrEqualTo(1024 * 1024));
    },
    skip: skipUnlessGit(),
  );
}
