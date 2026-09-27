import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_reader.dart';

final _root = p.join(
  'test',
  'features',
  'tides',
  'data',
  'fixtures',
  'fes_grid',
);

Future<ByteData> _fileLoader(String relative) async =>
    ByteData.sublistView(File(p.join(_root, relative)).readAsBytesSync());

FesGridReader _reader({Map<String, ByteData Function()> replace = const {}}) {
  return FesGridReader(
    load: (relative) async {
      final replacement = replace[relative];
      if (replacement != null) return replacement();
      return _fileLoader(relative);
    },
  );
}

void main() {
  test('a grid node returns that cell (coastal resolution)', () async {
    final sample = await _reader().sampleAt(10.0, -180.0);
    expect(sample!.resolutionKm, closeTo(55.6, 0.1));
    expect(sample.constituents['M2']!.amplitude, closeTo(1.0, 1e-6));
    expect(sample.constituents['M2']!.phase, closeTo(0.0, 1e-6));
  });

  test('phases interpolate across the 0/360 wrap', () async {
    // Halfway between (0,0) K1 350 deg and (0,1) K1 10 deg.
    final k1 = (await _reader().sampleAt(10.0, -179.75))!.constituents['K1']!;
    expect(k1.phase % 360, anyOf(closeTo(0, 0.01), closeTo(360, 0.01)));
    expect(k1.amplitude, closeTo(0.1 * 0.98481, 1e-4));
  });

  test('opposed phases cancel in the complex plane', () async {
    // Row 3: col 0 at 0 deg and col 1 at 180 deg, amplitudes 1.300/1.301 m.
    final m2 = (await _reader().sampleAt(11.5, -179.75))!.constituents['M2']!;
    expect(m2.amplitude, lessThan(0.001));
  });

  test('missing corners are dropped and weights renormalized', () async {
    // Cell (1,0) is absent; the three present corners average equally.
    final sample = await _reader().sampleAt(10.25, -179.75);
    expect(sample!.resolutionKm, closeTo(55.6, 0.1));
    expect(sample.constituents['M2'], isNotNull);
  });

  test('a node without data resolves from its present neighbours', () async {
    // (1,0) is absent; its neighbour (1,1) is present with a tiny weight.
    final sample = await _reader().sampleAt(10.5, -180.0);
    expect(sample, isNotNull);
    expect(sample!.resolutionKm, closeTo(55.6, 0.1));
  });

  test(
    'a constituent missing at the only weighted corner is omitted',
    () async {
      final sample = await _reader().sampleAt(11.5, -178.5);
      expect(sample!.constituents.containsKey('M2'), isTrue);
      expect(sample.constituents.containsKey('K1'), isFalse);
    },
  );

  test('columns wrap across the antimeridian', () async {
    final sample = await _reader().sampleAt(10.0, 179.9);
    expect(sample!.resolutionKm, closeTo(55.6, 0.1));
  });

  test('outside the coastal band the global layer answers', () async {
    final sample = await _reader().sampleAt(10.25, -170.0);
    expect(sample!.resolutionKm, closeTo(555.975, 0.01));
    expect(sample.constituents['M2']!.phase, closeTo(90, 1e-6));
  });

  test(
    'an unreadable or malformed tile falls back to the global layer',
    () async {
      final missing = await _reader(
        replace: {
          'coastal/tile_0_0.bin': () => throw const FileSystemException('gone'),
        },
      ).sampleAt(10.0, -180.0);
      expect(missing!.resolutionKm, closeTo(555.975, 0.01));

      final garbage = await _reader(
        replace: {'coastal/tile_0_0.bin': () => ByteData(20)},
      ).sampleAt(10.0, -180.0);
      expect(garbage!.resolutionKm, closeTo(555.975, 0.01));
    },
  );

  test('a malformed manifest yields no data', () async {
    final reader = _reader(
      replace: {
        'manifest.json': () => ByteData.sublistView(
          Uint8List.fromList('{"format":"x"}'.codeUnits),
        ),
      },
    );
    expect(await reader.manifest(), isNull);
    expect(await reader.sampleAt(10.0, -180.0), isNull);
  });

  test('beyond both layers there is no data', () async {
    expect(await _reader().sampleAt(60.0, 0.0), isNull);
  });
}
