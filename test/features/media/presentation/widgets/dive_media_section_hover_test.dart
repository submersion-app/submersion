import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/media/presentation/widgets/media_hover_region.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  diveId: 'dive-1',
  filePath: '/tmp/$id.jpg',
  originalFilename: '$id.jpg',
  mediaType: MediaType.photo,
  takenAt: DateTime(2026, 3, 15),
  createdAt: DateTime(2026, 3, 15),
  updatedAt: DateTime(2026, 3, 15),
);

/// Mutable media list, so a test can take an item away the way an unlink
/// does.
final _mediaProvider = StateProvider<List<MediaItem>>((ref) => const []);

/// A point in the default 800 x 600 test window that is clear of the grid.
const _offGrid = Offset(790, 590);

void main() {
  Widget host(
    List<MediaItem> media, {
    void Function(MediaItem? item)? onHoverMedia,
  }) {
    return testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        _mediaProvider.overrideWith((ref) => media),
        // Synchronous on purpose: a change of the list then rebuilds the
        // grid in a single frame, so a removed thumbnail and the one taking
        // its place meet in that frame, as they do after an unlink.
        mediaForDiveProvider(
          'dive-1',
        ).overrideWith((ref) => ref.watch(_mediaProvider)),
      ],
      child: SingleChildScrollView(
        child: DiveMediaSection(diveId: 'dive-1', onHoverMedia: onHoverMedia),
      ),
    );
  }

  Finder thumbnails() => find.descendant(
    of: find.byType(DragSelectGridView<MediaItem>),
    matching: find.byType(MediaHoverRegion),
  );

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: _offGrid);
    addTearDown(gesture.removePointer);
    return gesture;
  }

  group('DiveMediaSection hover', () {
    testWidgets(
      'reports the item under the pointer, then null when it leaves',
      (tester) async {
        final reported = <MediaItem?>[];
        await tester.pumpWidget(
          host([_item('a'), _item('b')], onHoverMedia: reported.add),
        );
        await tester.pumpAndSettle();
        final gesture = await mouse(tester);

        await gesture.moveTo(tester.getCenter(thumbnails().at(0)));
        await tester.pump();
        expect(reported.single!.id, 'a');

        await gesture.moveTo(_offGrid);
        await tester.pump();
        expect(reported, hasLength(2));
        expect(reported.last, isNull);
      },
    );

    testWidgets('moving from one thumbnail to the next ends on the next item', (
      tester,
    ) async {
      final reported = <MediaItem?>[];
      await tester.pumpWidget(
        host([_item('a'), _item('b')], onHoverMedia: reported.add),
      );
      await tester.pumpAndSettle();
      final gesture = await mouse(tester);

      await gesture.moveTo(tester.getCenter(thumbnails().at(0)));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(thumbnails().at(1)));
      await tester.pump();

      expect(reported.last!.id, 'b');
    });

    testWidgets(
      'removing the hovered item ends on the item that slides under the '
      'pointer',
      (tester) async {
        final a = _item('a');
        final b = _item('b');
        final reported = <MediaItem?>[];
        await tester.pumpWidget(host([a, b], onHoverMedia: reported.add));
        await tester.pumpAndSettle();
        final gesture = await mouse(tester);
        await gesture.moveTo(tester.getCenter(thumbnails().at(0)));
        await tester.pump();
        expect(reported.last!.id, 'a');

        ProviderScope.containerOf(
          tester.element(find.byType(DiveMediaSection)),
        ).read(_mediaProvider.notifier).state = [
          b,
        ];
        await tester.pumpAndSettle();

        expect(thumbnails(), findsOneWidget);
        expect(reported.last!.id, 'b');
      },
    );

    testWidgets('removing the only hovered item ends on null', (tester) async {
      final a = _item('a');
      final reported = <MediaItem?>[];
      await tester.pumpWidget(host([a], onHoverMedia: reported.add));
      await tester.pumpAndSettle();
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(thumbnails().at(0)));
      await tester.pump();

      ProviderScope.containerOf(
        tester.element(find.byType(DiveMediaSection)),
      ).read(_mediaProvider.notifier).state = const [];
      await tester.pumpAndSettle();

      expect(reported.first!.id, 'a');
      expect(reported.last, isNull);
    });

    // A removed thumbnail reports its leave after the frame. Flutter happens
    // to run that before it re-checks what is under the pointer, but nothing
    // promises the order, so the section must not depend on it.
    testWidgets(
      'a late leave from another thumbnail does not clear the one now hovered',
      (tester) async {
        final reported = <MediaItem?>[];
        await tester.pumpWidget(
          host([_item('a'), _item('b')], onHoverMedia: reported.add),
        );
        await tester.pumpAndSettle();
        final first = tester.widget<MediaHoverRegion>(thumbnails().at(0));
        final second = tester.widget<MediaHoverRegion>(thumbnails().at(1));

        first.onHoverChanged(true);
        second.onHoverChanged(true);
        first.onHoverChanged(false);

        expect(reported.map((item) => item?.id), ['a', 'b']);
      },
    );

    testWidgets('still reports in selection mode', (tester) async {
      final reported = <MediaItem?>[];
      await tester.pumpWidget(
        host([_item('a'), _item('b')], onHoverMedia: reported.add),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      final gesture = await mouse(tester);

      await gesture.moveTo(tester.getCenter(thumbnails().at(0)));
      await tester.pump();

      expect(reported.last!.id, 'a');
    });

    testWidgets('without the callback, hovering does nothing', (tester) async {
      await tester.pumpWidget(host([_item('a'), _item('b')]));
      await tester.pumpAndSettle();
      final gesture = await mouse(tester);

      await gesture.moveTo(tester.getCenter(thumbnails().at(0)));
      await tester.pump();
      await gesture.moveTo(_offGrid);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
