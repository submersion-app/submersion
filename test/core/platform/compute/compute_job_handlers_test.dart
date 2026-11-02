import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/compute/compute_job_handlers.dart';
import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

import 'memory_opfs_files.dart';

void main() {
  late MemoryOpfsFiles files;
  late ComputeJobHandler handler;

  setUp(() {
    files = MemoryOpfsFiles();
    handler = ComputeJobHandler(files: files, parseBatchSize: 2);
  });

  Uint8List sample(int length, [int seed = 1]) =>
      Uint8List.fromList(List.generate(length, (i) => (i * seed + 3) & 0xff));

  Future<Uint8List> store(String name, List<int> bytes) async {
    final handle = await handler.handle(ComputeJob.opfsCreate, {'name': name});
    await handler.handle(ComputeJob.opfsAppend, {
      'handle': handle,
      'bytes': Uint8List.fromList(bytes),
    });
    final path = await handler.handle(ComputeJob.opfsClose, {'handle': handle});
    expect(path, 'opfs://submersion-sync-tmp/$name');
    return Uint8List.fromList(bytes);
  }

  group('zlib jobs', () {
    test(
      'inflateBounded matches PlatformZlib and throws past maxBytes',
      () async {
        final body = sample(50000);
        final packed = PlatformZlib.deflate(body);
        final inflated = await handler.handle(ComputeJob.inflateBounded, {
          'bytes': packed,
          'maxBytes': body.length,
          'framing': 'zlib',
        });
        expect(inflated, body);
        expect(
          () => handler.handle(ComputeJob.inflateBounded, {
            'bytes': packed,
            'maxBytes': 1000,
            'framing': 'zlib',
          }),
          throwsA(isA<ZlibBoundExceeded>()),
        );
        final gz = PlatformZlib.gzip(body);
        expect(
          await handler.handle(ComputeJob.inflateBounded, {
            'bytes': gz,
            'maxBytes': body.length,
            'framing': 'gzip',
          }),
          body,
        );
      },
    );

    test('deflate, gzip and gunzip round-trip', () async {
      final body = sample(4000);
      final deflated =
          await handler.handle(ComputeJob.deflate, {'bytes': body, 'level': 6})
              as Uint8List;
      expect(PlatformZlib.inflate(deflated), body);
      final gzipped =
          await handler.handle(ComputeJob.gzip, {'bytes': body, 'level': 6})
              as Uint8List;
      expect(await handler.handle(ComputeJob.gunzip, {'bytes': gzipped}), body);
    });
  });

  group('crypto jobs', () {
    final key = sample(32, 5);
    final nonce = sample(12, 9);
    final aad = utf8.encode('header');

    test('aesGcm encrypt then decrypt returns the plaintext', () async {
      final plaintext = sample(10000);
      final sealed =
          await handler.handle(ComputeJob.aesGcmEncrypt, {
                'key': key,
                'nonce': nonce,
                'plaintext': plaintext,
                'aad': Uint8List.fromList(aad),
              })
              as Uint8List;
      expect(sealed.length, plaintext.length + 16);
      // The same bytes the library produces directly.
      final box = await DartAesGcm.with256bits().encrypt(
        plaintext,
        secretKey: SecretKeyData(key),
        nonce: nonce,
        aad: aad,
      );
      expect(sealed, [...box.cipherText, ...box.mac.bytes]);
      final opened = await handler.handle(ComputeJob.aesGcmDecrypt, {
        'key': key,
        'nonce': nonce,
        'ciphertextWithMac': sealed,
        'aad': Uint8List.fromList(aad),
      });
      expect(opened, plaintext);
    });

    test('a flipped byte fails authentication', () async {
      final sealed =
          await handler.handle(ComputeJob.aesGcmEncrypt, {
                'key': key,
                'nonce': nonce,
                'plaintext': sample(100),
              })
              as Uint8List;
      sealed[10] ^= 0xff;
      expect(
        () => handler.handle(ComputeJob.aesGcmDecrypt, {
          'key': key,
          'nonce': nonce,
          'ciphertextWithMac': sealed,
        }),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('argon2id matches DartArgon2id.deriveKeyFromPassword', () async {
      final salt = sample(16, 11);
      final derived = await handler.handle(ComputeJob.argon2id, {
        'password': Uint8List.fromList(utf8.encode('correct horse')),
        'salt': salt,
        'memoryKiB': 1024,
        'iterations': 3,
        'parallelism': 1,
        'hashLength': 32,
      });
      final expected = await const DartArgon2id(
        parallelism: 1,
        memory: 1024,
        iterations: 3,
        hashLength: 32,
      ).deriveKeyFromPassword(password: 'correct horse', nonce: salt);
      expect(derived, await expected.extractBytes());
    });

    test('sha256 matches package:crypto', () async {
      final body = sample(777);
      expect(
        await handler.handle(ComputeJob.sha256, {'bytes': body}),
        crypto.sha256.convert(body).bytes,
      );
    });
  });

  group('hash session', () {
    test(
      'part digests and the whole digest match BaseChunker and sha256',
      () async {
        final parts = [sample(3000, 2), sample(3000, 3), sample(100, 4)];
        final session = await handler.handle(ComputeJob.hashStart, const {});
        for (final part in parts) {
          final digest = await handler.handle(ComputeJob.hashAddPart, {
            'session': session,
            'bytes': part,
          });
          expect(digest, BaseChunker.checksum(part));
        }
        final whole = await handler.handle(ComputeJob.hashFinish, {
          'session': session,
        });
        final all = Uint8List.fromList([for (final p in parts) ...p]);
        expect(whole, 'sha256:${crypto.sha256.convert(all)}');
        await handler.handle(ComputeJob.hashDispose, {'session': session});
        expect(
          () => handler.handle(ComputeJob.hashAddPart, {
            'session': session,
            'bytes': parts.first,
          }),
          throwsStateError,
        );
      },
    );
  });

  group('opfs jobs', () {
    test('create, append, close, length, read, exists and delete', () async {
      final handle = await handler.handle(ComputeJob.opfsCreate, {
        'name': 'base.json',
      });
      await handler.handle(ComputeJob.opfsAppend, {
        'handle': handle,
        'bytes': Uint8List.fromList([1, 2, 3]),
      });
      await handler.handle(ComputeJob.opfsAppend, {
        'handle': handle,
        'bytes': Uint8List.fromList([4, 5]),
      });
      await handler.handle(ComputeJob.opfsWriteAt, {
        'handle': handle,
        'offset': 3,
        'bytes': Uint8List.fromList([9]),
      });
      final path = await handler.handle(ComputeJob.opfsClose, {
        'handle': handle,
      });
      expect(path, 'opfs://submersion-sync-tmp/base.json');
      expect(await handler.handle(ComputeJob.opfsLength, {'path': path}), 5);
      expect(
        await handler.handle(ComputeJob.opfsRead, {
          'path': path,
          'offset': 1,
          'length': 3,
        }),
        [2, 3, 9],
      );
      expect(
        await handler.handle(ComputeJob.opfsExists, {'path': path}),
        isTrue,
      );
      await handler.handle(ComputeJob.opfsDelete, {'path': path});
      expect(
        await handler.handle(ComputeJob.opfsExists, {'path': path}),
        isFalse,
      );
    });
  });

  group('base parse jobs', () {
    final doc = {
      'exportedAt': 1700000000000,
      'deletions': {
        'dives': [
          {'id': 'd9', 'deletedAt': 5},
          'legacy-id',
        ],
      },
      'data': {
        'dives': [
          for (var i = 0; i < 5; i++) {'id': 'd$i', 'maxDepth': 10 + i},
        ],
        'tanks': [
          {'id': 't1', 'diveId': 'd0'},
        ],
        'sites': [
          {'id': 's1'},
        ],
      },
    };

    test(
      'scalars and deletions come first, with legacy ids normalised',
      () async {
        await store('base.json', utf8.encode(jsonEncode(doc)));
        final scalars =
            await handler.handle(ComputeJob.baseParseScalars, {
                  'path': 'opfs://submersion-sync-tmp/base.json',
                })
                as Map;
        expect(scalars['exportedAt'], 1700000000000);
        expect(scalars['rows'], [
          {
            'table': 'dives',
            'row': {'id': 'd9', 'deletedAt': 5},
          },
          {
            'table': 'dives',
            'row': {'id': 'legacy-id', 'deletedAt': 0},
          },
        ]);
      },
    );

    test(
      'data rows stream in batches of the requested tables, then dispose',
      () async {
        await store('base.json', utf8.encode(jsonEncode(doc)));
        final session = await handler.handle(ComputeJob.baseParseStart, {
          'path': 'opfs://submersion-sync-tmp/base.json',
          'tables': ['dives', 'tanks'],
        });
        final batches = <List<Object?>>[];
        Map? last;
        while (true) {
          last =
              await handler.handle(ComputeJob.baseParseNext, {
                    'session': session,
                  })
                  as Map;
          batches.add(last['rows'] as List<Object?>);
          if (last['done'] == true) break;
        }
        // The closing batch is empty when the rows fill the last one exactly,
        // as with the isolate worker.
        expect(batches.map((b) => b.length), [2, 2, 2, 0]);
        final rows = batches.expand((b) => b).cast<Map>().toList();
        expect(rows.map((r) => r['table']).toSet(), {'dives', 'tanks'});
        expect(rows.length, 6);
        expect(last['total'], greaterThan(0));
        expect(last['bytes'], last['total']);
        await handler.handle(ComputeJob.baseParseDispose, {'session': session});
        expect(
          () => handler.handle(ComputeJob.baseParseNext, {'session': session}),
          throwsStateError,
        );
      },
    );

    test('a file that is not JSON fails the pass instead of hanging', () async {
      await store('bad.json', utf8.encode('{ not json'));
      expect(
        () => handler.handle(ComputeJob.baseParseScalars, {
          'path': 'opfs://submersion-sync-tmp/bad.json',
        }),
        throwsA(anything),
      );
    });
  });

  group('parse session lifecycle', () {
    final doc = {
      'data': {
        'dives': [
          for (var i = 0; i < 9; i++) {'id': 'd$i', 'maxDepth': 10 + i},
        ],
      },
    };

    test('disposing a session with a batch in flight ends its parse', () async {
      // Eight-byte reads keep the parse at an await when the dispose lands.
      final slow = ComputeJobHandler(
        files: files,
        parseBatchSize: 2,
        readChunkBytes: 8,
      );
      await store('base.json', utf8.encode(jsonEncode(doc)));
      final session = await slow.handle(ComputeJob.baseParseStart, {
        'path': 'opfs://submersion-sync-tmp/base.json',
        'tables': ['dives'],
      });
      // The expectation listens before the dispose errors the call, or the
      // error counts as unhandled.
      final inFlight = expectLater(
        slow.handle(ComputeJob.baseParseNext, {'session': session}),
        throwsStateError,
      );
      await slow
          .handle(ComputeJob.baseParseDispose, {'session': session})
          .timeout(const Duration(seconds: 2));
      await inFlight;
      // Nothing is parked on a resume that no caller will ever send.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(slow.runningParses, 0);
    });

    test('a second next while one is in flight is refused', () async {
      await store('base.json', utf8.encode(jsonEncode(doc)));
      final session = await handler.handle(ComputeJob.baseParseStart, {
        'path': 'opfs://submersion-sync-tmp/base.json',
        'tables': ['dives'],
      });
      final first = handler.handle(ComputeJob.baseParseNext, {
        'session': session,
      });
      await expectLater(
        handler.handle(ComputeJob.baseParseNext, {'session': session}),
        throwsStateError,
      );
      expect(((await first) as Map)['rows'], hasLength(2));
      await handler.handle(ComputeJob.baseParseDispose, {'session': session});
      expect(handler.runningParses, 0);
    });
  });

  group('opfs sweep', () {
    test('removes every closed file and leaves one still open', () async {
      await store('ssv1_old.json', [1, 2, 3]);
      await store('ssv1_older.json', [4]);
      final open = await handler.handle(ComputeJob.opfsCreate, {
        'name': 'ssv1_live.json',
      });
      await handler.handle(ComputeJob.opfsAppend, {
        'handle': open,
        'bytes': Uint8List.fromList([5]),
      });
      expect(await handler.handle(ComputeJob.opfsSweep, {}), 2);
      expect(await files.list(), ['ssv1_live.json']);
      final path = await handler.handle(ComputeJob.opfsClose, {'handle': open});
      expect(
        await handler.handle(ComputeJob.opfsExists, {'path': path}),
        isTrue,
      );
      expect(await handler.handle(ComputeJob.opfsSweep, {}), 1);
      expect(
        await handler.handle(ComputeJob.opfsExists, {'path': path}),
        isFalse,
      );
    });

    test('an empty directory sweeps to nothing', () async {
      expect(await handler.handle(ComputeJob.opfsSweep, {}), 0);
    });
  });
}
