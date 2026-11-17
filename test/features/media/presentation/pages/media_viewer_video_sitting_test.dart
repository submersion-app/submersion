import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/video_color_filter.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';
import 'video_viewer_test_harness.dart';

/// A video in its sitting is drawn with the sitting's colour (issue #4527),
/// as a photo is: the panel lets go of its draft on every release, so a
/// player drawing the stored row would snap back to the old colour.
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await insertTestDiver('me');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10, 9), diverId: 'me');
    await insertTestMedia(
      id: 'v1',
      diveId: 'd1',
      takenAt: DateTime(2024, 1, 10, 9, 2),
      fileType: 'video',
    );
  });
  tearDown(tearDownTestDatabase);

  testWidgets('the player draws the held colour, not the stored one', (
    tester,
  ) async {
    final platform = FakeVideoPlatform();
    useVideoPlatform(platform);
    final items = await tester.runAsync(() => storedMedia(['v1']));
    await pumpViewerApp(
      tester,
      MediaViewerPage(mediaList: items!, initialMediaId: 'v1'),
      overrides: [
        resolvedFilePathProvider.overrideWith(
          (ref, MediaItem arg) async => tempVideoPath('v1'),
        ),
      ],
    );
    await tester.runAsync(() async {
      platform.completeInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleViewer(tester);
    expect(find.byType(VideoColorFilter), findsOneWidget);

    await tapUnlock(tester);
    const held = ColorAdjustment(warmth: 0.5);
    photoController(tester).session!.set(photoColorField, held);
    await settleViewer(tester);

    final drawn = tester.widget<VideoColorFilter>(
      find.byType(VideoColorFilter),
    );
    expect(drawn.item.colorAdjustment, held);
  });
}
