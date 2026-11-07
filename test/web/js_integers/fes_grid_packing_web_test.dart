@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_layers.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_packing.dart';

/// The bundled tide grid unpacked in JavaScript, where the bitwise operators
/// work on 32 bits and hand back unsigned results: a zigzag decode written
/// as `(z >> 1) ^ -(z & 1)` turns every negative delta into about 2^32. The
/// amplitudes survived that by luck (they wrap at 65536), but every phase
/// after a falling one landed 232.96 degrees off. The VM suite in
/// test/features/tides/data/fes_grid/ cannot see it.
///
/// The files are packed here, in arithmetic that means the same on both
/// platforms, so the test needs no bundled asset.

/// A signed delta folded into a uint16: 0, -1, 1, -2, ... as 0, 1, 2, 3.
int _zigzag(int delta) => delta >= 0 ? 2 * delta : -2 * delta - 1;

/// The packed planes for [amplitudes] and [phases], one constituent per
/// cell: zigzag deltas from the previous cell, low bytes then high bytes.
List<int> _planes(List<int> amplitudes, List<int> phases) {
  final values = <int>[];
  for (final (plane, modulus) in [(amplitudes, 65536), (phases, 36000)]) {
    var previous = 0;
    for (final value in plane) {
      var delta = (value - previous) % modulus;
      if (delta >= modulus ~/ 2) delta -= modulus;
      values.add(_zigzag(delta));
      previous = value;
    }
  }
  return [for (final v in values) v % 256, for (final v in values) v ~/ 256];
}

List<int> _uint16(int value) => [value % 256, value ~/ 256];

ByteData _file(String magic, List<int> header, List<int> body) =>
    ByteData.sublistView(
      Uint8List.fromList([
        ...magic.codeUnits,
        ..._uint16(2),
        ...header,
        ...PlatformZlib.deflate(body),
      ]),
    );

void main() {
  // Each phase falls from the one before it; 359.90 degrees is a fall of
  // 1.04 degrees across 360.
  const amplitudes = [1000, 994, 1010];
  const phases = [100, 94, 35990];

  test('a global layer keeps phases that fall from cell to cell', () async {
    final layer = FesGlobalLayer.parse(
      await unpackFesGlobalLayer(
        _file('SFG2', [
          ..._uint16(1),
          ..._uint16(3),
          ..._uint16(1),
        ], _planes(amplitudes, phases)),
      ),
      expectedConstituents: 1,
    );

    for (var col = 0; col < 3; col++) {
      final cell = layer.cellAt(0, col)!;
      expect(cell.amplitudeMeters(0), closeTo(amplitudes[col] / 1000, 1e-9));
      expect(cell.phaseDegrees(0), closeTo(phases[col] / 100, 1e-9));
    }
  });

  test('a coastal tile keeps phases that fall from cell to cell', () async {
    // One row of three cells, the first and last present (bitmap 0b101).
    final tile = FesTile.parse(
      await unpackFesTile(
        _file(
          'SFT2',
          [
            ..._uint16(0),
            ..._uint16(0),
            ..._uint16(1),
            ..._uint16(3),
            ..._uint16(1),
          ],
          [
            0x05,
            ..._planes([1000, 994], [100, 35990]),
          ],
        ),
      ),
      expectedConstituents: 1,
    );

    expect(tile.cellAt(0, 1), isNull);
    expect(tile.cellAt(0, 0)!.phaseDegrees(0), closeTo(1.00, 1e-9));
    expect(tile.cellAt(0, 2)!.amplitudeMeters(0), closeTo(0.994, 1e-9));
    expect(tile.cellAt(0, 2)!.phaseDegrees(0), closeTo(359.90, 1e-9));
  });
}
