import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_grid_codec.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

BathymetryGrid _grid({
  int rows = 3,
  int cols = 4,
  List<double?>? depths,
  String sourceId = 'swissbathy3d',
  DateTime? fetchedAt,
}) => BathymetryGrid(
  originLat: 46.123456789012,
  originLon: -68.987654321098,
  cellSizeLatDeg: 0.0000179,
  cellSizeLonDeg: -0.0000261,
  rows: rows,
  cols: cols,
  depthsMeters:
      depths ??
      [
        for (var i = 0; i < rows * cols; i++)
          i % 5 == 0 ? null : 12.3456789 * i - 7.1,
      ],
  sourceId: sourceId,
  resolutionMeters: 2.0000000001,
  fetchedAt: fetchedAt ?? DateTime.utc(2026, 11, 7, 10, 11, 12, 345, 678),
);

/// Same terrain shape the issue's probe used: smooth relief with noise and a
/// block of no-data cells.
BathymetryGrid _terrain(int n) {
  final random = math.Random(7);
  return _grid(
    rows: n,
    cols: n,
    depths: [
      for (var r = 0; r < n; r++)
        for (var c = 0; c < n; c++)
          r < n ~/ 10 && c < n ~/ 6
              ? null
              : 20 +
                    30 * math.sin(r / 37) * math.cos(c / 23) +
                    random.nextDouble() * 0.5,
    ],
  );
}

void _expectSameGrid(BathymetryGrid actual, BathymetryGrid expected) {
  expect(actual.originLat, expected.originLat);
  expect(actual.originLon, expected.originLon);
  expect(actual.cellSizeLatDeg, expected.cellSizeLatDeg);
  expect(actual.cellSizeLonDeg, expected.cellSizeLonDeg);
  expect(actual.rows, expected.rows);
  expect(actual.cols, expected.cols);
  expect(actual.depthsMeters, expected.depthsMeters);
  expect(actual.sourceId, expected.sourceId);
  expect(actual.resolutionMeters, expected.resolutionMeters);
  expect(actual.fetchedAt, expected.fetchedAt);
  expect(actual.fetchedAt.isUtc, isTrue);
}

void main() {
  group('BathymetryGridCodec', () {
    test('round trips every field and every depth exactly', () {
      final grid = _grid();
      _expectSameGrid(
        BathymetryGridCodec.decode(BathymetryGridCodec.encode(grid)),
        grid,
      );
    });

    test('keeps no-data cells as null, never as a reading', () {
      final grid = _grid(rows: 1, cols: 4, depths: const [null, 0, -3.5, null]);
      final decoded = BathymetryGridCodec.decode(
        BathymetryGridCodec.encode(grid),
      );
      expect(decoded.depthsMeters, const [null, 0.0, -3.5, null]);
    });

    test('keeps negative zero and extreme magnitudes bit for bit', () {
      final grid = _grid(
        rows: 1,
        cols: 3,
        depths: const [-0.0, double.maxFinite, double.minPositive],
      );
      final decoded = BathymetryGridCodec.decode(
        BathymetryGridCodec.encode(grid),
      );
      expect(decoded.depthsMeters[0]!.isNegative, isTrue);
      expect(decoded.depthsMeters.sublist(1), grid.depthsMeters.sublist(1));
    });

    test('reads a local fetch time back as the same instant in UTC', () {
      final local = DateTime(2026, 3, 4, 5, 6, 7, 8, 9);
      final decoded = BathymetryGridCodec.decode(
        BathymetryGridCodec.encode(_grid(fetchedAt: local)),
      );
      expect(decoded.fetchedAt, local.toUtc());
      expect(decoded.fetchedAt.isUtc, isTrue);
    });

    test('keeps a non-ASCII source id', () {
      final grid = _grid(sourceId: 'quelle-zürich');
      expect(
        BathymetryGridCodec.decode(BathymetryGridCodec.encode(grid)).sourceId,
        'quelle-zürich',
      );
    });

    test('decodes exactly what the JSON form decoded', () {
      final grid = _terrain(120);
      final viaJson = BathymetryGrid.fromJson(
        jsonDecode(jsonEncode(grid.toJson())) as Map<String, dynamic>,
      );
      _expectSameGrid(
        BathymetryGridCodec.decode(BathymetryGridCodec.encode(grid)),
        viaJson,
      );
    });

    test('stores a base square in well under half the JSON bytes', () {
      final grid = _terrain(120);
      final json = utf8.encode(jsonEncode(grid.toJson())).length;
      final blob = BathymetryGridCodec.encode(grid).length;
      expect(blob, lessThan(json ~/ 2));
    });

    test('recognises its own blobs and nothing else', () {
      expect(
        BathymetryGridCodec.isEncoded(BathymetryGridCodec.encode(_grid())),
        isTrue,
      );
      expect(BathymetryGridCodec.isEncoded(utf8.encode('{"rows":1}')), isFalse);
      expect(BathymetryGridCodec.isEncoded(Uint8List(0)), isFalse);
    });

    group('refuses malformed input with a FormatException', () {
      test('wrong magic', () {
        final blob = BathymetryGridCodec.encode(_grid());
        blob[0] = 0;
        expect(
          () => BathymetryGridCodec.decode(blob),
          throwsA(isA<FormatException>()),
        );
      });

      test('shorter than the magic', () {
        expect(
          () => BathymetryGridCodec.decode(Uint8List.fromList([0x53])),
          throwsA(isA<FormatException>()),
        );
      });

      test('a body that is not a deflate stream', () {
        final blob = BathymetryGridCodec.encode(_grid());
        final broken = Uint8List.fromList([
          ...blob.sublist(0, 4),
          ...List.filled(32, 0xFF),
        ]);
        expect(
          () => BathymetryGridCodec.decode(broken),
          throwsA(isA<FormatException>()),
        );
      });

      test('a truncated body', () {
        final blob = BathymetryGridCodec.encode(_terrain(40));
        expect(
          () => BathymetryGridCodec.decode(blob.sublist(0, blob.length ~/ 2)),
          throwsA(isA<FormatException>()),
        );
      });
    });

    test('refuses a grid whose cell count does not match its shape', () {
      final grid = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 1,
        cellSizeLonDeg: 1,
        rows: 2,
        cols: 2,
        depthsMeters: const [1, 2, 3],
        sourceId: 's',
        resolutionMeters: 1,
        fetchedAt: DateTime.utc(2026),
      );
      expect(
        () => BathymetryGridCodec.encode(grid),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('refuses a dimension too large for its header field', () {
      final grid = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 1,
        cellSizeLonDeg: 1,
        rows: BathymetryGridCodec.maxCells + 1,
        cols: 0,
        depthsMeters: const [],
        sourceId: 's',
        resolutionMeters: 1,
        fetchedAt: DateTime.utc(2026),
      );
      expect(
        () => BathymetryGridCodec.encode(grid),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
