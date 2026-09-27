import 'dart:convert';

/// Kilometres per degree of latitude (mean Earth radius 6371 km).
const double kmPerDegree = 111.195;

/// Geometry of one layer of the bundled FES2022 grid. Cell (row, col) is
/// centred on (latMin + row * resolution, lonMin + col * resolution);
/// columns wrap in longitude.
class FesLayerGeometry {
  final double latMin;
  final double lonMin;
  final double resolution;
  final int rows;
  final int cols;

  const FesLayerGeometry({
    required this.latMin,
    required this.lonMin,
    required this.resolution,
    required this.rows,
    required this.cols,
  });

  factory FesLayerGeometry.fromJson(Map<String, dynamic> json) {
    return FesLayerGeometry(
      latMin: (json['latMin'] as num).toDouble(),
      lonMin: (json['lonMin'] as num).toDouble(),
      resolution: (json['resolution'] as num).toDouble(),
      rows: json['rows'] as int,
      cols: json['cols'] as int,
    );
  }

  double get resolutionKm => resolution * kmPerDegree;
}

/// The grid's `manifest.json`, written by `scripts/tide/extract_fes_grid.py`.
class FesGridManifest {
  static const formatName = 'submersion-fes-grid';
  static const supportedVersion = 1;
  static const manifestPath = 'manifest.json';
  static const globalPath = 'global.bin';

  static String tilePath(int tileRow, int tileCol) =>
      'coastal/tile_${tileRow}_$tileCol.bin';

  final String model;
  final String extractionDate;
  final double bandKm;
  final List<String> constituents;
  final FesLayerGeometry coastal;
  final int tileSize;
  final Set<(int, int)> coastalTiles;
  final FesLayerGeometry global;

  const FesGridManifest({
    required this.model,
    required this.extractionDate,
    required this.bandKm,
    required this.constituents,
    required this.coastal,
    required this.tileSize,
    required this.coastalTiles,
    required this.global,
  });

  /// Parses [source]. Throws [FormatException] for anything that is not a
  /// supported manifest, including JSON of the wrong shape.
  static FesGridManifest parse(String source) {
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic> ||
          json['format'] != formatName ||
          json['version'] != supportedVersion) {
        throw const FormatException('Unsupported FES grid manifest');
      }
      final coastal = json['coastal'] as Map<String, dynamic>;
      return FesGridManifest(
        model: json['model'] as String,
        extractionDate: json['extractionDate'] as String,
        bandKm: (json['bandKm'] as num).toDouble(),
        constituents: (json['constituents'] as List).cast<String>(),
        coastal: FesLayerGeometry.fromJson(coastal),
        tileSize: coastal['tileSize'] as int,
        coastalTiles: {
          for (final tile in (coastal['tiles'] as List).cast<List>())
            (tile[0] as int, tile[1] as int),
        },
        global: FesLayerGeometry.fromJson(
          json['global'] as Map<String, dynamic>,
        ),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Malformed FES grid manifest: $e');
    }
  }
}
