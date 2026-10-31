import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher.dart';
import 'package:submersion/core/utils/off_isolate.dart';

// SHA-256 of 'abc', from FIPS 180-2.
const _abcDigest =
    'sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
// SHA-256 of no bytes.
const _emptyDigest =
    'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

/// Handshakes, then ignores every request.
void _neverReplies(SendPort client) {
  final rx = ReceivePort();
  client.send(rx.sendPort);
  rx.listen((_) {});
}

/// Dies before the handshake.
void _throwsAtStart(SendPort client) => throw StateError('no worker for you');

/// Stays alive and never handshakes.
void _neverHandshakes(SendPort client) {
  ReceivePort().listen((_) {});
}

Uint8List _bytes(int length, int seed) =>
    Uint8List.fromList(List.generate(length, (i) => (i * seed + seed) % 251));

void main() {
  for (final (name, firstPartBytes) in [
    ('inline', kOffIsolateMinBytes - 1),
    ('worker', kOffIsolateMinBytes),
  ]) {
    group('$name hasher', () {
      late BasePartHasher hasher;

      setUp(() async {
        hasher = await openBasePartHasher(firstPartBytes);
        addTearDown(hasher.dispose);
      });

      test('hashes a known vector', () async {
        final abc = Uint8List.fromList(utf8.encode('abc'));
        expect(await hasher.addPart(abc), _abcDigest);
        expect(await hasher.finish(), _abcDigest);
      });

      test('rolls the whole-file digest across parts', () async {
        final parts = [_bytes(1000, 3), _bytes(1000, 5), _bytes(17, 7)];
        final expected = [...parts[0], ...parts[1], ...parts[2]];
        for (final part in parts) {
          expect(await hasher.addPart(part), BaseChunker.checksum(part));
        }
        expect(
          await hasher.finish(),
          BaseChunker.checksum(Uint8List.fromList(expected)),
        );
      });

      test('an empty part hashes to the empty digest', () async {
        expect(await hasher.addPart(Uint8List(0)), _emptyDigest);
        expect(await hasher.finish(), _emptyDigest);
      });

      test('leaves the caller its bytes', () async {
        final part = _bytes(4096, 11);
        final before = Uint8List.fromList(part);
        await hasher.addPart(part);
        expect(part, before);
      });

      test('dispose is safe to repeat', () async {
        await hasher.dispose();
        await hasher.dispose();
      });
    });
  }

  test('a first part below the threshold uses no worker', () async {
    final hasher = await openBasePartHasher(kOffIsolateMinBytes - 1);
    addTearDown(hasher.dispose);
    expect(hasher, isNot(isA<WorkerBasePartHasher>()));
  });

  test('a first part at the threshold uses another isolate', () async {
    final hasher = await openBasePartHasher(kOffIsolateMinBytes);
    addTearDown(hasher.dispose);
    expect(hasher, isA<WorkerBasePartHasher>());
    expect(
      (hasher as WorkerBasePartHasher).debugIsolate.controlPort,
      isNot(Isolate.current.controlPort),
    );
  });

  test('two hashers keep their rolling state apart', () async {
    final a = await openBasePartHasher(kOffIsolateMinBytes);
    final b = await openBasePartHasher(kOffIsolateMinBytes);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final one = _bytes(500, 3);
    final two = _bytes(500, 5);
    await Future.wait([a.addPart(one), b.addPart(two)]);
    await Future.wait([a.addPart(two), b.addPart(one)]);
    expect(
      await a.finish(),
      BaseChunker.checksum(Uint8List.fromList([...one, ...two])),
    );
    expect(
      await b.finish(),
      BaseChunker.checksum(Uint8List.fromList([...two, ...one])),
    );
  });

  group('when the worker cannot start', () {
    test('a failed spawn falls back inline and reports it', () async {
      final reported = <Object>[];
      final hasher = await openBasePartHasher(
        kOffIsolateMinBytes,
        onWorkerUnavailable: reported.add,
        entryPoint: _throwsAtStart,
      );
      addTearDown(hasher.dispose);
      expect(hasher, isNot(isA<WorkerBasePartHasher>()));
      expect(reported, hasLength(1));
      final abc = Uint8List.fromList(utf8.encode('abc'));
      expect(await hasher.addPart(abc), _abcDigest);
    });

    test('an isolate that will not spawn falls back inline', () async {
      final unsendable = ReceivePort();
      addTearDown(unsendable.close);
      final reported = <Object>[];
      final hasher = await openBasePartHasher(
        kOffIsolateMinBytes,
        onWorkerUnavailable: reported.add,
        // A closure over a port cannot reach a new isolate, so spawn throws.
        entryPoint: (_) => unsendable.hashCode,
      );
      addTearDown(hasher.dispose);
      expect(hasher, isNot(isA<WorkerBasePartHasher>()));
      expect(reported, hasLength(1));
    });

    test('a silent worker falls back at the handshake timeout', () async {
      final hasher = await openBasePartHasher(
        kOffIsolateMinBytes,
        entryPoint: _neverHandshakes,
        handshakeTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(hasher.dispose);
      expect(hasher, isNot(isA<WorkerBasePartHasher>()));
    });
  });

  group('when the worker dies mid-transfer', () {
    Future<WorkerBasePartHasher> stuck({Duration? replyTimeout}) async {
      final hasher =
          await openBasePartHasher(
                kOffIsolateMinBytes,
                entryPoint: _neverReplies,
                replyTimeout: replyTimeout ?? const Duration(seconds: 60),
              )
              as WorkerBasePartHasher;
      addTearDown(hasher.dispose);
      return hasher;
    }

    test('killing it fails the call in flight promptly', () async {
      final hasher = await stuck();
      final pending = hasher.addPart(Uint8List(16));
      hasher.debugIsolate.kill(priority: Isolate.immediate);
      await expectLater(
        pending.timeout(const Duration(seconds: 5)),
        throwsA(isA<BasePartHasherException>()),
      );
    });

    test('a dead worker fails every later call', () async {
      final hasher = await stuck();
      final pending = hasher.addPart(Uint8List(16));
      hasher.debugIsolate.kill(priority: Isolate.immediate);
      await expectLater(pending, throwsA(isA<BasePartHasherException>()));
      await expectLater(
        hasher.addPart(Uint8List(16)),
        throwsA(isA<BasePartHasherException>()),
      );
      await expectLater(
        hasher.finish(),
        throwsA(isA<BasePartHasherException>()),
      );
    });

    test('a silent worker fails the call at the reply timeout', () async {
      final hasher = await stuck(
        replyTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        hasher.addPart(Uint8List(16)),
        throwsA(isA<BasePartHasherException>()),
      );
    });

    test('dispose is safe after a failure', () async {
      final hasher = await stuck(
        replyTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        hasher.addPart(Uint8List(16)),
        throwsA(isA<BasePartHasherException>()),
      );
      await hasher.dispose();
      await hasher.dispose();
    });
  });
}
