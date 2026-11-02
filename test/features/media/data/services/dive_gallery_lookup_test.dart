import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
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
    this.files = const {},
    this.unreadable = const {},
    this.hanging = const {},
    this.supportsGalleryBrowsing = true,
  });

  final List<AssetInfo> assets;
  final Map<String, MediaSourceMetadata> exif;

  /// Copies of assets on disk, for a platform with no native reader.
  final Map<String, String> files;

  /// Assets whose metadata read fails, like an iCloud download that errors.
  final Set<String> unreadable;

  /// Assets whose metadata read never finishes, like a stalled download.
  final Set<String> hanging;

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
    if (unreadable.contains(assetId)) {
      throw StateError('download failed');
    }
    if (hanging.contains(assetId)) {
      return Completer<MediaSourceMetadata?>().future;
    }
    return exif[assetId];
  }

  @override
  Future<String?> getFilePath(String assetId) async {
    fileFetches.add(assetId);
    return files[assetId];
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

    test(
      'keeps a photo this device places in the dive when its EXIF says '
      'otherwise, since a date fixed in Photos leaves the EXIF stale',
      () async {
        final library = _Library(
          assets: [
            _asset('date-fixed', DateTime(2026, 3, 10, 9, 30)),
            _asset('in-dive', DateTime(2026, 3, 10, 10)),
          ],
          exif: {
            'date-fixed': _exif(DateTime.utc(2026, 3, 10, 8, 30)),
            'in-dive': _exif(DateTime.utc(2026, 3, 10, 11)),
          },
        );

        final found = await find(library);

        expect(found.map((a) => a.id), ['in-dive', 'date-fixed']);
        expect(found.last.createDateTime, DateTime(2026, 3, 10, 9, 30));
      },
    );

    test('stops after a few photos when their EXIF agrees with this device, '
        'so the common case downloads almost nothing', () async {
      final library = _Library(
        assets: [
          _asset('in-dive', DateTime(2026, 3, 10, 10, 20)),
          _asset('also-in-dive', DateTime(2026, 3, 10, 10, 40)),
          _asset('lunch', DateTime(2026, 3, 10, 13)),
          _asset('coffee', DateTime(2026, 3, 10, 14)),
          _asset('walk', DateTime(2026, 3, 10, 15)),
          _asset('dinner', DateTime(2026, 3, 10, 19)),
        ],
        exif: {
          'in-dive': _exif(DateTime.utc(2026, 3, 10, 10, 20)),
          'also-in-dive': _exif(DateTime.utc(2026, 3, 10, 10, 40)),
          'lunch': _exif(DateTime.utc(2026, 3, 10, 13)),
          'coffee': _exif(DateTime.utc(2026, 3, 10, 14)),
          'walk': _exif(DateTime.utc(2026, 3, 10, 15)),
          'dinner': _exif(DateTime.utc(2026, 3, 10, 19)),
        },
      );

      final found = await find(library);

      expect(found.map((a) => a.id), ['also-in-dive', 'in-dive']);
      expect(library.metadataReads, ['in-dive', 'lunch', 'coffee', 'walk']);
    });

    test('finds phone photos from the dive when camera photos from it agree '
        'with this device', () async {
      // A camera that records no timezone, imported at home, is stamped in
      // this device's zone. The phone's photo of the same dive is an instant.
      final library = _Library(
        assets: [
          _asset('camera', DateTime(2026, 3, 10, 10, 10)),
          _asset('phone', DateTime(2026, 3, 9, 19, 20)),
        ],
        exif: {
          'camera': _exif(DateTime.utc(2026, 3, 10, 10, 10)),
          'phone': _exif(DateTime.utc(2026, 3, 10, 10, 20)),
        },
      );

      final found = await find(library);

      expect(found.map((a) => a.id), ['phone', 'camera']);
      expect(found.first.createDateTime, DateTime(2026, 3, 10, 10, 20));
    });

    test('corrects a photo inside the window once another photo shows the '
        'clocks disagree', () async {
      final library = _Library(
        assets: [
          _asset('camera', DateTime(2026, 3, 10, 10)),
          _asset('near-zone', DateTime(2026, 3, 10, 11)),
          _asset('palau', DateTime(2026, 3, 9, 19, 20)),
        ],
        exif: {
          'camera': _exif(DateTime.utc(2026, 3, 10, 10)),
          'near-zone': _exif(DateTime.utc(2026, 3, 10, 11, 30)),
          'palau': _exif(DateTime.utc(2026, 3, 10, 10, 20)),
        },
      );

      final found = await find(library);

      expect(
        found.singleWhere((a) => a.id == 'near-zone').createDateTime,
        DateTime(2026, 3, 10, 11, 30),
      );
    });

    test(
      'reads each photo only once, since a read can be a download',
      () async {
        final library = _Library(
          assets: [
            _asset('camera', DateTime(2026, 3, 10, 10)),
            _asset('palau', DateTime(2026, 3, 9, 19, 20)),
          ],
          exif: {
            'camera': _exif(DateTime.utc(2026, 3, 10, 10)),
            'palau': _exif(DateTime.utc(2026, 3, 10, 10, 20)),
          },
        );

        await find(library);

        expect(library.metadataReads, unorderedEquals(['camera', 'palau']));
      },
    );

    test('does not take an EXIF date no timezone could explain as a clock '
        'disagreement', () async {
      final library = _Library(
        assets: [
          _asset('unset-clock', DateTime(2026, 3, 10, 10)),
          _asset('lunch', DateTime(2026, 3, 10, 13)),
          _asset('coffee', DateTime(2026, 3, 10, 14)),
          _asset('walk', DateTime(2026, 3, 10, 15)),
          _asset('dinner', DateTime(2026, 3, 10, 19)),
        ],
        exif: {
          'unset-clock': _exif(DateTime.utc(2000, 1, 1)),
          'lunch': _exif(DateTime.utc(2026, 3, 10, 13)),
          'coffee': _exif(DateTime.utc(2026, 3, 10, 14)),
          'walk': _exif(DateTime.utc(2026, 3, 10, 15)),
          'dinner': _exif(DateTime.utc(2026, 3, 10, 19)),
        },
      );

      await find(library);

      expect(library.metadataReads, ['unset-clock', 'lunch', 'coffee', 'walk']);
    });

    test('gives up the clock check after a handful of photos with no EXIF, '
        'rather than fetching every one', () async {
      final library = _Library(
        assets: [
          for (var i = 0; i < 20; i++)
            _asset('screenshot-$i', DateTime(2026, 3, 10, 13, i)),
        ],
      );

      await find(library);

      expect(library.metadataReads, hasLength(8));
    });

    test('once the clocks disagree, reads first the photos that gap puts in '
        'the dive', () async {
      // Fifteen hours out, as a phone in Denver is from Palau.
      final library = _Library(
        assets: [
          _asset('after-dive', DateTime(2026, 3, 10, 8)),
          _asset('further', DateTime(2026, 3, 10, 1)),
          _asset('in-dive', DateTime(2026, 3, 9, 19, 20)),
        ],
        exif: {
          'after-dive': _exif(DateTime.utc(2026, 3, 10, 23)),
          'further': _exif(DateTime.utc(2026, 3, 10, 16)),
          'in-dive': _exif(DateTime.utc(2026, 3, 10, 10, 20)),
        },
      );

      await find(library);

      expect(library.metadataReads, ['after-dive', 'in-dive', 'further']);
    });

    test('moves on from a read that never finishes', () {
      fakeAsync((async) {
        final library = _Library(
          assets: [
            _asset('stalled', DateTime(2026, 3, 10, 10)),
            _asset('palau', DateTime(2026, 3, 9, 19, 20)),
          ],
          exif: {'palau': _exif(DateTime.utc(2026, 3, 10, 10, 20))},
          hanging: {'stalled'},
        );
        List<AssetInfo>? found;

        find(library).then((result) => found = result);
        async.elapse(const Duration(seconds: 16));

        expect(found, isNotNull);
        expect(found!.map((a) => a.id), containsAll(['stalled', 'palau']));
      });
    });

    test('stops reading when its time is spent, and returns what it has', () {
      fakeAsync((async) {
        final library = _Library(
          assets: [
            _asset('after-dive', DateTime(2026, 3, 10, 8)),
            _asset('palau', DateTime(2026, 3, 9, 19, 20)),
            for (var i = 0; i < 20; i++)
              _asset('stalled-$i', DateTime(2026, 3, 10, 1, i)),
          ],
          exif: {
            'after-dive': _exif(DateTime.utc(2026, 3, 10, 23)),
            'palau': _exif(DateTime.utc(2026, 3, 10, 10, 20)),
          },
          hanging: {for (var i = 0; i < 20; i++) 'stalled-$i'},
        );
        List<AssetInfo>? found;

        find(library).then((result) => found = result);
        async.elapse(const Duration(minutes: 2));

        expect(found, isNotNull);
        expect(found!.map((a) => a.id), ['palau']);
        expect(library.metadataReads.length, lessThanOrEqualTo(7));
      });
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

    test('reads the capture time from a copy of the file on a platform with '
        'no native reader', () async {
      final tempDir = await Directory.systemTemp.createTemp('gallery_lookup');
      addTearDown(() => tempDir.delete(recursive: true));
      final image = img.Image(width: 8, height: 8);
      image.exif.exifIfd['DateTimeOriginal'] = '2026:03:10 10:20:00';
      final path = p.join(tempDir.path, 'palau.jpg');
      await File(path).writeAsBytes(img.encodeJpg(image));
      final library = _Library(
        assets: [_asset('palau', DateTime(2026, 3, 9, 19, 20))],
        files: {'palau': path},
      );

      final found = await find(library);

      expect(found.single.createDateTime, DateTime(2026, 3, 10, 10, 20));
    });

    test('carries on past a photo that cannot be read', () async {
      final library = _Library(
        assets: [
          _asset('broken', DateTime(2026, 3, 10, 10)),
          _asset('palau', DateTime(2026, 3, 9, 19, 20)),
        ],
        exif: {'palau': _exif(DateTime.utc(2026, 3, 10, 10, 20))},
        unreadable: {'broken'},
      );

      final found = await find(library);

      expect(found.map((a) => a.id), containsAll(['broken', 'palau']));
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

  group('DiveGalleryLookup.correctedForDive', () {
    Future<List<AssetInfo>> correct(
      PhotoPickerService library,
      List<AssetInfo> assets,
    ) => DiveGalleryLookup.correctedForDive(
      assets: assets,
      windowStart: windowStart,
      windowEnd: windowEnd,
      photoPickerService: library,
    );

    test('gives a photo outside the dive its EXIF wall-time when that lands '
        'in the dive', () async {
      final palau = _asset('palau', DateTime(2026, 3, 9, 19, 20));
      final library = _Library(
        exif: {'palau': _exif(DateTime.utc(2026, 3, 10, 10, 20))},
      );

      final corrected = await correct(library, [palau]);

      expect(corrected.single.createDateTime, DateTime(2026, 3, 10, 10, 20));
    });

    test('reads nothing for a photo this device already places in the dive, '
        'so the usual import downloads nothing', () async {
      final inDive = _asset('in-dive', DateTime(2026, 3, 10, 10, 20));
      final library = _Library(
        exif: {'in-dive': _exif(DateTime.utc(2026, 3, 10, 11))},
      );

      final corrected = await correct(library, [inDive]);

      expect(corrected.single.createDateTime, DateTime(2026, 3, 10, 10, 20));
      expect(library.metadataReads, isEmpty);
    });

    test('leaves a photo alone when its EXIF is not in the dive either, since '
        'the diver chose this dive and a date fixed in Photos leaves EXIF '
        'stale', () async {
      final elsewhere = _asset('elsewhere', DateTime(2026, 3, 9, 19, 20));
      final library = _Library(
        exif: {'elsewhere': _exif(DateTime.utc(2026, 3, 10, 18))},
      );

      final corrected = await correct(library, [elsewhere]);

      expect(corrected.single.createDateTime, DateTime(2026, 3, 9, 19, 20));
    });

    test('never fetches a video', () async {
      final clip = _asset(
        'clip',
        DateTime(2026, 3, 9, 19, 20),
        type: AssetType.video,
      );
      final library = _Library();

      await correct(library, [clip]);

      expect(library.metadataReads, isEmpty);
    });

    test('leaves what a file dialog picked as it is, since that time came '
        'from the file itself', () async {
      final picked = _asset('picked', DateTime(2026, 3, 9, 19, 20));
      final library = _Library(
        supportsGalleryBrowsing: false,
        exif: {'picked': _exif(DateTime.utc(2026, 3, 10, 10, 20))},
      );

      final corrected = await correct(library, [picked]);

      expect(corrected.single.createDateTime, DateTime(2026, 3, 9, 19, 20));
      expect(library.metadataReads, isEmpty);
    });

    test('keeps every photo, in order, when its time runs out', () {
      fakeAsync((async) {
        final stalled = [
          for (var i = 0; i < 20; i++)
            _asset('stalled-$i', DateTime(2026, 3, 9, 19, i)),
        ];
        final library = _Library(hanging: {for (final a in stalled) a.id});
        List<AssetInfo>? corrected;

        correct(library, stalled).then((result) => corrected = result);
        async.elapse(const Duration(minutes: 2));

        expect(corrected, isNotNull);
        expect(corrected!.map((a) => a.id), stalled.map((a) => a.id));
        expect(library.metadataReads.length, lessThanOrEqualTo(5));
      });
    });
  });
}
