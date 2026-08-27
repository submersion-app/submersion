import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/map_tile_config.dart';
import 'package:submersion/core/utils/slippy_tiles.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/terrain_imagery_frame.dart';

/// A stitched tile mosaic plus the frame that maps it onto geometry.
class TerrainImagery {
  final ui.Image image;
  final TerrainImageryFrame frame;
  const TerrainImagery({required this.image, required this.frame});
}

const int _tileSizePx = 256;
const int _whiteStripPx = 4;
const int _maxTiles = 20;

/// Fetches and stitches keyless map tiles covering a bathymetry grid's
/// footprint into one mosaic image with a reserved white strip at the
/// bottom. Returns null on ANY failure (offline, HTTP error, decode
/// error, oversized range): the terrain then silently falls back to depth
/// colors, matching the seascape's no-spinner posture.
class TerrainImageryService {
  final http.Client _client;

  TerrainImageryService(this._client);

  Future<TerrainImagery?> fetch({
    required BathymetryGrid grid,
    required MapStyle style,
  }) async {
    if (grid.rows < 2 || grid.cols < 2) return null;
    final halfLat = grid.cellSizeLatDeg / 2;
    final halfLon = grid.cellSizeLonDeg / 2;
    final west = grid.originLon - halfLon;
    final east =
        grid.originLon + grid.cellSizeLonDeg * (grid.cols - 1) + halfLon;
    final south = grid.originLat - halfLat;
    final north =
        grid.originLat + grid.cellSizeLatDeg * (grid.rows - 1) + halfLat;

    final z = imageryZoomFor(
      lonSpanDeg: east - west,
      maxZoom: MapTileConfig.maxZoom(style),
    );
    final xMin = slippyTileOf(north, west, z).x;
    final xMax = slippyTileOf(north, east, z).x;
    final yMin = slippyTileOf(north, west, z).y; // mercator y grows south
    final yMax = slippyTileOf(south, west, z).y;
    final tilesX = xMax - xMin + 1;
    final tilesY = yMax - yMin + 1;
    if (tilesX <= 0 || tilesY <= 0 || tilesX * tilesY > _maxTiles) {
      return null;
    }

    final width = tilesX * _tileSizePx;
    final tileAreaHeight = tilesY * _tileSizePx;
    final height = tileAreaHeight + _whiteStripPx;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();
    final tileImages = <ui.Image>[];
    try {
      for (var x = xMin; x <= xMax; x++) {
        for (var y = yMin; y <= yMax; y++) {
          final bytes = await _fetchTile(style, z, x, y);
          if (bytes == null) return null;
          final ui.Image tile;
          try {
            final codec = await ui.instantiateImageCodec(bytes);
            try {
              tile = (await codec.getNextFrame()).image;
            } finally {
              codec.dispose();
            }
          } catch (_) {
            return null;
          }
          tileImages.add(tile);
          canvas.drawImage(
            tile,
            ui.Offset(
              ((x - xMin) * _tileSizePx).toDouble(),
              ((y - yMin) * _tileSizePx).toDouble(),
            ),
            paint,
          );
        }
      }
      // The reserved strip: an opaque white band UV-less draped meshes
      // sample so color modulation is the identity for them.
      canvas.drawRect(
        ui.Rect.fromLTWH(
          0,
          tileAreaHeight.toDouble(),
          width.toDouble(),
          _whiteStripPx.toDouble(),
        ),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      final image = await recorder.endRecording().toImage(width, height);
      final scale = 1 << z;
      return TerrainImagery(
        image: image,
        frame: TerrainImageryFrame(
          u0MercX: xMin / scale,
          u1MercX: (xMax + 1) / scale,
          v0MercY: yMin / scale,
          v1MercY: yMin / scale + (height / _tileSizePx) / scale,
          whiteU: 0.5,
          whiteV: (tileAreaHeight + _whiteStripPx / 2) / height,
        ),
      );
    } finally {
      for (final tile in tileImages) {
        tile.dispose();
      }
    }
  }

  Future<Uint8List?> _fetchTile(MapStyle style, int z, int x, int y) async {
    try {
      final response = await _client.get(
        Uri.parse(MapTileConfig.tileUrl(style, z, x, y)),
        headers: const {'User-Agent': 'app.submersion'},
      );
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}
