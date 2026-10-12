import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

class _SeededLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededLibraryNotifier(super.state);
  int loadMoreCalls = 0;

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepo extends AppSettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> getRawSetting(String key) async => values[key];

  @override
  Future<void> setRawSetting(String key, String value) async {
    values[key] = value;
  }
}

MediaLibraryEntry entry(String id) => MediaLibraryEntry(
  item: MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: p.join(Directory.systemTemp.path, id),
    localPath: p.join(Directory.systemTemp.path, id),
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  ),
);

void main() {
  Widget host(_SeededLibraryNotifier notifier) {
    return ProviderScope(
      overrides: [
        mediaLibraryNotifierProvider.overrideWith((ref) => notifier),
        appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({
            MediaSourceType.localFile: _UnavailableResolver(),
          }),
        ),
        // The filter sheet reads both; without overrides they reach real
        // repositories that have no database under flutter test.
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaLibraryView()),
      ),
    );
  }

  testWidgets('renders one tile per entry', (tester) async {
    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(entries: [entry('a'), entry('b'), entry('c')]),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryGrid), findsOneWidget);
    expect(
      tester.widgetList(find.byType(GestureDetector)).length,
      greaterThanOrEqualTo(3),
    );
  });

  // Issue #3297: the toolbar's slider sizes the thumbnails, and a resize
  // scales them instead of changing how many are across.
  testWidgets('the size slider sets how many thumbnails go across, and a '
      'resize keeps that number', (tester) async {
    int tilesInFirstRow() {
      final tiles = find.byType(MediaLibraryTile);
      final top = tester.getTopLeft(tiles.first).dy;
      return tiles
          .evaluate()
          .where((e) => tester.getTopLeft(find.byWidget(e.widget)).dy == top)
          .length;
    }

    Future<void> resizeTo(double width) async {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
    }

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(entries: [for (var i = 0; i < 40; i++) entry('m$i')]),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();

    // The middle of seven steps at 1200.
    expect(tilesInFirstRow(), 6);
    await resizeTo(900);
    expect(tilesInFirstRow(), 6);
    // (900 - 8 padding - 5 x 4 gaps) / 6: scaled down from 192 at 1200.
    expect(
      tester.getSize(find.byType(MediaLibraryTile).first).width,
      moreOrLessEquals(145.33, epsilon: 0.01),
    );

    final slider = find.byKey(const ValueKey('thumbnail_size_slider'));
    await tester.tapAt(tester.getRect(slider).centerRight - const Offset(2, 0));
    await tester.pumpAndSettle();

    // The largest: half the pane each.
    expect(tilesInFirstRow(), 2);
    await resizeTo(1200);
    expect(tilesInFirstRow(), 2);

    // The same size carries into the grouped views.
    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryGroupedList), findsOneWidget);
    expect(tilesInFirstRow(), 2);
  });

  // Issue #3297. Enough entries to scroll is the point: a scroll view with
  // nothing to scroll ignores the wheel, which hid a version of this that
  // resized only until the content outgrew the pane.
  testWidgets('Ctrl + wheel resizes a gallery long enough to scroll, in every '
      'thumbnail view, and the wheel alone still scrolls it', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(entries: [for (var i = 0; i < 200; i++) entry('m$i')]),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaLibraryView)),
    );
    int step() => container.read(mediaThumbnailScaleProvider).step;

    Future<void> wheel(double dy) async {
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      // Over a thumbnail, not the gap between two.
      pointer.hover(tester.getCenter(find.byType(MediaLibraryTile).first));
      await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
      await tester.pumpAndSettle();
    }

    for (final icon in [
      Icons.grid_view,
      Icons.scuba_diving,
      Icons.calendar_month,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, greaterThan(0), reason: '$icon');
      container.read(mediaThumbnailScaleProvider.notifier).setStep(3);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await wheel(-100);
      expect(step(), 4, reason: '$icon');
      await wheel(100);
      await wheel(100);
      expect(step(), 2, reason: '$icon');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Without Ctrl the wheel scrolls again.
      final before = position.pixels;
      await wheel(100);
      expect(position.pixels, before + 100, reason: '$icon');
      expect(step(), 2, reason: '$icon');
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  group('zoom keeps the photo under the cursor on its line (issue #3297)', () {
    // Thirteen photos a day, newest first, so the by-date view has many
    // groups and the ones above the cursor change height with the size.
    MediaLibraryEntry dated(int i) => MediaLibraryEntry(
      item: MediaItem(
        id: 'm$i',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: p.join(Directory.systemTemp.path, 'm$i'),
        localPath: p.join(Directory.systemTemp.path, 'm$i'),
        takenAt: DateTime(2026, 6, 28).subtract(Duration(days: i ~/ 13)),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      ),
    );

    Future<ScrollPosition> open(WidgetTester tester, IconData mode) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final notifier = _SeededLibraryNotifier(
        MediaLibraryState(entries: [for (var i = 0; i < 400; i++) dated(i)]),
      );
      await tester.pumpWidget(host(notifier));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(mode));
      await tester.pumpAndSettle();
      return tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
    }

    Finder tileOf(String id) => find.byWidgetPredicate(
      (w) => w is MediaLibraryTile && w.entry.item.id == id,
    );

    /// A thumbnail about halfway down the pane, and a point a third of the
    /// way down it.
    (String id, Offset cursor) pickTile(WidgetTester tester) {
      for (final element in find.byType(MediaLibraryTile).evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        if (rect.top > 450 && rect.top < 650 && rect.left > 300) {
          final tile = element.widget as MediaLibraryTile;
          return (
            tile.entry.item.id,
            Offset(rect.center.dx, rect.top + rect.height / 3),
          );
        }
      }
      fail('no thumbnail in the middle of the pane');
    }

    Future<void> ctrlWheel(
      WidgetTester tester,
      Offset cursor,
      double dy, {
      bool settle = true,
    }) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(cursor);
      await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      settle ? await tester.pumpAndSettle() : await tester.pump();
    }

    /// Where down the thumbnail [cursor] sits, 0 at its top to 1 at its foot.
    double fractionDown(WidgetTester tester, String id, Offset cursor) {
      final rect = tester.getRect(tileOf(id));
      return (cursor.dy - rect.top) / rect.height;
    }

    for (final (name, mode) in [
      ('gallery', Icons.grid_view),
      ('by date', Icons.calendar_month),
    ]) {
      testWidgets('$name: zooming in and out', (tester) async {
        final position = await open(tester, mode);
        position.jumpTo(1500);
        await tester.pumpAndSettle();
        final (id, cursor) = pickTile(tester);
        expect(fractionDown(tester, id, cursor), moreOrLessEquals(1 / 3));

        // Larger, twice: a single frame each, so nothing settles into place.
        await ctrlWheel(tester, cursor, -100, settle: false);
        expect(
          fractionDown(tester, id, cursor),
          moreOrLessEquals(1 / 3, epsilon: 0.01),
        );
        await ctrlWheel(tester, cursor, -100, settle: false);
        expect(
          fractionDown(tester, id, cursor),
          moreOrLessEquals(1 / 3, epsilon: 0.01),
        );

        // And smaller, past where it started. Not all the way: small
        // enough, the photo is nearer the gallery's start than the cursor
        // is to the top of the pane, which is the next tests' business.
        for (var i = 0; i < 3; i++) {
          await ctrlWheel(tester, cursor, 100, settle: false);
          expect(
            fractionDown(tester, id, cursor),
            moreOrLessEquals(1 / 3, epsilon: 0.01),
            reason: 'wheel down $i',
          );
        }
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    }

    testWidgets('over the gap between two rows, holds the photo above', (
      tester,
    ) async {
      final position = await open(tester, Icons.grid_view);
      position.jumpTo(1500);
      await tester.pumpAndSettle();
      final (id, onTile) = pickTile(tester);
      final foot = tester.getRect(tileOf(id)).bottom;
      // Two pixels into the four between this row and the next.
      final cursor = Offset(onTile.dx, foot + 2);

      for (final dy in [-100.0, -100.0, 100.0, 100.0, 100.0]) {
        await ctrlWheel(tester, cursor, dy, settle: false);
        expect(
          tester.getRect(tileOf(id)).bottom,
          moreOrLessEquals(foot, epsilon: 0.5),
          reason: 'wheel $dy',
        );
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('over the gap between two columns, holds a photo beside it', (
      tester,
    ) async {
      final position = await open(tester, Icons.grid_view);
      position.jumpTo(1500);
      await tester.pumpAndSettle();
      final (id, onTile) = pickTile(tester);
      final rect = tester.getRect(tileOf(id));
      final cursor = Offset(rect.right + 2, onTile.dy);

      await ctrlWheel(tester, cursor, -100, settle: false);

      expect(
        fractionDown(tester, id, cursor),
        moreOrLessEquals(1 / 3, epsilon: 0.01),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('over a date heading, holds the photo above it', (
      tester,
    ) async {
      final position = await open(tester, Icons.calendar_month);
      position.jumpTo(1500);
      await tester.pumpAndSettle();
      // A heading with photos above it on screen: under its text, the
      // nearest thumbnail foot.
      final headings = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.style?.fontSize ==
                Theme.of(
                  tester.element(find.byType(MediaLibraryView)),
                ).textTheme.labelLarge?.fontSize,
      );
      Offset? cursor;
      String? id;
      double? foot;
      for (final heading in headings.evaluate()) {
        final at = tester.getCenter(find.byWidget(heading.widget));
        if (at.dy < 200 || at.dy > 850) continue;
        for (final element in find.byType(MediaLibraryTile).evaluate()) {
          final rect = tester.getRect(find.byWidget(element.widget));
          if (rect.bottom <= at.dy && at.dy - rect.bottom < 40) {
            // The heading spans the pane; stand on it under this photo.
            cursor = Offset(rect.center.dx, at.dy);
            id = (element.widget as MediaLibraryTile).entry.item.id;
            foot = rect.bottom;
          }
        }
        if (cursor != null) break;
      }
      expect(cursor, isNotNull, reason: 'no heading under a photo on screen');

      for (final dy in [-100.0, 100.0, 100.0]) {
        await ctrlWheel(tester, cursor!, dy, settle: false);
        expect(
          tester.getRect(tileOf(id!)).bottom,
          moreOrLessEquals(foot!, epsilon: 0.5),
          reason: 'wheel $dy',
        );
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('stops at the start of the gallery', (tester) async {
      final position = await open(tester, Icons.grid_view);
      final first = tester.getRect(tileOf('m0'));
      // The foot of a first-row photo: shrinking it would need the gallery
      // to start below its own top.
      final cursor = Offset(first.center.dx, first.bottom - 2);

      await ctrlWheel(tester, cursor, 100, settle: false);

      expect(position.pixels, 0);
      expect(tester.getRect(tileOf('m0')).top, first.top);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('stops at the end of the gallery', (tester) async {
      final position = await open(tester, Icons.grid_view);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final last = tester.getRect(tileOf('m399'));
      // The top of a last-row photo: shrinking it leaves less gallery below
      // than the pane below the cursor.
      final cursor = Offset(last.center.dx, last.top + 2);

      for (var i = 0; i < 3; i++) {
        await ctrlWheel(tester, cursor, 100, settle: false);
        expect(position.outOfRange, isFalse, reason: 'wheel down $i');
        expect(position.pixels, position.maxScrollExtent);
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    // A zoom relays the gallery out while Cmd is still down. Whether the
    // list can be dragged is decided at layout, so it must not be decided
    // by the key, or two-finger scrolling stays off once Cmd is let go.
    testWidgets('a trackpad still scrolls the gallery after a Cmd + wheel '
        'zoom', (tester) async {
      final position = await open(tester, Icons.grid_view);
      final (_, cursor) = pickTile(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      mouse.hover(cursor);
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(position.pixels, 0);

      final trackpad = TestPointer(2, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(trackpad.panZoomStart(cursor));
      await tester.sendEventToBinding(
        trackpad.panZoomUpdate(cursor, pan: const Offset(0, -300)),
      );
      await tester.sendEventToBinding(trackpad.panZoomEnd());
      await tester.pumpAndSettle();

      expect(position.pixels, greaterThan(0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  testWidgets('shows localized empty state when no entries', (tester) async {
    final notifier = _SeededLibraryNotifier(const MediaLibraryState());
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();
    expect(find.text('No media yet'), findsOneWidget);
  });

  testWidgets('scrolling near the end calls loadMore', (tester) async {
    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(
        entries: [for (var i = 0; i < 60; i++) entry('m$i')],
        nextCursor: const MediaLibraryCursor(sortKey: 1, id: 'm59'),
      ),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GridView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(notifier.loadMoreCalls, greaterThan(0));
  });

  testWidgets('view mode switcher swaps to the grouped presentation', (
    tester,
  ) async {
    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(entries: [entry('a'), entry('b')]),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryGrid), findsOneWidget);

    await tester.tap(find.byIcon(Icons.scuba_diving));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryGroupedList), findsOneWidget);
    expect(find.byType(MediaLibraryGrid), findsNothing);

    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    expect(find.byType(MediaLibraryGroupedList), findsOneWidget);
  });

  testWidgets('the toolbar filter button reaches the sheet and applies', (
    tester,
  ) async {
    // End to end through the real view: the type facet now lives in the
    // filter sheet, so this proves the view mounts the toolbar and the
    // toolbar opens a sheet that writes the shared filter provider.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _SeededLibraryNotifier(
      MediaLibraryState(entries: [entry('a')]),
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaLibraryView)),
    );

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      container.read(mediaLibraryFilterProvider).mediaType,
      MediaType.video,
    );

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).mediaType, isNull);
  });
}
