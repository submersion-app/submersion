import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
import 'package:submersion/features/species_id/domain/services/scanned_ranges_codec.dart';

void main() {
  final gapped = const ScannedRanges()
      .add(0, 10000)
      .add(10000, 12000)
      .add(30000, 40000)
      .add(35000, 50000);

  test('add merges touching and overlapping stretches', () {
    expect(gapped.stretches, [
      (startMs: 0, endMs: 12000),
      (startMs: 30000, endMs: 50000),
    ]);
  });

  test('add keeps stretches sorted whatever the order they come in', () {
    final ranges = const ScannedRanges().add(30000, 40000).add(0, 5000);
    expect(ranges.stretches, [
      (startMs: 0, endMs: 5000),
      (startMs: 30000, endMs: 40000),
    ]);
  });

  test('add ignores an empty stretch', () {
    expect(const ScannedRanges().add(5000, 5000).stretches, isEmpty);
  });

  test('stretches cannot be changed from outside', () {
    for (final ranges in [ScannedRanges.prefix(5000), gapped]) {
      expect(
        () => ranges.stretches.add((startMs: 90000, endMs: 95000)),
        throwsUnsupportedError,
      );
    }
  });

  test('prefix(0) is empty and prefix(25000) is one stretch', () {
    expect(ScannedRanges.prefix(0).stretches, isEmpty);
    expect(ScannedRanges.prefix(25000).stretches, [(startMs: 0, endMs: 25000)]);
  });

  test('firstGapAtOrAfter finds where scanning is still to do', () {
    expect(gapped.firstGapAtOrAfter(5000), 12000);
    expect(gapped.firstGapAtOrAfter(20000), 20000);
    expect(gapped.firstGapAtOrAfter(30000), 50000);
    expect(gapped.firstGapAtOrAfter(45000, durationMs: 50000), isNull);
    expect(gapped.firstGapAtOrAfter(60000, durationMs: 50000), isNull);
  });

  test('stretchStartAfter gives the next stretch beginning later', () {
    expect(gapped.stretchStartAfter(12000), 30000);
    expect(gapped.stretchStartAfter(30000), isNull);
  });

  test('coveredMs is clipped to the duration', () {
    expect(gapped.coveredMs(40000), 22000);
    expect(gapped.coveredMs(60000), 32000);
  });

  test('isComplete only when the stretches cover the whole video', () {
    expect(gapped.isComplete(50000), isFalse);
    expect(ScannedRanges.prefix(25000).isComplete(25000), isTrue);
    expect(const ScannedRanges().isComplete(0), isTrue);
  });

  test('covers and coversRange', () {
    expect(gapped.covers(11999), isTrue);
    expect(gapped.covers(12000), isFalse);
    expect(gapped.coversRange(1000, 12000), isTrue);
    expect(gapped.coversRange(1000, 13000), isFalse);
  });

  test('of sorts and merges whatever it is given', () {
    expect(
      ScannedRanges.of([
        (startMs: 30000, endMs: 40000),
        (startMs: 0, endMs: 10000),
        (startMs: 5000, endMs: 12000),
        (startMs: 50000, endMs: 50000),
      ]).stretches,
      [(startMs: 0, endMs: 12000), (startMs: 30000, endMs: 40000)],
    );
  });

  test('copyWith sorts and merges too', () {
    expect(
      gapped
          .copyWith(
            stretches: const [
              (startMs: 20000, endMs: 30000),
              (startMs: 0, endMs: 25000),
            ],
          )
          .stretches,
      [(startMs: 0, endMs: 30000)],
    );
  });

  test('copyWith with nothing given is an equal copy', () {
    expect(gapped.copyWith(), gapped);
    expect(
      gapped.copyWith(stretches: const [(startMs: 0, endMs: 5000)]),
      ScannedRanges.prefix(5000),
    );
  });

  test('prefixEndMs is the end of a stretch starting at 0', () {
    expect(gapped.prefixEndMs, 12000);
    expect(const ScannedRanges().add(5000, 9000).prefixEndMs, 0);
  });

  group('codec', () {
    test('round trips', () {
      expect(decodeScannedRanges(encodeScannedRanges(gapped)), gapped);
      expect(
        decodeScannedRanges(encodeScannedRanges(const ScannedRanges())),
        const ScannedRanges(),
      );
    });

    test('an unknown version throws', () {
      expect(
        () => decodeScannedRanges(Uint8List.fromList([2])),
        throwsFormatException,
      );
      expect(() => decodeScannedRanges(Uint8List(0)), throwsFormatException);
    });

    test('a length that is not whole stretches throws', () {
      expect(
        () => decodeScannedRanges(Uint8List.fromList([1, 0, 0, 0, 0, 0])),
        throwsFormatException,
      );
    });

    test('a stretch that ends where it starts throws', () {
      final data = ByteData(9)
        ..setUint8(0, 1)
        ..setUint32(1, 500, Endian.little)
        ..setUint32(5, 500, Endian.little);
      expect(
        () => decodeScannedRanges(data.buffer.asUint8List()),
        throwsFormatException,
      );
    });
  });
}
