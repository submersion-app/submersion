// The Photos & videos page shows its upload settings only on a device that
// keeps copies. Attaching or detaching must not discard the Advanced
// section's State, which holds any export, verify or backfill in flight.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media_store/presentation/pages/photos_videos_page.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_advanced_section.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_upload_settings.dart';

import 'photos_page_harness.dart';

void main() {
  late PhotosPageHarness h;

  setUp(() async => h = await PhotosPageHarness.create());

  Future<void> settle(WidgetTester tester) => tester.runAsync(() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });

  for (final startAttached in [true, false]) {
    testWidgets('the Advanced section keeps its State when attached flips '
        '(starting ${startAttached ? 'attached' : 'detached'})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var attached = startAttached;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          h.app(
            copies: () => (
              attached: attached,
              store: null,
              group: null,
              label: 'dive-media @ minio',
            ),
          ),
        );
      });
      await settle(tester);

      expect(
        find.byType(PhotosUploadSettings),
        startAttached ? findsOneWidget : findsNothing,
      );
      final before = tester.state(find.byType(PhotosAdvancedSection));

      attached = !startAttached;
      ProviderScope.containerOf(
        tester.element(find.byType(PhotosVideosPage)),
      ).invalidate(photosCopiesProvider);
      await settle(tester);

      expect(
        find.byType(PhotosUploadSettings),
        attached ? findsOneWidget : findsNothing,
      );
      expect(tester.state(find.byType(PhotosAdvancedSection)), same(before));
    });
  }
}
