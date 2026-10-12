import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
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
      'thumbnail view, without scrolling it', (tester) async {
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
      // Not always 0: a view swapped in takes over the last one's offset.
      final before = position.pixels;
      container.read(mediaThumbnailScaleProvider.notifier).setStep(3);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await wheel(-100);
      expect(step(), 4, reason: '$icon');
      await wheel(100);
      await wheel(100);
      expect(step(), 2, reason: '$icon');
      expect(position.pixels, before, reason: '$icon');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      // Without Ctrl the wheel scrolls again.
      await wheel(100);
      expect(position.pixels, before + 100, reason: '$icon');
      expect(step(), 2, reason: '$icon');
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

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
