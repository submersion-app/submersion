import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/lightroom/lightroom_models.dart';

void main() {
  group('LightroomAsset.fromResource', () {
    test('parses a well-formed resource', () {
      final asset = LightroomAsset.fromResource({
        'id': 'a1',
        'subtype': 'image',
        'payload': {
          'captureDate': '2026-07-01T10:00:00',
          'importSource': {'fileName': 'DSC1.jpg'},
          'location': {'latitude': 1.5, 'longitude': -2.5},
        },
      });
      expect(asset, isNotNull);
      expect(asset!.id, 'a1');
      expect(asset.fileName, 'DSC1.jpg');
      expect(asset.latitude, 1.5);
      expect(asset.longitude, -2.5);
      expect(asset.captureDate, isNotNull);
    });

    test('returns null when the id is missing', () {
      expect(LightroomAsset.fromResource({'subtype': 'image'}), isNull);
    });

    test('returns null when the id is not a non-empty string', () {
      expect(LightroomAsset.fromResource({'id': 123}), isNull);
      expect(LightroomAsset.fromResource({'id': ''}), isNull);
      expect(LightroomAsset.fromResource({'id': null}), isNull);
    });

    test('tolerates non-scalar fields without throwing', () {
      final asset = LightroomAsset.fromResource({
        'id': 'a2',
        // Odd shapes the partner API has been seen to return.
        'subtype': ['weird'],
        'payload': {
          'location': 'not-a-map',
          'importSource': ['also-wrong'],
        },
      });
      expect(asset, isNotNull);
      expect(asset!.subtype, 'image'); // falls back to the default
      expect(asset.latitude, isNull);
      expect(asset.fileName, isNull);
    });

    test('ignores a placeholder 0000 capture date', () {
      final asset = LightroomAsset.fromResource({
        'id': 'a3',
        'payload': {'captureDate': '0000-00-00T00:00:00'},
      });
      expect(asset, isNotNull);
      expect(asset!.captureDate, isNull);
    });

    test('reads video subtype and duration', () {
      final asset = LightroomAsset.fromResource({
        'id': 'v1',
        'subtype': 'video',
        'payload': {
          'video': {'duration': 12},
        },
      });
      expect(asset, isNotNull);
      expect(asset!.isVideo, isTrue);
      expect(asset.videoDurationSeconds, 12);
    });
  });
}
