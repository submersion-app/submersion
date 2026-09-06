import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/sources/arcgis_float32_tiff_parser.dart';

/// Builds a minimal little-endian tiled float32 TIFF matching the shape the
/// NOAA ImageServer returns, so these tests pin the real wire format without
/// carrying a 66 KB binary fixture.
Uint8List buildTiff({
  required int width,
  required int height,
  required int tileSize,
  required List<double> tilePixels, // tileSize * tileSize per tile, row-major
  int compression = 1,
  int bitsPerSample = 32,
  int? sampleFormat = 3, // 3 = IEEE float; null omits the tag entirely
  int? tileByteCountOverride,
}) {
  final tilesAcross = (width + tileSize - 1) ~/ tileSize;
  final tilesDown = (height + tileSize - 1) ~/ tileSize;
  final tileCount = tilesAcross * tilesDown;
  final tileBytes = tileSize * tileSize * 4;

  final entries = sampleFormat == null ? 9 : 10;
  const headerLen = 8;
  final ifdLen = 2 + entries * 12 + 4;
  // Tile offset and byte-count arrays live after the IFD when there is more
  // than one tile; a single LONG fits inline in the entry's value field.
  final arraysLen = tileCount > 1 ? tileCount * 4 * 2 : 0;
  final pixelStart = headerLen + ifdLen + arraysLen;

  final out = BytesBuilder();
  final head = ByteData(headerLen);
  head.setUint8(0, 0x49);
  head.setUint8(1, 0x49);
  head.setUint16(2, 42, Endian.little);
  head.setUint32(4, headerLen, Endian.little);
  out.add(head.buffer.asUint8List());

  final ifd = ByteData(ifdLen);
  ifd.setUint16(0, entries, Endian.little);
  var e = 2;
  void entry(int tag, int type, int count, int value) {
    ifd.setUint16(e, tag, Endian.little);
    ifd.setUint16(e + 2, type, Endian.little);
    ifd.setUint32(e + 4, count, Endian.little);
    if (type == 3 && count == 1) {
      ifd.setUint16(e + 8, value, Endian.little);
      ifd.setUint16(e + 10, 0, Endian.little);
    } else {
      ifd.setUint32(e + 8, value, Endian.little);
    }
    e += 12;
  }

  final offsetsAt = headerLen + ifdLen;
  final countsAt = offsetsAt + tileCount * 4;
  entry(256, 3, 1, width); // ImageWidth
  entry(257, 3, 1, height); // ImageLength
  entry(258, 3, 1, bitsPerSample); // BitsPerSample
  entry(259, 3, 1, compression); // Compression
  entry(277, 3, 1, 1); // SamplesPerPixel
  entry(322, 3, 1, tileSize); // TileWidth
  entry(323, 3, 1, tileSize); // TileLength
  entry(324, 4, tileCount, tileCount == 1 ? pixelStart : offsetsAt);
  entry(
    325,
    4,
    tileCount,
    tileCount == 1 ? (tileByteCountOverride ?? tileBytes) : countsAt,
  );
  if (sampleFormat != null) {
    entry(339, 3, 1, sampleFormat); // 1 = uint, 2 = int, 3 = IEEE float
  }
  ifd.setUint32(ifdLen - 4, 0, Endian.little); // next IFD = none
  out.add(ifd.buffer.asUint8List());

  if (tileCount > 1) {
    final arrays = ByteData(arraysLen);
    for (var i = 0; i < tileCount; i++) {
      arrays.setUint32(i * 4, pixelStart + i * tileBytes, Endian.little);
      arrays.setUint32(
        tileCount * 4 + i * 4,
        tileByteCountOverride ?? tileBytes,
        Endian.little,
      );
    }
    out.add(arrays.buffer.asUint8List());
  }

  final pixels = ByteData(tileCount * tileBytes);
  for (var i = 0; i < tilePixels.length; i++) {
    pixels.setFloat32(i * 4, tilePixels[i], Endian.little);
  }
  out.add(pixels.buffer.asUint8List());
  return out.toBytes();
}

void main() {
  final when = DateTime.utc(2026, 9, 5);

  test('reads a single-tile image, flips rows south-first and negates', () {
    // 2x2 image inside a 4x4 tile. Image row 0 is NORTHERNMOST.
    final tile = List<double>.filled(16, 0);
    tile[0] = -10.0; // north-west
    tile[1] = -20.0; // north-east
    tile[4] = -30.0; // south-west
    tile[5] = -40.0; // south-east

    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(width: 2, height: 2, tileSize: 4, tilePixels: tile),
      westLon: -80.4,
      eastLon: -80.2,
      southLat: 25.0,
      northLat: 25.2,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );

    expect(g.rows, 2);
    expect(g.cols, 2);
    // Grid row 0 is SOUTHERNMOST, and elevation negates into depth.
    expect(g.depthAt(0, 0), closeTo(30.0, 1e-6));
    expect(g.depthAt(0, 1), closeTo(40.0, 1e-6));
    expect(g.depthAt(1, 0), closeTo(10.0, 1e-6));
    expect(g.depthAt(1, 1), closeTo(20.0, 1e-6));
    expect(g.sourceId, 'noaa_dem');
    expect(g.resolutionMeters, 8);
    expect(g.fetchedAt, when);
  });

  test('land above the waterline becomes a negative depth', () {
    final tile = List<double>.filled(16, 4.0); // 4 m above sea level
    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(width: 2, height: 2, tileSize: 4, tilePixels: tile),
      westLon: 0,
      eastLon: 1,
      southLat: 0,
      northLat: 1,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );
    expect(g.depthAt(0, 0), closeTo(-4.0, 1e-6));
    expect(g.wetFraction, 0.0);
  });

  test('origin is the south-west CELL CENTER and cell sizes span the box', () {
    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(
        width: 2,
        height: 2,
        tileSize: 4,
        tilePixels: List<double>.filled(16, -5.0),
      ),
      westLon: -80.4,
      eastLon: -80.2,
      southLat: 25.0,
      northLat: 25.2,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );
    // 2 columns across a 0.2 degree box: cell width 0.1, first center half
    // a cell in from the western edge.
    expect(g.cellSizeLonDeg, closeTo(0.1, 1e-9));
    expect(g.cellSizeLatDeg, closeTo(0.1, 1e-9));
    expect(g.originLon, closeTo(-80.35, 1e-9));
    expect(g.originLat, closeTo(25.05, 1e-9));
  });

  test('assembles a multi-tile image in row-major tile order', () {
    // 4x4 image as four 2x2 tiles, each filled with its own value so a
    // misplaced tile is obvious.
    final pixels = <double>[
      -1, -1, -1, -1, // tile 0 (north-west)
      -2, -2, -2, -2, // tile 1 (north-east)
      -3, -3, -3, -3, // tile 2 (south-west)
      -4, -4, -4, -4, // tile 3 (south-east)
    ];
    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(width: 4, height: 4, tileSize: 2, tilePixels: pixels),
      westLon: 0,
      eastLon: 1,
      southLat: 0,
      northLat: 1,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );
    // After the south-first flip, grid row 0 is the image's LAST row.
    expect(g.depthAt(0, 0), closeTo(3.0, 1e-6));
    expect(g.depthAt(0, 3), closeTo(4.0, 1e-6));
    expect(g.depthAt(3, 0), closeTo(1.0, 1e-6));
    expect(g.depthAt(3, 3), closeTo(2.0, 1e-6));
  });

  test('ignores tile padding outside the image bounds', () {
    // A 3x3 image in 2x2 tiles: the right and bottom tiles are half padding.
    final pixels = <double>[
      -1, -1, -1, -1, //
      -2, -2, -2, -2, //
      -3, -3, -3, -3, //
      -4, -4, -4, -4, //
    ];
    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(width: 3, height: 3, tileSize: 2, tilePixels: pixels),
      westLon: 0,
      eastLon: 1,
      southLat: 0,
      northLat: 1,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );
    expect(g.rows, 3);
    expect(g.cols, 3);
    expect(g.depthsMeters.length, 9);
    expect(g.depthsMeters.whereType<double>().length, 9);
  });

  test('maps the ArcGIS nodata sentinel to null', () {
    final tile = List<double>.filled(16, -5.0);
    tile[0] = -3.4028234663852886e38; // float32 lowest, ArcGIS NoData
    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(width: 2, height: 2, tileSize: 4, tilePixels: tile),
      westLon: 0,
      eastLon: 1,
      southLat: 0,
      northLat: 1,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );
    // Image (0,0) is the northernmost row, which flips to grid row 1.
    expect(g.depthAt(1, 0), isNull);
    expect(g.depthAt(0, 0), closeTo(5.0, 1e-6));
  });

  test('a genuinely deep reading is not mistaken for nodata', () {
    // The Challenger Deep is about 10935 m; the sentinel is 1e38 away.
    final tile = List<double>.filled(16, -10935.0);
    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(width: 2, height: 2, tileSize: 4, tilePixels: tile),
      westLon: 0,
      eastLon: 1,
      southLat: 0,
      northLat: 1,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );
    expect(g.depthAt(0, 0), closeTo(10935.0, 1e-3));
  });

  test('throws FormatException on a compressed TIFF', () {
    expect(
      () => ArcgisFloat32TiffParser.parse(
        buildTiff(
          width: 2,
          height: 2,
          tileSize: 4,
          tilePixels: List<double>.filled(16, -5.0),
          compression: 5,
        ),
        westLon: 0,
        eastLon: 1,
        southLat: 0,
        northLat: 1,
        sourceId: 'noaa_dem',
        resolutionMeters: 8,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });

  test('throws FormatException on a non-float sample depth', () {
    expect(
      () => ArcgisFloat32TiffParser.parse(
        buildTiff(
          width: 2,
          height: 2,
          tileSize: 4,
          tilePixels: List<double>.filled(16, -5.0),
          bitsPerSample: 16,
        ),
        westLon: 0,
        eastLon: 1,
        southLat: 0,
        northLat: 1,
        sourceId: 'noaa_dem',
        resolutionMeters: 8,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });

  test('throws FormatException on a non-TIFF body', () {
    // ArcGIS returns error envelopes with HTTP 200, so this is the shape a
    // failed request actually arrives in.
    expect(
      () => ArcgisFloat32TiffParser.parse(
        Uint8List.fromList('{"error":{"code":400}}'.codeUnits),
        westLon: 0,
        eastLon: 1,
        southLat: 0,
        northLat: 1,
        sourceId: 'noaa_dem',
        resolutionMeters: 8,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });

  test('throws FormatException when a tile runs past the end of the body', () {
    final bytes = buildTiff(
      width: 2,
      height: 2,
      tileSize: 4,
      tilePixels: List<double>.filled(16, -5.0),
    );
    expect(
      () => ArcgisFloat32TiffParser.parse(
        bytes.sublist(0, bytes.length - 8), // truncated response
        westLon: 0,
        eastLon: 1,
        southLat: 0,
        northLat: 1,
        sourceId: 'noaa_dem',
        resolutionMeters: 8,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });

  group('format strictness (the throw-on-anything-unexpected contract)', () {
    Uint8List variant({int? sampleFormat = 3, int? tileByteCountOverride}) =>
        buildTiff(
          width: 2,
          height: 2,
          tileSize: 4,
          tilePixels: List<double>.filled(16, -5.0),
          sampleFormat: sampleFormat,
          tileByteCountOverride: tileByteCountOverride,
        );

    void expectRejected(Uint8List bytes) {
      expect(
        () => ArcgisFloat32TiffParser.parse(
          bytes,
          westLon: 0,
          eastLon: 1,
          southLat: 0,
          northLat: 1,
          sourceId: 'noaa_dem',
          resolutionMeters: 8,
          fetchedAt: DateTime.utc(2026, 9, 5),
        ),
        throwsFormatException,
      );
    }

    test('rejects unsigned integer samples', () {
      // 32-bit ints read as float32 do not crash: they yield denormals near
      // zero for small values and huge magnitudes for large ones, all
      // non-null, so every downstream quality floor passes and the garbage
      // renders as terrain. Failing fast falls through to the next source.
      expectRejected(variant(sampleFormat: 1));
    });

    test('rejects signed integer samples', () {
      expectRejected(variant(sampleFormat: 2));
    });

    test('rejects a TIFF with no SampleFormat tag', () {
      // The TIFF default when the tag is absent is unsigned integer, not
      // float, so an untagged raster must not be assumed to be float.
      expectRejected(variant(sampleFormat: null));
    });

    test('accepts IEEE float samples', () {
      final g = ArcgisFloat32TiffParser.parse(
        variant(),
        westLon: 0,
        eastLon: 1,
        southLat: 0,
        northLat: 1,
        sourceId: 'noaa_dem',
        resolutionMeters: 8,
        fetchedAt: DateTime.utc(2026, 9, 5),
      );
      expect(g.depthAt(0, 0), closeTo(5.0, 1e-6));
    });

    test('rejects a tile byte count that disagrees with the tile size', () {
      // A short count means the tile is not the plain uncompressed block
      // this parser assumes, whatever the Compression tag claims.
      // A 4x4 float32 tile is 64 bytes; claim half that.
      expectRejected(variant(tileByteCountOverride: 32));
    });

    test('rejects a multi-tile image whose byte counts disagree', () {
      expectRejected(
        buildTiff(
          width: 4,
          height: 4,
          tileSize: 2,
          tilePixels: List<double>.filled(16, -5.0),
          tileByteCountOverride: 8,
        ),
      );
    });

    test('rejects a TIFF with no TileOffsets tag', () {
      // Rewrite the TileOffsets tag id to an unused one so the tag is
      // absent. Entries start at byte 10 and run 12 bytes each; TileOffsets
      // is the eighth, at 10 + 7 * 12.
      final bytes = variant();
      const tileOffsetsEntry = 10 + 7 * 12;
      ByteData.sublistView(
        bytes,
      ).setUint16(tileOffsetsEntry, 700, Endian.little);
      expectRejected(bytes);
    });

    test('rejects a tile offset array pointing past the body', () {
      // Four tiles, so TileOffsets is a real array rather than an inline
      // value, and the array pointer is then out of range.
      final bytes = buildTiff(
        width: 4,
        height: 4,
        tileSize: 2,
        tilePixels: List<double>.filled(16, -5.0),
      );
      const tileOffsetsValue = 10 + 7 * 12 + 8;
      ByteData.sublistView(
        bytes,
      ).setUint32(tileOffsetsValue, 0x0FFFFFF0, Endian.little);
      expectRejected(bytes);
    });

    test('rejects TileOffsets declared as SHORT rather than LONG', () {
      // A SHORT array has 2-byte elements. Reading it as 4-byte LONGs
      // yields garbage offsets that still land inside the body, so without
      // a type check the tiles decode into plausible-looking nonsense.
      // Entry layout is tag(2) type(2) count(4) value(4).
      final bytes = buildTiff(
        width: 4,
        height: 4,
        tileSize: 2,
        tilePixels: List<double>.filled(16, -5.0),
      );
      const typeField = 10 + 7 * 12 + 2;
      ByteData.sublistView(bytes).setUint16(typeField, 3, Endian.little);
      expectRejected(bytes);
    });

    test('rejects TileOffsets declared as LONG8', () {
      final bytes = buildTiff(
        width: 4,
        height: 4,
        tileSize: 2,
        tilePixels: List<double>.filled(16, -5.0),
      );
      const typeField = 10 + 7 * 12 + 2;
      ByteData.sublistView(bytes).setUint16(typeField, 16, Endian.little);
      expectRejected(bytes);
    });

    test('rejects TileByteCounts declared with an unexpected type', () {
      final bytes = buildTiff(
        width: 4,
        height: 4,
        tileSize: 2,
        tilePixels: List<double>.filled(16, -5.0),
      );
      const typeField = 10 + 8 * 12 + 2;
      ByteData.sublistView(bytes).setUint16(typeField, 3, Endian.little);
      expectRejected(bytes);
    });

    test('rejects a TileOffsets count of zero', () {
      final bytes = variant();
      const countField = 10 + 7 * 12 + 4;
      ByteData.sublistView(bytes).setUint32(countField, 0, Endian.little);
      expectRejected(bytes);
    });
  });
}
