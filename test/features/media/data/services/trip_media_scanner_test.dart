import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';

/// Helper to create an AssetInfo for testing.
AssetInfo _testAsset(
  String id, {
  DateTime? createdAt,
  double? latitude,
  double? longitude,
  AssetType type = AssetType.image,
  int? durationSeconds,
}) => AssetInfo(
  id: id,
  type: type,
  createDateTime: createdAt ?? DateTime(2024, 1, 15, 10, 0),
  width: 1920,
  height: 1080,
  durationSeconds: durationSeconds,
  latitude: latitude,
  longitude: longitude,
);

/// Stub photo picker that records calls and returns the provided
/// [_assets] from `getAssetsInDateRange`.
class _StubPhotoPicker implements PhotoPickerService {
  _StubPhotoPicker({
    this.permission = PhotoPermissionStatus.authorized,
    List<AssetInfo>? assets,
  }) : _assets = assets ?? const [];

  final PhotoPermissionStatus permission;
  final List<AssetInfo> _assets;

  DateTime? lastStart;
  DateTime? lastEnd;

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async {
    lastStart = start;
    lastEnd = end;
    return _assets;
  }

  @override
  Future<PhotoPermissionStatus> requestPermission() async => permission;

  @override
  Future<PhotoPermissionStatus> checkPermission() async => permission;

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      null;

  @override
  Future<Uint8List?> getFileBytes(String assetId) async => null;

  @override
  Future<String?> getFilePath(String assetId) async => null;

  @override
  bool get supportsGalleryBrowsing => true;
}

void main() {
  group('TripMediaScanner', () {
    group('matchPhotoToDive', () {
      test('returns dive when photo is within dive time range', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          entryTime: DateTime(2024, 1, 15, 10, 0),
          exitTime: DateTime(2024, 1, 15, 11, 0),
          bottomTime: const Duration(minutes: 60),
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
          bottomTime: const Duration(minutes: 60),
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
          bottomTime: const Duration(minutes: 60),
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
          bottomTime: const Duration(minutes: 60),
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
          bottomTime: const Duration(minutes: 60),
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
          bottomTime: const Duration(minutes: 60),
        );
        final dive2 = Dive(
          id: 'dive-2',
          dateTime: DateTime(2024, 1, 15, 12, 0),
          entryTime: DateTime(2024, 1, 15, 12, 0),
          exitTime: DateTime(2024, 1, 15, 13, 0),
          bottomTime: const Duration(minutes: 60),
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
            bottomTime: const Duration(minutes: 60),
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
          bottomTime: const Duration(minutes: 60),
        );
        final dive2 = Dive(
          id: 'dive-2',
          dateTime: DateTime(2024, 1, 15, 10, 30),
          entryTime: DateTime(2024, 1, 15, 10, 30),
          exitTime: DateTime(2024, 1, 15, 11, 30),
          bottomTime: const Duration(minutes: 60),
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
          bottomTime: const Duration(minutes: 60),
        );

        // 25 minutes before entry (within default 30 min buffer)
        final photoTime = DateTime(2024, 1, 15, 9, 35);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [dive]);

        expect(result, equals(dive));
      });
    });

    group('matchPhotoToDive with wall-clock-as-UTC dive times', () {
      // In production, dive times are stored as wall-clock-as-UTC:
      // a dive at 10:00 AM local is DateTime.utc(2024, 1, 15, 10, 0).
      // Photo times from photo_manager are local DateTime objects:
      // a photo at 10:30 AM local is DateTime(2024, 1, 15, 10, 30).
      // The matching must compare wall-clock components, not raw epochs.

      test(
        'matches local photo time to UTC dive time with same wall-clock',
        () {
          final dive = Dive(
            id: 'dive-1',
            dateTime: DateTime.utc(2024, 1, 15, 10, 0),
            entryTime: DateTime.utc(2024, 1, 15, 10, 0),
            exitTime: DateTime.utc(2024, 1, 15, 11, 0),
            bottomTime: const Duration(minutes: 60),
          );

          // Photo taken at 10:30 AM local (same wall-clock window as dive)
          final photoTime = DateTime(2024, 1, 15, 10, 30);
          final result = TripMediaScanner.matchPhotoToDive(photoTime, [dive]);

          expect(result, equals(dive));
        },
      );

      test('matches local photo in buffer zone before UTC dive entry', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime.utc(2024, 1, 15, 10, 0),
          entryTime: DateTime.utc(2024, 1, 15, 10, 0),
          exitTime: DateTime.utc(2024, 1, 15, 11, 0),
          bottomTime: const Duration(minutes: 60),
        );

        // 20 minutes before entry in local time
        final photoTime = DateTime(2024, 1, 15, 9, 40);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [
          dive,
        ], bufferMinutes: 30);

        expect(result, equals(dive));
      });

      test('matches local photo in buffer zone after UTC dive exit', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime.utc(2024, 1, 15, 10, 0),
          entryTime: DateTime.utc(2024, 1, 15, 10, 0),
          exitTime: DateTime.utc(2024, 1, 15, 11, 0),
          bottomTime: const Duration(minutes: 60),
        );

        // 15 minutes after exit in local time
        final photoTime = DateTime(2024, 1, 15, 11, 15);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [
          dive,
        ], bufferMinutes: 30);

        expect(result, equals(dive));
      });

      test('rejects local photo outside buffer of UTC dive', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime.utc(2024, 1, 15, 10, 0),
          entryTime: DateTime.utc(2024, 1, 15, 10, 0),
          exitTime: DateTime.utc(2024, 1, 15, 11, 0),
          bottomTime: const Duration(minutes: 60),
        );

        // 4 hours later in local time
        final photoTime = DateTime(2024, 1, 15, 15, 0);
        final result = TripMediaScanner.matchPhotoToDive(photoTime, [dive]);

        expect(result, isNull);
      });

      test('uses dateTime + duration fallback with mixed UTC/local', () {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime.utc(2024, 1, 15, 10, 0),
          bottomTime: const Duration(minutes: 60),
        );

        final photoTime = DateTime(2024, 1, 15, 10, 30);
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

    group('toWallClockUtc / wallClockUtcToLocal helpers', () {
      test(
        'toWallClockUtc preserves wall-clock components from local DateTime',
        () {
          final local = DateTime(2024, 6, 1, 10, 30, 45, 123);
          final result = TripMediaScanner.toWallClockUtc(local);
          expect(result.isUtc, isTrue);
          expect(result.year, 2024);
          expect(result.month, 6);
          expect(result.day, 1);
          expect(result.hour, 10);
          expect(result.minute, 30);
          expect(result.second, 45);
          expect(result.millisecond, 123);
        },
      );

      test('toWallClockUtc returns input unchanged when already UTC', () {
        final utc = DateTime.utc(2024, 6, 1, 10, 30, 45);
        final result = TripMediaScanner.toWallClockUtc(utc);
        expect(identical(result, utc), isTrue);
      });

      test('wallClockUtcToLocal preserves wall-clock components', () {
        final utc = DateTime.utc(2024, 6, 1, 10, 30, 45, 123);
        final result = TripMediaScanner.wallClockUtcToLocal(utc);
        expect(result.isUtc, isFalse);
        expect(result.year, 2024);
        expect(result.month, 6);
        expect(result.day, 1);
        expect(result.hour, 10);
        expect(result.minute, 30);
        expect(result.second, 45);
        expect(result.millisecond, 123);
      });

      test(
        'wallClockUtcToLocal returns input unchanged when already local',
        () {
          final local = DateTime(2024, 6, 1, 10, 30, 45);
          final result = TripMediaScanner.wallClockUtcToLocal(local);
          expect(identical(result, local), isTrue);
        },
      );
    });

    group('scanGalleryForDive', () {
      test('returns null when permission is denied', () async {
        final picker = _StubPhotoPicker(
          permission: PhotoPermissionStatus.denied,
        );
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime.utc(2024, 1, 15, 10, 0),
          entryTime: DateTime.utc(2024, 1, 15, 10, 0),
          exitTime: DateTime.utc(2024, 1, 15, 11, 0),
        );
        final result = await TripMediaScanner.scanGalleryForDive(
          dive: dive,
          existingAssetIds: const {},
          photoPickerService: picker,
        );
        expect(result, isNull);
      });

      test(
        'returns assets within the buffer window, filtering already-linked',
        () async {
          final assets = [
            _testAsset('a-new', createdAt: DateTime(2024, 1, 15, 10, 30)),
            _testAsset('a-old', createdAt: DateTime(2024, 1, 15, 10, 45)),
          ];
          final picker = _StubPhotoPicker(assets: assets);
          final dive = Dive(
            id: 'dive-1',
            dateTime: DateTime.utc(2024, 1, 15, 10, 0),
            entryTime: DateTime.utc(2024, 1, 15, 10, 0),
            exitTime: DateTime.utc(2024, 1, 15, 11, 0),
          );

          final result = await TripMediaScanner.scanGalleryForDive(
            dive: dive,
            existingAssetIds: const {'a-old'},
            photoPickerService: picker,
          );

          expect(result, hasLength(1));
          expect(result!.first.id, 'a-new');
          // The picker was called with local-time bounds (UTC bounds were
          // adjusted by pre/post buffers and converted via wallClockUtcToLocal).
          expect(picker.lastStart, isNotNull);
          expect(picker.lastEnd, isNotNull);
          expect(picker.lastStart!.isUtc, isFalse);
        },
      );

      test(
        'uses dateTime + duration fallback when entry/exit not set',
        () async {
          final picker = _StubPhotoPicker(
            assets: [
              _testAsset('a1', createdAt: DateTime(2024, 1, 15, 10, 30)),
            ],
          );
          final dive = Dive(
            id: 'dive-1',
            dateTime: DateTime.utc(2024, 1, 15, 10, 0),
            // no entryTime / exitTime / runtime
          );
          final result = await TripMediaScanner.scanGalleryForDive(
            dive: dive,
            existingAssetIds: const {},
            photoPickerService: picker,
          );
          expect(result, hasLength(1));
        },
      );
    });

    group('scanGalleryForTrip', () {
      test('returns null when permission is denied', () async {
        final picker = _StubPhotoPicker(
          permission: PhotoPermissionStatus.denied,
        );
        final result = await TripMediaScanner.scanGalleryForTrip(
          dives: const [],
          tripStartDate: DateTime.utc(2024, 1, 15),
          tripEndDate: DateTime.utc(2024, 1, 17),
          existingAssetIds: const {},
          photoPickerService: picker,
        );
        expect(result, isNull);
      });

      test('groups matched assets by dive and surfaces unmatched', () async {
        final dive = Dive(
          id: 'dive-1',
          dateTime: DateTime.utc(2024, 1, 15, 10, 0),
          entryTime: DateTime.utc(2024, 1, 15, 10, 0),
          exitTime: DateTime.utc(2024, 1, 15, 11, 0),
        );
        // a1: during the dive → matched
        // a2: outside dive bounds → unmatched
        // a3: already linked → filtered out before matching
        final assets = [
          _testAsset(
            'a1',
            createdAt: DateTime(2024, 1, 15, 10, 30),
            latitude: 30.0,
            longitude: -120.0,
          ),
          _testAsset('a2', createdAt: DateTime(2024, 1, 15, 18, 0)),
          _testAsset('a3', createdAt: DateTime(2024, 1, 15, 10, 45)),
        ];
        final picker = _StubPhotoPicker(assets: assets);

        final result = await TripMediaScanner.scanGalleryForTrip(
          dives: [dive],
          tripStartDate: DateTime.utc(2024, 1, 15),
          tripEndDate: DateTime.utc(2024, 1, 16),
          existingAssetIds: const {'a3'},
          photoPickerService: picker,
        );

        expect(result, isNotNull);
        expect(result!.alreadyLinkedCount, 1);
        expect(result.matchedByDive[dive], hasLength(1));
        expect(result.matchedByDive[dive]!.first.id, 'a1');
        expect(result.unmatched, hasLength(1));
        expect(result.unmatched.first.id, 'a2');
      });

      test('handles permission limited (still scans)', () async {
        final picker = _StubPhotoPicker(
          permission: PhotoPermissionStatus.limited,
        );
        final result = await TripMediaScanner.scanGalleryForTrip(
          dives: const [],
          tripStartDate: DateTime.utc(2024, 1, 15),
          tripEndDate: DateTime.utc(2024, 1, 17),
          existingAssetIds: const {},
          photoPickerService: picker,
        );
        expect(result, isNotNull);
      });

      test('returns empty unmatched when no assets', () async {
        final picker = _StubPhotoPicker();
        final result = await TripMediaScanner.scanGalleryForTrip(
          dives: const [],
          tripStartDate: DateTime.utc(2024, 1, 15),
          tripEndDate: DateTime.utc(2024, 1, 17),
          existingAssetIds: const {},
          photoPickerService: picker,
        );
        expect(result, isNotNull);
        expect(result!.unmatched, isEmpty);
        expect(result.matchedByDive, isEmpty);
      });
    });
  });
}
