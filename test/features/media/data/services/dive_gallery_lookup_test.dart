import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/dive_gallery_lookup.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/taken_at_source.dart';

AssetInfo _asset(
  String id,
  DateTime createdAt, {
  AssetType type = AssetType.image,
}) => AssetInfo(
  id: id,
  type: type,
  createDateTime: createdAt,
  width: 4032,
  height: 3024,
  filename: '$id.jpg',
);

MediaSourceMetadata _exif(
  DateTime takenAt, {
  TakenAtSource source = TakenAtSource.none,
}) => MediaSourceMetadata(
  takenAt: takenAt,
  takenAtSource: source,
  mimeType: 'image/jpeg',
);

/// A library whose date filter works the way photo_manager's does, so a
/// lookup that asks for too narrow a range really does get nothing back.
class _Library implements PhotoPickerService {
  _Library({
    this.assets = const [],
    this.exif = const {},
    this.supportsGalleryBrowsing = true,
  });

  final List<AssetInfo> assets;
  final Map<String, MediaSourceMetadata> exif;

  @override
  final bool supportsGalleryBrowsing;

  final List<(DateTime, DateTime)> queries = [];
  final List<String> metadataReads = [];
  final List<String> fileFetches = [];

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async {
    queries.add((start, end));
    return assets
        .where(
          (a) =>
              !a.createDateTime.isBefore(start) &&
              !a.createDateTime.isAfter(end),
        )
        .toList();
  }

  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) async {
    metadataReads.add(assetId);
    return exif[assetId];
  }

  @override
  Future<String?> getFilePath(String assetId) async {
    fileFetches.add(assetId);
    return null;
  }

  @override
  Future<PhotoPermissionStatus> checkPermission() async =>
      PhotoPermissionStatus.authorized;

  @override
  Future<PhotoPermissionStatus> currentPermission() async =>
      PhotoPermissionStatus.authorized;

  @override
  Future<PhotoPermissionStatus> requestPermission() async =>
      PhotoPermissionStatus.authorized;

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      null;

  @override
  Future<Uint8List?> getFileBytes(String assetId) async => null;
}

void main() {
  // The dive computer read 10:00 to 11:00, so with the 30 and 60 minute
  // buffers the window is 09:30 to 12:00 on the diver's clock.
  final windowStart = DateTime.utc(2026, 3, 10, 9, 30);
  final windowEnd = DateTime.utc(2026, 3, 10, 12);

  Future<List<AssetInfo>> find(
    PhotoPickerService library, {
    bool Function()? isActive,
  }) => DiveGalleryLookup.find(
    windowStart: windowStart,
    windowEnd: windowEnd,
    photoPickerService: library,
    isActive: isActive,
  );

  group('DiveGalleryLookup.find', () {
    test('asks the library for every zone the device could be in', () async {
      final library = _Library();

      await find(library);

      expect(library.queries, [
        (DateTime(2026, 3, 9, 7, 30), DateTime(2026, 3, 11, 14)),
      ]);
    });

    test('finds a photo by its EXIF wall-time when the device has changed '
        'timezone since the dive', () async {
      final library = _Library(
        assets: [_asset('palau', DateTime(2026, 3, 9, 19, 20))],
        exif: {'palau': _exif(DateTime.utc(2026, 3, 10, 10, 20))},
      );

      final found = await find(library);

      expect(found.map((a) => a.id), ['palau']);
    });

    test('hands a rescued photo over with the time the diver\'s clock showed, '
        'so its stored capture time and profile position are right', () async {
      final library = _Library(
        assets: [_asset('palau', DateTime(2026, 3, 9, 19, 20))],
        exif: {'palau': _exif(DateTime.utc(2026, 3, 10, 10, 20))},
      );

      final found = await find(library);

      expect(found.single.createDateTime, DateTime(2026, 3, 10, 10, 20));
      expect(found.single.createDateTime.isUtc, isFalse);
    });

    test('leaves out a photo whose EXIF wall-time is outside the dive, even '
        'when the digits on this device fall inside it', () async {
      // The phone's clock runs an hour behind where the photos were taken:
      // this one was an hour before the window, the other is in the dive.
      final library = _Library(
        assets: [
          _asset('before-dive', DateTime(2026, 3, 10, 9, 30)),
          _asset('in-dive', DateTime(2026, 3, 10, 10)),
        ],
        exif: {
          'before-dive': _exif(DateTime.utc(2026, 3, 10, 8, 30)),
          'in-dive': _exif(DateTime.utc(2026, 3, 10, 11)),
        },
      );

      final found = await find(library);

      expect(found.map((a) => a.id), ['in-dive']);
      expect(found.single.createDateTime, DateTime(2026, 3, 10, 11));
    });

    test('reads one photo and stops when its EXIF agrees with this device, '
        'so the common case downloads nothing else', () async {
      final library = _Library(
        assets: [
          _asset('in-dive', DateTime(2026, 3, 10, 10, 20)),
          _asset('lunch', DateTime(2026, 3, 10, 13)),
          _asset('dinner', DateTime(2026, 3, 10, 19)),
        ],
        exif: {
          'in-dive': _exif(DateTime.utc(2026, 3, 10, 10, 20)),
          'lunch': _exif(DateTime.utc(2026, 3, 10, 13)),
          'dinner': _exif(DateTime.utc(2026, 3, 10, 19)),
        },
      );

      final found = await find(library);

      expect(found.map((a) => a.id), ['in-dive']);
      expect(library.metadataReads, ['in-dive']);
    });

    test('checks the clock on the photo nearest the dive', () async {
      final library = _Library(
        assets: [
          _asset('next-day', DateTime(2026, 3, 11, 9)),
          _asset('after-dive', DateTime(2026, 3, 10, 13)),
          _asset('day-before', DateTime(2026, 3, 9, 9)),
        ],
        exif: {'after-dive': _exif(DateTime.utc(2026, 3, 10, 13))},
      );

      await find(library);

      expect(library.metadataReads.first, 'after-dive');
    });

    test('moves past photos with no EXIF to find one that settles the clock '
        'question', () async {
      final library = _Library(
        assets: [
          _asset('screenshot', DateTime(2026, 3, 10, 10)),
          _asset('palau', DateTime(2026, 3, 9, 19, 20)),
        ],
        exif: {'palau': _exif(DateTime.utc(2026, 3, 10, 10, 20))},
      );

      final found = await find(library);

      expect(found.map((a) => a.id), containsAll(['screenshot', 'palau']));
    });

    test('does not fetch a copy of a photo the library says has no capture '
        'time', () async {
      final library = _Library(
        assets: [_asset('screenshot', DateTime(2026, 3, 10, 10))],
        exif: {'screenshot': const MediaSourceMetadata(mimeType: 'image/png')},
      );

      await find(library);

      expect(library.fileFetches, isEmpty);
    });

    test('keeps a photo with no EXIF when its digits on this device fall '
        'inside the dive', () async {
      final library = _Library(
        assets: [_asset('screenshot', DateTime(2026, 3, 10, 10))],
      );

      final found = await find(library);

      expect(found.map((a) => a.id), ['screenshot']);
    });

    test('does not trust a file\'s modified date as a capture time', () async {
      final library = _Library(
        assets: [_asset('edited', DateTime(2026, 3, 9, 19, 20))],
        exif: {
          'edited': _exif(
            DateTime.utc(2026, 3, 10, 10, 20),
            source: TakenAtSource.fileModifiedTime,
          ),
        },
      );

      expect(await find(library), isEmpty);
    });

    test('never fetches a video to read its capture time', () async {
      final library = _Library(
        assets: [
          _asset('clip', DateTime(2026, 3, 9, 19, 20), type: AssetType.video),
        ],
      );

      final found = await find(library);

      expect(found, isEmpty);
      expect(library.metadataReads, isEmpty);
    });

    test(
      'keeps a video whose digits on this device fall inside the dive',
      () async {
        final library = _Library(
          assets: [
            _asset('clip', DateTime(2026, 3, 10, 10), type: AssetType.video),
          ],
        );

        expect((await find(library)).map((a) => a.id), ['clip']);
      },
    );

    test('lists photos newest first by the corrected time', () async {
      final library = _Library(
        assets: [
          _asset('second', DateTime(2026, 3, 9, 19, 40)),
          _asset('first', DateTime(2026, 3, 9, 19, 20)),
        ],
        exif: {
          'first': _exif(DateTime.utc(2026, 3, 10, 10, 20)),
          'second': _exif(DateTime.utc(2026, 3, 10, 10, 40)),
        },
      );

      expect((await find(library)).map((a) => a.id), ['second', 'first']);
    });

    test('stops reading once the caller has gone away', () async {
      var active = true;
      final library = _Library(
        assets: [
          _asset('one', DateTime(2026, 3, 9, 19, 20)),
          _asset('two', DateTime(2026, 3, 9, 19, 30)),
          _asset('three', DateTime(2026, 3, 9, 19, 40)),
        ],
        exif: {
          'one': _exif(DateTime.utc(2026, 3, 10, 10, 20)),
          'two': _exif(DateTime.utc(2026, 3, 10, 10, 30)),
          'three': _exif(DateTime.utc(2026, 3, 10, 10, 40)),
        },
      );

      await find(
        library,
        isActive: () {
          final wasActive = active;
          active = false;
          return wasActive;
        },
      );

      expect(library.metadataReads, hasLength(1));
    });

    test('opens one file dialog over the dive window on platforms with no '
        'photo library, and keeps whatever the diver picks', () async {
      final library = _Library(
        supportsGalleryBrowsing: false,
        assets: [_asset('picked', DateTime(2026, 3, 10, 10))],
      );

      final found = await find(library);

      expect(library.queries, [
        (DateTime(2026, 3, 10, 9, 30), DateTime(2026, 3, 10, 12)),
      ]);
      expect(found.map((a) => a.id), ['picked']);
      expect(library.metadataReads, isEmpty);
    });
  });
}
