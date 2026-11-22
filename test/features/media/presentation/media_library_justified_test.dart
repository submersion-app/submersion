import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/value_objects/learned_aspect.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import 'support/media_widget_harness.dart';

MediaLibraryEntry _entry(String id, {int? width, int? height}) =>
    MediaLibraryEntry(
      item: testMediaItem(
        id: id,
        originalFilename: '$id.png',
      ).copyWith(width: width, height: height),
    );

Finder _tile(String id) => find.byWidgetPredicate(
  (w) => w is MediaLibraryTile && w.entry.item.id == id,
);

/// The justified media library (issue #4738).
void main() {
  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpHost(
    WidgetTester tester,
    Widget body, {
    MediaAspectCacheRepository? shapes,
    MediaSourceData? resolverData,
  }) async {
    await tester.pumpWidget(
      await mediaTestApp(
        home: Scaffold(body: body),
        resolverData: resolverData,
        overrides: [
          mediaStoreAttachedProvider.overrideWith((ref) async => false),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaAspectCacheRepositoryProvider.overrideWithValue(
            shapes ?? FakeAspectCacheRepository(),
          ),
        ],
      ),
    );
  }

  Widget grid(List<MediaLibraryEntry> entries, {double rowHeight = 200}) =>
      MediaLibraryGrid(
        entries: entries,
        hasMore: false,
        onLoadMore: () {},
        onTileTap: (_, _) {},
        rowHeight: rowHeight,
      );

  testWidgets('tiles keep their shape and share a row height', (tester) async {
    await setSize(tester, const Size(1200, 900));
    await pumpHost(
      tester,
      grid([
        _entry('landscape', width: 4000, height: 3000),
        _entry('portrait', width: 3000, height: 4000),
        _entry('wide', width: 1600, height: 900),
      ]),
    );
    await tester.pump();

    for (final (id, ratio) in [
      ('landscape', 4 / 3),
      ('portrait', 3 / 4),
      ('wide', 16 / 9),
    ]) {
      final size = tester.getSize(_tile(id));
      expect(size.height, moreOrLessEquals(200), reason: id);
      expect(size.width, moreOrLessEquals(200 * ratio, epsilon: 0.5));
    }
  });

  testWidgets('full rows end at the pane edge', (tester) async {
    await setSize(tester, const Size(1200, 900));
    await pumpHost(
      tester,
      grid([
        for (var i = 0; i < 12; i++) _entry('m$i', width: 4000, height: 3000),
      ]),
    );
    await tester.pump();

    final top = tester.getRect(_tile('m0')).top;
    final firstRow = [
      for (var i = 0; i < 12; i++)
        if (tester.getRect(_tile('m$i')).top == top)
          tester.getRect(_tile('m$i')),
    ];
    expect(firstRow.length, greaterThan(1));
    expect(firstRow.first.left, moreOrLessEquals(8));
    expect(firstRow.last.right, moreOrLessEquals(1200 - 8));
  });

  testWidgets('the first layout waits for the learned shapes', (tester) async {
    await setSize(tester, const Size(1200, 900));
    final load = Completer<Map<String, LearnedAspect>>();
    await pumpHost(
      tester,
      grid([_entry('a', width: 4000, height: 3000)]),
      shapes: FakeAspectCacheRepository.held(load.future),
    );
    await tester.pump();
    expect(_tile('a'), findsNothing);

    load.complete({'a': (ratio: 0.75, width: 4000, height: 3000)});
    await tester.pump();
    await tester.pump();

    final size = tester.getSize(_tile('a'));
    expect(size.width / size.height, moreOrLessEquals(0.75, epsilon: 0.01));
  });

  testWidgets('a thumbnail decoded upright re-lays its tile', (tester) async {
    await setSize(tester, const Size(1200, 900));
    // Stored as landscape, as a camera writes a portrait shot with an EXIF
    // rotation; its thumbnail decodes upright.
    final portrait = img.encodePng(img.Image(width: 3, height: 4));
    await pumpHost(
      tester,
      grid([_entry('a', width: 4000, height: 3000)]),
      resolverData: BytesData(bytes: portrait),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    final size = tester.getSize(_tile('a'));
    expect(size.width / size.height, moreOrLessEquals(0.75, epsilon: 0.01));
  });

  testWidgets('a shape learned above the view leaves the view in place', (
    tester,
  ) async {
    await setSize(tester, const Size(1200, 700));
    final groups = [
      for (var g = 0; g < 200; g++)
        MediaLibraryGroup(
          header: DiveGroupHeader(diveId: 'd$g', diveNumber: g),
          entries: [
            for (var i = 0; i < 4; i++)
              _entry('$g-$i', width: 4000, height: 3000),
          ],
        ),
    ];
    await pumpHost(
      tester,
      MediaLibraryGroupedList(
        groups: groups,
        hasMore: false,
        onLoadMore: () {},
        onTileTap: (_) {},
        rowHeight: 120,
      ),
    );
    await tester.pump();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(8000);
    await tester.pump();
    final onScreen =
        find.byType(MediaLibraryTile).evaluate().first.widget
            as MediaLibraryTile;
    final id = onScreen.entry.item.id;
    final top = tester.getRect(_tile(id)).top;

    // A photo near the start, far above the view, turns out to be portrait.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaLibraryGroupedList)),
    );
    container
        .read(mediaLearnedAspectsProvider.notifier)
        .report(groups[1].entries.first.item, const Size(300, 400));
    await tester.pump();
    await tester.pump();

    expect(
      container.read(mediaLearnedAspectsProvider).requireValue,
      contains('1-0'),
    );
    expect(tester.getRect(_tile(id)).top, moreOrLessEquals(top));
  });
}
