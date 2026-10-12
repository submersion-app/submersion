import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/domain/nav_track_source_metadata_codec.dart';

void main() {
  const metadata = {
    'DiveRouteQuality': 0,
    'QualityFeatures': [16, 0.10000000149011612, 3505.73388671875],
  };

  test('round-trips a map exactly', () {
    final decoded = decodeNavTrackSourceMetadata(
      encodeNavTrackSourceMetadata(metadata),
    );
    expect(decoded, metadata);
    expect((decoded!['QualityFeatures']! as List).first, isA<int>());
  });

  test('null and an empty map encode to null', () {
    expect(encodeNavTrackSourceMetadata(null), isNull);
    expect(encodeNavTrackSourceMetadata(const {}), isNull);
  });

  test('a map JSON cannot hold encodes to null instead of throwing', () {
    expect(encodeNavTrackSourceMetadata({'q': double.nan}), isNull);
    expect(encodeNavTrackSourceMetadata({'q': Object()}), isNull);
  });

  test('null decodes to null', () {
    expect(decodeNavTrackSourceMetadata(null), isNull);
  });

  test('a stored value that is not a JSON object decodes to null', () {
    for (final stored in ['not json', '[1,2]', '"x"', '3', 'null', '']) {
      expect(decodeNavTrackSourceMetadata(stored), isNull, reason: stored);
    }
  });

  test('the decoded map and its lists are unmodifiable', () {
    final decoded = decodeNavTrackSourceMetadata(
      encodeNavTrackSourceMetadata(metadata),
    )!;
    expect(() => decoded['x'] = 1, throwsUnsupportedError);
    expect(
      () => (decoded['QualityFeatures']! as List).add(1),
      throwsUnsupportedError,
    );
  });
}
