import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/pages/species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/species_photos_section.dart';

import '../support/media_widget_harness.dart';
import '../../../../helpers/marine_life_id_off.dart';

MediaItem _photo(String id, {int width = 600, int height = 600}) =>
    testMediaItem(id: id, diveId: 'd1').copyWith(width: width, height: height);

MediaLibraryEntry _entry(
  String id, {
  int width = 600,
  int height = 600,
  DateTime? diveDateTime,
  String? siteName,
}) => MediaLibraryEntry(
  item: _photo(id, width: width, height: height),
  diveDateTime: diveDateTime,
  siteName: siteName,
);

List<MediaLibraryEntry> _squares(int count, {String prefix = 'p'}) => [
  for (var i = 0; i < count; i++) _entry('$prefix$i'),
];

Future<void> _pump(
  WidgetTester tester,
  List<MediaLibraryEntry> entries, {
  VoidCallback? onTagPhotos,
  VoidCallback? onAddPhotos,
  List<MediaItem> pendingItems = const [],
  Widget Function(MediaItem item)? pendingOverlay,
  bool browser = false,
  double width = 800,
  FakeAspectCacheRepository? shapes,
}) async {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    await mediaTestApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SpeciesPhotosSection(
            speciesId: 'sp_x',
            onTagPhotos: onTagPhotos,
            onAddPhotos: onAddPhotos,
            pendingItems: pendingItems,
            pendingOverlay: pendingOverlay,
          ),
        ),
      ),
      overrides: [
        mediaEntriesForSpeciesProvider(
          'sp_x',
        ).overrideWith((ref) async => entries),
        mediaForSpeciesProvider(
          'sp_x',
        ).overrideWith((ref) async => [for (final e in entries) e.item]),
        mediaAspectCacheRepositoryProvider.overrideWithValue(
          shapes ?? FakeAspectCacheRepository(),
        ),
        if (browser)
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Rect _tileRect(WidgetTester tester, String id) =>
    tester.getRect(find.byKey(ValueKey('species_photo_$id')));

String _formatDate(WidgetTester tester, DateTime date) =>
    ProviderScope.containerOf(
      tester.element(find.byType(SpeciesPhotosSection)),
    ).read(unitFormatterProvider).formatDate(date);

void main() {
  turnOffMarineLifeIdForEachTest();

  final entries = [_entry('p1'), _entry('p2')];

  testWidgets('renders a titled section of tagged photos', (tester) async {
    await _pump(tester, entries);

    expect(find.text('Photos (2)'), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
    expect(find.byType(MediaEmptyState), findsNothing);
  });

  testWidgets('shows the empty state with the actions still available', (
    tester,
  ) async {
    await _pump(tester, const [], onTagPhotos: () {}, onAddPhotos: () {});

    expect(find.text('Photos (0)'), findsOneWidget);
    expect(find.byType(MediaEmptyState), findsOneWidget);
    expect(find.text('Tag photos'), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
  });

  testWidgets('hides an action whose callback is absent', (tester) async {
    await _pump(tester, entries, onAddPhotos: () {});

    expect(find.text('Tag photos'), findsNothing);
    expect(find.text('Add photos'), findsOneWidget);
  });

  testWidgets('the actions call back', (tester) async {
    var tagged = false;
    var added = false;
    await _pump(
      tester,
      entries,
      onTagPhotos: () => tagged = true,
      onAddPhotos: () => added = true,
    );

    await tester.tap(find.text('Tag photos'));
    await tester.tap(find.text('Add photos'));

    expect(tagged, isTrue);
    expect(added, isTrue);
  });

  testWidgets('tapping a thumbnail opens the species viewer on that photo', (
    tester,
  ) async {
    await _pump(tester, entries);

    await tester.tap(find.byType(MediaThumbnailTile).last);
    await tester.pumpAndSettle();

    final viewer = tester.widget<SpeciesPhotoViewerPage>(
      find.byType(SpeciesPhotoViewerPage),
    );
    expect(viewer.speciesId, 'sp_x');
    expect(viewer.initialMediaId, 'p2');
  });

  testWidgets('a browser can tag the photos it has, not add any (#4121)', (
    tester,
  ) async {
    await _pump(
      tester,
      entries,
      onTagPhotos: () {},
      onAddPhotos: () {},
      browser: true,
    );
    expect(find.byKey(const ValueKey('species_tag_photos')), findsOneWidget);
    expect(find.byKey(const ValueKey('species_add_photos')), findsNothing);
  });

  testWidgets('lays photos out at their own shapes', (tester) async {
    await _pump(tester, [
      _entry('wide', width: 900, height: 600),
      _entry('tall', width: 600, height: 900),
    ]);

    final wide = _tileRect(tester, 'wide');
    final tall = _tileRect(tester, 'tall');
    expect(wide.height, tall.height);
    expect(wide.height, kSpeciesPhotoRowHeight);
    expect(wide.width / tall.width, closeTo(9 / 4, 0.01));
    expect(tall.left - wide.right, closeTo(kSpeciesPhotoGap, 0.01));
  });

  testWidgets('captions each photo with its dive date and site', (
    tester,
  ) async {
    final date = DateTime.utc(2025, 3, 12, 9, 30);
    await _pump(tester, [
      _entry('p1', diveDateTime: date, siteName: 'Blue Hole'),
    ]);

    expect(
      find.text('${_formatDate(tester, date)} · Blue Hole'),
      findsOneWidget,
    );
  });

  testWidgets('a dive with no site captions the date alone', (tester) async {
    final date = DateTime.utc(2025, 3, 12);
    await _pump(tester, [_entry('p1', diveDateTime: date)]);

    expect(find.text(_formatDate(tester, date)), findsOneWidget);
  });

  testWidgets('a photo with no dive has no caption', (tester) async {
    await _pump(tester, [_entry('p1')]);

    expect(
      find.byKey(const ValueKey('species_photo_caption_p1')),
      findsNothing,
    );
  });

  testWidgets(
    'caps at three rows and opens the viewer at the first hidden photo',
    (tester) async {
      // 390 wide holds three squares a row: 9 shown, 11 left out.
      await _pump(tester, _squares(20), width: 390);

      expect(find.byType(MediaThumbnailTile), findsNWidgets(9));
      expect(find.text('+11'), findsOneWidget);

      await tester.tap(find.text('+11'));
      await tester.pumpAndSettle();

      final viewer = tester.widget<SpeciesPhotoViewerPage>(
        find.byType(SpeciesPhotoViewerPage),
      );
      expect(viewer.initialMediaId, 'p9');
    },
  );

  testWidgets('+N is announced as more photos', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _squares(20), width: 390);

    expect(find.bySemanticsLabel(RegExp('11 more photos')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a photo with a caption carries it in its label', (tester) async {
    final semantics = tester.ensureSemantics();
    final date = DateTime.utc(2025, 3, 12);
    await _pump(tester, [
      _entry('p1', diveDateTime: date, siteName: 'Blue Hole'),
    ]);

    expect(
      find.bySemanticsLabel(
        'Species photo, ${_formatDate(tester, date)} · Blue Hole',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('pending photos come first, uncaptioned, never hidden', (
    tester,
  ) async {
    final date = DateTime.utc(2025, 3, 12);
    await _pump(
      tester,
      [
        for (final e in _squares(20))
          MediaLibraryEntry(item: e.item, diveDateTime: date),
      ],
      pendingItems: [for (var i = 0; i < 12; i++) _photo('held$i')],
      pendingOverlay: (item) => SizedBox(key: ValueKey('overlay_${item.id}')),
      width: 390,
    );

    for (var i = 0; i < 12; i++) {
      expect(find.byKey(ValueKey('overlay_held$i')), findsOneWidget);
      expect(
        find.byKey(ValueKey('species_photo_caption_held$i')),
        findsNothing,
      );
    }
    expect(
      _tileRect(tester, 'held0').top,
      lessThan(_tileRect(tester, 'held11').top),
    );
    expect(find.text('+20'), findsOneWidget);
  });

  testWidgets('lays a photo out at its learned shape', (tester) async {
    // Stored 600x600, but its thumbnail decoded at 1:2 (an EXIF rotation).
    await _pump(
      tester,
      [_entry('p1')],
      shapes: FakeAspectCacheRepository({
        'p1': (ratio: 0.5, width: 600, height: 600),
      }),
    );

    expect(_tileRect(tester, 'p1').size, const Size(75, 150));
  });

  testWidgets('hides the caption on a tile narrower than 64 px', (
    tester,
  ) async {
    final date = DateTime.utc(2025, 3, 12);
    await _pump(tester, [
      _entry('narrow', width: 600, height: 1800, diveDateTime: date),
      _entry('wide', width: 900, height: 600, diveDateTime: date),
    ]);

    expect(_tileRect(tester, 'narrow').width, lessThan(64));
    expect(
      find.byKey(const ValueKey('species_photo_caption_narrow')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('species_photo_caption_wide')),
      findsOneWidget,
    );
  });

  testWidgets('a stored photo teaches its shape, a pending one does not', (
    tester,
  ) async {
    // Both are stored 3:2 and decode as the harness's 1x1 PNG, a shape that
    // differs enough to be learned.
    final shapes = FakeAspectCacheRepository();
    await _pump(
      tester,
      [_entry('stored', width: 900, height: 600)],
      pendingItems: [_photo('held', width: 900, height: 600)],
      shapes: shapes,
    );
    // Decoding runs on real time: wait on a clock, not a fixed number of
    // rounds, so a loaded runner does not fail it.
    final clock = Stopwatch()..start();
    while (!shapes.written.contains('stored') &&
        clock.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(shapes.written, contains('stored'));
    expect(shapes.written, isNot(contains('held')));
  });

  testWidgets('a photo both held and stored shows once, as the held one', (
    tester,
  ) async {
    // Save writes the tag before the sitting lets the photo go, so for a
    // moment the stored list already holds it.
    await _pump(
      tester,
      [_entry('both'), _entry('p1')],
      pendingItems: [_photo('both')],
      pendingOverlay: (item) => SizedBox(key: ValueKey('overlay_${item.id}')),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('species_photo_both')), findsOneWidget);
    expect(find.byKey(const ValueKey('overlay_both')), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
  });

  testWidgets('+N is the only control on its tile for a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _squares(20), width: 390);

    // Nine tiles shown; the ninth is the "+N" one, announced only as that.
    expect(find.bySemanticsLabel('Species photo'), findsNWidgets(8));

    tester.semantics.tap(find.semantics.byLabel(RegExp('11 more photos')));
    await tester.pumpAndSettle();

    final viewer = tester.widget<SpeciesPhotoViewerPage>(
      find.byType(SpeciesPhotoViewerPage),
    );
    expect(viewer.initialMediaId, 'p9');
    semantics.dispose();
  });

  testWidgets('+N stays on one line on a narrow tile', (tester) async {
    // 1:3 photos are about 52 px wide at 390: seven a row, 21 shown, and
    // a three-digit count left over.
    await _pump(tester, [
      for (var i = 0; i < 125; i++) _entry('t$i', width: 600, height: 1800),
    ], width: 390);

    final tile = _tileRect(tester, 't20');
    final count = tester.getRect(find.text('+104'));
    expect(tile.width, lessThan(60));
    expect(count.width, lessThanOrEqualTo(tile.width));
    // One line of the count, not the number broken across two.
    expect(count.height, lessThan(30));
  });
}
