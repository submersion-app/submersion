import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_overlay_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The built-in overlay reads the catalogue sites the map shows, not all
/// of them. These pin the piece that tells the providers what the map
/// shows, and the caption for a view that holds more than it can mark.

Future<({ProviderContainer container, MapController map})> _pumpMap(
  WidgetTester tester, {
  bool show = true,
  LatLng center = const LatLng(12, -68),
  double zoom = 9,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final map = MapController();
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        showBuiltInSitesProvider.overrideWith((ref) => show),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return Stack(
                children: [
                  FlutterMap(
                    mapController: map,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: zoom,
                    ),
                    children: const [BuiltInOverlayBoundsReporter()],
                  ),
                  const Positioned(
                    top: 8,
                    left: 8,
                    child: BuiltInOverlayCaption(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (container: container, map: map);
}

void main() {
  testWidgets('the first view is reported at once', (tester) async {
    final h = await _pumpMap(tester);
    await tester.pump();

    final bounds = h.container.read(builtInOverlayBoundsProvider);
    expect(bounds, isNotNull);
    expect(bounds!.contains(const GeoPoint(12, -68)), isTrue);
    expect(bounds.contains(const GeoPoint(58.9, -3.1)), isFalse);
  });

  testWidgets('a moved map is reported once it stops, not while it moves', (
    tester,
  ) async {
    final h = await _pumpMap(tester);
    await tester.pump();
    final first = h.container.read(builtInOverlayBoundsProvider);

    h.map.move(const LatLng(58.9, -3.1), 9);
    await tester.pump();
    h.map.move(const LatLng(58.95, -3.1), 9);
    await tester.pump(const Duration(milliseconds: 100));
    // Still the first view: the map has not rested yet.
    expect(h.container.read(builtInOverlayBoundsProvider), first);

    await tester.pump(const Duration(milliseconds: 400));
    final settled = h.container.read(builtInOverlayBoundsProvider)!;
    expect(settled.contains(const GeoPoint(58.95, -3.1)), isTrue);
    expect(settled.contains(const GeoPoint(12, -68)), isFalse);
  });

  testWidgets('with the overlay off nothing is reported', (tester) async {
    final h = await _pumpMap(tester, show: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(h.container.read(builtInOverlayBoundsProvider), isNull);
  });

  testWidgets('turning the overlay on reports the view it finds', (
    tester,
  ) async {
    final h = await _pumpMap(tester, show: false);
    await tester.pump(const Duration(milliseconds: 500));

    h.container.read(showBuiltInSitesProvider.notifier).state = true;
    await tester.pump();
    await tester.pump();

    expect(
      h.container
          .read(builtInOverlayBoundsProvider)!
          .contains(const GeoPoint(12, -68)),
      isTrue,
    );
  });

  testWidgets('a view of the whole world is one box, not a seam', (
    tester,
  ) async {
    final h = await _pumpMap(tester, center: const LatLng(0, 0), zoom: 0);
    await tester.pump();

    final bounds = h.container.read(builtInOverlayBoundsProvider)!;
    expect(bounds.crossesAntimeridian, isFalse);
    expect(bounds.west, -180);
    expect(bounds.east, 180);
    expect(bounds.contains(const GeoPoint(-16.8, 179.95)), isTrue);
    expect(bounds.contains(const GeoPoint(58.9, -3.1)), isTrue);
  });

  testWidgets('a view across the antimeridian is a box that crosses it', (
    tester,
  ) async {
    final h = await _pumpMap(tester, center: const LatLng(-17, 179.9), zoom: 8);
    await tester.pump();

    final bounds = h.container.read(builtInOverlayBoundsProvider)!;
    expect(bounds.crossesAntimeridian, isTrue);
    expect(bounds.contains(const GeoPoint(-17, 179.95)), isTrue);
    expect(bounds.contains(const GeoPoint(-17, -179.95)), isTrue);
    expect(bounds.contains(const GeoPoint(-17, 0)), isFalse);
  });

  testWidgets('leaving the map with a report pending leaves no timer', (
    tester,
  ) async {
    final h = await _pumpMap(tester);
    await tester.pump();
    h.map.move(const LatLng(58.9, -3.1), 9);
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });

  group('the caption', () {
    testWidgets('says to zoom in when the view holds more than it marks', (
      tester,
    ) async {
      await _pumpMap(
        tester,
        overrides: [
          builtInOverlayTruncatedProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.text('Zoom in to see every built-in site'), findsOneWidget);
    });

    testWidgets('is absent when everything in view is marked', (tester) async {
      await _pumpMap(
        tester,
        overrides: [
          builtInOverlayTruncatedProvider.overrideWith((ref) => false),
        ],
      );

      expect(find.textContaining('Zoom in'), findsNothing);
    });

    testWidgets('is absent with the overlay off', (tester) async {
      await _pumpMap(
        tester,
        show: false,
        overrides: [
          builtInOverlayTruncatedProvider.overrideWith((ref) => true),
        ],
      );

      expect(find.textContaining('Zoom in'), findsNothing);
    });
  });

  test('the bounds type knows its own middle', () {
    expect(
      const CatalogueBounds(south: 0, west: 10, north: 20, east: 30).center,
      const GeoPoint(10, 20),
    );
  });
}
