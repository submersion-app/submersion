import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/presentation/widgets/import_photo_locate_prompt.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_linker.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/presentation/providers/import_photo_link_controller.dart';

// These render-only tests never pick a folder, so the linker is never
// invoked. `linker` is a non-function field, so a `throw` in argument
// position would fire eagerly at construction; a real (unused) linker is the
// faithful render-only stand-in.
LocalMediaLinker _neverLinker() => LocalMediaLinker(
  mediaRepository: MediaRepository(),
  bookmarkStorage: LocalBookmarkStorage(),
);

ImportPhotoLinkController _seededController({PhotoLinkSummary? summary}) {
  final c = ImportPhotoLinkController(
    scannerFor: (_) => throw UnimplementedError(),
    linker: _neverLinker(),
    metadataFor: (_) => throw UnimplementedError(),
    alreadyLinkedBasenames: (_) async => const <String>{},
    fallbackTakenAtFor: (_) => DateTime(2020),
  );
  c.seed(
    imageRefs: const [
      ImportImageRef(originalPath: '/x/a.jpg', diveSourceUuid: 'd'),
      ImportImageRef(originalPath: '/x/b.jpg', diveSourceUuid: 'd'),
    ],
    sourceUuidToDiveId: const {'d': 'dive-1'},
  );
  if (summary != null) {
    c.state = c.state.copyWith(summary: summary);
  }
  return c;
}

Widget _wrap(ImportPhotoLinkController controller, Widget child) {
  return ProviderScope(
    overrides: [
      importPhotoLinkControllerProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('prompt shows the photo-reference count + a Locate action', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final controller = _seededController();
      await tester.pumpWidget(
        _wrap(controller, const ImportPhotoLocatePrompt()),
      );
      expect(find.textContaining('2'), findsWidgets);
      expect(find.text('Locate Photos'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'summary state shows linked/notFound counts + Try another folder',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final controller = _seededController(
          summary: const PhotoLinkSummary(
            total: 2,
            linked: 1,
            notFound: 1,
            skippedNonImage: 0,
          ),
        );
        await tester.pumpWidget(
          _wrap(controller, const ImportPhotoLocatePrompt()),
        );
        expect(find.textContaining('1'), findsWidgets);
        expect(find.text('Try another folder'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('renders nothing when there are no photo references', (
    tester,
  ) async {
    final controller = ImportPhotoLinkController(
      scannerFor: (_) => throw UnimplementedError(),
      linker: _neverLinker(),
      metadataFor: (_) => throw UnimplementedError(),
      alreadyLinkedBasenames: (_) async => const <String>{},
      fallbackTakenAtFor: (_) => DateTime(2020),
    ); // not seeded -> refCount 0
    await tester.pumpWidget(_wrap(controller, const ImportPhotoLocatePrompt()));
    expect(find.text('Locate Photos'), findsNothing);
  });

  testWidgets('error state shows the message + Try another folder', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final controller = _seededController();
      controller.state = controller.state.copyWith(
        errorMessage: 'Could not scan that folder.',
      );
      await tester.pumpWidget(
        _wrap(controller, const ImportPhotoLocatePrompt()),
      );
      expect(find.text('Could not scan that folder.'), findsOneWidget);
      expect(find.text('Try another folder'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
