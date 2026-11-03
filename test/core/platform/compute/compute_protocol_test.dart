import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/zlib/platform_zlib.dart';

/// Requests and replies cross `postMessage`, which clones JSON scalars,
/// lists, maps and typed arrays and nothing else.
bool _isWireValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return true;
  }
  if (value is Uint8List) return true;
  if (value is List) return value.every(_isWireValue);
  if (value is Map) {
    return value.keys.every((k) => k is String) &&
        value.values.every(_isWireValue);
  }
  return false;
}

void main() {
  final bytes = Uint8List.fromList(List.generate(300, (i) => (i * 7) & 0xff));

  test('every ComputeJob round-trips a request with its bytes intact', () {
    for (final job in ComputeJob.values) {
      final request = ComputeRequest(
        id: job.index + 1,
        job: job,
        args: {'bytes': bytes, 'maxBytes': 1024, 'name': 'base.json'},
      );
      final json = request.toJson();
      expect(_isWireValue(json), isTrue, reason: '$job request');
      final back = ComputeRequest.fromJson(json);
      expect(back.id, request.id);
      expect(back.job, job);
      expect(back.args['bytes'], bytes);
      expect(back.args['bytes'], isA<Uint8List>());
      expect(back.args['maxBytes'], 1024);
      expect(back.args['name'], 'base.json');
    }
  });

  test('a reply round-trips a result, an error and a progress tick', () {
    final ok = ComputeReply(id: 3, result: bytes);
    final okBack = ComputeReply.fromJson(ok.toJson());
    expect(okBack.id, 3);
    expect(okBack.result, bytes);
    expect(okBack.error, isNull);

    const failed = ComputeReply(
      id: 4,
      error: 'bad data',
      errorKind: ComputeErrorKind.authentication,
    );
    final failedBack = ComputeReply.fromJson(failed.toJson());
    expect(failedBack.error, 'bad data');
    expect(failedBack.errorKind, ComputeErrorKind.authentication);

    const tick = ComputeReply.progress(id: 5, bytes: 10, total: 20);
    final tickBack = ComputeReply.fromJson(tick.toJson());
    expect(tickBack.isProgress, isTrue);
    expect(tickBack.progressBytes, 10);
    expect(tickBack.progressTotal, 20);
    expect(_isWireValue(tick.toJson()), isTrue);
  });

  test('the non-binary part of a request is plain JSON', () {
    const request = ComputeRequest(
      id: 1,
      job: ComputeJob.baseParseStart,
      args: {
        'path': 'opfs://submersion-sync-tmp/base.json',
        'tables': ['dives', 'tanks'],
      },
    );
    final text = jsonEncode(request.toJson());
    final back = ComputeRequest.fromJson(
      jsonDecode(text) as Map<String, Object?>,
    );
    expect(back.job, ComputeJob.baseParseStart);
    expect(back.args['tables'], ['dives', 'tanks']);
  });

  test('known exceptions survive the wire as the same types', () {
    final cases = <Object>[
      SecretBoxAuthenticationError(),
      const ZlibBoundExceeded(4096),
      const ZlibFormatException('not a zlib stream'),
      StateError('session gone'),
      ArgumentError('bad'),
    ];
    for (final error in cases) {
      final kind = computeErrorKindOf(error);
      final back = computeErrorFromWire(kind, error.toString(), const {
        'maxBytes': 4096,
      });
      expect(back.runtimeType, error.runtimeType, reason: '$error');
    }
    expect(
      computeErrorKindOf(const ZlibBoundExceeded(1)),
      ComputeErrorKind.bound,
    );
    expect(
      computeErrorKindOf(SecretBoxAuthenticationError()),
      ComputeErrorKind.authentication,
    );
    expect(computeErrorKindOf(Exception('x')), ComputeErrorKind.other);
    expect(
      computeErrorFromWire(ComputeErrorKind.other, 'x', const {}),
      isA<ComputeJobException>(),
    );
  });
}
