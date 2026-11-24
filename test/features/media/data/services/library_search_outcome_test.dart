import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/library_search_outcome.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

import '../../../../helpers/fake_photo_picker_service.dart';

/// What a library search for a file that stopped reading comes to (media
/// sync program spec 6.3). A search that could not look is inconclusive,
/// never "found nothing": the caller turns nothing into notFound.
void main() {
  final taken = DateTime(2026, 11, 21, 11, 10);
  late FakePhotoPickerService library;

  setUp(() {
    library = FakePhotoPickerService(
      assets: [
        FakeGalleryAsset(
          id: 'B-1',
          bytes: Uint8List.fromList([1]),
          takenAt: taken,
        ),
      ],
    );
  });

  test('a search that could not look stays inconclusive', () async {
    final outcome = await librarySearchOutcome(
      const ResolutionResult(status: ResolutionStatus.accessDenied),
      library,
    );

    final data = outcome! as UnavailableData;
    expect(data.kind, UnavailableKind.accessDenied);
    expect(data.limitedAccess, isFalse);
  });

  test('a limited search stays inconclusive, flagged limited', () async {
    final outcome = await librarySearchOutcome(
      const ResolutionResult(
        status: ResolutionStatus.accessDenied,
        limitedAccess: true,
      ),
      library,
    );

    expect((outcome! as UnavailableData).limitedAccess, isTrue);
  });

  test('a search that looked and found nothing is null', () async {
    expect(
      await librarySearchOutcome(
        const ResolutionResult(status: ResolutionStatus.unavailable),
        library,
      ),
      isNull,
    );
  });

  test('a found photo that reads is served', () async {
    final outcome = await librarySearchOutcome(
      const ResolutionResult(
        localAssetId: 'B-1',
        status: ResolutionStatus.resolved,
      ),
      library,
    );

    expect((outcome! as BytesData).bytes, [1]);
  });

  test('a found photo that does not read is null', () async {
    expect(
      await librarySearchOutcome(
        const ResolutionResult(
          localAssetId: 'B-9',
          status: ResolutionStatus.resolved,
        ),
        library,
      ),
      isNull,
    );
  });

  test('where the library keeps originals as files, a found video is served '
      'as its file and no bytes are read (#4999)', () async {
    // Read as bytes, a gallery video crossed the platform channel whole,
    // copied several times over, and on Android that ran the app out of
    // memory with nothing to catch it.
    final dir = Directory.systemTemp.createTempSync('library_search');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'VID_20261121_121034_197.mp4'))
      ..writeAsBytesSync([1, 2, 3]);
    library
      ..originalsAsFiles = true
      ..add(
        FakeGalleryAsset(
          id: 'V-1',
          bytes: Uint8List.fromList([1, 2, 3]),
          takenAt: taken,
          type: AssetType.video,
          filename: 'VID_20261121_121034_197.mp4',
          file: file,
        ),
      );

    final outcome = await librarySearchOutcome(
      const ResolutionResult(
        localAssetId: 'V-1',
        status: ResolutionStatus.resolved,
      ),
      library,
    );

    final data = outcome! as FileData;
    expect(data.file.path, file.path);
    expect(data.servedFrom, ServedFrom.platformGallery);
    expect(library.originBytesReads, 0);
  });
}
