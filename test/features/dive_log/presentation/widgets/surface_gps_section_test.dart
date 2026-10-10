import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
}) async {
  final overrides = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(600, 1200));
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

    testWidgets('a trackpad two-finger scroll over the map does not zoom it', (
      tester,
    ) async {
      final controller = MapController();
      await _pump(tester, controller: controller);
      final zoom = controller.camera.zoom;

      final center = tester.getCenter(find.byType(FlutterMap));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomStart(center);
      await tester.pump();
      await gesture.panZoomUpdate(center, pan: const Offset(0, 100));
      await tester.pump();
      await gesture.panZoomEnd();
      await tester.pump();

      expect(controller.camera.zoom, zoom);
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
    expect(find.text('12.345670° N, 98.765430° E'), findsOneWidget); // entry
    expect(find.text('12.346120° N, 98.764890° E'), findsOneWidget); // exit
    expect(find.text('12.340000° N, 98.760000° E'), findsOneWidget); // site
    expect(find.text('Open in Maps'), findsNothing);
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
      expect(find.text('12.340000° N, 98.760000° E'), findsOneWidget);
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
}
