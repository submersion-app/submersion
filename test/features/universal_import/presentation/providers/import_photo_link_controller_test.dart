import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/local_media_linker.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';
import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/import_photo_link_controller.dart';

class _FakeScanner implements DirectoryScanner {
  _FakeScanner(this.files);
  final Map<String, String> files; // basename -> path
  @override
  Stream<ScannedFile> scan(GrantedFolder folder) async* {
    for (final e in files.entries) {
      yield ScannedFile(
        basename: e.key,
        handle: MediaHandle.localPath(e.value),
      );
    }
  }
}

/// Scanner whose enumeration throws, to exercise the run-level error path.
class _ThrowingScanner implements DirectoryScanner {
  @override
  Stream<ScannedFile> scan(GrantedFolder folder) async* {
    throw StateError('scan boom');
  }
}

/// Records linked (diveId, basename) pairs; can be told to throw for a
/// specific basename to exercise per-photo isolation.
class _FakeLinker implements LocalMediaLinker {
  final List<({String diveId, String basename})> linked = [];
  String? throwForBasename;

  @override
  Future<MediaItem> link({
    required String diveId,
    required MediaHandle handle,
    required String basename,
    required MediaSourceMetadata metadata,
    required DateTime fallbackTakenAt,
    String? caption,
  }) async {
    if (basename == throwForBasename) {
      throw StateError('boom');
    }
    linked.add((diveId: diveId, basename: basename));
    return MediaItem(
      id: 'm-${linked.length}',
      diveId: diveId,
      mediaType: MediaType.photo,
      takenAt: DateTime(2024),
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
  }

  // Unused by the controller in tests but required by the interface.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ImportPhotoLinkController _controller({
  required DirectoryScanner scanner,
  required LocalMediaLinker linker,
  required List<ImportImageRef> imageRefs,
  required Map<String, String> sourceUuidToDiveId,
  Set<String> Function(String diveId)? alreadyLinkedBasenames,
}) {
  return ImportPhotoLinkController(
    scannerFor: (_) => scanner,
    linker: linker,
    metadataFor: (_) async => const MediaSourceMetadata(mimeType: 'image/jpeg'),
    alreadyLinkedBasenames: alreadyLinkedBasenames ?? (_) => const <String>{},
    fallbackTakenAtFor: (_) => DateTime(2020),
  )..seed(imageRefs: imageRefs, sourceUuidToDiveId: sourceUuidToDiveId);
}

void main() {
  test(
    'links resolved photos to the mapped dive and summarises counts',
    () async {
      final linker = _FakeLinker();
      final controller = _controller(
        scanner: _FakeScanner({
          'shark.jpg': '/picked/shark.jpg',
          'turtle.jpg': '/picked/turtle.jpg',
        }),
        linker: linker,
        imageRefs: const [
          ImportImageRef(originalPath: '/x/shark.jpg', diveSourceUuid: 'src-1'),
          ImportImageRef(
            originalPath: '/x/turtle.jpg',
            diveSourceUuid: 'src-1',
          ),
        ],
        sourceUuidToDiveId: const {'src-1': 'dive-1'},
      );

      await controller.pickedFolder(const GrantedFolder(path: '/picked'));

      final s = controller.state.summary!;
      expect(s.total, 2);
      expect(s.linked, 2);
      expect(s.notFound, 0);
      expect(s.skippedNonImage, 0);
      expect(linker.linked, [
        (diveId: 'dive-1', basename: 'shark.jpg'),
        (diveId: 'dive-1', basename: 'turtle.jpg'),
      ]);
    },
  );

  test('photo with no dive mapping is counted not-found, not linked', () async {
    final linker = _FakeLinker();
    final controller = _controller(
      scanner: _FakeScanner({'a.jpg': '/picked/a.jpg'}),
      linker: linker,
      imageRefs: const [
        ImportImageRef(originalPath: '/x/a.jpg', diveSourceUuid: 'unknown'),
      ],
      sourceUuidToDiveId: const {},
    );
    await controller.pickedFolder(const GrantedFolder(path: '/picked'));
    expect(controller.state.summary!.linked, 0);
    expect(controller.state.summary!.notFound, 1);
    expect(linker.linked, isEmpty);
  });

  test('dedupe by (diveId + basename): skips already-linked', () async {
    final linker = _FakeLinker();
    final controller = _controller(
      scanner: _FakeScanner({'shark.jpg': '/picked/shark.jpg'}),
      linker: linker,
      imageRefs: const [
        ImportImageRef(originalPath: '/x/shark.jpg', diveSourceUuid: 'src-1'),
      ],
      sourceUuidToDiveId: const {'src-1': 'dive-1'},
      alreadyLinkedBasenames: (diveId) =>
          diveId == 'dive-1' ? {'shark.jpg'} : const {},
    );
    await controller.pickedFolder(const GrantedFolder(path: '/picked'));
    expect(linker.linked, isEmpty);
    // Already-linked photos count as linked in the summary (they ARE linked).
    expect(controller.state.summary!.linked, 1);
  });

  test('re-pick is idempotent: second run links nothing new', () async {
    final linker = _FakeLinker();
    final alreadyLinked = <String, Set<String>>{'dive-1': <String>{}};
    final controller =
        ImportPhotoLinkController(
          scannerFor: (_) => _FakeScanner({'shark.jpg': '/picked/shark.jpg'}),
          linker: linker,
          metadataFor: (_) async =>
              const MediaSourceMetadata(mimeType: 'image/jpeg'),
          alreadyLinkedBasenames: (diveId) =>
              alreadyLinked[diveId] ?? const <String>{},
          fallbackTakenAtFor: (_) => DateTime(2020),
        )..seed(
          imageRefs: const [
            ImportImageRef(
              originalPath: '/x/shark.jpg',
              diveSourceUuid: 'src-1',
            ),
          ],
          sourceUuidToDiveId: const {'src-1': 'dive-1'},
        );

    await controller.pickedFolder(const GrantedFolder(path: '/picked'));
    expect(linker.linked.length, 1);
    // Simulate persistence: the linked basename is now present.
    alreadyLinked['dive-1'] = {'shark.jpg'};
    await controller.pickedFolder(const GrantedFolder(path: '/picked'));
    expect(linker.linked.length, 1); // no new links
  });

  test('per-photo failure is isolated and counted as not-found', () async {
    final linker = _FakeLinker()..throwForBasename = 'bad.jpg';
    final controller = _controller(
      scanner: _FakeScanner({
        'good.jpg': '/picked/good.jpg',
        'bad.jpg': '/picked/bad.jpg',
      }),
      linker: linker,
      imageRefs: const [
        ImportImageRef(originalPath: '/x/good.jpg', diveSourceUuid: 'src-1'),
        ImportImageRef(originalPath: '/x/bad.jpg', diveSourceUuid: 'src-1'),
      ],
      sourceUuidToDiveId: const {'src-1': 'dive-1'},
    );
    await controller.pickedFolder(const GrantedFolder(path: '/picked'));
    expect(linker.linked.map((l) => l.basename), ['good.jpg']);
    expect(controller.state.summary!.linked, 1);
    expect(controller.state.summary!.notFound, 1);
  });

  test(
    'run-level scan failure sets errorMessage and resets progress',
    () async {
      final controller =
          ImportPhotoLinkController(
            scannerFor: (_) => _ThrowingScanner(),
            linker: _FakeLinker(),
            metadataFor: (_) async =>
                const MediaSourceMetadata(mimeType: 'image/jpeg'),
            alreadyLinkedBasenames: (_) => const <String>{},
            fallbackTakenAtFor: (_) => DateTime(2020),
          )..seed(
            imageRefs: const [
              ImportImageRef(originalPath: '/x/a.jpg', diveSourceUuid: 'src-1'),
            ],
            sourceUuidToDiveId: const {'src-1': 'dive-1'},
          );

      await controller.pickedFolder(const GrantedFolder(path: '/picked'));

      expect(controller.state.isRunning, isFalse);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.summary, isNull);
      expect(controller.state.processed, 0);
      expect(controller.state.total, 0);
    },
  );

  test('non-image refs are skipped and counted', () async {
    final linker = _FakeLinker();
    final controller = _controller(
      scanner: _FakeScanner({'clip.mov': '/picked/clip.mov'}),
      linker: linker,
      imageRefs: const [
        ImportImageRef(originalPath: '/x/clip.mov', diveSourceUuid: 'src-1'),
      ],
      sourceUuidToDiveId: const {'src-1': 'dive-1'},
    );
    await controller.pickedFolder(const GrantedFolder(path: '/picked'));
    expect(controller.state.summary!.skippedNonImage, 1);
    expect(controller.state.summary!.linked, 0);
    expect(linker.linked, isEmpty);
  });
}
