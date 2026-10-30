import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/people_tag_viewer_mixin.dart';

import '../../../../../helpers/test_database.dart';
import 'people_tag_test_host.dart';

/// Tag mode in the viewer (issue #1745): tap a person, pick who it is, and
/// edit or remove a box by tapping it.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedPeopleTagFixtures();
  });
  tearDown(tearDownTestDatabase);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openViewer(
    WidgetTester tester, {
    MediaItem? item,
    bool withImage = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final shown = item ?? photoItem();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        await peopleTagHost(
          MediaViewerPage(mediaList: [shown], initialMediaId: shown.id),
          withImage: withImage,
        ),
      );
    });
    await settle(tester);
  }

  Future<List<MediaPeopleData>> rows(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.mediaPeople).get()))!;

  testWidgets('the toolbar offers Tag people, which shows the hint', (
    tester,
  ) async {
    await openViewer(tester);
    await tester.tap(find.byTooltip('Tag people'));
    await settle(tester);

    expect(find.text('Tap a person to tag them'), findsOneWidget);
    expect(find.text('Tag without a spot'), findsOneWidget);
  });

  testWidgets('a tap on the photo opens the picker and saves the box', (
    tester,
  ) async {
    await openViewer(tester);
    await tester.tap(find.byTooltip('Tag people'));
    await settle(tester);

    // The photo is 1200 x 900 in a 1200 x 900 view: the centre is (0.5, 0.5).
    await tester.tapAt(const Offset(600, 450));
    await settle(tester);
    expect(find.text('Who is this?'), findsOneWidget);
    // The dropped box shows while the picker asks who it is.
    expect(find.byKey(const ValueKey('pending-face-box')), findsOneWidget);
    await tester.tap(find.text('Alex'));
    await settle(tester);

    expect(find.byKey(const ValueKey('pending-face-box')), findsNothing);
    final row = (await rows(tester)).single;
    expect(row.buddyId, 'alex');
    expect(row.bboxX! + row.bboxWidth! / 2, closeTo(0.5, 0.01));
    expect(row.bboxY! + row.bboxHeight! / 2, closeTo(0.5, 0.01));
    expect(find.text("Add Alex to this dive's buddies?"), findsOneWidget);
  });

  testWidgets('Tag without a spot saves a tag with no box', (tester) async {
    await openViewer(tester);
    await tester.tap(find.byTooltip('Tag people'));
    await settle(tester);
    await tester.tap(find.text('Tag without a spot'));
    await settle(tester);
    await tester.tap(find.text('Me'));
    await settle(tester);

    final row = (await rows(tester)).single;
    expect(row.diverId, 'A');
    expect(row.bboxX, isNull);
  });

  testWidgets('tapping an existing box offers to remove it', (tester) async {
    await tester.runAsync(
      () => MediaPeopleRepository().addTag(
        mediaId: 'p1',
        buddyId: 'bea',
        box: const FaceBox(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
      ),
    );
    await openViewer(tester);
    await tester.tap(find.byTooltip('Tag people'));
    await settle(tester);

    await tester.tapAt(const Offset(600, 450));
    await settle(tester);
    expect(find.text('Who is this?'), findsNothing);
    expect(find.text('Change person'), findsOneWidget);
    await tester.tap(find.text('Remove tag'));
    await settle(tester);

    expect(await rows(tester), isEmpty);
  });

  testWidgets('Escape leaves tag mode before it closes the viewer', (
    tester,
  ) async {
    await openViewer(tester);
    await tester.tap(find.byTooltip('Tag people'));
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    expect(find.text('Tap a person to tag them'), findsNothing);
    expect(find.byType(MediaViewerPage), findsOneWidget);
  });

  testWidgets('starting Pick white leaves tag mode, and tagging leaves it', (
    tester,
  ) async {
    await openViewer(tester);
    await tester.tap(find.byTooltip('Tag people'));
    await settle(tester);
    expect(find.text('Tap a person to tag them'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('viewer_adjust_color')));
    await settle(tester);
    await tester.tap(find.text('Pick white'));
    await settle(tester);
    expect(find.text('Tap a person to tag them'), findsNothing);
    expect(
      find.text('Tap something that should be white or gray'),
      findsOneWidget,
    );
  });

  testWidgets('a tag without a spot can be picked from the bar and removed', (
    tester,
  ) async {
    await tester.runAsync(
      () => MediaPeopleRepository().addTag(mediaId: 'p1', buddyId: 'bea'),
    );
    await openViewer(tester);
    await tester.tap(find.byTooltip('Tag people'));
    await settle(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Bea'));
    await settle(tester);
    expect(find.text('Change person'), findsOneWidget);
    await tester.tap(find.text('Remove tag'));
    await settle(tester);

    expect(await rows(tester), isEmpty);
  });

  testWidgets(
    'without a known image size only a tag without a spot is offered',
    (tester) async {
      await openViewer(
        tester,
        item: photoItem(width: null, height: null),
        withImage: false,
      );
      await tester.tap(find.byTooltip('Tag people'));
      await settle(tester);

      expect(find.text('Tap a person to tag them'), findsNothing);
      expect(find.text("Spots can't be marked on this one"), findsOneWidget);
      expect(find.text('Tag without a spot'), findsOneWidget);
    },
  );

  testWidgets('a moment chip on a video that cannot play shows its time and '
      'stays put', (tester) async {
    await tester.runAsync(() async {
      await db.customStatement(
        "UPDATE media SET file_type = 'video' WHERE id = 'p1'",
      );
      await MediaPeopleRepository().addTag(
        mediaId: 'p1',
        buddyId: 'bea',
        box: const FaceBox(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
        videoPosition: const Duration(seconds: 42),
      );
    });
    final video = MediaItem(
      id: 'p1',
      diveId: 'd1',
      mediaType: MediaType.video,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime(2024, 1, 10),
      createdAt: DateTime(2024, 1, 10),
      updatedAt: DateTime(2024, 1, 10),
    );
    await openViewer(tester, item: video, withImage: false);

    expect(find.text('Bea · 0:42'), findsOneWidget);
    await tester.tap(find.text('Bea · 0:42'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(find.text('Bea · 0:42'), findsOneWidget);
  });

  group('canPlaceSpot', () {
    MediaItem video({
      MediaSourceType source = MediaSourceType.platformGallery,
    }) => MediaItem(
      id: 'v1',
      mediaType: MediaType.video,
      sourceType: source,
      takenAt: DateTime(2024),
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    test('a photo with a known size can take a spot', () {
      expect(
        canPlaceSpot(
          photoItem(),
          videoReady: false,
          imageSize: const Size(4, 3),
        ),
        isTrue,
      );
      expect(
        canPlaceSpot(photoItem(), videoReady: false, imageSize: null),
        isFalse,
      );
    });

    test('a video needs a ready player off Linux and off a connector', () {
      const size = Size(16, 9);
      expect(
        canPlaceSpot(video(), videoReady: true, imageSize: size, linux: false),
        isTrue,
      );
      expect(
        canPlaceSpot(video(), videoReady: false, imageSize: size, linux: false),
        isFalse,
      );
      expect(
        canPlaceSpot(video(), videoReady: true, imageSize: size, linux: true),
        isFalse,
      );
      expect(
        canPlaceSpot(
          video(source: MediaSourceType.serviceConnector),
          videoReady: true,
          imageSize: size,
          linux: false,
        ),
        isFalse,
      );
    });
  });
}
