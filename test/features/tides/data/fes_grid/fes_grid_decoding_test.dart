import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_layers.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_manifest.dart';

final _root = p.join(
  'test',
  'features',
  'tides',
  'data',
  'fixtures',
  'fes_grid',
);

ByteData _bytes(String relative) {
  final list = File(p.join(_root, relative)).readAsBytesSync();
  return ByteData.sublistView(list);
}

void main() {
  late FesGridManifest manifest;

  setUpAll(() {
    manifest = FesGridManifest.parse(
      File(p.join(_root, FesGridManifest.manifestPath)).readAsStringSync(),
    );
  });

  test('manifest describes both layers and the written tiles', () {
    expect(manifest.constituents, ['M2', 'K1']);
    expect(manifest.coastal.resolution, 0.5);
    expect(manifest.coastal.cols, 720);
    expect(manifest.tileSize, 4);
    expect(manifest.coastalTiles, {(0, 0), (1, 0), (0, 179), (1, 179)});
    expect(manifest.global.rows, 5);
    expect(manifest.global.resolutionKm, closeTo(555.975, 0.01));
  });

  test('a manifest of another format is rejected', () {
    expect(
      () => FesGridManifest.parse('{"format":"other","version":1}'),
      throwsFormatException,
    );
    expect(() => FesGridManifest.parse('not json'), throwsFormatException);
  });

  group('FesTile', () {
    late FesTile tile;

    setUp(() {
      tile = FesTile.parse(
        _bytes(FesGridManifest.tilePath(0, 0)),
        expectedConstituents: 2,
      );
    });

    test('reads present cells and their values', () {
      final cell = tile.cellAt(1, 2)!;
      expect(cell.amplitudeMeters(0), closeTo(1.102, 1e-9));
      expect(cell.phaseDegrees(0), closeTo((37 + 22) % 360, 1e-9));
      expect(cell.amplitudeMeters(1), closeTo(0.1, 1e-9));
      expect(cell.phaseDegrees(1), closeTo(350, 1e-9));
    });

    test('absent cells, an empty row and out-of-range cells are null', () {
      expect(tile.cellAt(0, 2), isNull);
      expect(tile.cellAt(1, 0), isNull);
      for (var col = 0; col < 4; col++) {
        expect(tile.cellAt(2, col), isNull);
      }
      expect(tile.cellAt(4, 0), isNull);
      expect(tile.cellAt(-1, 0), isNull);
    });

    test('a constituent can be missing in a present cell', () {
      final cell = tile.cellAt(3, 3)!;
      expect(cell.amplitudeMeters(0), closeTo(1.303, 1e-9));
      expect(cell.amplitudeMeters(1), isNull);
    });

    test('the last cell of a partial edge tile is readable', () {
      final edge = FesTile.parse(
        _bytes(FesGridManifest.tilePath(1, 179)),
        expectedConstituents: 2,
      );
      expect(edge.rows, 1);
      expect(edge.cols, 4);
      expect(edge.cellAt(0, 3)!.amplitudeMeters(0), closeTo(1.4 + 0.719, 1e-9));
    });

    test('malformed bytes are rejected', () {
      expect(
        () => FesTile.parse(ByteData(8), expectedConstituents: 2),
        throwsFormatException,
      );
      final truncated = _bytes(FesGridManifest.tilePath(0, 0));
      expect(
        () => FesTile.parse(
          ByteData.sublistView(truncated, 0, truncated.lengthInBytes - 1),
          expectedConstituents: 2,
        ),
        throwsFormatException,
      );
      expect(
        () => FesTile.parse(
          _bytes(FesGridManifest.tilePath(0, 0)),
          expectedConstituents: 3,
        ),
        throwsFormatException,
      );
    });
  });

  group('FesGlobalLayer', () {
    late FesGlobalLayer layer;

    setUp(() {
      layer = FesGlobalLayer.parse(
        _bytes(FesGridManifest.globalPath),
        expectedConstituents: 2,
      );
    });

    test('reads cells and treats a no-data cell as absent', () {
      expect(layer.cellAt(2, 3)!.amplitudeMeters(0), closeTo(2.023, 1e-9));
      expect(layer.cellAt(2, 3)!.phaseDegrees(0), closeTo(90, 1e-9));
      expect(layer.cellAt(0, 0), isNull);
      expect(layer.cellAt(5, 0), isNull);
    });

    test('malformed bytes are rejected', () {
      expect(
        () => FesGlobalLayer.parse(ByteData(12), expectedConstituents: 2),
        throwsFormatException,
      );
    });
  });
}
