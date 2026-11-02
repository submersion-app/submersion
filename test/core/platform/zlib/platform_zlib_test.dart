import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/core/platform/zlib/platform_zlib_pure.dart';

/// One mebibyte of bytes that neither compress to nothing nor refuse to
/// compress: runs of a repeated byte broken up by pseudo-random noise.
Uint8List _mixedBytes() {
  final out = Uint8List(1024 * 1024);
  final random = Random(7);
  var i = 0;
  while (i < out.length) {
    final run = min(random.nextInt(400) + 1, out.length - i);
    if (random.nextBool()) {
      out.fillRange(i, i + run, random.nextInt(256));
    } else {
      for (var j = i; j < i + run; j++) {
        out[j] = random.nextInt(256);
      }
    }
    i += run;
  }
  return out;
}

void main() {
  final sample = _mixedBytes();

  final paths =
      <(String, Uint8List Function(List<int>), Uint8List Function(List<int>))>[
        (
          'facade',
          (b) => PlatformZlib.deflate(b),
          (b) => PlatformZlib.inflate(b),
        ),
        ('pure', (b) => pureDeflate(b), (b) => pureInflate(b)),
      ];

  for (final (name, deflate, inflate) in paths) {
    test('$name round-trips 1 MiB of mixed bytes', () {
      final packed = deflate(sample);
      expect(packed.length, lessThan(sample.length));
      expect(inflate(packed), sample);
    });
  }

  test('native deflate output is byte-identical to ZLibCodec(level: 6)', () {
    expect(PlatformZlib.deflate(sample), ZLibCodec(level: 6).encode(sample));
  });

  test('pure inflate accepts native deflate output and vice versa', () {
    expect(pureInflate(PlatformZlib.deflate(sample)), sample);
    expect(PlatformZlib.inflate(pureDeflate(sample)), sample);
  });

  test('inflateBounded throws ZlibBoundExceeded at maxBytes on both paths', () {
    final zeros = Uint8List(2 * 1024 * 1024);
    final packed = PlatformZlib.deflate(zeros);
    expect(
      () => PlatformZlib.inflateBounded(packed, maxBytes: 1024 * 1024),
      throwsA(
        isA<ZlibBoundExceeded>().having(
          (e) => e.maxBytes,
          'maxBytes',
          1024 * 1024,
        ),
      ),
    );
    expect(
      () => pureInflateBounded(packed, maxBytes: 1024 * 1024),
      throwsA(isA<ZlibBoundExceeded>()),
    );
  });

  test('inflateBounded returns the body when it fits exactly', () {
    final body = Uint8List.fromList(List.generate(4096, (i) => i & 0xff));
    final packed = PlatformZlib.deflate(body);
    expect(PlatformZlib.inflateBounded(packed, maxBytes: 4096), body);
    expect(pureInflateBounded(packed, maxBytes: 4096), body);
  });

  test(
    'inflateBounded with gzip framing bounds a gzip stream on both paths',
    () {
      final zeros = Uint8List(2 * 1024 * 1024);
      final packed = PlatformZlib.gzip(zeros);
      expect(
        () => PlatformZlib.inflateBounded(
          packed,
          maxBytes: 1024,
          framing: ZlibFraming.gzip,
        ),
        throwsA(isA<ZlibBoundExceeded>()),
      );
      expect(
        () => pureInflateBounded(
          packed,
          maxBytes: 1024,
          framing: ZlibFraming.gzip,
        ),
        throwsA(isA<ZlibBoundExceeded>()),
      );
      expect(
        pureInflateBounded(
          packed,
          maxBytes: zeros.length,
          framing: ZlibFraming.gzip,
        ),
        zeros,
      );
    },
  );

  test('inflate of garbage throws ZlibFormatException on both paths', () {
    final garbage = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(
      () => PlatformZlib.inflate(garbage),
      throwsA(isA<ZlibFormatException>()),
    );
    expect(() => pureInflate(garbage), throwsA(isA<ZlibFormatException>()));
    expect(
      () => PlatformZlib.inflateBounded(garbage, maxBytes: 1024),
      throwsA(isA<ZlibFormatException>()),
    );
    expect(
      () => pureInflateBounded(garbage, maxBytes: 1024),
      throwsA(isA<ZlibFormatException>()),
    );
    expect(
      () => PlatformZlib.gunzip(garbage),
      throwsA(isA<ZlibFormatException>()),
    );
    expect(() => pureGunzip(garbage), throwsA(isA<ZlibFormatException>()));
  });

  test('pure inflate rejects a zlib stream whose checksum is wrong', () {
    final packed = pureDeflate(sample);
    packed[packed.length - 1] ^= 0xff;
    expect(() => pureInflate(packed), throwsA(isA<ZlibFormatException>()));
  });

  group('pure path on corrupt deflate data', () {
    // A valid zlib header, then a back-reference (length code 257,
    // distance 1) into an output that has no bytes yet.
    final badDistance = Uint8List.fromList([
      0x78,
      0x9c,
      0x03,
      0x02,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
    ]);
    // A valid zlib header, then a dynamic block whose code lengths are all
    // zero: archive decodes symbol 0 at no bit cost and would write zeros
    // until memory runs out.
    final zeroLengths = Uint8List.fromList([
      0x78,
      0x9c,
      0x05,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
    // A valid zlib header followed by a reserved block type.
    final reservedBlock = Uint8List.fromList([0x78, 0x9c, 0x07, 0x00]);

    test('a back-reference before the start is a format error', () {
      expect(
        () => pureInflate(badDistance),
        throwsA(isA<ZlibFormatException>()),
      );
      expect(
        () => pureInflateBounded(badDistance, maxBytes: 1024),
        throwsA(isA<ZlibFormatException>()),
      );
      expect(
        () => PlatformZlib.inflate(badDistance),
        throwsA(isA<ZlibFormatException>()),
      );
    });

    test('a block that produces output without input stops at the cap', () {
      expect(
        () => pureInflateBounded(zeroLengths, maxBytes: 4096),
        throwsA(isA<ZlibBoundExceeded>()),
      );
    });

    test('the unbounded pure entry still has a ceiling', () {
      expect(pureInflateCeilingBytes, lessThanOrEqualTo(512 * 1024 * 1024));
      expect(pureInflateCeilingBytes, greaterThanOrEqualTo(64 * 1024 * 1024));
    });

    test('a reserved block type with a trailer is a format error', () {
      final withTrailer = Uint8List.fromList([
        ...reservedBlock,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
      expect(
        () => pureInflate(withTrailer),
        throwsA(isA<ZlibFormatException>()),
      );
    });
  });

  test('gzip round-trips and gunzip accepts the other path\'s output', () {
    final native = PlatformZlib.gzip(sample);
    final pure = pureGzip(sample);
    expect(native.sublist(0, 2), [0x1f, 0x8b]);
    expect(pure.sublist(0, 2), [0x1f, 0x8b]);
    expect(PlatformZlib.gunzip(native), sample);
    expect(pureGunzip(pure), sample);
    expect(pureGunzip(native), sample);
    expect(PlatformZlib.gunzip(pure), sample);
  });

  test('gzip output is byte-identical to GZipCodec(level: 6) on the VM', () {
    expect(PlatformZlib.gzip(sample), GZipCodec(level: 6).encode(sample));
  });
}
