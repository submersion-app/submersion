import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/presentation/widgets/region_selection.dart';
import 'package:submersion/features/maps/presentation/widgets/region_selector.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late MapController controller;
  late RegionSelection selection;
  LatLng? southWest;
  LatLng? northEast;

  setUp(() {
    controller = MapController();
    selection = RegionSelection();
    southWest = null;
    northEast = null;
    addTearDown(selection.dispose);
  });

  Future<void> pumpSelector(
    WidgetTester tester, {
    bool selecting = true,
    LatLng center = const LatLng(0, 0),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(initialCenter: center, initialZoom: 3),
                children: regionSelectionLayers(selection),
              ),
              RegionSelector(
                mapController: controller,
                selection: selection,
                selecting: selecting,
                onRegionSelected: (sw, ne) {
                  southWest = sw;
                  northEast = ne;
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  FilledButton selectButton(WidgetTester tester) =>
      tester.widget(find.byType(FilledButton));

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  // A pan starts after the touch slop, so the drawn corner sits a few pixels
  // past the press point. At zoom 3 that is a few degrees: compare loosely.
  const tolerance = 6.0;

  testWidgets('a drag draws a rectangle that Select Region reports', (
    tester,
  ) async {
    await pumpSelector(tester);

    await tester.dragFrom(const Offset(200, 200), const Offset(200, 150));
    await tester.pump();
    await confirm(tester);

    final topLeft = controller.camera.screenOffsetToLatLng(
      const Offset(200, 200),
    );
    final bottomRight = controller.camera.screenOffsetToLatLng(
      const Offset(400, 350),
    );
    expect(southWest, isNotNull);
    expect(southWest!.latitude, closeTo(bottomRight.latitude, tolerance));
    expect(southWest!.longitude, closeTo(topLeft.longitude, tolerance));
    expect(northEast!.latitude, closeTo(topLeft.latitude, tolerance));
    expect(northEast!.longitude, closeTo(bottomRight.longitude, tolerance));
  });

  testWidgets('the rectangle is drawn inside the map, as a map layer', (
    tester,
  ) async {
    await pumpSelector(tester);
    expect(
      tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons,
      isEmpty,
    );

    await tester.dragFrom(const Offset(200, 200), const Offset(200, 150));
    await tester.pump();

    final polygons = tester
        .widget<PolygonLayer>(find.byType(PolygonLayer))
        .polygons;
    expect(polygons, hasLength(1));
    expect(polygons.single.points, hasLength(4));
    expect(
      tester.widget<CircleLayer>(find.byType(CircleLayer)).circles,
      hasLength(4),
    );
  });

  testWidgets('dragging a corner moves it and keeps the opposite corner', (
    tester,
  ) async {
    await pumpSelector(tester);
    await tester.dragFrom(const Offset(200, 200), const Offset(200, 150));
    await tester.pump();

    // Pull the bottom-right corner out to (500, 400).
    await tester.dragFrom(const Offset(400, 350), const Offset(100, 50));
    await tester.pump();
    await confirm(tester);

    final topLeft = controller.camera.screenOffsetToLatLng(
      const Offset(200, 200),
    );
    final bottomRight = controller.camera.screenOffsetToLatLng(
      const Offset(500, 400),
    );
    expect(southWest!.latitude, closeTo(bottomRight.latitude, tolerance));
    expect(northEast!.longitude, closeTo(bottomRight.longitude, tolerance));
    // The opposite (top-left) corner stayed where it was drawn.
    expect(southWest!.longitude, closeTo(topLeft.longitude, tolerance));
    expect(northEast!.latitude, closeTo(topLeft.latitude, tolerance));
  });

  testWidgets('in move mode a drag draws nothing', (tester) async {
    await pumpSelector(tester, selecting: false);

    await tester.dragFrom(const Offset(200, 200), const Offset(200, 150));
    await tester.pump();

    expect(selection.hasSelection, isFalse);
    expect(selectButton(tester).onPressed, isNull);
  });

  testWidgets('a box across the date line cannot be selected', (tester) async {
    // Centred on 180 E, so a drag over the middle of the screen straddles it.
    await pumpSelector(tester, center: const LatLng(0, 180));

    await tester.dragFrom(const Offset(300, 200), const Offset(200, 150));
    await tester.pump();

    expect(selection.crossesDateLine, isTrue);
    expect(selectButton(tester).onPressed, isNull);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(southWest, isNull);
  });

  testWidgets(
    'a box drawn on another copy of the world is reported in this one',
    (tester) async {
      // Centred on 500 E, the next world east of Palau (140 E).
      await pumpSelector(tester, center: const LatLng(0, 500));

      await tester.dragFrom(const Offset(300, 200), const Offset(100, 100));
      await tester.pump();
      await confirm(tester);

      expect(southWest, isNotNull);
      expect(southWest!.longitude, inInclusiveRange(-180, 180));
      expect(northEast!.longitude, inInclusiveRange(-180, 180));
      // Around 140 E, not collapsed onto 180 (what a clamped conversion gives).
      expect(southWest!.longitude, closeTo(140, 25));
      expect(northEast!.longitude, greaterThan(southWest!.longitude));
    },
  );

  testWidgets('Cancel clears the rectangle', (tester) async {
    await pumpSelector(tester);
    await tester.dragFrom(const Offset(200, 200), const Offset(200, 150));
    await tester.pump();
    expect(selection.hasSelection, isTrue);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();

    expect(selection.hasSelection, isFalse);
  });
}
