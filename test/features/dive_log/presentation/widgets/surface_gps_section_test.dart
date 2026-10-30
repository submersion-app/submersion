import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_locations_map_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/surface_gps_section.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Dive _dive() => Dive(
  id: 'sgps',
  diveNumber: 1,
  dateTime: DateTime(2026, 5, 22, 9, 14),
  maxDepth: 30.0,
  entryLocation: const GeoPoint(12.34567, 98.76543),
  exitLocation: const GeoPoint(12.34612, 98.76489),
  site: const DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    location: GeoPoint(12.34000, 98.76000),
  ),
);

/// A dive whose fixes sit metres apart, so the inline map's camera fit
/// saturates at its maxZoom of 16: three zoom levels past the zoom 13 the map
/// mounts at.
Dive _tightDive() => Dive(
  id: 'tight',
  diveNumber: 3,
  dateTime: DateTime(2026, 5, 6, 18, 54),
  maxDepth: 12.0,
  entryLocation: const GeoPoint(12.046730, -68.268700),
  exitLocation: const GeoPoint(12.046780, -68.268550),
  site: const DiveSite(
    id: 'site-2',
    name: 'Red Beryl',
    location: GeoPoint(12.046640, -68.268529),
  ),
);

/// A dive whose only location is its site's coordinates: no GPS fixes.
Dive _siteOnlyDive() => Dive(
  id: 'site-only',
  diveNumber: 2,
  dateTime: DateTime(2026, 5, 22, 9, 14),
  maxDepth: 30.0,
  site: const DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    location: GeoPoint(12.34000, 98.76000),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  MapController? controller,
  Dive? dive,
  bool expanded = true,
  ScrollController? scrollController,
  Key? sectionKey,
  double width = 600,
}) async {
  final overrides = await getBaseOverrides();
  await tester.binding.setSurfaceSize(Size(width, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        surfaceGpsSectionExpandedProvider.overrideWithValue(expanded),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            // Content taller than the viewport, so the page can scroll the way
            // the dive detail pane does.
            child: Column(
              children: [
                SurfaceGpsSection(
                  key: sectionKey,
                  dive: dive ?? _dive(),
                  controller: controller,
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = originalOnError;
}

void main() {
  group('the inline map does not capture scrolling (#3156)', () {
    testWidgets('a mouse wheel over the map scrolls the page, not the map', (
      tester,
    ) async {
      final controller = MapController();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await _pump(tester, controller: controller, scrollController: scroll);
      final zoom = controller.camera.zoom;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      final center = tester.getCenter(find.byType(FlutterMap));
      await tester.sendEventToBinding(pointer.hover(center));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pump();

      expect(controller.camera.zoom, zoom);
      expect(scroll.offset, greaterThan(0));
    });

    testWidgets('a trackpad two-finger scroll over the map scrolls the page', (
      tester,
    ) async {
      final controller = MapController();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await _pump(tester, controller: controller, scrollController: scroll);
      final zoom = controller.camera.zoom;
      final mapCenter = controller.camera.center;

      final center = tester.getCenter(find.byType(FlutterMap));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomStart(center);
      await tester.pump();
      // Fingers moving up scroll the content forward, as on a touch screen.
      await gesture.panZoomUpdate(center, pan: const Offset(0, -100));
      await tester.pump();
      await gesture.panZoomEnd();
      await tester.pump();

      expect(controller.camera.zoom, zoom);
      expect(controller.camera.center, mapCenter);
      expect(scroll.offset, greaterThan(0));
    });

    testWidgets('a touch drag starting on the map scrolls the page', (
      tester,
    ) async {
      final controller = MapController();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await _pump(tester, controller: controller, scrollController: scroll);
      final mapCenter = controller.camera.center;

      await tester.drag(find.byType(FlutterMap), const Offset(0, -150));
      await tester.pump();

      expect(controller.camera.center, mapCenter);
      expect(scroll.offset, greaterThan(0));
    });
  });

  testWidgets('renders a map and entry/exit/site coordinate rows', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(FlutterMap), findsOneWidget);
    // Rendered in the diver's coordinate notation, decimal degrees here.
    expect(
      find.bySemanticsLabel('12.345670° N, 98.765430° E'),
      findsOneWidget,
    ); // entry
    expect(
      find.bySemanticsLabel('12.346120° N, 98.764890° E'),
      findsOneWidget,
    ); // exit
    expect(
      find.bySemanticsLabel('12.340000° N, 98.760000° E'),
      findsOneWidget,
    ); // site
    expect(find.text('Open in Maps'), findsNothing);
  });

  group('coordinate rows stay readable at any width (#3745)', () {
    /// The rendered paragraph of the [coordinate] link.
    RenderParagraph paragraphOf(WidgetTester tester, Finder coordinate) =>
        tester.renderObject<RenderParagraph>(
          find.descendant(of: coordinate, matching: find.byType(RichText)),
        );

    /// The character offsets at which [coordinate]'s rendered text starts a
    /// new line.
    List<int> lineStarts(WidgetTester tester, Finder coordinate) {
      final paragraph = paragraphOf(tester, coordinate);
      final text = paragraph.text.toPlainText();
      double top(int offset) => paragraph
          .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
          .dy;
      return [
        for (var i = 1; i < text.length; i++)
          if (top(i) > top(i - 1)) i,
      ];
    }

    /// Whether [label] renders on a single line.
    bool isOneLine(WidgetTester tester, Finder label) {
      final paragraph = tester.renderObject<RenderParagraph>(label);
      return paragraph.getMaxIntrinsicWidth(double.infinity) <=
          paragraph.size.width;
    }

    testWidgets('a wide row keeps label and coordinate on one line', (
      tester,
    ) async {
      await _pump(tester);

      final label = find.text('Entry');
      final coordinate = find.byKey(const ValueKey('gps-coord-entry'));
      expect(isOneLine(tester, label), isTrue);
      expect(lineStarts(tester, coordinate), isEmpty);
      expect(
        tester.getCenter(label).dy,
        moreOrLessEquals(tester.getCenter(coordinate).dy, epsilon: 1),
      );
    });

    testWidgets('a narrow row stacks the label above the coordinate', (
      tester,
    ) async {
      await _pump(tester, width: 320);

      final label = find.text('Entry');
      final coordinate = find.byKey(const ValueKey('gps-coord-entry'));
      expect(isOneLine(tester, label), isTrue);
      expect(
        tester.getRect(coordinate).top,
        greaterThanOrEqualTo(tester.getRect(label).bottom),
      );
    });

    testWidgets('a coordinate breaks only between latitude and longitude', (
      tester,
    ) async {
      await _pump(tester, width: 320);

      final coordinate = find.byKey(const ValueKey('gps-coord-entry'));
      final text = paragraphOf(tester, coordinate).text.toPlainText();
      final starts = lineStarts(tester, coordinate);
      expect(starts, isNotEmpty, reason: 'the width should force a break');
      for (final start in starts) {
        expect(
          text.substring(0, start),
          endsWith(', '),
          reason: 'line broke inside an axis at offset $start of "$text"',
        );
      }
    });

    testWidgets('screen readers hear the coordinate with plain spaces', (
      tester,
    ) async {
      await _pump(tester, width: 320);

      expect(
        find.bySemanticsLabel('12.345670° N, 98.765430° E'),
        findsOneWidget,
      );
    });
  });

  testWidgets('copy icon copies the coordinate at full (6-dp) precision', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('gps-copy-entry')));
    await tester.pump();

    final setData = calls.firstWhere((c) => c.method == 'Clipboard.setData');
    final text = (setData.arguments as Map)['text'] as String;
    expect(text, '12.345670, 98.765430');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('tapping a coordinate recenters the map on that point', (
    tester,
  ) async {
    final controller = MapController();
    await _pump(tester, controller: controller);

    await tester.tap(find.byKey(const ValueKey('gps-coord-exit')));
    await tester.pump();

    expect(controller.camera.center.latitude, closeTo(12.34612, 1e-4));
    expect(controller.camera.center.longitude, closeTo(98.76489, 1e-4));
  });

  testWidgets('expand button opens the fullscreen locations page', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('gps-expand')));
    await tester.pumpAndSettle();

    expect(find.byType(DiveLocationsMapPage), findsOneWidget);
  });

  testWidgets('a GPS dive keeps the Surface GPS title', (tester) async {
    await _pump(tester);

    expect(find.text('Surface GPS'), findsOneWidget);
    expect(find.text('Location'), findsNothing);
  });

  group('site-only dive', () {
    testWidgets('is titled Location and maps the site alone', (tester) async {
      await _pump(tester, dive: _siteOnlyDive());

      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Surface GPS'), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const ValueKey('gps-coord-site')), findsOneWidget);
      expect(
        find.bySemanticsLabel('12.340000° N, 98.760000° E'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('gps-coord-entry')), findsNothing);
      expect(find.byKey(const ValueKey('gps-coord-exit')), findsNothing);
      expect(find.textContaining('Drift'), findsNothing);
      expect(find.byKey(const ValueKey('gps-expand')), findsOneWidget);
    });

    testWidgets('shows the site name as the collapsed subtitle', (
      tester,
    ) async {
      await _pump(tester, dive: _siteOnlyDive(), expanded: false);

      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Blue Hole'), findsOneWidget);
      expect(find.text('Entry point recorded'), findsNothing);
      expect(find.text('Exit point recorded'), findsNothing);
    });

    testWidgets('the expand button opens the fullscreen map of the site', (
      tester,
    ) async {
      await _pump(tester, dive: _siteOnlyDive());

      await tester.tap(find.byKey(const ValueKey('gps-expand')));
      await tester.pumpAndSettle();

      final page = tester.widget<DiveLocationsMapPage>(
        find.byType(DiveLocationsMapPage),
      );
      expect(page.site, const GeoPoint(12.34000, 98.76000));
      expect(page.entry, isNull);
      expect(page.exit, isNull);
    });
  });

  // Selecting a dive mounts this card more than once (the Tide card arriving
  // turns the layout into a pair), and a dive seen before is the same. Either
  // way the second map finds its tiles already in the image cache, so they
  // load synchronously. With instantaneous tile display flutter_map then
  // prunes against the camera of its previous build, still at the pre-fit
  // zoom 13, discards the zoom-16 tiles and never requests them again: the map
  // stayed blank until a coordinate tap moved the camera (issue #3285).
  testWidgets('tiles already in the image cache show after the camera fit', (
    tester,
  ) async {
    final imageCache = PaintingBinding.instance.imageCache;
    addTearDown(() {
      imageCache
        ..clear()
        ..clearLiveImages();
    });

    // Made before any map mounts: real async work during runAsync would let
    // flutter_map's tile cache reach the (absent) path_provider plugin.
    final image = await tester.runAsync(
      () => createTestImage(width: 256, height: 256),
    );
    // The cache holds clones; this handle is the test's own.
    addTearDown(() => image?.dispose());

    final controller = MapController();
    await _pump(tester, dive: _tightDive(), controller: controller);
    expect(controller.camera.zoom, 16.0);

    // Seed the tiles an earlier mount of the card would have left in the
    // cache: those the fitted zoom-16 camera shows and those of the zoom-13
    // camera the map mounts at, each with a margin for the pan buffer. The
    // zoom-13 tiles matter: flutter_map prunes only once every tile it holds
    // has loaded. The first map goes first, because disposing it evicts its
    // failed tiles' keys, which are these same URLs.
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    final pixels = controller.camera.pixelBounds;
    await tester.pumpWidget(const SizedBox.shrink());
    imageCache.clear();
    void seed(int zoom, int minX, int maxX, int minY, int maxY) {
      for (var x = minX - 2; x <= maxX + 2; x++) {
        for (var y = minY - 2; y <= maxY + 2; y++) {
          final coordinates = TileCoordinates(x, y, zoom);
          // Image keys compare by tile URL, so this provider's key is the one
          // the remounted layer will look up.
          final provider = layer.tileProvider.supportsCancelLoading
              ? layer.tileProvider.getImageWithCancelLoadingSupport(
                  coordinates,
                  layer,
                  Completer<void>().future,
                )
              : layer.tileProvider.getImage(coordinates, layer);
          imageCache.putIfAbsent(
            provider,
            () => OneFrameImageStreamCompleter(
              SynchronousFuture(ImageInfo(image: image!.clone())),
            ),
          );
        }
      }
    }

    final (minX, maxX) = (pixels.left ~/ 256, pixels.right ~/ 256);
    final (minY, maxY) = (pixels.top ~/ 256, pixels.bottom ~/ 256);
    seed(16, minX, maxX, minY, maxY);
    // Three zoom levels up, a tile index is an eighth.
    seed(13, minX >> 3, maxX >> 3, minY >> 3, maxY >> 3);

    await _pump(
      tester,
      dive: _tightDive(),
      sectionKey: const ValueKey('remounted'),
    );

    final tiles = tester.widgetList<RawImage>(
      find.descendant(
        of: find.byType(TileLayer),
        matching: find.byType(RawImage),
      ),
    );
    expect(tiles, isNotEmpty);
    expect(tiles.where((t) => t.image == null), isEmpty);
  });
}
