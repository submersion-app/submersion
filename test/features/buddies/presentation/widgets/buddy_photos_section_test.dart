import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_photos_section.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';
import '../../../media/presentation/widgets/people_tags/people_tag_test_host.dart';

/// The photos and videos a buddy is tagged in, on the buddy page
/// (issue #1745).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await seedPeopleTagFixtures();
    await insertTestMedia(
      id: 'p2',
      diveId: 'd1',
      takenAt: DateTime(2024, 3, 1),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        await peopleTagHost(
          const Scaffold(
            body: SingleChildScrollView(
              child: BuddyPhotosSection(buddyId: 'alex'),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  testWidgets('is hidden while the buddy is tagged in nothing', (tester) async {
    await pump(tester);
    expect(find.text('Photos and videos'), findsNothing);
  });

  testWidgets('shows the tagged media newest first', (tester) async {
    await tester.runAsync(() async {
      await MediaPeopleRepository().addTag(mediaId: 'p1', buddyId: 'alex');
      await MediaPeopleRepository().addTag(mediaId: 'p2', buddyId: 'alex');
    });
    await pump(tester);

    expect(find.text('Photos and videos'), findsOneWidget);
    final tiles = tester
        .widgetList<MediaThumbnailTile>(find.byType(MediaThumbnailTile))
        .map((t) => t.item.id)
        .toList();
    expect(tiles, ['p2', 'p1']);
  });

  testWidgets('a tap opens the viewer on that item', (tester) async {
    await tester.runAsync(
      () => MediaPeopleRepository().addTag(mediaId: 'p1', buddyId: 'alex'),
    );
    await pump(tester);
    await tester.tap(find.byType(MediaThumbnailTile));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final viewer = tester.widget<MediaViewerPage>(find.byType(MediaViewerPage));
    expect(viewer.initialMediaId, 'p1');
  });

  testWidgets('shows nine and a View All that filters the library', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 10; i++) {
        await insertTestMedia(
          id: 'x$i',
          diveId: 'd1',
          takenAt: DateTime(2024, 4, 1 + i),
        );
        await MediaPeopleRepository().addTag(mediaId: 'x$i', buddyId: 'alex');
      }
    });
    await pump(tester);

    expect(find.byType(MediaThumbnailTile), findsNWidgets(9));
    expect(find.text('View All (10)'), findsOneWidget);
  });
}
