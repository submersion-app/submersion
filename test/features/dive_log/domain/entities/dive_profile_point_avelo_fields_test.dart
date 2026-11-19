import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #4664: the Shearwater Avelo fields on a profile point and sample.
void main() {
  group('DiveProfilePoint Avelo fields', () {
    test('default to null', () {
      const point = DiveProfilePoint(timestamp: 0, depth: 10.0);
      expect(point.aveloBuoyancy, isNull);
      expect(point.aveloGasRemaining, isNull);
      expect(point.computerRmv, isNull);
    });

    test('take part in equality and copyWith', () {
      const a = DiveProfilePoint(
        timestamp: 60,
        depth: 20.0,
        aveloBuoyancy: -0.393,
        aveloGasRemaining: 64,
        computerRmv: 10.68,
      );
      const b = DiveProfilePoint(
        timestamp: 60,
        depth: 20.0,
        aveloBuoyancy: -0.393,
        aveloGasRemaining: 64,
        computerRmv: 10.68,
      );
      expect(a, b);
      expect(a, isNot(a.copyWith(aveloBuoyancy: 1.242)));
      expect(a, isNot(a.copyWith(aveloGasRemaining: 35)));
      expect(a, isNot(a.copyWith(computerRmv: 29.75)));
      final moved = a.copyWith(computerRmv: 29.75);
      expect(moved.computerRmv, 29.75);
      expect(moved.aveloBuoyancy, -0.393);
      expect(moved.aveloGasRemaining, 64);
    });
  });

  group('ProfileSample Avelo fields', () {
    const sample = ProfileSample(
      timestamp: 30,
      depth: 12.0,
      aveloBuoyancy: -0.393,
      aveloGasRemaining: 64,
      computerRmv: 10.68,
    );

    test('shiftedBy keeps them', () {
      final shifted = sample.shiftedBy(15);
      expect(shifted.aveloBuoyancy, -0.393);
      expect(shifted.aveloGasRemaining, 64);
      expect(shifted.computerRmv, 10.68);
    });

    test('withTissue keeps them', () {
      final tissue = sample.withTissue(gf99: 40);
      expect(tissue.aveloBuoyancy, -0.393);
      expect(tissue.aveloGasRemaining, 64);
      expect(tissue.computerRmv, 10.68);
    });

    test('withAvelo sets exactly its arguments and keeps the rest', () {
      final withGf = sample.withTissue(gf99: 40);
      final changed = withGf.withAvelo(aveloGasRemaining: 35);
      expect(changed.aveloGasRemaining, 35);
      expect(changed.aveloBuoyancy, isNull);
      expect(changed.computerRmv, isNull);
      expect(changed.gf99, 40);
      expect(changed.depth, 12.0);
    });
  });
}
