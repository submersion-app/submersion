import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/unmatched_diagnostic.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';

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
        // The real enqueue reads MediaStorePolicies, which needs
        // SharedPreferences and therefore a Flutter binding that plain
        // test() bodies do not have. Enqueue behavior is covered by the
        // "commit enqueues each created row for upload" group, which
        // constructs the notifier directly.
        mediaStoreEnqueueProvider.overrideWithValue((_) {}),
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

    // The notifier is not autoDispose, so an abandoned session's files
    // outlive it. The next session may attach to a different dive or to a
    // site, where they would show up as that entity's staged set.
    test('clearStagedFiles drops files and match, keeping the toggle', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      notifier.toggleAutoMatch();
      notifier.setFiles(
        [a],
        match: MatchedSelection(
          matched: {
            'd1': [a],
          },
          unmatched: const [],
        ),
      );
      notifier.setExtractionProgress(done: 1, total: 2);

      notifier.clearStagedFiles();

      final state = container.read(filesTabNotifierProvider);
      expect(state.files, isEmpty);
      expect(state.match, MatchedSelection.empty());
      expect(state.isExtracting, isFalse);
      expect(state.extractedCount, 0);
      expect(state.totalToExtract, 0);
      // Unlike clear(), the user's preference is not a staging artifact.
      expect(state.autoMatchByDate, isFalse);
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

  // commit() only ever persists files sitting in match.matched, so a file the
  // date matcher rejected had no route into the database at all: the Link
  // button is gated on matched being non-empty, and turning the auto-match
  // checkbox off put EVERY file in unmatched, making the whole tab a no-op.
  // These mutators are what let a user link photos the matcher didn't claim.
  group('manual dive assignment', () {
    test('assignToDive moves an unmatched file into the dive bucket', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      final b = _ef('/b.jpg');
      notifier.setFiles([
        a,
        b,
      ], match: MatchedSelection(matched: const {}, unmatched: [a, b]));

      notifier.assignToDive('/a.jpg', 'd1');

      final state = container.read(filesTabNotifierProvider);
      expect(state.match.matched['d1'], [a]);
      expect(state.match.unmatched, [b]);
    });

    test('assignToDive appends to an existing dive bucket', () {
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

      notifier.assignToDive('/b.jpg', 'd1');

      final state = container.read(filesTabNotifierProvider);
      expect(state.match.matched['d1'], [a, b]);
      expect(state.match.unmatched, isEmpty);
    });

    test('assignToDive re-homes a file without duplicating it', () {
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

      notifier.assignToDive('/a.jpg', 'd2');

      final state = container.read(filesTabNotifierProvider);
      // Emptied groups are dropped, mirroring removeFile.
      expect(state.match.matched.containsKey('d1'), isFalse);
      expect(state.match.matched['d2'], [a]);
      expect(state.match.totalFiles, 1);
    });

    test('assignToDive ignores a path that is not staged', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      notifier.setFiles([
        a,
      ], match: MatchedSelection(matched: const {}, unmatched: [a]));

      notifier.assignToDive('/nope.jpg', 'd1');

      final state = container.read(filesTabNotifierProvider);
      expect(state.match.matched, isEmpty);
      expect(state.match.unmatched, [a]);
    });

    test('assignAllUnmatched empties the unmatched bucket', () {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      final b = _ef('/b.jpg');
      final c = _ef('/c.jpg');
      notifier.setFiles(
        [a, b, c],
        match: MatchedSelection(
          matched: {
            'd1': [a],
          },
          unmatched: [b, c],
        ),
      );

      notifier.assignAllUnmatched('d1');

      final state = container.read(filesTabNotifierProvider);
      expect(state.match.matched['d1'], [a, b, c]);
      expect(state.match.unmatched, isEmpty);
    });

    test('assignAllUnmatched on an empty bucket is a no-op', () {
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
      final before = container.read(filesTabNotifierProvider);

      notifier.assignAllUnmatched('d1');

      expect(container.read(filesTabNotifierProvider), before);
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

    // The Files tab never recorded originalFilename, unlike the other import
    // path (MediaImportService). A null filename makes
    // StoreKeys.extensionFor fall back to 'bin', so a linked video uploads
    // and caches as <hash>.bin -- and AVFoundation, which infers a container
    // from the path extension, cannot open that. The video plays on the
    // machine that linked it (local file, real name) and fails everywhere
    // else, which is what made it look like a sync bug.
    test('commit records the picked file name', () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final clip = _ef(
        '/Users/somebody/Downloads/dive media/GX015932-2.MP4',
        metadata: const MediaSourceMetadata(mimeType: 'video/mp4'),
      );
      notifier.setFiles(
        [clip],
        match: MatchedSelection(
          matched: {
            'd1': [clip],
          },
          unmatched: const [],
        ),
      );

      when(
        mockPlatform.createBookmark(any),
      ).thenAnswer((_) async => Uint8List.fromList([1]));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
      when(mockPlatform.takePersistableUri(any)).thenAnswer((_) async => 'uri');
      when(
        mockRepo.createMedia(any),
      ).thenAnswer((_) async => _saved('saved-video'));

      await notifier.commit();

      final captured =
          verify(mockRepo.createMedia(captureAny)).captured.single as MediaItem;
      expect(captured.originalFilename, 'GX015932-2.MP4');
      expect(captured.mediaType, MediaType.video);
    });

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
        // bookmarkRef (UUID, not asserted by exact value).
        // On macOS, localPath is also populated so the desktop right-click
        // "Show in Finder" gate fires (bookmark stays the source of truth
        // for resolution). On iOS, localPath stays null — the picker's
        // sandboxed path is not reusable.
        final captured =
            verify(mockRepo.createMedia(captureAny)).captured.single
                as MediaItem;
        expect(captured.sourceType, MediaSourceType.localFile);
        expect(captured.bookmarkRef, isNotNull);
        expect(captured.bookmarkRef, isNotEmpty);
        if (Platform.isMacOS) {
          expect(captured.localPath, '/a.jpg');
        } else {
          expect(captured.localPath, isNull);
        }
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

    test('commit persists video MIME files as MediaType.video', () async {
      // Local-file video import is supported on desktop: the file resolves
      // by localPath and plays via VideoPlayerController.file, so commit()
      // persists videos alongside photos and tags the row MediaType.video.
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

      // Both the photo and the video were persisted.
      expect(created.length, 2);
      final captured = verify(mockRepo.createMedia(captureAny)).captured;
      expect(captured.length, 2);
      final types = captured.map((c) => (c as MediaItem).mediaType).toList();
      expect(types, containsAll([MediaType.photo, MediaType.video]));
    });

    test('commit on empty match returns empty list and clears state', () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      notifier.setFiles([_ef('/a.jpg')], match: MatchedSelection.empty());

      final created = await notifier.commit();
      expect(created, isEmpty);
      verifyNever(mockRepo.createMedia(any));
      // State still resets — the Files tab returns to its initial blank state.
      expect(container.read(filesTabNotifierProvider), FilesTabState.initial());
    });

    test('undoCommit deletes the committed rows via the deletion '
        'coordinator', () async {
      // The provider-wired notifier routes through the deletion
      // coordinator, which looks each row up (for a possible remote-blob
      // delete intent) and then batch-deletes.
      when(mockRepo.getMediaById(any)).thenAnswer((_) async => null);
      when(mockRepo.deleteMultipleMedia(any)).thenAnswer((_) async {});

      final notifier = container.read(filesTabNotifierProvider.notifier);
      await notifier.undoCommit(['id-1', 'id-2', 'id-3']);

      verify(mockRepo.deleteMultipleMedia(['id-1', 'id-2', 'id-3'])).called(1);
    });

    test('undoCommit on empty list deletes nothing', () async {
      when(mockRepo.deleteMultipleMedia(any)).thenAnswer((_) async {});
      final notifier = container.read(filesTabNotifierProvider.notifier);
      await notifier.undoCommit(const []);
      verifyNever(mockRepo.deleteMedia(any));
    });
  });

  group('commit enqueues each created row for upload', () {
    test(
      'onMediaCreated fires once per persisted row with the saved id',
      () async {
        final enqueued = <String>[];
        when(
          mockPlatform.createBookmark(any),
        ).thenAnswer((_) async => Uint8List(0));
        when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
        when(
          mockRepo.createMedia(any),
        ).thenAnswer((_) async => _saved('media-1'));

        final notifier = FilesTabNotifier(
          mediaRepository: mockRepo,
          bookmarkStorage: mockBookmarkStorage,
          platform: mockPlatform,
          onMediaCreated: enqueued.add,
        );
        notifier.setFiles(
          [_ef('/a.jpg')],
          match: MatchedSelection(
            matched: {
              'dive-1': [_ef('/a.jpg')],
            },
            unmatched: const [],
          ),
        );

        final ids = await notifier.commit();

        expect(ids, ['media-1']);
        expect(enqueued, ['media-1']);
      },
    );

    test('a null onMediaCreated does not throw', () async {
      when(
        mockPlatform.createBookmark(any),
      ).thenAnswer((_) async => Uint8List(0));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
      when(
        mockRepo.createMedia(any),
      ).thenAnswer((_) async => _saved('media-2'));

      final notifier = FilesTabNotifier(
        mediaRepository: mockRepo,
        bookmarkStorage: mockBookmarkStorage,
        platform: mockPlatform,
      );
      notifier.setFiles(
        [_ef('/b.jpg')],
        match: MatchedSelection(
          matched: {
            'dive-1': [_ef('/b.jpg')],
          },
          unmatched: const [],
        ),
      );

      await expectLater(notifier.commit(), completion(['media-2']));
    });
  });

  // Issue #1098: the picker opened from a dive site staged files that had no
  // route into the database. commit() only walked match.matched, which is
  // keyed by dive id, so a site session committed nothing no matter what the
  // user did. A site target bypasses the matcher entirely: every staged file
  // belongs to the site the user was looking at.
  group('commit with a site target', () {
    setUp(() {
      when(
        mockPlatform.createBookmark(any),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
    });

    test('persists every staged file against the site', () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      final b = _ef('/b.jpg');
      notifier.setFiles([a, b], match: MatchedSelection.empty());

      final captured = <MediaItem>[];
      var counter = 0;
      when(mockRepo.createMedia(any)).thenAnswer((invocation) async {
        captured.add(invocation.positionalArguments.first as MediaItem);
        counter += 1;
        return _saved('saved-$counter');
      });

      final created = await notifier.commit(
        target: const SiteAttachTarget('site-1'),
      );

      expect(created, ['saved-1', 'saved-2']);
      expect(captured.map((m) => m.siteId), ['site-1', 'site-1']);
      // A site attachment is not a dive attachment. Setting both would make
      // the row show up in the dive's grid too.
      expect(captured.map((m) => m.diveId), [null, null]);
    });

    test('persists files the dive matcher rejected', () async {
      // The exact state from the issue: auto-match ran, matched no dive, and
      // parked everything in `unmatched`. Under the dive-keyed commit this
      // was the unreachable case.
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      notifier.setFiles([
        a,
      ], match: MatchedSelection(matched: const {}, unmatched: [a]));
      when(
        mockRepo.createMedia(any),
      ).thenAnswer((_) async => _saved('saved-1'));

      final created = await notifier.commit(
        target: const SiteAttachTarget('site-1'),
      );

      expect(created, ['saved-1']);
      verify(mockRepo.createMedia(any)).called(1);
    });

    test('ignores a stale dive grouping left in match', () async {
      // `match` can still hold a dive grouping from an earlier session on the
      // same (non-autoDispose) notifier. `files` is the authority for a site
      // commit, so nothing may be persisted twice or routed to a dive.
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      notifier.setFiles(
        [a],
        match: MatchedSelection(
          matched: {
            'stale-dive': [a],
          },
          unmatched: const [],
        ),
      );

      final captured = <MediaItem>[];
      when(mockRepo.createMedia(any)).thenAnswer((invocation) async {
        captured.add(invocation.positionalArguments.first as MediaItem);
        return _saved('saved-1');
      });

      await notifier.commit(target: const SiteAttachTarget('site-1'));

      expect(captured, hasLength(1));
      expect(captured.single.diveId, isNull);
      expect(captured.single.siteId, 'site-1');
    });

    test('clears state on success', () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      notifier.setFiles([_ef('/a.jpg')], match: MatchedSelection.empty());
      when(
        mockRepo.createMedia(any),
      ).thenAnswer((_) async => _saved('saved-1'));

      await notifier.commit(target: const SiteAttachTarget('site-1'));

      expect(container.read(filesTabNotifierProvider), FilesTabState.initial());
    });

    test('enqueues each created row for upload', () async {
      final enqueued = <String>[];
      when(
        mockRepo.createMedia(any),
      ).thenAnswer((_) async => _saved('media-1'));

      final notifier = FilesTabNotifier(
        mediaRepository: mockRepo,
        bookmarkStorage: mockBookmarkStorage,
        platform: mockPlatform,
        onMediaCreated: enqueued.add,
      );
      notifier.setFiles([_ef('/a.jpg')], match: MatchedSelection.empty());

      await notifier.commit(target: const SiteAttachTarget('site-1'));

      expect(enqueued, ['media-1']);
    });
  });

  // A row that names both owners shows up in a dive's grid and a site's; one
  // that names neither shows up in nothing, which is indistinguishable from
  // the import having silently failed. Neither announces itself, so the
  // one-owner rule is asserted at the write.
  group('one-owner invariant', () {
    test('a site commit never also stamps a dive', () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      notifier.setFiles([a], match: MatchedSelection.empty());
      when(
        mockPlatform.createBookmark(any),
      ).thenAnswer((_) async => Uint8List.fromList([1]));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
      final captured = <MediaItem>[];
      when(mockRepo.createMedia(any)).thenAnswer((invocation) async {
        captured.add(invocation.positionalArguments.first as MediaItem);
        return _saved('saved-1');
      });

      await notifier.commit(target: const SiteAttachTarget('site-1'));

      // The assert in _persistOne would have thrown before reaching here had
      // commit passed both; this pins the resulting row shape too.
      expect(captured.single.siteId, 'site-1');
      expect(captured.single.diveId, isNull);
    });

    test('a dive commit never also stamps a site', () async {
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
      ).thenAnswer((_) async => Uint8List.fromList([1]));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
      final captured = <MediaItem>[];
      when(mockRepo.createMedia(any)).thenAnswer((invocation) async {
        captured.add(invocation.positionalArguments.first as MediaItem);
        return _saved('saved-1');
      });

      await notifier.commit(target: const DiveAttachTarget('d1'));

      expect(captured.single.diveId, 'd1');
      expect(captured.single.siteId, isNull);
    });
  });

  // A dive target must keep routing through the matcher's grouping: a file
  // the user assigned to dive B stays on dive B even though the picker was
  // opened from dive A.
  group('commit with a dive target', () {
    test('still persists the matcher grouping, not the opening dive', () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      final b = _ef('/b.jpg');
      notifier.setFiles(
        [a, b],
        match: MatchedSelection(
          matched: {
            'dive-a': [a],
            'dive-b': [b],
          },
          unmatched: const [],
        ),
      );

      when(
        mockPlatform.createBookmark(any),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
      final captured = <MediaItem>[];
      var counter = 0;
      when(mockRepo.createMedia(any)).thenAnswer((invocation) async {
        captured.add(invocation.positionalArguments.first as MediaItem);
        counter += 1;
        return _saved('saved-$counter');
      });

      await notifier.commit(target: const DiveAttachTarget('dive-a'));

      expect(captured.map((m) => m.diveId), ['dive-a', 'dive-b']);
      expect(captured.map((m) => m.siteId), [null, null]);
    });
  });

  group('diveBoundsProvider', () {
    test('uses the dive exit time when present', () async {
      final dive = Dive(
        id: 'dive-1',
        dateTime: DateTime.utc(2025, 12, 27, 11, 26),
        exitTime: DateTime.utc(2025, 12, 27, 12, 9),
      );
      final boundsContainer = ProviderContainer(
        overrides: [
          divesProvider.overrideWith((ref) async => [dive]),
        ],
      );
      addTearDown(boundsContainer.dispose);

      final bounds = await boundsContainer.read(diveBoundsProvider.future);

      expect(bounds.single.diveId, 'dive-1');
      expect(bounds.single.entryTime, DateTime.utc(2025, 12, 27, 11, 26));
      expect(bounds.single.exitTime, DateTime.utc(2025, 12, 27, 12, 9));
    });

    test('falls back to entry plus one hour with no exit or runtime', () async {
      final dive = Dive(
        id: 'dive-2',
        dateTime: DateTime.utc(2025, 12, 27, 11, 26),
      );
      final boundsContainer = ProviderContainer(
        overrides: [
          divesProvider.overrideWith((ref) async => [dive]),
        ],
      );
      addTearDown(boundsContainer.dispose);

      final bounds = await boundsContainer.read(diveBoundsProvider.future);

      expect(bounds.single.exitTime, DateTime.utc(2025, 12, 27, 12, 26));
    });
  });

  group('capture time offset', () {
    FilesTabNotifier makeNotifier() => FilesTabNotifier(
      mediaRepository: mockRepo,
      bookmarkStorage: mockBookmarkStorage,
      platform: mockPlatform,
    );

    test('defaults to zero', () {
      expect(FilesTabState.initial().captureTimeOffset, Duration.zero);
    });

    test('setCaptureTimeOffset updates the offset and the match together', () {
      final notifier = makeNotifier();
      final rematched = MatchedSelection(
        matched: {
          'dive-1': [_ef('/a.jpg')],
        },
        unmatched: const [],
      );

      notifier.setCaptureTimeOffset(
        const Duration(hours: -5),
        match: rematched,
      );

      expect(notifier.state.captureTimeOffset, const Duration(hours: -5));
      expect(notifier.state.match, rematched);
    });

    test('clearStagedFiles resets the offset but keeps auto-match', () {
      final notifier = makeNotifier();
      notifier.toggleAutoMatch();
      notifier.setCaptureTimeOffset(
        const Duration(hours: 5),
        match: MatchedSelection.empty(),
      );

      notifier.clearStagedFiles();

      expect(notifier.state.captureTimeOffset, Duration.zero);
      expect(notifier.state.autoMatchByDate, isFalse);
    });

    test('the diagnostics survive a manual assignment', () {
      final notifier = makeNotifier();
      final file = _ef('/a.jpg');
      notifier.setFiles(
        [file],
        match: MatchedSelection(
          matched: const {},
          unmatched: [file],
          diagnostics: const {
            '/a.jpg': UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp),
          },
        ),
      );

      notifier.assignToDive('/a.jpg', 'dive-1');

      expect(notifier.state.match.diagnostics, isNotEmpty);
      expect(notifier.state.match.matched['dive-1'], [file]);
    });

    test('the diagnostics survive removing a file', () {
      final notifier = makeNotifier();
      final kept = _ef('/a.jpg');
      final dropped = _ef('/b.jpg');
      notifier.setFiles(
        [kept, dropped],
        match: MatchedSelection(
          matched: const {},
          unmatched: [kept, dropped],
          diagnostics: const {
            '/a.jpg': UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp),
            '/b.jpg': UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp),
          },
        ),
      );

      notifier.removeFile('/b.jpg');

      expect(notifier.state.match.diagnostics.containsKey('/a.jpg'), isTrue);
      expect(notifier.state.match.unmatched, [kept]);
    });

    test('the diagnostics survive a bulk assignment', () {
      final notifier = makeNotifier();
      final file = _ef('/a.jpg');
      notifier.setFiles(
        [file],
        match: MatchedSelection(
          matched: const {},
          unmatched: [file],
          diagnostics: const {
            '/a.jpg': UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp),
          },
        ),
      );

      notifier.assignAllUnmatched('dive-1');

      expect(notifier.state.match.diagnostics, isNotEmpty);
      expect(notifier.state.match.unmatched, isEmpty);
    });
  });

  group('offset is applied when persisting', () {
    setUp(() {
      when(
        mockPlatform.createBookmark(any),
      ).thenAnswer((_) async => Uint8List(0));
      when(mockBookmarkStorage.write(any, any)).thenAnswer((_) async {});
      when(
        mockRepo.createMedia(any),
      ).thenAnswer((_) async => _saved('media-1'));
    });

    FilesTabNotifier stagedNotifier(DateTime takenAt) {
      final file = _ef(
        '/a.jpg',
        metadata: MediaSourceMetadata(takenAt: takenAt, mimeType: 'image/jpeg'),
      );
      final notifier = FilesTabNotifier(
        mediaRepository: mockRepo,
        bookmarkStorage: mockBookmarkStorage,
        platform: mockPlatform,
      );
      notifier.setFiles(
        [file],
        match: MatchedSelection(
          matched: {
            'dive-1': [file],
          },
          unmatched: const [],
        ),
      );
      return notifier;
    }

    test('commit writes taken_at shifted by the session offset', () async {
      final notifier = stagedNotifier(DateTime.utc(2025, 12, 27, 16, 47));
      notifier.setCaptureTimeOffset(
        const Duration(hours: -5),
        match: notifier.state.match,
      );

      await notifier.commit();

      final captured = verify(mockRepo.createMedia(captureAny)).captured;
      expect(
        (captured.single as MediaItem).takenAt,
        DateTime.utc(2025, 12, 27, 11, 47),
      );
    });

    test('a zero offset writes the extracted time unchanged', () async {
      final notifier = stagedNotifier(DateTime.utc(2025, 12, 27, 11, 47));

      await notifier.commit();

      final captured = verify(mockRepo.createMedia(captureAny)).captured;
      expect(
        (captured.single as MediaItem).takenAt,
        DateTime.utc(2025, 12, 27, 11, 47),
      );
    });
  });
}
