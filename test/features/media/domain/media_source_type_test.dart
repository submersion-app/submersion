import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

void main() {
  group('MediaSourceType', () {
    test('parses canonical names', () {
      expect(
        MediaSourceType.fromString('platformGallery'),
        MediaSourceType.platformGallery,
      );
      expect(
        MediaSourceType.fromString('localFile'),
        MediaSourceType.localFile,
      );
      expect(
        MediaSourceType.fromString('networkUrl'),
        MediaSourceType.networkUrl,
      );
      expect(
        MediaSourceType.fromString('manifestEntry'),
        MediaSourceType.manifestEntry,
      );
      expect(
        MediaSourceType.fromString('serviceConnector'),
        MediaSourceType.serviceConnector,
      );
      expect(
        MediaSourceType.fromString('signature'),
        MediaSourceType.signature,
      );
    });

    test('returns null for unknown', () {
      expect(MediaSourceType.fromString('bogus'), isNull);
      expect(MediaSourceType.fromString(null), isNull);
    });

    test('round-trips name', () {
      for (final t in MediaSourceType.values) {
        expect(MediaSourceType.fromString(t.name), t);
      }
    });
  });
}
