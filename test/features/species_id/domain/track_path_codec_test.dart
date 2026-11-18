import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/services/track_path_codec.dart';

/// A video track's path is packed into one column (issue #4675).
void main() {
  TrackSample at(int ms, double x) => TrackSample(
    ms: ms,
    box: IdentificationBox(x: x, y: 0.25, width: 0.1, height: 0.05),
  );

  test('round trip keeps times exactly and boxes within 1/65535', () {
    final samples = [at(1000, 0.1), at(1250, 0.123456), at(1500, 0.9)];
    final decoded = decodeTrackPath(1000, encodeTrackPath(1000, samples));
    expect(decoded, hasLength(3));
    for (var k = 0; k < 3; k++) {
      expect(decoded[k].ms, samples[k].ms);
      expect(decoded[k].box.x, closeTo(samples[k].box.x, 1 / 65535));
      expect(decoded[k].box.y, closeTo(0.25, 1 / 65535));
      expect(decoded[k].box.width, closeTo(0.1, 1 / 65535));
      expect(decoded[k].box.height, closeTo(0.05, 1 / 65535));
    }
  });

  test('an empty path encodes to the version byte alone', () {
    final bytes = encodeTrackPath(0, const []);
    expect(bytes, [1]);
    expect(decodeTrackPath(0, bytes), isEmpty);
  });

  test('an unknown version is rejected', () {
    expect(
      () => decodeTrackPath(0, Uint8List.fromList([2])),
      throwsFormatException,
    );
  });

  test('a truncated blob is rejected', () {
    final bytes = encodeTrackPath(0, [at(0, 0.1)]);
    expect(
      () =>
          decodeTrackPath(0, Uint8List.sublistView(bytes, 0, bytes.length - 1)),
      throwsFormatException,
    );
    expect(() => decodeTrackPath(0, Uint8List(0)), throwsFormatException);
  });

  test('boxes outside 0..1 are clamped', () {
    final decoded = decodeTrackPath(
      0,
      encodeTrackPath(0, const [
        TrackSample(
          ms: 0,
          box: IdentificationBox(x: -0.1, y: 0.5, width: 1.2, height: 0.1),
        ),
      ]),
    );
    expect(decoded.single.box.x, 0);
    expect(decoded.single.box.width, 1);
  });
}
