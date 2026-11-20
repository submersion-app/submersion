import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_preview.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';

import '../support/media_widget_harness.dart';

class _ShapesRepository implements MediaAspectCacheRepository {
  _ShapesRepository([this.shapes = const {}]);

  final Map<String, LearnedAspect> shapes;

  @override
  Future<Map<String, LearnedAspect>> loadAll() async => shapes;

  @override
  Future<void> putAll(Map<String, LearnedAspect> entries) async {}
}

/// The fixed-row justified preview on detail cards (issue #4741).
void main() {
  /// Square items: at 400 wide and 100 high, four to a row.
  List<MediaItem> squares(int n) => [
    for (var i = 0; i < n; i++)
      testMediaItem(id: 'p$i').copyWith(width: 100, height: 100),
  ];

  late List<String> tapped;
  late int moreTaps;

  setUp(() {
    tapped = [];
    moreTaps = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    List<MediaItem> items, {
    int? maxRows = 2,
    int? totalCount,
    bool withShowMore = true,
    Map<String, LearnedAspect> shapes = const {},
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          mediaAspectCacheRepositoryProvider.overrideWithValue(
            _ShapesRepository(shapes),
          ),
        ],
        home: Scaffold(
          body: Directionality(
            textDirection: direction,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: JustifiedMediaPreview(
                  items: items,
                  rowHeight: 100,
                  maxRows: maxRows,
                  totalCount: totalCount,
                  onShowMore: withShowMore ? () => moreTaps++ : null,
                  tileBuilder: (context, item, size, onImageSize) =>
                      GestureDetector(
                        onTap: () => tapped.add(item.id),
                        child: ColoredBox(
                          key: ValueKey('tile-${item.id}'),
                          color: Colors.teal,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> shownIds(WidgetTester tester) => [
    for (final e in tester.widgetList<ColoredBox>(
      find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('tile-'),
      ),
    ))
      (e.key! as ValueKey<String>).value.substring(5),
  ];

  testWidgets('shows at most two rows of tiles', (tester) async {
    await pump(tester, squares(20));
    expect(shownIds(tester), [for (var i = 0; i < 8; i++) 'p$i']);
  });

  testWidgets('the last tile shown carries +N for the items left out', (
    tester,
  ) async {
    await pump(tester, squares(20));
    expect(find.text('+12'), findsOneWidget);
    final more = tester.getRect(find.byKey(kJustifiedPreviewMoreKey));
    final last = tester.getRect(find.byKey(const ValueKey('tile-p7')));
    expect(more, last);
  });

  testWidgets('+N counts items beyond a capped read', (tester) async {
    await pump(tester, squares(3), totalCount: 40);
    expect(find.text('+37'), findsOneWidget);
  });

  testWidgets('tapping +N calls onShowMore, not the tile', (tester) async {
    await pump(tester, squares(20));
    await tester.tap(find.byKey(kJustifiedPreviewMoreKey));
    expect(moreTaps, 1);
    expect(tapped, isEmpty);
  });

  testWidgets('tapping any other tile opens that tile', (tester) async {
    await pump(tester, squares(20));
    await tester.tap(find.byKey(const ValueKey('tile-p2')));
    expect(tapped, ['p2']);
    expect(moreTaps, 0);
  });

  testWidgets('everything that fits shows without +N', (tester) async {
    await pump(tester, squares(5));
    expect(shownIds(tester), hasLength(5));
    expect(find.byKey(kJustifiedPreviewMoreKey), findsNothing);
  });

  testWidgets('a count with nothing read draws nothing, and no +N', (
    tester,
  ) async {
    // The count and the capped read can disagree for a moment, as when a
    // photo is unlinked between the two reads.
    await pump(tester, const [], totalCount: 3);
    expect(tester.takeException(), isNull);
    expect(find.byKey(kJustifiedPreviewMoreKey), findsNothing);
  });

  testWidgets('without onShowMore nothing is darkened', (tester) async {
    await pump(tester, squares(20), withShowMore: false);
    expect(shownIds(tester), hasLength(8));
    expect(find.byKey(kJustifiedPreviewMoreKey), findsNothing);
  });

  testWidgets('no row limit lays out every item', (tester) async {
    await pump(tester, squares(20), maxRows: null);
    expect(shownIds(tester), hasLength(20));
    expect(find.byKey(kJustifiedPreviewMoreKey), findsNothing);
  });

  testWidgets('tiles keep their shape, rows sharing a height', (tester) async {
    final items = [
      testMediaItem(id: 'wide').copyWith(width: 300, height: 100),
      testMediaItem(id: 'tall').copyWith(width: 100, height: 200),
    ];
    await pump(tester, items);
    final wide = tester.getSize(find.byKey(const ValueKey('tile-wide')));
    final tall = tester.getSize(find.byKey(const ValueKey('tile-tall')));
    expect(wide.height, tall.height);
    expect(wide.width / wide.height, closeTo(3, 0.01));
    expect(tall.width / tall.height, closeTo(0.5, 0.01));
  });

  testWidgets('a learned shape wins over the stored size', (tester) async {
    final item = testMediaItem(id: 'rot').copyWith(width: 400, height: 300);
    await pump(
      tester,
      [item],
      shapes: {'rot': (ratio: 0.75, width: 400, height: 300)},
    );
    final size = tester.getSize(find.byKey(const ValueKey('tile-rot')));
    expect(size.width / size.height, closeTo(0.75, 0.01));
  });

  testWidgets('right to left, the first tile starts at the right', (
    tester,
  ) async {
    await pump(tester, squares(2), direction: TextDirection.rtl);
    final first = tester.getRect(find.byKey(const ValueKey('tile-p0')));
    final second = tester.getRect(find.byKey(const ValueKey('tile-p1')));
    expect(first.right, closeTo(400, 0.01));
    expect(second.right, lessThan(first.left));
  });

  testWidgets('the preview does not zoom', (tester) async {
    await pump(tester, squares(20));
    expect(find.byType(MediaThumbnailWheelZoom), findsNothing);
  });
}
