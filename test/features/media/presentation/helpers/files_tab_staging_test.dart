import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/helpers/files_tab_staging.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

class _Unused
    implements MediaRepository, LocalBookmarkStorage, LocalMediaPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// Reads a capture time out of the file name instead of EXIF, so each test
/// decides which dive a file lands on. A file named `unreadable.jpg` has no
/// metadata at all, the way a corrupt file reads.
class _NameTimeExtractor implements ExifExtractor {
  @override
  Future<MediaSourceMetadata?> extract(File file) async {
    final name = p.basenameWithoutExtension(file.path);
    if (name == 'unreadable') return null;
    return MediaSourceMetadata(
      mimeType: 'image/jpeg',
      takenAt: DateTime.utc(2024, 1, 1, int.parse(name)),
    );
  }
}

/// One dive, 10:00 to 11:00 UTC on 2024-01-01.
final _dive = DiveBounds(
  diveId: 'dive-1',
  entryTime: DateTime.utc(2024, 1, 1, 10),
  exitTime: DateTime.utc(2024, 1, 1, 11),
);

ProviderContainer _container() {
  final unused = _Unused();
  final container = ProviderContainer(
    overrides: [
      filesTabNotifierProvider.overrideWith(
        (ref) => FilesTabNotifier(
          mediaRepository: unused,
          bookmarkStorage: unused,
          platform: unused,
        ),
      ),
      exifExtractorProvider.overrideWithValue(_NameTimeExtractor()),
      diveBoundsProvider.overrideWith((ref) async => [_dive]),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

String _path(String name) => p.join('photos', name);

void main() {
  group('stageFilesForReview', () {
    test('matches each readable file to a dive by capture time', () async {
      final container = _container();

      await stageFilesForReview(container, [
        _path('10.jpg'),
        _path('23.jpg'),
        _path('unreadable.jpg'),
      ]);

      final state = container.read(filesTabNotifierProvider);
      expect(state.files.map((f) => f.sourcePath), [
        _path('10.jpg'),
        _path('23.jpg'),
      ]);
      expect(state.match.matched['dive-1']!.map((f) => f.sourcePath), [
        _path('10.jpg'),
      ]);
      expect(state.match.unmatched.map((f) => f.sourcePath), [_path('23.jpg')]);
      expect(state.isExtracting, isFalse);
      expect(state.extractedCount, 3);
    });

    test('a site session stages every file flat, with no matching', () async {
      final container = _container();

      await stageFilesForReview(container, [
        _path('10.jpg'),
        _path('23.jpg'),
      ], target: const SiteAttachTarget('site-1'));

      final state = container.read(filesTabNotifierProvider);
      expect(state.files, hasLength(2));
      expect(state.match.matched, isEmpty);
      expect(state.match.unmatched, isEmpty);
    });

    test('stops publishing once the session that started it is gone', () async {
      // A picker closed mid-extraction must not overwrite the files a newer
      // picker session has staged in the shared notifier.
      final container = _container();
      final notifier = container.read(filesTabNotifierProvider.notifier);
      var active = true;
      final newer = ExtractedFile(
        sourcePath: _path('newer.jpg'),
        file: File(_path('newer.jpg')),
        metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
      );

      final staging = stageFilesForReview(container, [
        _path('10.jpg'),
        _path('11.jpg'),
      ], isActive: () => active);
      active = false;
      notifier.setFiles([newer], match: MatchedSelection.empty());
      await staging;

      final state = container.read(filesTabNotifierProvider);
      expect(state.files, [newer]);
    });

    test(
      'with auto-match off, a dive session stages every file on its dive',
      () async {
        final container = _container();
        container.read(filesTabNotifierProvider.notifier).toggleAutoMatch();

        await stageFilesForReview(container, [
          _path('23.jpg'),
        ], target: const DiveAttachTarget('dive-9'));

        final state = container.read(filesTabNotifierProvider);
        expect(state.match.matched['dive-9']!.map((f) => f.sourcePath), [
          _path('23.jpg'),
        ]);
        expect(state.match.unmatched, isEmpty);
      },
    );
  });
}
