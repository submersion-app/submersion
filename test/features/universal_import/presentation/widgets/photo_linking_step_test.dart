import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/photo_linking_step.dart';

// Minimal override — seeds a state with imageRefs so the widget has
// something to render. We don't use the real notifier's async methods
// in widget tests.
ProviderContainer _containerWithPayload({
  int photoCount = 3,
  String? photoRootDir,
  List<ResolvedPhoto>? resolvedPhotos,
  bool skipped = false,
}) {
  final refs = List.generate(
    photoCount,
    (i) => ImportImageRef(
      originalPath: '/fake/photo$i.jpg',
      diveSourceUuid: 'dive-$i',
    ),
  );
  final container = ProviderContainer(
    overrides: [
      universalImportNotifierProvider.overrideWith((ref) {
        final notifier = UniversalImportNotifier(ref);
        notifier.state = notifier.state.copyWith(
          payload: ImportPayload(entities: const {}, imageRefs: refs),
          photoRootDir: photoRootDir,
          resolvedPhotos: resolvedPhotos,
          photoLinkingSkipped: skipped,
        );
        return notifier;
      }),
    ],
  );
  return container;
}

Widget _wrap(ProviderContainer c, Widget child) {
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  // Flutter widget tests default to TargetPlatform.android. Our desktop
  // branch only renders on non-mobile platforms, so each desktop test
  // wraps its body in try/finally to temporarily force macOS and
  // restore the default before the framework's debug-var invariant
  // check runs.
  testWidgets('shows photo count when payload has imageRefs', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final container = _containerWithPayload(photoCount: 42);
      addTearDown(container.dispose);
      await tester.pumpWidget(_wrap(container, const PhotoLinkingStep()));
      expect(find.textContaining('42'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('no root picked: shows Pick folder + Skip photos actions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final container = _containerWithPayload();
      addTearDown(container.dispose);
      await tester.pumpWidget(_wrap(container, const PhotoLinkingStep()));
      expect(find.text('Pick folder'), findsOneWidget);
      expect(find.text('Skip photos'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('after resolution: shows "N found, M missing" summary', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final container = _containerWithPayload(
        photoRootDir: '/some/folder',
        resolvedPhotos: const [
          ResolvedPhoto(
            ref: ImportImageRef(originalPath: 'a', diveSourceUuid: 'd'),
            kind: PhotoResolutionKind.directPath,
            resolvedPath: '/some/folder/a',
          ),
          ResolvedPhoto(
            ref: ImportImageRef(originalPath: 'b', diveSourceUuid: 'd'),
            kind: PhotoResolutionKind.miss,
          ),
          ResolvedPhoto(
            ref: ImportImageRef(originalPath: 'c', diveSourceUuid: 'd'),
            kind: PhotoResolutionKind.rebased,
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_wrap(container, const PhotoLinkingStep()));
      // 2 found (direct + rebased), 1 missing.
      expect(find.textContaining('2 found'), findsOneWidget);
      expect(find.textContaining('1 missing'), findsOneWidget);
      expect(find.text('Change folder'), findsOneWidget);
      expect(find.text('Skip remaining'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tapping "Skip photos" calls skipPhotoLinking on notifier', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final container = _containerWithPayload();
      addTearDown(container.dispose);
      await tester.pumpWidget(_wrap(container, const PhotoLinkingStep()));
      await tester.tap(find.text('Skip photos'));
      await tester.pump();
      final state = container.read(universalImportNotifierProvider);
      expect(state.photoLinkingSkipped, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
