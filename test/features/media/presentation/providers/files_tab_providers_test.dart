import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

import 'files_tab_providers_test.mocks.dart';

ExtractedFile _ef(String path, {MediaSourceMetadata? metadata}) =>
    ExtractedFile(
      sourcePath: path,
      file: File(path),
      metadata: metadata ?? const MediaSourceMetadata(mimeType: 'image/jpeg'),
    );

/// Minimal saved-item factory mirroring what [MediaRepository.createMedia]
/// returns: caller-supplied id (or generated one) plus timestamps.
MediaItem _saved(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  takenAt: DateTime(2024),
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

@GenerateMocks([MediaRepository, LocalBookmarkStorage, LocalMediaPlatform])
void main() {
  late MockMediaRepository mockRepo;
  late MockLocalBookmarkStorage mockBookmarkStorage;
  late MockLocalMediaPlatform mockPlatform;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockMediaRepository();
    mockBookmarkStorage = MockLocalBookmarkStorage();
    mockPlatform = MockLocalMediaPlatform();
    container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(mockRepo),
        localBookmarkStorageProvider.overrideWithValue(mockBookmarkStorage),
        localMediaPlatformProvider.overrideWithValue(mockPlatform),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('FilesTabState defaults & basic mutators', () {
    test('default state: no files, autoMatchByDate=true, not extracting', () {
      final state = container.read(filesTabNotifierProvider);
      expect(state.files, isEmpty);
      expect(state.autoMatchByDate, isTrue);
      expect(state.isExtracting, isFalse);
      expect(state.extractedCount, 0);
      expect(state.totalToExtract, 0);
      expect(state.match, MatchedSelection.empty());
    });

    test('toggleAutoMatch flips the flag', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      notifier.toggleAutoMatch();
      expect(container.read(filesTabNotifierProvider).autoMatchByDate, isFalse);
      notifier.toggleAutoMatch();
      expect(container.read(filesTabNotifierProvider).autoMatchByDate, isTrue);
    });

    test('clear resets to initial state', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      notifier.setFiles([
        _ef('/a.jpg'),
      ], match: const MatchedSelection(matched: {}, unmatched: []));
      notifier.clear();
      final state = container.read(filesTabNotifierProvider);
      expect(state.files, isEmpty);
      expect(state.autoMatchByDate, isTrue); // reset to default
    });

    test('setFiles updates files and match', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final files = [_ef('/a.jpg'), _ef('/b.jpg')];
      final match = MatchedSelection(
        matched: {'d1': files},
        unmatched: const [],
      );
      notifier.setFiles(files, match: match);
      final state = container.read(filesTabNotifierProvider);
      expect(state.files, files);
      expect(state.match, match);
    });

    test('setExtractionProgress reflects done/total', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      notifier.setExtractionProgress(done: 3, total: 10);
      final state = container.read(filesTabNotifierProvider);
      expect(state.extractedCount, 3);
      expect(state.totalToExtract, 10);
      expect(state.isExtracting, isTrue);
      notifier.setExtractionProgress(done: 10, total: 10);
      final done = container.read(filesTabNotifierProvider);
      expect(done.isExtracting, isFalse); // done == total
    });

    test('removeFile filters by sourcePath', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      final b = _ef('/b.jpg');
      notifier.setFiles([
        a,
        b,
      ], match: const MatchedSelection(matched: {}, unmatched: []));
      notifier.removeFile('/a.jpg');
      final state = container.read(filesTabNotifierProvider);
      expect(state.files, [b]);
    });

    test('removeFile removes file from state.files AND state.match', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      final b = _ef('/b.jpg');
      final c = _ef('/c.jpg');
      // Seed: a is solo in d1 (group will be dropped on removal),
      // b is alongside c in d2, c is also unmatched.
      notifier.setFiles(
        [a, b, c],
        match: MatchedSelection(
          matched: {
            'd1': [a],
            'd2': [b, c],
          },
          unmatched: [c],
        ),
      );

      notifier.removeFile('/a.jpg');
      final afterA = container.read(filesTabNotifierProvider);
      expect(afterA.files, [b, c]);
      // d1 group dropped because it's now empty.
      expect(afterA.match.matched.containsKey('d1'), isFalse);
      expect(afterA.match.matched['d2'], [b, c]);
      expect(afterA.match.unmatched, [c]);

      notifier.removeFile('/c.jpg');
      final afterC = container.read(filesTabNotifierProvider);
      expect(afterC.files, [b]);
      expect(afterC.match.matched['d2'], [b]);
      expect(afterC.match.unmatched, isEmpty);
    });
  });

  // The platform-conditional branches in _persistOne are exercised on the
  // host platform (macOS in CI / dev box) — the iOS / macOS branch. Coverage
  // for the Android / desktop branches is left to integration testing,
  // since Platform.isIOS et al. are read-only globals at runtime.
  group('commit / undoCommit (host platform: iOS / macOS branch)', () {
    test(
      'commit returns the saved IDs and persists one MediaItem per matched file',
      () async {
        final notifier = container.read(filesTabNotifierProvider.notifier);
        final a = _ef('/a.jpg');
        final b = _ef('/b.jpg');
        final c = _ef('/c.jpg');
        notifier.setFiles(
          [a, b, c],
          match: MatchedSelection(
            matched: {
              'd1': [a, b],
              'd2': [c],
            },
            unmatched: const [],
          ),
        );

        when(
          mockPlatform.createBookmark(any),
        ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
        when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
        // Echo a deterministic id derived from the call order. Exact value
        // doesn't matter — we only assert the count and that they're returned.
        var counter = 0;
        when(mockRepo.createMedia(any)).thenAnswer((invocation) async {
          counter += 1;
          return _saved('saved-$counter');
        });

        final created = await notifier.commit();

        expect(created, ['saved-1', 'saved-2', 'saved-3']);
        verify(mockRepo.createMedia(any)).called(3);
      },
    );

    test('commit clears state on success', () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      notifier.setFiles(
        [a],
        match: MatchedSelection(
          matched: {
            'd1': [a],
          },
          unmatched: const [],
        ),
      );

      when(
        mockPlatform.createBookmark(any),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
      when(
        mockRepo.createMedia(any),
      ).thenAnswer((_) async => _saved('saved-1'));

      await notifier.commit();

      expect(container.read(filesTabNotifierProvider), FilesTabState.initial());
    });

    test(
      'commit skips unmatched files (only matched entries get persisted)',
      () async {
        final notifier = container.read(filesTabNotifierProvider.notifier);
        final a = _ef('/a.jpg');
        final b = _ef('/b.jpg');
        notifier.setFiles(
          [a, b],
          match: MatchedSelection(
            matched: {
              'd1': [a],
            },
            unmatched: [b],
          ),
        );

        when(
          mockPlatform.createBookmark(any),
        ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
        when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
        when(
          mockRepo.createMedia(any),
        ).thenAnswer((_) async => _saved('saved-1'));

        final created = await notifier.commit();

        expect(created.length, 1);
        verify(mockRepo.createMedia(any)).called(1);
      },
    );

    test(
      'commit on iOS / macOS calls createBookmark + bookmarkStorage.write',
      () async {
        // Skip on platforms where this branch isn't exercised.
        if (!Platform.isIOS && !Platform.isMacOS) return;

        final notifier = container.read(filesTabNotifierProvider.notifier);
        final a = _ef('/a.jpg');
        notifier.setFiles(
          [a],
          match: MatchedSelection(
            matched: {
              'd1': [a],
            },
            unmatched: const [],
          ),
        );

        final blob = Uint8List.fromList([9, 8, 7]);
        when(
          mockPlatform.createBookmark('/a.jpg'),
        ).thenAnswer((_) async => blob);
        when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
        when(
          mockRepo.createMedia(any),
        ).thenAnswer((_) async => _saved('saved-1'));

        await notifier.commit();

        verify(mockPlatform.createBookmark('/a.jpg')).called(1);
        verify(mockBookmarkStorage.write(any, blob)).called(1);
        // Verify the inserted MediaItem carried sourceType=localFile and a
        // bookmarkRef (UUID, not asserted by exact value) and no localPath.
        final captured =
            verify(mockRepo.createMedia(captureAny)).captured.single
                as MediaItem;
        expect(captured.sourceType, MediaSourceType.localFile);
        expect(captured.bookmarkRef, isNotNull);
        expect(captured.bookmarkRef, isNotEmpty);
        expect(captured.localPath, isNull);
        expect(captured.diveId, 'd1');
      },
    );

    test(
      'commit propagates EXIF metadata onto the inserted MediaItem',
      () async {
        final takenAt = DateTime.utc(2024, 6, 1, 12, 30);
        final a = _ef(
          '/a.jpg',
          metadata: MediaSourceMetadata(
            mimeType: 'image/jpeg',
            takenAt: takenAt,
            latitude: 30.5,
            longitude: -85.3,
            width: 4032,
            height: 3024,
          ),
        );
        final notifier = container.read(filesTabNotifierProvider.notifier);
        notifier.setFiles(
          [a],
          match: MatchedSelection(
            matched: {
              'd1': [a],
            },
            unmatched: const [],
          ),
        );

        when(
          mockPlatform.createBookmark(any),
        ).thenAnswer((_) async => Uint8List.fromList([1]));
        when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
        when(
          mockRepo.createMedia(any),
        ).thenAnswer((_) async => _saved('saved-1'));

        await notifier.commit();

        final captured =
            verify(mockRepo.createMedia(captureAny)).captured.single
                as MediaItem;
        expect(captured.takenAt, takenAt);
        expect(captured.latitude, 30.5);
        expect(captured.longitude, -85.3);
        expect(captured.width, 4032);
        expect(captured.height, 3024);
        expect(captured.mediaType, MediaType.photo);
      },
    );

    test(
      'commit skips video MIME files (Phase 2 photo-only constraint)',
      () async {
        // Phase 2 doesn't yet support local-file video playback — videos
        // are filtered at the picker, but `commit()` defends against pick
        // bypass by skipping any video MIME inside the loop.
        final photo = _ef(
          '/a.jpg',
          metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
        );
        final video = _ef(
          '/b.mp4',
          metadata: const MediaSourceMetadata(mimeType: 'video/mp4'),
        );
        final notifier = container.read(filesTabNotifierProvider.notifier);
        notifier.setFiles(
          [photo, video],
          match: MatchedSelection(
            matched: {
              'd1': [photo, video],
            },
            unmatched: const [],
          ),
        );

        when(
          mockPlatform.createBookmark(any),
        ).thenAnswer((_) async => Uint8List.fromList([1]));
        when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
        when(
          mockRepo.createMedia(any),
        ).thenAnswer((_) async => _saved('saved-1'));

        final created = await notifier.commit();

        // Only the photo was persisted — the video MIME entry was dropped.
        expect(created.length, 1);
        final captured = verify(mockRepo.createMedia(captureAny)).captured;
        expect(captured.length, 1);
        expect((captured.single as MediaItem).mediaType, MediaType.photo);
      },
    );

    test('commit on empty match returns empty list and clears state', () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      notifier.setFiles([_ef('/a.jpg')], match: MatchedSelection.empty());

      final created = await notifier.commit();
      expect(created, isEmpty);
      verifyNever(mockRepo.createMedia(any));
      // State still resets — the Files tab returns to its initial blank state.
      expect(container.read(filesTabNotifierProvider), FilesTabState.initial());
    });

    test('undoCommit calls deleteMedia for each id', () async {
      when(mockRepo.deleteMedia(any)).thenAnswer((_) async {});

      final notifier = container.read(filesTabNotifierProvider.notifier);
      await notifier.undoCommit(['id-1', 'id-2', 'id-3']);

      verify(mockRepo.deleteMedia('id-1')).called(1);
      verify(mockRepo.deleteMedia('id-2')).called(1);
      verify(mockRepo.deleteMedia('id-3')).called(1);
    });

    test('undoCommit on empty list is a no-op', () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      await notifier.undoCommit(const []);
      verifyNever(mockRepo.deleteMedia(any));
    });
  });
}
