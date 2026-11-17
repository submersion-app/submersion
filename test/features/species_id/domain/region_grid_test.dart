import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/domain/services/region_grid.dart';

/// The vectors the pack builder's Python grid writes. Both sides must agree
/// on every one, or the app would filter against the wrong region.
Map<String, Object?> _vectors() {
  final file = File(
    p.join('tool', 'species_pack', 'testdata', 'region_vectors.json'),
  );
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Uint8List _hex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

void main() {
  final vectors = _vectors();
  final grid = RegionGrid(cellDegrees: vectors['cellDegrees']! as int);

  test('the grid size matches the pack builder', () {
    expect(grid.columns, vectors['columns']);
    expect(grid.rows, vectors['rows']);
    expect(grid.cellCount, grid.columns * grid.rows);
  });

  test('every cellOf vector matches', () {
    for (final raw in vectors['cellOf']! as List) {
      final v = (raw as Map).cast<String, Object?>();
      expect(
        grid.cellOf(
          (v['lat']! as num).toDouble(),
          (v['lon']! as num).toDouble(),
        ),
        v['cell'],
        reason: 'lat ${v['lat']} lon ${v['lon']}',
      );
    }
  });

  test('every neighbourhood vector matches', () {
    for (final raw in vectors['neighbourhood']! as List) {
      final v = (raw as Map).cast<String, Object?>();
      expect(
        grid.neighbourhood(v['cell']! as int, rings: v['rings']! as int),
        (v['cells']! as List).cast<int>().toSet(),
        reason: 'cell ${v['cell']}',
      );
    }
  });

  test('a cell on the longitude seam has nine neighbours, wrapping', () {
    final seam = grid.cellOf(12.1, -179);
    final cells = grid.neighbourhood(seam, rings: 1);
    expect(cells, hasLength(9));
    expect(cells, contains(grid.cellOf(12.1, 179)));
  });

  test('a cell in the top row has six neighbours, all in range', () {
    final top = grid.cellOf(89, 10);
    final cells = grid.neighbourhood(top, rings: 1);
    expect(cells, hasLength(6));
    for (final c in cells) {
      expect(c, inInclusiveRange(0, grid.cellCount - 1));
    }
  });

  test('latitude past a pole clamps instead of leaving the grid', () {
    expect(grid.cellOf(-95, 0), grid.cellOf(-90, 0));
    expect(grid.cellOf(95, 0), grid.cellOf(90, 0));
  });

  test('the region table reads the packed bits', () {
    final packed = (vectors['packBits']! as Map).cast<String, Object?>();
    final rows = [
      for (final r in packed['rows']! as List) (r as List).cast<int>().toSet(),
    ];
    final table = RegionTable(
      grid: grid,
      bits: _hex(packed['hex']! as String),
      candidateCount: rows.length,
    );

    for (var i = 0; i < rows.length; i++) {
      for (var c = 0; c < grid.cellCount; c++) {
        expect(
          table.recorded(i, c),
          rows[i].contains(c),
          reason: 'row $i cell $c',
        );
      }
    }
    expect(table.allowedMask({0}), [true, false, false]);
    expect(table.allowedMask({grid.cellCount - 1}), [false, false, true]);
    expect(table.allowedMask({1, 2}), [false, false, false]);
  });

  test('a table whose bytes do not fit the candidates is refused', () {
    expect(
      () => RegionTable(grid: grid, bits: Uint8List(10), candidateCount: 1),
      throwsArgumentError,
    );
  });
}
