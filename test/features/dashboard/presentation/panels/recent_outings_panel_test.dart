import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/domain/home_outings.dart';
import 'package:submersion/features/dashboard/presentation/panels/recent_outings_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_outings_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/outing_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/outing_sites_map.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'panel_harness.dart';

/// A gallery photo whose bytes have not arrived on this device yet.
class _StillFetching implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.stillFetching);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// Missing until [found] is set, then a tiny PNG.
class _Toggle implements MediaSourceResolver {
  bool found = false;
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async => found
      ? BytesData(bytes: _png)
      : const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// A small valid PNG.
final _png = img.encodePng(img.Image(width: 4, height: 4));

Outing _outing(
  String id, {
  String? tripId,
  String? name,
  int month = 5,
  int dives = 3,
  double? maxDepth = 29.7,
  int species = 25,
}) => Outing(
  tripId: tripId,
  name: name ?? 'Outing $id',
  firstDay: DateTime(2026, month, 3),
  lastDay: DateTime(2026, month, 7),
  diveIds: [for (var i = 0; i < dives; i++) '$id-$i'],
  maxDepth: maxDepth,
  speciesCount: species,
  depths: [for (var i = 0; i < dives; i++) 10.0 + i * 5],
);

List<HomeOuting> _many(int n) => [
  for (var i = 0; i < n; i++)
    HomeOuting(
      outing: _outing('o$i', tripId: 't$i', month: 12 - i),
    ),
];

Future<PanelNav> _pump(
  WidgetTester tester, {
  required Future<List<HomeOuting>> Function() outings,
  double width = 390,
  double height = 300,
  AppSettings settings = const AppSettings(),
  double textScale = 1,
  List<Object> extra = const [],
}) => pumpPanel(
  tester,
  const RecentOutingsPanel(),
  width: width,
  height: height,
  settings: settings,
  textScale: textScale,
  overrides: [
    homeRecentOutingsProvider.overrideWith((ref) => outings()),
    ...extra,
  ],
);

void main() {
  testWidgets('a phone shows one card at a time with page dots', (
    tester,
  ) async {
    await _pump(tester, outings: () async => _many(3));
    expect(find.text('Outing o0'), findsOneWidget);
    expect(find.byKey(const Key('outing-page-dots')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('outing-page-dots')),
        matching: find.byType(DecoratedBox),
      ),
      findsNWidgets(3),
    );
    final first = tester.getRect(find.byType(OutingCard).first);
    expect(first.width, greaterThan(390 * 0.7));
  });

  testWidgets('a desktop panel shows cards side by side', (tester) async {
    await _pump(tester, width: 840, outings: () async => _many(5));
    final rects = [
      for (final e in find.byType(OutingCard).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    final onScreen = rects.where((r) => r.right <= 840).toList();
    expect(onScreen.length, greaterThanOrEqualTo(4));
    expect(onScreen.map((r) => r.top).toSet(), hasLength(1));
    expect(find.byKey(const Key('outing-page-dots')), findsNothing);
  });

  testWidgets('a card shows name, dates, dives, depth in feet and species', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
      outings: () async => [
        HomeOuting(
          outing: _outing(
            'b',
            tripId: 't1',
            name: 'Bonaire May 2026',
            dives: 15,
          ),
        ),
      ],
    );
    expect(find.text('Bonaire May 2026'), findsOneWidget);
    expect(find.textContaining('May 3'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OutingCard),
        matching: find.textContaining('15 dives'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('97ft max'), findsOneWidget);
    expect(find.textContaining('25 species'), findsOneWidget);
  });

  testWidgets('species are left out at zero', (tester) async {
    await _pump(
      tester,
      outings: () async => [HomeOuting(outing: _outing('p', species: 0))],
    );
    expect(find.textContaining('species'), findsNothing);
  });

  testWidgets('an outing with no name shows the fallback', (tester) async {
    await _pump(
      tester,
      outings: () async => [
        HomeOuting(
          outing: Outing(
            tripId: null,
            name: null,
            firstDay: DateTime(2026, 4, 1),
            lastDay: DateTime(2026, 4, 1),
            diveIds: const ['n'],
            maxDepth: null,
            speciesCount: 0,
            depths: const [0],
          ),
        ),
      ],
    );
    expect(find.text('Dives'), findsOneWidget);
  });

  testWidgets('a coverless card draws the skyline', (tester) async {
    await _pump(tester, outings: () async => _many(1));
    expect(find.byType(OutingSkyline), findsOneWidget);
  });

  testWidgets('a cover that cannot load falls back to the skyline', (
    tester,
  ) async {
    final missing = MediaItem(
      id: 'm',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: '/does/not/exist.jpg',
      filePath: '/does/not/exist.jpg',
      takenAt: DateTime(2026, 5, 3),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await _pump(
      tester,
      outings: () async => [HomeOuting(outing: _outing('o'), cover: missing)],
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(OutingSkyline), findsOneWidget);
  });

  testWidgets('a trip card opens the trip', (tester) async {
    final nav = await _pump(tester, outings: () async => _many(1));
    await tester.tap(find.byType(OutingCard));
    await tester.pumpAndSettle();
    expect(nav.location, '/trips/t0');
  });

  testWidgets('a trip-less card opens exactly its dives', (tester) async {
    final nav = await _pump(
      tester,
      outings: () async => [HomeOuting(outing: _outing('pool', dives: 2))],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecentOutingsPanel)),
    );
    await tester.tap(find.byType(OutingCard));
    await tester.pumpAndSettle();
    expect(nav.location, '/dives');
    expect(container.read(diveFilterProvider).diveIds, ['pool-0', 'pool-1']);
  });

  testWidgets('an empty log shows the empty line', (tester) async {
    await _pump(tester, outings: () async => const []);
    expect(
      find.text('Your outings will show here once you log a dive'),
      findsOneWidget,
    );
  });

  testWidgets('a failed read shows the shared error state', (tester) async {
    await _pump(tester, outings: () async => throw StateError('boom'));
    expect(find.byType(OutingCard), findsNothing);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('the summary counts outings and dives', (tester) async {
    await _pump(tester, outings: () async => _many(2));
    expect(find.text('2 outings · 6 dives'), findsOneWidget);
  });

  testWidgets('a long name at text scale 1.6 does not overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      textScale: 1.6,
      height: 420,
      outings: () async => [
        HomeOuting(
          outing: _outing(
            'l',
            tripId: 't',
            name: 'A very long trip name that goes on and on past the card',
          ),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card reads its name, dates, dives, depth and species', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
      outings: () async => [
        HomeOuting(
          outing: _outing('b', tripId: 't1', name: 'Bonaire'),
        ),
      ],
    );
    final label = tester
        .getSemantics(find.byType(OutingCard))
        .getSemanticsData()
        .label;
    expect(label, contains('Bonaire'));
    expect(label, contains('May 3'));
    expect(label, contains('3 dives'));
    expect(label, contains('97ft'));
    expect(label, contains('25 species'));
    handle.dispose();
  });

  testWidgets('a screen reader can open a card', (tester) async {
    final handle = tester.ensureSemantics();
    final nav = await _pump(tester, outings: () async => _many(1));
    final data = tester
        .getSemantics(find.byType(OutingCard))
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel(RegExp('^Outing o0')));
    await tester.pumpAndSettle();
    expect(nav.location, '/trips/t0');
    handle.dispose();
  });

  testWidgets('a mouse can drag the desktop row to the later cards', (
    tester,
  ) async {
    await _pump(tester, width: 840, outings: () async => _many(8));
    ScrollPosition row() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(RecentOutingsPanel),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(row().pixels, 0);
    await tester.dragFrom(
      tester.getCenter(find.byType(OutingCard).first),
      const Offset(-300, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(row().pixels, greaterThan(0));
  });

  testWidgets('a cover still downloading shows the skyline and taps open '
      'the trip', (tester) async {
    final fetching = MediaItem(
      id: 'f',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime(2026, 5, 3),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final nav = await _pump(
      tester,
      outings: () async => [
        HomeOuting(
          outing: _outing('o', tripId: 't9'),
          cover: fetching,
        ),
      ],
      extra: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({
            MediaSourceType.platformGallery: _StillFetching(),
          }),
        ),
      ],
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(OutingSkyline), findsOneWidget);
    // The middle of the cover, not the text strip.
    final card = tester.getRect(find.byType(OutingCard));
    await tester.tapAt(Offset(card.center.dx, card.top + 40));
    await tester.pumpAndSettle();
    expect(nav.location, '/trips/t9');
  });

  testWidgets('one outing on a phone fills the panel width', (tester) async {
    await _pump(tester, outings: () async => _many(1));
    final card = tester.getRect(find.byType(OutingCard));
    final panel = tester.getRect(find.byType(RecentOutingsPanel));
    // The panel's side padding is 10.
    expect(card.width, closeTo(panel.width - 20, 1));
  });

  testWidgets('in a right-to-left language the first card starts at the '
      'right edge', (tester) async {
    await pumpPanel(
      tester,
      const RecentOutingsPanel(),
      width: 390,
      height: 300,
      locale: const Locale('he'),
      overrides: [
        homeRecentOutingsProvider.overrideWith((ref) async => _many(3)),
      ],
    );
    final card = tester.getRect(find.byType(OutingCard).first);
    final panel = tester.getRect(find.byType(RecentOutingsPanel));
    expect(card.right, closeTo(panel.right - 10, 1));
  });

  testWidgets('a cover that failed retries when the outings rebuild', (
    tester,
  ) async {
    final resolver = _Toggle();
    final item = MediaItem(
      id: 'c',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime(2026, 5, 3),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await _pump(
      tester,
      outings: () async => [
        HomeOuting(
          outing: _outing('o', tripId: 't'),
          cover: item,
        ),
      ],
      extra: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({
            MediaSourceType.platformGallery: resolver,
          }),
        ),
      ],
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(MediaItemView), findsNothing);

    resolver.found = true;
    ProviderScope.containerOf(
      tester.element(find.byType(RecentOutingsPanel)),
    ).invalidate(homeRecentOutingsProvider);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(MediaItemView), findsOneWidget);
  });

  testWidgets('on desktop the next card peeks in when more do not fit', (
    tester,
  ) async {
    await _pump(tester, width: 840, outings: () async => _many(6));
    final panel = tester.getRect(find.byType(RecentOutingsPanel));
    final edge = panel.right - 10;
    final rects = [
      for (final e in find.byType(OutingCard).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    // One card is cut by the edge: part of it shows, so more are there.
    expect(
      rects.where((r) => r.left < edge - 16 && r.right > edge),
      hasLength(1),
    );
  });

  testWidgets('on desktop cards that all fit are not shrunk', (tester) async {
    await _pump(tester, width: 840, outings: () async => _many(2));
    final rects = [
      for (final e in find.byType(OutingCard).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    final panel = tester.getRect(find.byType(RecentOutingsPanel));
    // The width four cards share: nothing peeks, nothing is cut.
    expect(rects.first.width, closeTo((panel.width - 20 - 3 * 8) / 4, 1));
  });

  testWidgets('a cover that loads is shown over the skyline', (tester) async {
    final resolver = _Toggle()..found = true;
    final item = MediaItem(
      id: 'ok',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime(2026, 5, 3),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await _pump(
      tester,
      outings: () async => [
        HomeOuting(
          outing: _outing('o', tripId: 't'),
          cover: item,
        ),
      ],
      extra: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({
            MediaSourceType.platformGallery: resolver,
          }),
        ),
      ],
    );
    Opacity cover() => tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byType(MediaItemView),
            matching: find.byType(Opacity),
          )
          .first,
    );
    await tester.pump(const Duration(milliseconds: 50));
    // Decoding runs outside the fake clock.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(cover().opacity, 1);
    // Once the photo shows, nothing is built behind it.
    expect(find.byType(OutingSkyline), findsNothing);
    expect(find.byType(OutingSitesMap), findsNothing);
  });

  group('a cover without a photo', () {
    Outing sited(String id) => _outing(
      id,
      tripId: 't',
    ).copyWith(sites: const [(latitude: 18.4654, longitude: -66.0859)]);

    testWidgets('is a map of the outing\'s sites when they have a position', (
      tester,
    ) async {
      await _pump(
        tester,
        outings: () async => [HomeOuting(outing: sited('pr'))],
      );
      expect(find.byType(OutingSitesMap), findsOneWidget);
      expect(find.byType(OutingSkyline), findsNothing);
    });

    testWidgets('is the skyline when no site has a position', (tester) async {
      await _pump(tester, outings: () async => _many(1));
      expect(find.byType(OutingSitesMap), findsNothing);
      expect(find.byType(OutingSkyline), findsOneWidget);
    });

    testWidgets('a photo that cannot load falls back to the map', (
      tester,
    ) async {
      final missing = MediaItem(
        id: 'gone',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        takenAt: DateTime(2026, 5, 3),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await _pump(
        tester,
        outings: () async => [HomeOuting(outing: sited('pr'), cover: missing)],
        extra: [
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery: _Toggle(),
            }),
          ),
        ],
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(MediaItemView), findsNothing);
      expect(find.byType(OutingSitesMap), findsOneWidget);
    });
  });

  testWidgets('a new outing at the front gets its own map, not the old one', (
    tester,
  ) async {
    final pr = _outing(
      'pr',
      tripId: 'pr',
    ).copyWith(sites: const [(latitude: 18.4654, longitude: -66.0859)]);
    final pool = _outing(
      'pool',
      tripId: 'pool',
    ).copyWith(sites: const [(latitude: 40.1371, longitude: -74.0749)]);
    var list = [HomeOuting(outing: pr)];
    await _pump(tester, width: 840, outings: () async => list);
    double firstLatitude() => MapCamera.of(
      tester.element(find.byType(MarkerLayer).first),
    ).center.latitude;
    expect(firstLatitude(), closeTo(18.4654, 0.01));

    list = [HomeOuting(outing: pool), HomeOuting(outing: pr)];
    ProviderScope.containerOf(
      tester.element(find.byType(RecentOutingsPanel)),
    ).invalidate(homeRecentOutingsProvider);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Outing pool'), findsOneWidget);
    expect(firstLatitude(), closeTo(40.1371, 0.01));
  });
}
