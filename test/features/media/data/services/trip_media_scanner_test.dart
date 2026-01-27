import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';

/// Helper to create an AssetInfo for testing.
AssetInfo _testAsset(String id) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2024, 1, 15, 10, 0),
  width: 1920,
  height: 1080,
);

void main() {
  group('TripMediaScanner', () {
    group('matchPhotoToDive', () {
      test('returns dive when photo is within dive time range', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );

        final photoTime = DateTime(2024, 1, 15, 10, 30);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [dive]);

        expect(result, equals(dive));
      });

      test('returns null when photo is outside all dive time ranges', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );

        final photoTime = DateTime(2024, 1, 15, 15, 0); // 4 hours later
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [dive]);

        expect(result, isNull);
      });

      test('returns dive when photo is within buffer zone before entry', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );

        // 20 minutes before entry (within 30 min buffer)
        final photoTime = DateTime(2024, 1, 15, 9, 40);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [
          dive,
        ], bufferMinutes: 30);

        expect(result, equals(dive));
      });

      test('returns dive when photo is within buffer zone after exit', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );

        // 15 minutes after exit (within 30 min buffer)
        final photoTime = DateTime(2024, 1, 15, 11, 15);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [
          dive,
        ], bufferMinutes: 30);

        expect(result, equals(dive));
      });

      test('returns null when photo is outside buffer zone', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );

        // 45 minutes before entry (outside 30 min buffer)
        final photoTime = DateTime(2024, 1, 15, 9, 15);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [
          dive,
        ], bufferMinutes: 30);

        expect(result, isNull);
      });

      test('returns closest dive when photo matches multiple dive buffers', () {
        final dive1 = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );
        final dive2 = Dive(
          id: 'dive-2',
          dateTime: DateTime(2024, 1, 15, 12, 0),
          entryTime: DateTime(2024, 1, 15, 12, 0),
          exitTime: DateTime(2024, 1, 15, 13, 0),
          duration: const Duration(minutes: 60),
        );

        // 11:45 - 45 min after dive1 exit, 15 min before dive2 entry
        final photoTime = DateTime(2024, 1, 15, 11, 45);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [
          dive1,
          dive2,
        ], bufferMinutes: 60);

        // Should return dive2 since it's closer
        expect(result, equals(dive2));
      });

      test(
        'uses dateTime + duration fallback when entry/exit times not set',
        () {
          final dive = Dive(
            id: 'dive-1',
            dateTime: DateTime(2024, 1, 15, 10, 0),
            duration: const Duration(minutes: 60),
          );

          // Photo during the calculated dive time
          final photoTime = DateTime(2024, 1, 15, 10, 30);
          final result = TripMediaScanner.matchPhotoToDive(photoTime, [dive]);

          expect(result, equals(dive));
        },
      );

      test('returns null for empty dive list', () {
        final photoTime = DateTime(2024, 1, 15, 10, 30);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, []);

        expect(result, isNull);
      });

      test('prefers exact dive match over buffer match', () {
        final dive1 = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );
        final dive2 = Dive(
          id: 'dive-2',
          dateTime: DateTime(2024, 1, 15, 10, 30),
          entryTime: DateTime(2024, 1, 15, 10, 30),
          exitTime: DateTime(2024, 1, 15, 11, 30),
          duration: const Duration(minutes: 60),
        );

        // 10:15 - during dive1, within buffer of dive2
        final photoTime = DateTime(2024, 1, 15, 10, 15);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [
          dive1,
          dive2,
        ], bufferMinutes: 30);

        // Should return dive1 since photo was taken during this dive
        expect(result, equals(dive1));
      });

      test('default buffer is 30 minutes', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          duration: const Duration(minutes: 60),
        );

        // 25 minutes before entry (within default 30 min buffer)
        final photoTime = DateTime(2024, 1, 15, 9, 35);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [dive]);

        expect(result, equals(dive));
      });
    });

    group('ScanResult', () {
      test('totalMatchedPhotos returns sum of all matched photos', () {
        final dive1 = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
        );
        final dive2 = Dive(
          id: 'dive-2',
          dateTime: DateTime(2024, 1, 15, 14, 0),
        );

        final result = ScanResult(
          matchedByDive: {
            dive1: [_testAsset('asset-1'), _testAsset('asset-2')],
            dive2: [_testAsset('asset-3')],
          },
          unmatched: [_testAsset('asset-4')],
          alreadyLinkedCount: 5,
        );

        expect(result.totalMatchedPhotos, equals(3));
      });

      test('totalNewPhotos returns matched plus unmatched count', () {
        final dive = Dive(id: 'dive-1', dateTime: DateTime(2024, 1, 15, 10, 0));

        final result = ScanResult(
          matchedByDive: {
            dive: [_testAsset('asset-1'), _testAsset('asset-2')],
          },
          unmatched: [_testAsset('asset-3'), _testAsset('asset-4')],
          alreadyLinkedCount: 5,
        );

        expect(result.totalNewPhotos, equals(4));
      });

      test('handles empty matchedByDive', () {
        final result = ScanResult(
          matchedByDive: const {},
          unmatched: [_testAsset('asset-1')],
          alreadyLinkedCount: 0,
        );

        expect(result.totalMatchedPhotos, equals(0));
        expect(result.totalNewPhotos, equals(1));
      });

      test('handles empty unmatched', () {
        final dive = Dive(id: 'dive-1', dateTime: DateTime(2024, 1, 15, 10, 0));

        final result = ScanResult(
          matchedByDive: {
            dive: [_testAsset('asset-1')],
          },
          unmatched: const [],
          alreadyLinkedCount: 3,
        );

        expect(result.totalMatchedPhotos, equals(1));
        expect(result.totalNewPhotos, equals(1));
      });
    });
  });
}
