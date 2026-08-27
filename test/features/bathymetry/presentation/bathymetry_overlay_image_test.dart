import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
// LatLngBounds comes from flutter_map (bathymetry_overlay_image exports its
// use through BathymetryOverlayData.bounds).
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_overlay_image.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';

BathymetryGrid gridOf(List<List<double?>> rowsSouthToNorth) {
  final rows = rowsSouthToNorth.length;
  final cols = rowsSouthToNorth.first.length;
  return BathymetryGrid(
    originLat: 10.0,
    originLon: 20.0,
    cellSizeLatDeg: 0.001,
    cellSizeLonDeg: 0.002,
    rows: rows,
    cols: cols,
    depthsMeters: [for (final r in rowsSouthToNorth) ...r],
    sourceId: 'test',
    resolutionMeters: 100,
    fetchedAt: DateTime.utc(2026, 8, 15),
  );
}

/// Decodes PNG bytes and reads the straight-alpha RGBA pixel at (x, y).
/// (rawRgba is PREMULTIPLIED; rawStraightRgba returns the actual colors.)
/// Codec and image are engine resources: dispose both so the suite never
/// accumulates handles.
Future<ui.Color> pixelAt(Uint8List png, int x, int y) async {
  final codec = await ui.instantiateImageCodec(png);
  try {
    final image = (await codec.getNextFrame()).image;
    try {
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      final i = (y * image.width + x) * 4;
      final bytes = data.buffer.asUint8List();
      return ui.Color.fromARGB(
        bytes[i + 3],
        bytes[i],
        bytes[i + 1],
        bytes[i + 2],
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bounds extend half a cell beyond the center grid', () {
    final grid = gridOf([
      [10.0, 20.0],
      [30.0, 40.0],
    ]);
    final b = bathymetryGridBounds(grid);
    // Origin is the CENTER of the south-west cell.
    expect(b.southWest, const LatLng(10.0 - 0.0005, 20.0 - 0.001));
    expect(
      b.northEast,
      const LatLng(10.0 + 0.001 + 0.0005, 20.0 + 0.002 + 0.001),
    );
  });

  test(
    'wet cells carry the ramp color, land and nodata are transparent',
    () async {
      // South row wet (10 m, 40 m), north row land + nodata. maxDepth 40.
      final grid = gridOf([
        [10.0, 40.0],
        [-2.0, null],
      ]);
      final data = await buildBathymetryOverlay(
        grid: grid,
        appearance: const SeascapeAppearance(),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
        pixelsPerCell: 4,
      );
      expect(data, isNotNull);
      // Image is 8x8 (2x2 cells at 4 px). Rows flip: grid row 0 (south) is
      // the BOTTOM image row. Land cell (grid r1,c0) = image top-left.
      final land = await pixelAt(data!.pngBytes, 1, 1);
      expect(land.a, 0.0); // fully transparent
      final nodata = await pixelAt(data.pngBytes, 6, 1);
      expect(nodata.a, 0.0);
      // Wet 40 m cell (grid r0,c1) = image bottom-right; ramp t = 1.0.
      final deep = await pixelAt(data.pngBytes, 6, 6);
      expect(deep.a, greaterThan(0.5)); // translucent fill, not opaque
      final expected = BathymetryTerrainBuilder.depthColor(1.0);
      expect((deep.r - expected.r).abs(), lessThan(0.05));
      expect((deep.g - expected.g).abs(), lessThan(0.05));
      expect((deep.b - expected.b).abs(), lessThan(0.05));
    },
  );

  test('contour strokes appear between wet cells', () async {
    // 3x3 sloping grid 5 -> 45 m: auto levels include the 25 m major
    // crossing the middle row of cell centers.
    final grid = gridOf([
      [5.0, 5.0, 5.0],
      [25.0, 25.0, 25.0],
      [45.0, 45.0, 45.0],
    ]);
    final data = await buildBathymetryOverlay(
      grid: grid,
      appearance: const SeascapeAppearance(),
      displayUnitInMeters: 1.0,
      depthSymbol: 'm',
      pixelsPerCell: 8,
    );
    // Image 24x24. The 25 m contour runs along image y = 24 - 1.5 * 8 = 12.
    final ink = await pixelAt(data!.pngBytes, 12, 12);
    // Contour ink is near-white, far brighter than any ramp color.
    expect(ink.r, greaterThan(0.8));
    expect(ink.g, greaterThan(0.8));
    expect(ink.a, greaterThan(0.7));
  });

  test('degenerate grids return null', () async {
    final grid = gridOf([
      [10.0, 20.0],
    ]);
    expect(
      await buildBathymetryOverlay(
        grid: grid,
        appearance: const SeascapeAppearance(),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      ),
      isNull,
    );
  });
}
