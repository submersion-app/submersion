import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:submersion/core/tide/entities/tide_constituent.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_layers.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_manifest.dart';

/// Constituents interpolated at a point, and the grid spacing behind them.
class FesGridSample {
  final Map<String, TideConstituent> constituents;
  final double resolutionKm;

  const FesGridSample({required this.constituents, required this.resolutionKm});
}

/// Reads the bundled FES2022 grid: the 0.1-degree coastal tiles first, the
/// 1-degree global layer when no coastal corner has data, else nothing.
/// Tiles load on demand and stay cached for the reader's lifetime. Every
/// failure (missing or malformed file) degrades to the next layer and is
/// logged; nothing throws to the caller.
class FesGridReader {
  static const bundledRoot = 'assets/data/tide/fes';

  final Future<ByteData> Function(String relativePath) _load;
  Future<FesGridManifest?>? _manifest;
  Future<FesGlobalLayer?>? _global;
  final Map<(int, int), Future<FesTile?>> _tiles = {};

  FesGridReader({required Future<ByteData> Function(String relativePath) load})
    : _load = load;

  factory FesGridReader.bundled() => FesGridReader(
    load: (relative) => rootBundle.load('$bundledRoot/$relative'),
  );

  Future<FesGridManifest?> manifest() => _manifest ??= _loadManifest();

  Future<FesGridSample?> sampleAt(double latitude, double longitude) async {
    final m = await manifest();
    if (m == null) return null;

    final coastal = await _coastalCorners(m, latitude, longitude);
    final fromCoastal = _interpolate(m.constituents, coastal);
    if (fromCoastal != null) {
      return FesGridSample(
        constituents: fromCoastal,
        resolutionKm: m.coastal.resolutionKm,
      );
    }

    final global = await _globalCorners(m, latitude, longitude);
    final fromGlobal = _interpolate(m.constituents, global);
    if (fromGlobal != null) {
      return FesGridSample(
        constituents: fromGlobal,
        resolutionKm: m.global.resolutionKm,
      );
    }
    return null;
  }

  Future<FesGridManifest?> _loadManifest() async {
    try {
      final data = await _load(FesGridManifest.manifestPath);
      return FesGridManifest.parse(
        utf8.decode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
    } catch (e) {
      developer.log('FES grid manifest unreadable: $e', name: 'FesGridReader');
      return null;
    }
  }

  Future<FesTile?> _tile(FesGridManifest m, int tileRow, int tileCol) {
    return _tiles[(tileRow, tileCol)] ??= () async {
      try {
        final data = await _load(FesGridManifest.tilePath(tileRow, tileCol));
        return FesTile.parse(data, expectedConstituents: m.constituents.length);
      } catch (e) {
        developer.log(
          'FES tile $tileRow,$tileCol unreadable: $e',
          name: 'FesGridReader',
        );
        return null;
      }
    }();
  }

  Future<FesGlobalLayer?> _globalLayer(FesGridManifest m) {
    return _global ??= () async {
      try {
        final layer = FesGlobalLayer.parse(
          await _load(FesGridManifest.globalPath),
          expectedConstituents: m.constituents.length,
        );
        if (layer.rows != m.global.rows || layer.cols != m.global.cols) {
          throw const FormatException('Global layer disagrees with manifest');
        }
        return layer;
      } catch (e) {
        developer.log('FES global layer unreadable: $e', name: 'FesGridReader');
        return null;
      }
    }();
  }

  Future<List<(FesCell, double)>> _coastalCorners(
    FesGridManifest m,
    double latitude,
    double longitude,
  ) async {
    final corners = <(FesCell, double)>[];
    for (final (row, col, weight) in _cornersFor(
      m.coastal,
      latitude,
      longitude,
    )) {
      if (row < 0 || row >= m.coastal.rows) continue;
      final tileRow = row ~/ m.tileSize;
      final tileCol = col ~/ m.tileSize;
      if (!m.coastalTiles.contains((tileRow, tileCol))) continue;
      final tile = await _tile(m, tileRow, tileCol);
      final cell = tile?.cellAt(
        row - tileRow * m.tileSize,
        col - tileCol * m.tileSize,
      );
      if (cell != null) corners.add((cell, weight));
    }
    return corners;
  }

  Future<List<(FesCell, double)>> _globalCorners(
    FesGridManifest m,
    double latitude,
    double longitude,
  ) async {
    final layer = await _globalLayer(m);
    if (layer == null) return const [];
    final corners = <(FesCell, double)>[];
    for (final (row, col, weight) in _cornersFor(
      m.global,
      latitude,
      longitude,
    )) {
      final cell = layer.cellAt(row, col);
      if (cell != null) corners.add((cell, weight));
    }
    return corners;
  }

  /// The four cells around a point with bilinear weights. Columns wrap; rows
  /// may fall outside the layer and are filtered by the caller. Weights are
  /// floored at 1e-9 so a point exactly on a missing node still resolves
  /// from its present neighbours.
  static List<(int, int, double)> _cornersFor(
    FesLayerGeometry g,
    double latitude,
    double longitude,
  ) {
    final y = (latitude - g.latMin) / g.resolution;
    final x = ((longitude - g.lonMin) % 360.0) / g.resolution;
    final r0 = y.floor();
    final c0 = x.floor();
    final fy = y - r0;
    final fx = x - c0;
    double floor(double w) => math.max(w, 1e-9);
    return [
      (r0, c0 % g.cols, floor((1 - fy) * (1 - fx))),
      (r0, (c0 + 1) % g.cols, floor((1 - fy) * fx)),
      (r0 + 1, c0 % g.cols, floor(fy * (1 - fx))),
      (r0 + 1, (c0 + 1) % g.cols, floor(fy * fx)),
    ];
  }

  /// Weighted average of each constituent as a complex number
  /// amplitude * e^(i * phase), renormalized over the corners that have it.
  static Map<String, TideConstituent>? _interpolate(
    List<String> names,
    List<(FesCell, double)> corners,
  ) {
    if (corners.isEmpty) return null;
    final result = <String, TideConstituent>{};
    for (var k = 0; k < names.length; k++) {
      var re = 0.0;
      var im = 0.0;
      var weightSum = 0.0;
      for (final (cell, weight) in corners) {
        final amplitude = cell.amplitudeMeters(k);
        if (amplitude == null) continue;
        final phase = cell.phaseDegrees(k) * math.pi / 180;
        re += weight * amplitude * math.cos(phase);
        im += weight * amplitude * math.sin(phase);
        weightSum += weight;
      }
      if (weightSum <= 0) continue;
      var phase = math.atan2(im, re) * 180 / math.pi;
      if (phase < 0) phase += 360;
      result[names[k]] = TideConstituent(
        name: names[k],
        amplitude: math.sqrt(re * re + im * im) / weightSum,
        phase: phase,
      );
    }
    return result.isEmpty ? null : result;
  }
}
