import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/sync/changeset_log/base_parse_client.dart';

File _writeBase(Directory dir, Map<String, dynamic> doc) {
  final f = File(p.join(dir.path, 'base.json'));
  f.writeAsStringSync(jsonEncode(doc));
  return f;
}

/// Test worker that throws before sending the 'ready' handshake (reaches the
/// main isolate as an `onError` message).
void _workerThrowsBeforeReady(List<Object> args) {
  throw StateError('boom before ready');
}

/// Test worker that exits without ever sending the 'ready' handshake.
void _workerSilentNoHandshake(List<Object> args) {
  // Intentionally no handshake: exercises the spawn timeout backstop.
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('s3base'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('spawns and disposes without hanging', () async {
    final f = _writeBase(tmp, {
      'exportedAt': 1,
      'deletions': <String, dynamic>{},
      'data': <String, dynamic>{},
    });
    final client = await BaseParseClient.spawn(f.path);
    await client.dispose();
  });

  test(
    'readScalarsAndDeletions returns exportedAt + deletions in file order',
    () async {
      final doc = {
        'exportedAt': 42,
        'deletions': {
          'dives': [
            {'id': 'd1', 'deletedAt': 100},
            {'id': 'd2', 'deletedAt': 200},
          ],
        },
        'data': {
          'dives': [
            {'id': 'a', 'updatedAt': 1},
          ],
        },
      };
      final f = _writeBase(tmp, doc);
      final client = await BaseParseClient.spawn(f.path);
      final r = await client.readScalarsAndDeletions();
      await client.dispose();

      expect(r.exportedAt, 42);
      expect(r.deletions.map((e) => e.table).toList(), ['dives', 'dives']);
      expect(r.deletions.map((e) => e.row['id']).toList(), ['d1', 'd2']);
    },
  );

  test(
    'readScalarsAndDeletions normalizes a legacy bare-string deletion row',
    () async {
      // Old bases encode a deletion as a bare JSON string id; the inline path
      // synthesizes {id, deletedAt: 0} for these. The worker must match, or
      // these peers crash _decodeRows (cast to Map) and lose the offload.
      final doc = {
        'exportedAt': 7,
        'deletions': {
          'dives': [
            'legacy-string-id',
            {'id': 'modern', 'deletedAt': 500},
          ],
        },
        'data': <String, dynamic>{},
      };
      final f = _writeBase(tmp, doc);
      final client = await BaseParseClient.spawn(f.path);
      final r = await client.readScalarsAndDeletions();
      await client.dispose();

      expect(r.deletions.map((e) => e.table).toList(), ['dives', 'dives']);
      expect(r.deletions[0].row['id'], 'legacy-string-id');
      expect(r.deletions[0].row['deletedAt'], 0);
      expect(r.deletions[1].row['id'], 'modern');
      expect(r.deletions[1].row['deletedAt'], 500);
    },
  );

  test(
    'dataRows streams filtered data rows in file order across batches',
    () async {
      final doc = {
        'exportedAt': 1,
        'deletions': <String, dynamic>{},
        'data': {
          'dives': [
            for (var i = 0; i < 1200; i++) {'id': 'd$i', 'updatedAt': i},
          ],
          'sites': [
            {'id': 's1', 'updatedAt': 1},
          ],
        },
      };
      final f = _writeBase(tmp, doc);
      final client = await BaseParseClient.spawn(f.path);

      client.startDataRows({'dives'});
      final got = <String>[];
      List<({String table, Map<String, dynamic> row})>? batch;
      while ((batch = await client.nextDataBatch()) != null) {
        for (final r in batch!) {
          expect(r.table, 'dives'); // 'sites' filtered out
          got.add(r.row['id'] as String);
        }
      }
      await client.dispose();

      expect(got.length, 1200);
      expect(got.first, 'd0');
      expect(
        got.last,
        'd1199',
      ); // order preserved across the 500-row boundaries
    },
  );

  test(
    'spawn rejects (does not hang) when the worker errors before handshake',
    () async {
      final f = _writeBase(tmp, {
        'exportedAt': 1,
        'deletions': <String, dynamic>{},
        'data': <String, dynamic>{},
      });
      // A worker error before 'ready' must surface as a thrown exception so the
      // caller falls back to inline -- never an unhandled LateInitializationError
      // that leaves the spawn Future hanging forever. The .timeout guard turns a
      // regression (hang) into a TimeoutException, failing this expectation.
      await expectLater(
        BaseParseClient.spawn(
          f.path,
          entryPoint: _workerThrowsBeforeReady,
        ).timeout(const Duration(seconds: 5)),
        throwsA(isA<BaseParseException>()),
      );
    },
  );

  test('spawn rejects when no handshake arrives within the timeout', () async {
    final f = _writeBase(tmp, {
      'exportedAt': 1,
      'deletions': <String, dynamic>{},
      'data': <String, dynamic>{},
    });
    await expectLater(
      BaseParseClient.spawn(
        f.path,
        entryPoint: _workerSilentNoHandshake,
        handshakeTimeout: const Duration(milliseconds: 300),
      ).timeout(const Duration(seconds: 5)),
      throwsA(isA<BaseParseException>()),
    );
  });
}
