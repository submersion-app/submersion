import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_map_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Mounts a map and drives a [MapCameraAnimator] against its controller.
class _AnimatorHarness extends StatefulWidget {
  const _AnimatorHarness();

  @override
  State<_AnimatorHarness> createState() => _AnimatorHarnessState();
}

class _AnimatorHarnessState extends State<_AnimatorHarness>
    with TickerProviderStateMixin {
  final MapController _controller = MapController();
  MapCameraAnimator? _animator;

  @override
  void dispose() {
    _animator?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            _animator = MapCameraAnimator(vsync: this, controller: _controller);
            _animator!.animateTo(center: const LatLng(10, 20), zoom: 6);
          },
          child: const Text('animate'),
        ),
        Expanded(
          child: FlutterMap(
            mapController: _controller,
            options: const MapOptions(
              initialCenter: LatLng(0, 0),
              initialZoom: 3,
            ),
            children: const [],
          ),
        ),
      ],
    );
  }
}

Trip _trip() => Trip(
  id: 'trip-1',
  name: 'Bonaire',
  startDate: DateTime(2026, 3, 7),
  endDate: DateTime(2026, 3, 10),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Pumps the map inside a scrolling page and returns its controller.
Future<MapController> pumpHeader(
  WidgetTester tester,
  TripStoryMapGeometry geometry,
) async {
  final overrides = await getBaseOverrides();
  final controller = MapController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: TripStoryMap(
                    geometry: geometry,
                    activeDayIndex: 0,
                    mapController: controller,
                    onDaySelected: (_) {},
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return controller;
}

const _twoPoints = TripStoryMapGeometry(
  points: [
    TripStoryMapPoint(
      latitude: 12.1,
      longitude: -68.2,
      dayIndex: 0,
      label: 'A',
    ),
    TripStoryMapPoint(
      latitude: 12.2,
      longitude: -68.3,
      dayIndex: 1,
      label: 'B',
    ),
  ],
);

/// A spot on the map well clear of the day pins and the attribution.
Offset _openMapSpot(WidgetTester tester) =>
    tester.getTopLeft(find.byType(FlutterMap)) + const Offset(40, 40);

Future<void> pumpStrip(
  WidgetTester tester,
  TripWithStats stats, {
  int siteCount = 0,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TripStatStrip(stats: stats, siteCount: siteCount),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders a FlutterMap when geometry has points', (tester) async {
    const geometry = TripStoryMapGeometry(
      points: [
        TripStoryMapPoint(
          latitude: 12.1,
          longitude: -68.2,
          dayIndex: 0,
          label: 'A',
        ),
        TripStoryMapPoint(
          latitude: 12.2,
          longitude: -68.3,
          dayIndex: 1,
          label: 'B',
        ),
      ],
    );
    await pumpHeader(tester, geometry);

    expect(find.byType(FlutterMap), findsWidgets);
  });

  testWidgets('draws a route polyline only with 2+ points', (tester) async {
    const onef = TripStoryMapGeometry(
      points: [
        TripStoryMapPoint(
          latitude: 12.1,
          longitude: -68.2,
          dayIndex: 0,
          label: 'A',
        ),
      ],
    );
    await pumpHeader(tester, onef);
    // Single point: map renders, but no route polyline.
    expect(find.byType(FlutterMap), findsWidgets);
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets('renders fallback (no map) when geometry is empty', (
    tester,
  ) async {
    const geometry = TripStoryMapGeometry(points: []);
    await pumpHeader(tester, geometry);

    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('dragging the map pans it instead of scrolling the page '
      '(issue #2777)', (tester) async {
    final controller = await pumpHeader(tester, _twoPoints);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final before = controller.camera.center;

    // Vertical: the drag an enclosing scroll view would otherwise claim.
    await tester.dragFrom(_openMapSpot(tester), const Offset(0, 120));
    await tester.pumpAndSettle();
    final afterVertical = controller.camera.center;
    expect(afterVertical.latitude, isNot(closeTo(before.latitude, 1e-9)));
    expect(scroll.position.pixels, 0);

    await tester.dragFrom(_openMapSpot(tester), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(
      controller.camera.center.longitude,
      isNot(closeTo(afterVertical.longitude, 1e-9)),
    );
    expect(scroll.position.pixels, 0);
  });

  testWidgets('a double-tap zooms the map in', (tester) async {
    final controller = await pumpHeader(tester, _twoPoints);
    final before = controller.camera.zoom;

    await tester.tapAt(_openMapSpot(tester));
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(_openMapSpot(tester));
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, greaterThan(before));
  });

  testWidgets('zooming in stops at the map style\'s deepest tiles', (
    tester,
  ) async {
    final controller = await pumpHeader(tester, _twoPoints);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FlutterMap)),
    );
    final tileMaxZoom = container.read(mapTileMaxZoomProvider);

    // Each double-tap zooms one level; enough of them would run far past the
    // last zoom the tile server draws and blank the map.
    for (var i = 0; i < 14; i++) {
      await tester.tapAt(_openMapSpot(tester));
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(_openMapSpot(tester));
      await tester.pumpAndSettle();
      await tester.pump(kDoubleTapTimeout);
    }

    expect(controller.camera.zoom, lessThanOrEqualTo(tileMaxZoom));
  });

  testWidgets('dragging stops at the poles', (tester) async {
    final controller = await pumpHeader(tester, _twoPoints);
    controller.move(controller.camera.center, 2);
    await tester.pump();

    // Far more than the distance to the north pole at zoom 2.
    await tester.dragFrom(_openMapSpot(tester), const Offset(0, 2000));
    await tester.pumpAndSettle();

    // In world pixels, the top of the world is y = 0; past it is empty grey.
    expect(controller.camera.pixelBounds.top, greaterThanOrEqualTo(-0.5));
  });

  testWidgets('the map never rotates', (tester) async {
    await pumpHeader(tester, _twoPoints);

    // A north-up overview: rotation is the one gesture the embedded detail
    // maps leave out.
    final flags = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .options
        .interactionOptions
        .flags;
    expect(flags & InteractiveFlag.rotate, 0);
    expect(flags & InteractiveFlag.drag, isNot(0));
  });

  testWidgets('stat strip shows the dive count', (tester) async {
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    await pumpStrip(tester, stats);

    expect(find.text('14'), findsOneWidget);
  });

  testWidgets('stat strip totals runtime, not bottom time (issue #889)', (
    tester,
  ) async {
    final stats = TripWithStats(
      trip: _trip(),
      diveCount: 14,
      totalRuntime: 12 * 3600 + 40 * 60,
    );
    await pumpStrip(tester, stats);

    expect(find.text('Total Runtime'), findsOneWidget);
    expect(find.text('12h 40m'), findsOneWidget);
  });

  testWidgets('stat strip shows sites visited when siteCount > 0', (
    tester,
  ) async {
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    await pumpStrip(tester, stats, siteCount: 5);

    expect(find.text('Sites visited'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('stat strip hides sites visited when siteCount is 0', (
    tester,
  ) async {
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    await pumpStrip(tester, stats);

    expect(find.text('Sites visited'), findsNothing);
  });

  testWidgets('stat strip renders as a tinted band', (tester) async {
    // The tint visually welds the strip to the map above it, bounding the
    // trip-summary region instead of floating the numbers on the page surface.
    final stats = TripWithStats(trip: _trip(), diveCount: 14);
    await pumpStrip(tester, stats);

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(TripStatStrip),
            matching: find.byType(Container),
          )
          .first,
    );
    final context = tester.element(find.byType(TripStatStrip));
    expect(container.color, Theme.of(context).colorScheme.surfaceContainerLow);
  });

  testWidgets('map markers expose a 48x48 button with a semantics label', (
    tester,
  ) async {
    const geometry = TripStoryMapGeometry(
      points: [
        TripStoryMapPoint(
          latitude: 12.1,
          longitude: -68.2,
          dayIndex: 0,
          label: 'Klein Bonaire',
        ),
      ],
    );
    await pumpHeader(tester, geometry);

    // The tappable marker meets the minimum touch target and is labeled for
    // screen readers with the point's name.
    final marker = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Klein Bonaire',
    );
    expect(marker, findsOneWidget);
    final size = tester.getSize(
      find.descendant(of: marker, matching: find.byType(GestureDetector)),
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('a drag on the map stops a camera move in flight', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _AnimatorHarness()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // attach the map camera

    await tester.tap(find.text('animate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // dragFrom sends its moves without pumping frames, so the eased move only
    // ticks again after the drag has ended.
    await tester.dragFrom(
      tester.getCenter(find.byType(FlutterMap)),
      const Offset(-150, 0),
    );
    await tester.pump(const Duration(seconds: 1));

    final center = tester
        .state<_AnimatorHarnessState>(find.byType(_AnimatorHarness))
        ._controller
        .camera
        .center;
    // Left running, the animation would land exactly on its target.
    expect(center.longitude, isNot(closeTo(20, 1e-6)));
  });

  testWidgets('another camera move stops a camera move in flight', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _AnimatorHarness()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // attach the map camera

    await tester.tap(find.text('animate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The trackpad zoom moves the camera through the controller, as the
    // animator does, rather than through a flutter_map gesture.
    final controller = tester
        .state<_AnimatorHarnessState>(find.byType(_AnimatorHarness))
        ._controller;
    controller.move(controller.camera.center, 8);
    await tester.pump(const Duration(seconds: 1));

    // Left running, the animation would land exactly on zoom 6.
    expect(controller.camera.zoom, 8);
  });

  testWidgets('a finished camera move stops watching for gestures', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _AnimatorHarness()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // attach the map camera

    await tester.tap(find.text('animate'));
    await tester.pump();
    final animator = tester
        .state<_AnimatorHarnessState>(find.byType(_AnimatorHarness))
        ._animator!;
    expect(animator.isWatchingGestures, isTrue);

    await tester.pump(const Duration(seconds: 1));
    expect(animator.isWatchingGestures, isFalse);
  });

  testWidgets('MapCameraAnimator eases the camera then disposes cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _AnimatorHarness()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // attach the map camera

    await tester.tap(find.text('animate'));
    // Advance through the 450ms eased move so the listener runs controller.move.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));

    // No assertion beyond "it ran without throwing"; teardown disposes the
    // animator and controller.
    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
