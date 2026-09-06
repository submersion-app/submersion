import 'dart:typed_data';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// Reads the uncompressed, tiled, little-endian float32 GeoTIFF an ArcGIS
/// ImageServer returns for `format=tiff&pixelType=F32`.
///
/// Deliberately narrow. This is not a TIFF library: it accepts exactly the
/// shape that service emits and throws [FormatException] on anything else,
/// so an unexpected response becomes a transient source failure rather than
/// silently wrong terrain. ArcGIS returns error envelopes with HTTP 200, so
/// "not a TIFF" is a routine outcome, not an exotic one.
///
/// Two conversions bring the raster into the app's convention: image rows
/// run north to south while [BathymetryGrid] rows run south to north, and
/// the raster carries elevation (negative below sea level) while the grid
/// carries depth (positive down).
class ArcgisFloat32TiffParser {
  /// ArcGIS writes float32 lowest as its NoData sentinel. Nothing on Earth
  /// is within thirty orders of magnitude of it, so the guard below cannot
  /// swallow a real reading.
  static const double _noDataCeiling = -1e30;

  static const int _tagImageWidth = 256;
  static const int _tagImageLength = 257;
  static const int _tagBitsPerSample = 258;
  static const int _tagCompression = 259;
  static const int _tagSamplesPerPixel = 277;
  static const int _tagTileWidth = 322;
  static const int _tagTileLength = 323;
  static const int _tagTileOffsets = 324;
  static const int _tagTileByteCounts = 325;
  static const int _tagSampleFormat = 339;

  /// SampleFormat 3 is IEEE floating point. 1 (unsigned) and 2 (signed)
  /// integer rasters carry the same 32 bits per sample, so BitsPerSample
  /// alone cannot tell them apart from float.
  static const int _sampleFormatIeeeFloat = 3;

  /// TIFF field type 4, a 32-bit unsigned integer. The tile offset and
  /// byte-count arrays are read at this width and no other.
  static const int _fieldTypeLong = 4;

  static BathymetryGrid parse(
    Uint8List bytes, {
    required double westLon,
    required double eastLon,
    required double southLat,
    required double northLat,
    required String sourceId,
    required double resolutionMeters,
    required DateTime fetchedAt,
  }) {
    if (bytes.length < 8 || bytes[0] != 0x49 || bytes[1] != 0x49) {
      throw const FormatException(
        'Expected a little-endian TIFF (II magic); the service returned '
        'something else, most likely an error envelope.',
      );
    }
    final d = ByteData.sublistView(bytes);
    if (d.getUint16(2, Endian.little) != 42) {
      throw const FormatException('Not a classic TIFF (magic 42 missing)');
    }

    final tags = _readIfd(d, bytes.length);

    int need(int tag, String what) {
      final t = tags[tag];
      if (t == null) throw FormatException('TIFF is missing $what');
      return t.value;
    }

    if (need(_tagCompression, 'Compression') != 1) {
      throw const FormatException('Only uncompressed TIFF is supported');
    }
    if (need(_tagBitsPerSample, 'BitsPerSample') != 32) {
      throw const FormatException('Only 32-bit samples are supported');
    }
    // BitsPerSample is not enough on its own: a 32-bit INTEGER raster has
    // the same sample width, and reading its bits as float32 does not
    // fail. It yields denormals near zero for small values and huge
    // magnitudes for large ones, all non-null, so every downstream quality
    // floor passes and the garbage renders as terrain. Require the tag
    // rather than defaulting: TIFF's own default when it is absent is
    // unsigned integer, so an untagged raster is not float either.
    if (need(_tagSampleFormat, 'SampleFormat') != _sampleFormatIeeeFloat) {
      throw const FormatException(
        'Only IEEE float samples are supported (SampleFormat 3)',
      );
    }
    if (need(_tagSamplesPerPixel, 'SamplesPerPixel') != 1) {
      throw const FormatException('Only single-band rasters are supported');
    }

    final width = need(_tagImageWidth, 'ImageWidth');
    final height = need(_tagImageLength, 'ImageLength');
    final tileW = need(_tagTileWidth, 'TileWidth');
    final tileH = need(_tagTileLength, 'TileLength');
    if (width < 1 || height < 1 || tileW < 1 || tileH < 1) {
      throw const FormatException('TIFF has a zero dimension');
    }

    final offsets = _longs(
      d,
      tags[_tagTileOffsets],
      'TileOffsets',
      bytes.length,
    );
    final counts = _longs(
      d,
      tags[_tagTileByteCounts],
      'TileByteCounts',
      bytes.length,
    );
    final tilesAcross = (width + tileW - 1) ~/ tileW;
    final tilesDown = (height + tileH - 1) ~/ tileH;
    if (offsets.length != tilesAcross * tilesDown) {
      throw const FormatException('TileOffsets count does not match the grid');
    }
    if (counts.length != offsets.length) {
      throw const FormatException('TileByteCounts does not match TileOffsets');
    }
    // Every tile of an uncompressed float32 raster is exactly this big. A
    // disagreement means the data is not the plain block this parser
    // assumes, whatever the Compression tag claims.
    final expectedTileBytes = tileW * tileH * 4;
    for (final c in counts) {
      if (c != expectedTileBytes) {
        throw FormatException(
          'Tile byte count $c is not the $expectedTileBytes bytes an '
          'uncompressed ${tileW}x$tileH float32 tile occupies',
        );
      }
    }

    // Image order first, northernmost row at index 0.
    final image = List<double?>.filled(width * height, null);
    for (var t = 0; t < offsets.length; t++) {
      final tx = t % tilesAcross;
      final ty = t ~/ tilesAcross;
      final base = offsets[t];
      if (base < 0 || base + tileW * tileH * 4 > bytes.length) {
        throw const FormatException('TIFF tile runs past the end of the body');
      }
      for (var r = 0; r < tileH; r++) {
        final imageRow = ty * tileH + r;
        if (imageRow >= height) break;
        for (var c = 0; c < tileW; c++) {
          final imageCol = tx * tileW + c;
          // Tiles are padded out to their full size at the right and
          // bottom edges; that padding is not part of the image.
          if (imageCol >= width) continue;
          final v = d.getFloat32(base + (r * tileW + c) * 4, Endian.little);
          image[imageRow * width + imageCol] = _isNoData(v)
              ? null
              : -v; // elevation -> depth
        }
      }
    }

    // Flip to south-first.
    final depths = List<double?>.filled(width * height, null);
    for (var r = 0; r < height; r++) {
      depths.setRange(
        r * width,
        r * width + width,
        image,
        (height - 1 - r) * width,
      );
    }

    // The requested box spans cell EDGES; the grid origin is a cell CENTER.
    final cellLon = (eastLon - westLon) / width;
    final cellLat = (northLat - southLat) / height;
    return BathymetryGrid(
      originLat: southLat + cellLat / 2,
      originLon: westLon + cellLon / 2,
      cellSizeLatDeg: cellLat,
      cellSizeLonDeg: cellLon,
      rows: height,
      cols: width,
      depthsMeters: depths,
      sourceId: sourceId,
      resolutionMeters: resolutionMeters,
      fetchedAt: fetchedAt,
    );
  }

  static Map<int, ({int type, int count, int value})> _readIfd(
    ByteData d,
    int length,
  ) {
    final ifd = d.getUint32(4, Endian.little);
    if (ifd + 2 > length) {
      throw const FormatException('TIFF directory offset is out of range');
    }
    final entryCount = d.getUint16(ifd, Endian.little);
    if (ifd + 2 + entryCount * 12 > length) {
      throw const FormatException('TIFF directory runs past the body');
    }
    final tags = <int, ({int type, int count, int value})>{};
    for (var i = 0; i < entryCount; i++) {
      final e = ifd + 2 + i * 12;
      final tag = d.getUint16(e, Endian.little);
      final type = d.getUint16(e + 2, Endian.little);
      final count = d.getUint32(e + 4, Endian.little);
      // A SHORT with count 1 sits in the low half of the value field.
      final value = type == 3 && count == 1
          ? d.getUint16(e + 8, Endian.little)
          : d.getUint32(e + 8, Endian.little);
      tags[tag] = (type: type, count: count, value: value);
    }
    return tags;
  }

  static bool _isNoData(double v) => v.isNaN || v < _noDataCeiling;

  static List<int> _longs(
    ByteData d,
    ({int type, int count, int value})? tag,
    String what,
    int length,
  ) {
    if (tag == null) throw FormatException('TIFF is missing $what');
    // The element width is implied by the field type, so reading a SHORT
    // array at LONG width walks the wrong bytes and yields offsets that
    // can still land inside the body: the tiles then decode into
    // plausible-looking nonsense rather than failing. BigTIFF's LONG8 is
    // already excluded by the magic-number check, but an out-of-spec
    // classic TIFF could still declare it, so the type is pinned here
    // rather than assumed.
    if (tag.type != _fieldTypeLong) {
      throw FormatException(
        '$what has TIFF field type ${tag.type}; only LONG '
        '($_fieldTypeLong) is supported',
      );
    }
    if (tag.count < 1) {
      throw FormatException('$what has no entries');
    }
    if (tag.count == 1) return [tag.value];
    if (tag.value + tag.count * 4 > length) {
      throw FormatException('$what array runs past the body');
    }
    return [
      for (var i = 0; i < tag.count; i++)
        d.getUint32(tag.value + i * 4, Endian.little),
    ];
  }
}
