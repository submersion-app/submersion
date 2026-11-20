import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/pages/media_scoped_gallery_page.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_scoped_gallery_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_toolbar.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../support/media_widget_harness.dart';

class _SeededLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededLibraryNotifier(super.state);

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoShapesRepository implements MediaAspectCacheRepository {
  @override
  Future<Map<String, LearnedAspect>> loadAll() async => const {};

  @override
  Future<void> putAll(Map<String, LearnedAspect> entries) async {}
}

/// The focused gallery a detail card's +N opens (issue #4741): the scope's
/// media and nothing else, with no tabs, actions, filters or map.
void main() {
  const filter = MediaLibraryFilter(
    siteId: 's1',
    attachedTo: {MediaAttachmentKind.dive},
  );

  final entries = [
    for (var i = 0; i < 3; i++)
      MediaLibraryEntry(
        item: testMediaItem(
          id: 'p$i',
          diveId: 'dive-$i',
        ).copyWith(width: 400, height: 300),
      ),
  ];

  late List<MediaGalleryScope> scopes;
  late List<(List<String>, String)> opened;

  setUp(() {
    scopes = [];
    opened = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    List<MediaLibraryEntry>? rows,
  }) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          mediaAspectCacheRepositoryProvider.overrideWithValue(
            _NoShapesRepository(),
          ),
          mediaStoreAttachedProvider.overrideWith((ref) async => false),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaScopedLibraryProvider.overrideWith((ref, scope) {
            scopes.add(scope);
            return _SeededLibraryNotifier(
              MediaLibraryState(entries: rows ?? entries),
            );
          }),
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openMediaGallery(
                context,
                title: 'Photos from dives',
                subtitle: 'Blue Hole',
                filter: filter,
                openViewer: (context, items, id) =>
                    opened.add(([for (final m in items) m.id], id)),
              ),
              child: const Text('SITE'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SITE'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the scope\'s media under its title', (tester) async {
    await pump(tester);
    expect(find.text('Photos from dives'), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.byType(MediaLibraryTile), findsNWidgets(3));
    expect(scopes.first.filter, filter);
    expect(scopes.first.mode, MediaLibraryViewMode.grid);
  });

  testWidgets('no tabs, actions, filters or map', (tester) async {
    await pump(tester);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(MediaLibraryToolbar), findsNothing);
    expect(find.byType(MediaLibraryActiveFilterChips), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate), findsNothing);
    expect(find.byIcon(Icons.map), findsNothing);

    await tester.tap(find.byKey(kMediaGalleryViewMenuKey));
    await tester.pumpAndSettle();
    expect(find.text('Grid'), findsWidgets);
    expect(find.text('By dive'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Map'), findsNothing);
  });

  testWidgets('By dive groups the same scope by dive', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(kMediaGalleryViewMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By dive'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaLibraryGroupedList), findsOneWidget);
    expect(find.byType(MediaLibraryGrid), findsNothing);
    expect(scopes.last.mode, MediaLibraryViewMode.byDive);
    expect(scopes.last.filter, filter);
  });

  testWidgets('it leaves the Media screen\'s own filter alone', (tester) async {
    await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaScopedGalleryPage)),
    );
    expect(container.read(mediaLibraryFilterProvider), MediaLibraryFilter.none);
  });

  testWidgets('a tile opens the viewer on what the gallery shows', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byType(MediaLibraryTile).at(1));
    await tester.pumpAndSettle();
    expect(opened.single.$1, ['p0', 'p1', 'p2']);
    expect(opened.single.$2, 'p1');
  });

  testWidgets('Back returns to the page that opened it', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('SITE'), findsOneWidget);
    expect(find.byType(MediaScopedGalleryPage), findsNothing);
  });

  testWidgets('an empty scope says so', (tester) async {
    await pump(tester, rows: const []);
    expect(find.byType(MediaLibraryTile), findsNothing);
    expect(find.text('No media matches these filters'), findsOneWidget);
  });

  // The menu holds the view, the sort and the size together (issue #4741).
  group('the view menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(kMediaGalleryViewMenuKey));
      await tester.pumpAndSettle();
    }

    testWidgets('offers sort and the size slider beside the views', (
      tester,
    ) async {
      await pump(tester);
      await openMenu(tester);
      expect(find.text('Sort media'), findsOneWidget);
      expect(find.byKey(const ValueKey('thumbnail_size_slider')), findsOne);
    });

    testWidgets('the slider resizes the thumbnails', (tester) async {
      await pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MediaScopedGalleryPage)),
      );
      final before = container.read(mediaThumbnailScaleProvider).step;
      final heightBefore = tester.getSize(find.byType(MediaLibraryTile).first);

      await openMenu(tester);
      final slider = find.byKey(const ValueKey('thumbnail_size_slider'));
      await tester.tapAt(
        tester.getRect(slider).centerRight - const Offset(30, 0),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(mediaThumbnailScaleProvider).step,
        greaterThan(before),
      );
      // Closing the menu shows the new size.
      await tester.tapAt(const Offset(4, 300));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(MediaLibraryTile).first).height,
        greaterThan(heightBefore.height),
      );
    });

    testWidgets('Sort opens the library sort sheet', (tester) async {
      await pump(tester);
      await openMenu(tester);
      await tester.tap(find.text('Sort media'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('the grouped views offer no sort: they order by date', (
      tester,
    ) async {
      await pump(tester);
      await openMenu(tester);
      await tester.tap(find.text('By dive'));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('Sort media'), findsNothing);
      expect(find.byKey(const ValueKey('thumbnail_size_slider')), findsOne);
    });
  });
}
