import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/bathymetry/data/terrain_imagery_service.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// One reusable 256x256 PNG tile.
Future<Uint8List> tilePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 256, 256),
    ui.Paint()..color = const ui.Color(0xFF336699),
  );
  final image = await recorder.endRecording().toImage(256, 256);
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return data.buffer.asUint8List();
}

/// Grid whose cell-edge extents are exactly lon 0.1..0.5, lat -0.1..0.1:
/// lonSpan 0.4 -> z = round(log2(4*360/0.4)) = 12; tiles x 2049..2053,
/// y 2046..2049 (5 x 4 tiles).
BathymetryGrid grid() => BathymetryGrid(
  originLat: -0.05,
  originLon: 0.2,
  cellSizeLatDeg: 0.1,
  cellSizeLonDeg: 0.2,
  rows: 2,
  cols: 2,
  depthsMeters: const [10, 20, 30, 40],
  sourceId: 'test',
  resolutionMeters: 100,
  fetchedAt: DateTime.utc(2026, 8, 15),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'stitches the tile range with the white strip and honest frame',
    () async {
      final png = await tilePng();
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.toString());
        expect(request.headers['User-Agent'], 'app.submersion');
        return http.Response.bytes(png, 200);
      });

      final result = await TerrainImageryService(
        client,
      ).fetch(grid: grid(), style: MapStyle.esriSatellite);

      expect(result, isNotNull);
      expect(requested, hasLength(20)); // 5 x 4 tiles at z12
      expect(result!.image.width, 5 * 256);
      expect(result.image.height, 4 * 256 + 4);
      final f = result.frame;
      expect(f.u0MercX, closeTo(2049 / 4096, 1e-12));
      expect(f.u1MercX, closeTo(2054 / 4096, 1e-12));
      expect(f.v0MercY, closeTo(2046 / 4096, 1e-12));
      // The 4px strip stretches v=1: (2046 + 1028/256) / 4096.
      expect(f.v1MercY, closeTo((2046 + 1028 / 256) / 4096, 1e-12));
      expect(f.whiteV, closeTo(1026 / 1028, 1e-12));
      // The reserved texel really is opaque white.
      final raw = (await result.image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      final bytes = raw.buffer.asUint8List();
      final i =
          ((4 * 256 + 2) * result.image.width + result.image.width ~/ 2) * 4;
      expect(bytes.sublist(i, i + 4), [255, 255, 255, 255]);
    },
  );

  test('an oversized tile range yields null without fetching', () async {
    // ~7 degrees each way clamps to the z10 floor, where the range is far
    // beyond the 20-tile cap; the guard must refuse before any request.
    final huge = BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 3.6,
      cellSizeLonDeg: 3.6,
      rows: 2,
      cols: 2,
      depthsMeters: const [10, 20, 30, 40],
      sourceId: 'test',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 8, 15),
    );
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('nope', 404);
    });
    expect(
      await TerrainImageryService(
        client,
      ).fetch(grid: huge, style: MapStyle.esriSatellite),
      isNull,
    );
    expect(requests, 0);
  });

  test('any tile failure yields null', () async {
    final client = MockClient((request) async => http.Response('nope', 404));
    expect(
      await TerrainImageryService(
        client,
      ).fetch(grid: grid(), style: MapStyle.openStreetMap),
      isNull,
    );
  });
}
