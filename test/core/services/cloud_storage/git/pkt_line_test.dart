import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/pkt_line.dart';

/// Delivers [bytes] one byte per chunk, the worst case for a framer.
Stream<List<int>> _byteByByte(List<int> bytes) =>
    Stream.fromIterable(bytes.map((b) => [b]));

Future<List<Pkt>> _readAll(PktLineReader reader) async {
  final out = <Pkt>[];
  while (true) {
    final pkt = await reader.next();
    if (pkt == null) return out;
    out.add(pkt);
  }
}

Uint8List _band(int band, String payload) =>
    pktData([band, ...utf8.encode(payload)]);

void main() {
  group('encoding', () {
    test('a text line carries its length in hex and a trailing newline', () {
      expect(
        ascii.decode(pktText('# service=git-upload-pack')),
        '001e# service=git-upload-pack\n',
      );
    });

    test('markers are their four-byte codes', () {
      expect(ascii.decode(pktFlushBytes), '0000');
      expect(ascii.decode(pktDelimBytes), '0001');
    });
  });

  group('PktLineReader', () {
    test('splits a byte-at-a-time stream into the same packets', () async {
      final bytes = [
        ...pktText('version 2'),
        ...pktDelimBytes,
        ...pktText('agent=git/2.47'),
        ...pktFlushBytes,
        ...ascii.encode('0002'),
      ];
      final packets = await _readAll(PktLineReader(_byteByByte(bytes)));
      expect(packets, hasLength(5));
      expect((packets[0] as PktData).text, 'version 2');
      expect(packets[1], isA<PktDelim>());
      expect((packets[2] as PktData).text, 'agent=git/2.47');
      expect(packets[3], isA<PktFlush>());
      expect(packets[4], isA<PktResponseEnd>());
    });

    test('a length below four that is not a marker is malformed', () async {
      final reader = PktLineReader(Stream.value(ascii.encode('0003')));
      await expectLater(
        reader.next(),
        throwsA(
          isA<GitException>().having(
            (e) => e.code,
            'code',
            GitErrorCode.unexpected,
          ),
        ),
      );
    });

    test('a length above 65520 is malformed', () async {
      final reader = PktLineReader(Stream.value(ascii.encode('fff1')));
      await expectLater(reader.next(), throwsA(isA<GitException>()));
    });

    test('a stream that ends inside a packet is malformed', () async {
      final reader = PktLineReader(Stream.value(ascii.encode('000ahel')));
      await expectLater(reader.next(), throwsA(isA<GitException>()));
    });

    test('readRemaining returns the bytes after the last packet', () async {
      final reader = PktLineReader(
        _byteByByte([...pktText('NAK'), ...ascii.encode('PACKrest')]),
      );
      expect((await reader.next() as PktData).text, 'NAK');
      expect(ascii.decode(await reader.readRemaining()), 'PACKrest');
    });
  });

  group('demuxSideBand', () {
    test('yields band 1 in order and sends band 2 to onProgress', () async {
      final progress = <String>[];
      final reader = PktLineReader(
        Stream.value([
          ..._band(2, 'Counting objects'),
          ..._band(1, 'PA'),
          ..._band(1, 'CK'),
          ...pktFlushBytes,
        ]),
      );
      final data = await demuxSideBand(
        reader,
        onProgress: progress.add,
      ).expand((chunk) => chunk).toList();
      expect(ascii.decode(data), 'PACK');
      expect(progress, ['Counting objects']);
    });

    test('band 3 throws a server error carrying its message', () async {
      final reader = PktLineReader(
        Stream.value([
          ..._band(3, 'repository is read-only'),
          ...pktFlushBytes,
        ]),
      );
      await expectLater(
        demuxSideBand(reader).toList(),
        throwsA(
          isA<GitException>()
              .having((e) => e.code, 'code', GitErrorCode.server)
              .having(
                (e) => e.serverReason,
                'reason',
                'repository is read-only',
              ),
        ),
      );
    });
  });
}
