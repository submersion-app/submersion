import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_json_weight.dart';
import 'package:submersion/core/utils/off_isolate.dart';

/// A real isolate that keeps count. runOffIsolate reruns anything a worker
/// could not do on this isolate, so a closure that drags the database along
/// would still give the right answer here. [failures] is what tells them apart.
class _Hops {
  var count = 0;
  final failures = <Object>[];

  Future<R> run<R>(FutureOr<R> Function() work) async {
    count++;
    try {
      return await Isolate.run(work);
    } catch (e) {
      failures.add(e);
      rethrow;
    }
  }
}

Future<R> _neverHops<R>(FutureOr<R> Function() work) =>
    throw StateError('this payload should have stayed on this isolate');

const _hlcA = '000000000000005:000000:aaa';
const _hlcB = '000000000000009:000000:bbb';

SyncPayload _payload({List<Map<String, dynamic>>? dives}) {
  final data = SyncData.fromJson({
    'dives':
        dives ??
        [
          {
            'id': 'd1',
            'notes': 'Zürich "quoted" line\nbreak',
            'maxDepth': 30.5,
            'diveNumber': 12,
            'rating': null,
            'hlc': _hlcA,
          },
        ],
    'tags': [
      {'id': 't1', 'name': 'wreck', 'hlc': _hlcB},
    ],
  });
  return SyncPayload(
    version: syncFormatVersion,
    exportedAt: 1700000000000,
    deviceId: 'device-1',
    lastSyncTimestamp: 1600000000000,
    checksum: SyncDataSerializer.checksumOf(data),
    data: data,
    deletions: const {
      'dives': [
        SyncDeletion(id: 'gone', deletedAt: 5, hlc: _hlcA),
        SyncDeletion(id: 'gone-legacy', deletedAt: 6),
      ],
      'tags': [],
    },
    uploadNonce: 'nonce-1',
    epochId: 'epoch-1',
    seq: 7,
    baseSeq: 3,
    sinceHlc: _hlcA,
    toHlc: _hlcB,
  );
}

SyncPayload _largePayload() => _payload(
  dives: [
    {'id': 'blob', 'notes': 'x' * kOffIsolateMinBytes, 'hlc': _hlcA},
  ],
);

Uint8List _documentBytes(Map<String, dynamic> document) =>
    Uint8List.fromList(utf8.encode(jsonEncode(document)));

void main() {
  group('encodeChangeset', () {
    test('writes exactly what jsonEncode of the payload writes', () async {
      final payload = _payload();
      final hops = _Hops();

      final inline = await const ChangesetCodec().encodeChangeset(payload);
      final viaWorker = await ChangesetCodec(
        offIsolateMinBytes: 0,
        offIsolateRunner: hops.run,
      ).encodeChangeset(payload);

      final expected = utf8.encode(jsonEncode(payload.toJson()));
      expect(inline, expected);
      expect(viaWorker, expected);
      expect(hops.count, 1);
      expect(hops.failures, isEmpty);
    });

    test('a small payload stays on this isolate', () async {
      await const ChangesetCodec(
        offIsolateRunner: _neverHops,
      ).encodeChangeset(_payload());
    });

    test('a payload past the threshold goes to a worker', () async {
      final hops = _Hops();

      await ChangesetCodec(
        offIsolateRunner: hops.run,
      ).encodeChangeset(_largePayload());

      expect(hops.count, 1);
      expect(hops.failures, isEmpty);
    });

    test('many small rows count as much as one large one', () async {
      final hops = _Hops();
      final rows = [
        for (var i = 0; i < kOffIsolateMinBytes ~/ 20; i++)
          {'id': 'row-$i', 'hlc': _hlcA},
      ];

      await ChangesetCodec(
        offIsolateRunner: hops.run,
      ).encodeChangeset(_payload(dives: rows));

      expect(hops.count, 1);
      expect(hops.failures, isEmpty);
    });

    test('a worker that fails falls back to this isolate', () async {
      Future<R> broken<R>(FutureOr<R> Function() work) =>
          throw StateError('no isolate today');
      final payload = _payload();

      final bytes = await ChangesetCodec(
        offIsolateMinBytes: 0,
        offIsolateRunner: broken,
      ).encodeChangeset(payload);

      expect(bytes, utf8.encode(jsonEncode(payload.toJson())));
    });
  });

  group('decodeVerifiedChangeset', () {
    Future<VerifiedChangeset> viaWorker(Uint8List bytes, _Hops hops) =>
        ChangesetCodec(
          offIsolateMinBytes: 0,
          offIsolateRunner: hops.run,
        ).decodeVerifiedChangeset(bytes);

    test('a worker hands back the whole payload, verified', () async {
      final sent = _payload();
      final bytes = await const ChangesetCodec().encodeChangeset(sent);
      final hops = _Hops();

      final decoded = await viaWorker(bytes, hops);

      expect(hops.count, 1);
      expect(hops.failures, isEmpty);
      expect(decoded.checksumValid, isTrue);
      final got = decoded.payload;
      expect(got.version, sent.version);
      expect(got.exportedAt, sent.exportedAt);
      expect(got.deviceId, sent.deviceId);
      expect(got.lastSyncTimestamp, sent.lastSyncTimestamp);
      expect(got.checksum, sent.checksum);
      expect(got.uploadNonce, sent.uploadNonce);
      expect(got.epochId, sent.epochId);
      expect(got.seq, sent.seq);
      expect(got.baseSeq, sent.baseSeq);
      expect(got.sinceHlc, sent.sinceHlc);
      expect(got.toHlc, sent.toHlc);
      expect(got.data.dives, sent.data.dives);
      expect(got.data.tags, sent.data.tags);
      expect(got.deletions.keys, ['dives', 'tags']);
      expect(got.deletions['dives']!.map((d) => (d.id, d.deletedAt, d.hlc)), [
        ('gone', 5, _hlcA),
        ('gone-legacy', 6, null),
      ]);
    });

    test('this isolate and a worker agree on what was received', () async {
      final bytes = await const ChangesetCodec().encodeChangeset(_payload());

      final inline = await const ChangesetCodec().decodeVerifiedChangeset(
        bytes,
      );
      final remote = await viaWorker(bytes, _Hops());

      expect(remote.checksumValid, inline.checksumValid);
      expect(remote.payload.rawDataJson, inline.payload.rawDataJson);
      expect(remote.payload.toJson(), inline.payload.toJson());
    });

    test('tampered data fails the checksum, not the decode', () async {
      final document = _payload().toJson();
      final data = document['data'] as Map<String, dynamic>;
      final tampered = [
        {'id': 'd1', 'notes': 'not what was signed', 'hlc': _hlcA},
      ];
      document['data'] = {...data, 'dives': tampered};
      final bytes = _documentBytes(document);

      final inline = await const ChangesetCodec().decodeVerifiedChangeset(
        bytes,
      );
      final remote = await viaWorker(bytes, _Hops());

      expect(inline.checksumValid, isFalse);
      expect(remote.checksumValid, isFalse);
      expect(remote.payload.data.dives, tampered);
    });

    test('a writer with other entity keys and key order validates', () async {
      // The writer's own bytes are what the checksum covers: a key this build
      // has never heard of, keys it does know left out, and an order that is
      // not SyncData.toJson's.
      final data = <String, dynamic>{
        'zFutureEntity': [
          {
            'id': 'f1',
            'nested': <String, dynamic>{'b': 1, 'a': 2},
          },
        ],
        'tags': [
          {'name': 'wreck', 'id': 't1'},
        ],
        'dives': [
          {'hlc': _hlcA, 'id': 'd1'},
        ],
      };
      final dataJson = jsonEncode(data);
      final bytes = _documentBytes({
        'version': syncFormatVersion,
        'exportedAt': 1,
        'deviceId': 'peer',
        'checksum': sha256.convert(utf8.encode(dataJson)).toString(),
        'data': data,
        'deletions': <String, dynamic>{},
      });

      final inline = await const ChangesetCodec().decodeVerifiedChangeset(
        bytes,
      );
      final remote = await viaWorker(bytes, _Hops());

      expect(inline.checksumValid, isTrue);
      expect(remote.checksumValid, isTrue);
      expect(remote.payload.rawDataJson, dataJson);
    });

    test('a legacy bare-string deletion survives the hop', () async {
      final data = SyncData.fromJson(const {});
      final bytes = _documentBytes({
        'version': syncFormatVersion,
        'exportedAt': 1,
        'deviceId': 'peer',
        'checksum': SyncDataSerializer.checksumOf(data),
        'data': data.toJson(),
        'deletions': {
          'dives': ['old-id'],
        },
      });

      final remote = await viaWorker(bytes, _Hops());

      expect(remote.checksumValid, isTrue);
      expect(remote.payload.deletions['dives']!.single.id, 'old-id');
    });

    test('bytes that are not JSON throw as they do inline', () async {
      final bytes = Uint8List.fromList(utf8.encode('not json'));

      await expectLater(
        const ChangesetCodec().decodeVerifiedChangeset(bytes),
        throwsFormatException,
      );
      await expectLater(viaWorker(bytes, _Hops()), throwsFormatException);
    });

    test('a malformed document is not decoded a second time here', () async {
      final bytes = Uint8List.fromList(utf8.encode('not json'));
      Future<R> rejecting<R>(FutureOr<R> Function() work) =>
          throw const FormatException('from the worker');

      await expectLater(
        ChangesetCodec(
          offIsolateMinBytes: 0,
          offIsolateRunner: rejecting,
        ).decodeVerifiedChangeset(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'from the worker',
          ),
        ),
      );
    });

    test('small bytes stay on this isolate', () async {
      final bytes = await const ChangesetCodec().encodeChangeset(_payload());

      final decoded = await const ChangesetCodec(
        offIsolateRunner: _neverHops,
      ).decodeVerifiedChangeset(bytes);

      expect(decoded.checksumValid, isTrue);
    });

    test('bytes past the threshold go to a worker', () async {
      final bytes = await const ChangesetCodec().encodeChangeset(
        _largePayload(),
      );
      final hops = _Hops();

      final decoded = await ChangesetCodec(
        offIsolateRunner: hops.run,
      ).decodeVerifiedChangeset(bytes);

      expect(hops.count, 1);
      expect(hops.failures, isEmpty);
      expect(decoded.checksumValid, isTrue);
    });
  });

  group('decodeChangeset', () {
    test('a worker hands back the payload without judging it', () async {
      final document = _payload().toJson();
      document['checksum'] = 'not the checksum';
      final hops = _Hops();

      final payload = await ChangesetCodec(
        offIsolateMinBytes: 0,
        offIsolateRunner: hops.run,
      ).decodeChangeset(_documentBytes(document));

      expect(hops.count, 1);
      expect(hops.failures, isEmpty);
      expect(payload.seq, 7);
      expect(SyncDataSerializer.checksumIsValid(payload), isFalse);
    });
  });

  group('checksumOfOffIsolate', () {
    test('a worker computes the same checksum as this isolate', () async {
      final data = _payload().data;
      final hops = _Hops();

      final remote = await SyncDataSerializer.checksumOfOffIsolate(
        data,
        minBytes: 0,
        runner: hops.run,
      );

      expect(remote, SyncDataSerializer.checksumOf(data));
      expect(hops.count, 1);
      expect(hops.failures, isEmpty);
    });

    test('small data stays on this isolate', () async {
      final data = _payload().data;

      final checksum = await SyncDataSerializer.checksumOfOffIsolate(
        data,
        runner: _neverHops,
      );

      expect(checksum, SyncDataSerializer.checksumOf(data));
    });

    test('large data goes to a worker', () async {
      final hops = _Hops();

      await SyncDataSerializer.checksumOfOffIsolate(
        _largePayload().data,
        runner: hops.run,
      );

      expect(hops.count, 1);
      expect(hops.failures, isEmpty);
    });
  });

  group('syncJsonWeight', () {
    test('counts strings, keys and other values', () {
      final weight = syncJsonWeight(const {
        'rows': [
          {'id': 'abc', 'n': 1},
        ],
      }, limit: 1 << 30);

      // Each string also pays for its quotes and separator.
      expect(weight, greaterThanOrEqualTo('rows'.length + 'id'.length + 3 + 1));
      expect(weight, lessThan(100));
    });

    test('stops walking once it reaches the limit', () {
      var visited = 0;
      final rows = Iterable<Object?>.generate(1000000, (i) {
        visited++;
        return 'aaaaaaa';
      });

      final weight = syncJsonWeight(rows, limit: 1000);

      expect(weight, greaterThanOrEqualTo(1000));
      expect(visited, lessThan(1000));
    });
  });
}
