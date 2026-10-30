import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/tank_extra_regulators.dart';

void main() {
  group('decodeExtraRegulatorIds', () {
    test('reads null, blank, empty and unreadable text as no extras', () {
      for (final text in [null, '', '  ', '[]', 'not json', '{"a":1}']) {
        expect(decodeExtraRegulatorIds(text), isEmpty, reason: '$text');
      }
    });

    test('reads the ids in order and drops non-strings', () {
      expect(decodeExtraRegulatorIds('["a","b"]'), ['a', 'b']);
      expect(decodeExtraRegulatorIds('["a",1,null,"b"]'), ['a', 'b']);
    });
  });

  group('encodeExtraRegulatorIds', () {
    test('stores no extras as null', () {
      expect(encodeExtraRegulatorIds(const []), isNull);
      expect(encodeExtraRegulatorIds(const ['', ' ']), isNull);
    });

    test('drops duplicates and blanks', () {
      expect(encodeExtraRegulatorIds(const ['a', 'a', '']), '["a"]');
    });
  });

  group('normalizeTankRegulators', () {
    test('promotes the first extra when there is no first', () {
      final r = normalizeTankRegulators(null, const ['a', 'b']);
      expect(r.first, 'a');
      expect(r.extras, ['b']);
    });

    test('drops duplicates of the first, repeats and blanks', () {
      final r = normalizeTankRegulators('a', const ['a', 'b', 'b', '']);
      expect(r.first, 'a');
      expect(r.extras, ['b']);
    });

    test('a blank first counts as none', () {
      final r = normalizeTankRegulators('', const ['b']);
      expect(r.first, 'b');
      expect(r.extras, isEmpty);
    });

    test('nothing stays nothing', () {
      final r = normalizeTankRegulators(null, const []);
      expect(r.first, isNull);
      expect(r.extras, isEmpty);
    });
  });

  group('DiveTank', () {
    const tank = DiveTank(
      id: 't',
      regulatorEquipmentId: 'a',
      extraRegulatorIds: ['b'],
    );

    test('regulatorIds lists the first, then the extras', () {
      expect(tank.regulatorIds, ['a', 'b']);
      expect(const DiveTank(id: 't').regulatorIds, isEmpty);
    });

    test('withRegulators sets the first and the extras', () {
      final t = tank.withRegulators(const ['b', 'c']);
      expect(t.regulatorEquipmentId, 'b');
      expect(t.extraRegulatorIds, ['c']);
    });

    test('withRegulators with no ids clears both', () {
      final t = tank.withRegulators(const []);
      expect(t.regulatorEquipmentId, isNull);
      expect(t.extraRegulatorIds, isEmpty);
    });

    test('clearing the first leaves the extras to the repository', () {
      final t = tank.copyWith(clearRegulatorEquipmentId: true);
      expect(t.regulatorEquipmentId, isNull);
      expect(t.extraRegulatorIds, ['b']);
    });

    test('copyWith replaces the extras', () {
      expect(tank.copyWith(extraRegulatorIds: ['c']).extraRegulatorIds, ['c']);
      expect(tank.copyWith(startPressure: 200).extraRegulatorIds, ['b']);
    });

    test('tanks differing only in extras are not equal', () {
      expect(tank, isNot(tank.copyWith(extraRegulatorIds: const [])));
    });
  });
}
