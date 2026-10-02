import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('DiveProfilePoint gf99 and n2Load', () {
    test('default to null', () {
      const point = DiveProfilePoint(timestamp: 0, depth: 10.0);
      expect(point.gf99, isNull);
      expect(point.n2Load, isNull);
    });

    test('take part in equality and copyWith', () {
      const a = DiveProfilePoint(
        timestamp: 60,
        depth: 20.0,
        gf99: 45,
        n2Load: 72,
      );
      const b = DiveProfilePoint(
        timestamp: 60,
        depth: 20.0,
        gf99: 45,
        n2Load: 72,
      );
      expect(a, b);
      expect(a, isNot(a.copyWith(gf99: 46)));
      expect(a.copyWith(n2Load: 80).n2Load, 80);
      expect(a.copyWith(n2Load: 80).gf99, 45);
    });
  });

  group('Dive computerTissue', () {
    final now = DateTime(2026, 1, 1);
    const snapshot = ComputerTissueSnapshot(
      algorithm: 'buhlmann',
      end: ComputerTissueState(gf99Percent: 33.0),
    );

    test('defaults to null and is carried by copyWith and props', () {
      final dive = Dive(id: 'd1', diveNumber: 1, dateTime: now);
      expect(dive.computerTissue, isNull);
      final withTissue = dive.copyWith(computerTissue: snapshot);
      expect(withTissue.computerTissue, snapshot);
      expect(withTissue, isNot(dive));
      expect(withTissue.copyWith(id: 'd2').computerTissue, snapshot);
    });
  });
}
