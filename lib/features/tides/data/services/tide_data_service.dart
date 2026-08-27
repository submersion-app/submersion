import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import 'package:submersion/core/tide/entities/tide_constituent.dart';
import 'package:submersion/core/tide/tide_calculator.dart';

/// Top-level function for parsing JSON on a background isolate.
///
/// This prevents JSON parsing from blocking the main UI thread.
Map<String, dynamic> _parseJsonInIsolate(String jsonStr) {
  return json.decode(jsonStr) as Map<String, dynamic>;
}

/// Service for loading and managing tidal constituent data.
///
/// This service:
/// - Loads bundled constituent data from assets
/// - Provides [TideCalculator] instances for specific locations
/// - Interpolates grid data for locations without pre-computed constituents
/// - Caches loaded data to avoid repeated asset reads
///
/// Usage:
/// ```dart
/// final service = TideDataService();
/// await service.initialize();
///
/// // Get calculator for a known site
/// final calculator = await service.getCalculatorForLocation(36.6, -121.9);
/// if (calculator != null) {
///   final height = calculator.calculateHeight(DateTime.now());
/// }
/// ```
class TideDataService {
  /// Cached metadata
  Map<String, dynamic>? _metadata;

  /// Cached grid data (loaded on demand due to size)
  Map<String, dynamic>? _gridData;

  /// Whether the service has been initialized
  bool _initialized = false;

  /// Whether grid data is available
  bool _hasGridData = false;

  /// Initialize the service by loading bundled data.
  ///
  /// Call this before using other methods. Safe to call multiple times.
  /// Uses background isolate for JSON parsing to avoid blocking the UI thread.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final metadataStr = await rootBundle.loadString(
        'assets/data/tide/metadata.json',
      );
      _metadata = await compute(_parseJsonInIsolate, metadataStr);
      _initialized = true;
    } catch (e) {
      // Allow initialization to succeed even if files missing
      _initialized = true;
      _metadata = {};
    }
  }

  /// Load grid data on demand.
  ///
  /// Grid data can be large (~50-100 MB), so it's loaded separately
  /// only when needed for interpolation.
  /// Uses background isolate for JSON parsing to avoid blocking the UI thread.
  Future<void> _loadGridDataIfNeeded() async {
    if (_gridData != null) return;

    try {
      final gridStr = await rootBundle.loadString(
        'assets/data/tide/constituents_grid.json',
      );
      // Parse on background isolate - this is especially important for large grid data
      _gridData = await compute(_parseJsonInIsolate, gridStr);
      _hasGridData = true;
    } catch (e) {
      // Grid data is optional
      _gridData = {'points': []};
      _hasGridData = false;
    }
  }

  /// Get a [TideCalculator] for a specific location.
  ///
  /// Interpolates the bundled FES2022 grid (if grid data available).
  ///
  /// Returns null if no data is available for the location.
  Future<TideCalculator?> getCalculatorForLocation(
    double latitude,
    double longitude,
  ) async {
    await initialize();

    await _loadGridDataIfNeeded();
    if (_hasGridData) {
      final gridConstituents = _interpolateGrid(latitude, longitude);
      if (gridConstituents != null) {
        return TideCalculator(constituents: gridConstituents);
      }
    }

    return null;
  }

  /// Check if tide data is available for a location.
  Future<bool> hasTideData(double latitude, double longitude) async {
    await initialize();

    await _loadGridDataIfNeeded();
    if (_hasGridData) {
      return _interpolateGrid(latitude, longitude) != null;
    }

    return false;
  }

  /// Get metadata about the tide data.
  Future<TideDataMetadata?> getMetadata() async {
    await initialize();

    if (_metadata == null || _metadata!.isEmpty) return null;

    return TideDataMetadata(
      version: _metadata!['version'] as String? ?? '1.0',
      model: _metadata!['model'] as String? ?? 'Unknown',
      datum: _metadata!['datum'] as String? ?? 'MSL',
      extractionDate: _metadata!['extraction_date'] as String?,
    );
  }

  /// Interpolate constituents from grid data.
  ///
  /// Uses bilinear interpolation for amplitude and special handling
  /// for phase (to handle 0/360 wraparound).
  Map<String, TideConstituent>? _interpolateGrid(
    double latitude,
    double longitude,
  ) {
    final grid = _gridData?['grid'] as Map<String, dynamic>?;
    final points = _gridData?['points'] as List<dynamic>?;

    if (grid == null || points == null || points.isEmpty) return null;

    final resolution = (grid['resolution'] as num).toDouble();
    final latMin = (grid['lat_min'] as num).toDouble();
    final lonMin = (grid['lon_min'] as num).toDouble();
    final latMax = (grid['lat_max'] as num).toDouble();
    final lonMax = (grid['lon_max'] as num).toDouble();

    // Check bounds
    if (latitude < latMin ||
        latitude > latMax ||
        longitude < lonMin ||
        longitude > lonMax) {
      return null;
    }

    // Find grid cell indices
    final latIndex = ((latitude - latMin) / resolution).floor();
    final lonIndex = ((longitude - lonMin) / resolution).floor();

    // Interpolation weights within the cell
    final latFrac = (latitude - (latMin + latIndex * resolution)) / resolution;
    final lonFrac = (longitude - (lonMin + lonIndex * resolution)) / resolution;

    // Get the four corner points
    final p00 = _getGridPoint(points, latIndex, lonIndex, grid);
    final p01 = _getGridPoint(points, latIndex, lonIndex + 1, grid);
    final p10 = _getGridPoint(points, latIndex + 1, lonIndex, grid);
    final p11 = _getGridPoint(points, latIndex + 1, lonIndex + 1, grid);

    // If any corner is missing (land), return null
    if (p00 == null || p01 == null || p10 == null || p11 == null) {
      return null;
    }

    // Get list of constituents from any point
    final constituentNames = p00.keys.toSet();

    // Interpolate each constituent
    final result = <String, TideConstituent>{};

    for (final name in constituentNames) {
      final c00 = p00[name];
      final c01 = p01[name];
      final c10 = p10[name];
      final c11 = p11[name];

      if (c00 == null || c01 == null || c10 == null || c11 == null) continue;

      // Bilinear interpolation for amplitude
      final amp =
          c00.amplitude * (1 - latFrac) * (1 - lonFrac) +
          c01.amplitude * (1 - latFrac) * lonFrac +
          c10.amplitude * latFrac * (1 - lonFrac) +
          c11.amplitude * latFrac * lonFrac;

      // Phase interpolation with wraparound handling
      final phase = _interpolatePhase(
        c00.phase,
        c01.phase,
        c10.phase,
        c11.phase,
        latFrac,
        lonFrac,
      );

      result[name] = TideConstituent(name: name, amplitude: amp, phase: phase);
    }

    return result.isEmpty ? null : result;
  }

  /// Get a grid point by indices.
  Map<String, TideConstituent>? _getGridPoint(
    List<dynamic> points,
    int latIndex,
    int lonIndex,
    Map<String, dynamic> grid,
  ) {
    // Calculate linear index based on grid dimensions
    final resolution = (grid['resolution'] as num).toDouble();
    final latMin = (grid['lat_min'] as num).toDouble();
    final latMax = (grid['lat_max'] as num).toDouble();
    final lonMin = (grid['lon_min'] as num).toDouble();
    final lonMax = (grid['lon_max'] as num).toDouble();

    final latCount = ((latMax - latMin) / resolution).ceil() + 1;
    final lonCount = ((lonMax - lonMin) / resolution).ceil() + 1;

    if (latIndex < 0 ||
        latIndex >= latCount ||
        lonIndex < 0 ||
        lonIndex >= lonCount) {
      return null;
    }

    // Find the point with matching coordinates
    final targetLat = latMin + latIndex * resolution;
    final targetLon = lonMin + lonIndex * resolution;

    for (final point in points) {
      final lat = (point['lat'] as num).toDouble();
      final lon = (point['lon'] as num).toDouble();

      if ((lat - targetLat).abs() < 0.001 && (lon - targetLon).abs() < 0.001) {
        return _parseConstituents(
          point['constituents'] as Map<String, dynamic>,
        );
      }
    }

    return null; // Land point (not in ocean data)
  }

  /// Interpolate phase with proper 0/360 wraparound handling.
  ///
  /// Uses complex number representation to avoid discontinuity issues.
  double _interpolatePhase(
    double p00,
    double p01,
    double p10,
    double p11,
    double latFrac,
    double lonFrac,
  ) {
    // Convert to radians for trig operations
    const toRad = math.pi / 180.0;

    // Use complex number representation: e^(i*phase)
    // Then interpolate and convert back
    double sinSum = 0, cosSum = 0;
    final weights = [
      ((1 - latFrac) * (1 - lonFrac), p00),
      ((1 - latFrac) * lonFrac, p01),
      (latFrac * (1 - lonFrac), p10),
      (latFrac * lonFrac, p11),
    ];

    for (final (w, p) in weights) {
      sinSum += w * math.sin(p * toRad);
      cosSum += w * math.cos(p * toRad);
    }

    // Convert back to degrees
    var result = math.atan2(sinSum, cosSum) * 180 / math.pi;
    if (result < 0) result += 360;

    return result;
  }

  /// Parse constituent JSON into TideConstituent objects.
  Map<String, TideConstituent> _parseConstituents(Map<String, dynamic> data) {
    final result = <String, TideConstituent>{};

    for (final entry in data.entries) {
      final constData = entry.value as Map<String, dynamic>;
      result[entry.key] = TideConstituent(
        name: entry.key,
        amplitude: (constData['amplitude'] as num).toDouble(),
        phase: (constData['phase'] as num).toDouble(),
      );
    }

    return result;
  }
}

/// Metadata about the tide data source.
class TideDataMetadata {
  final String version;
  final String model;
  final String datum;
  final String? extractionDate;

  const TideDataMetadata({
    required this.version,
    required this.model,
    required this.datum,
    this.extractionDate,
  });

  @override
  String toString() => 'TideDataMetadata($model $version, datum: $datum)';
}
