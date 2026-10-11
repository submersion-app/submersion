import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/services/divemate_values.dart';

void main() {
  group('waterType', () {
    test('1 salt, 2 fresh, anything else unset', () {
      expect(DiveMateValues.waterType(1), WaterType.salt);
      expect(DiveMateValues.waterType(2), WaterType.fresh);
      expect(DiveMateValues.waterType(0), isNull);
      expect(DiveMateValues.waterType(null), isNull);
      expect(DiveMateValues.waterType(7), isNull);
    });
  });

  group('entryMethod', () {
    test('1 shore, 2 boat, anything else unset', () {
      expect(DiveMateValues.entryMethod(1), EntryMethod.shore);
      expect(DiveMateValues.entryMethod(2), EntryMethod.boat);
      expect(DiveMateValues.entryMethod(0), isNull);
    });
  });

  group('rating', () {
    test('1 to 5 kept, 0 and out of range unset', () {
      expect(DiveMateValues.rating(1), 1);
      expect(DiveMateValues.rating(5), 5);
      expect(DiveMateValues.rating(0), isNull);
      expect(DiveMateValues.rating(6), isNull);
    });
  });

  group('visibility', () {
    test('German and English levels', () {
      expect(DiveMateValues.visibility('gut').level, Visibility.good);
      expect(DiveMateValues.visibility('Mittel').level, Visibility.moderate);
      expect(DiveMateValues.visibility('schlecht').level, Visibility.poor);
      expect(DiveMateValues.visibility('sehr gut').level, Visibility.excellent);
      expect(DiveMateValues.visibility('good').level, Visibility.good);
    });

    test('a distance reads as metres, feet converted', () {
      expect(DiveMateValues.visibility('15 m').meters, 15.0);
      expect(DiveMateValues.visibility('20m').meters, 20.0);
      expect(DiveMateValues.visibility('7,5 m').meters, 7.5);
      expect(DiveMateValues.visibility('30 ft').meters, closeTo(9.144, 1e-6));
    });

    test('other text is kept as text, blank is nothing', () {
      final read = DiveMateValues.visibility('trüb nach Sturm');
      expect(read.level, isNull);
      expect(read.meters, isNull);
      expect(read.text, 'trüb nach Sturm');
      expect(DiveMateValues.visibility('  ').text, isNull);
      expect(DiveMateValues.visibility(null).text, isNull);
    });
  });

  group('currentStrength', () {
    test('German and English words', () {
      expect(DiveMateValues.current('keine Strömung'), CurrentStrength.none);
      expect(DiveMateValues.current('leichte Strömung'), CurrentStrength.light);
      expect(
        DiveMateValues.current('mittlere Strömung'),
        CurrentStrength.moderate,
      );
      expect(DiveMateValues.current('starke Strömung'), CurrentStrength.strong);
      expect(DiveMateValues.current('strong'), CurrentStrength.strong);
      expect(DiveMateValues.current('none'), CurrentStrength.none);
    });

    test('unreadable text is null', () {
      expect(DiveMateValues.current('Gegenströmung am Riff'), isNull);
      expect(DiveMateValues.current(null), isNull);
    });
  });

  group('surfaceInterval', () {
    test('H:MM reads as a duration', () {
      expect(
        DiveMateValues.surfaceInterval('2:41'),
        const Duration(hours: 2, minutes: 41),
      );
      expect(
        DiveMateValues.surfaceInterval('122:50'),
        const Duration(hours: 122, minutes: 50),
      );
    });

    test("DiveMate's unknown markers and zero read as unset", () {
      expect(DiveMateValues.surfaceInterval('0:0-1'), isNull);
      expect(DiveMateValues.surfaceInterval('0:00'), isNull);
      expect(DiveMateValues.surfaceInterval(''), isNull);
      expect(DiveMateValues.surfaceInterval('3:75'), isNull);
    });
  });

  group('tankMaterial', () {
    test('1 aluminium, 2 steel, others unknown', () {
      expect(DiveMateValues.tankMaterial(1), TankMaterial.aluminum);
      expect(DiveMateValues.tankMaterial(2), TankMaterial.steel);
      expect(DiveMateValues.tankMaterial(0), isNull);
      expect(DiveMateValues.tankMaterial(3), isNull);
    });
  });

  group('tankRole', () {
    test('the dive phase wins: 3 deco, 4 stage', () {
      expect(
        DiveMateValues.tankRole(divePhase: 3, supplyType: 4, sidemountIndex: 0),
        TankRole.deco,
      );
      expect(
        DiveMateValues.tankRole(divePhase: 4, supplyType: 0, sidemountIndex: 0),
        TankRole.stage,
      );
    });

    test('sidemount: the first is left, the next right', () {
      expect(
        DiveMateValues.tankRole(divePhase: 0, supplyType: 4, sidemountIndex: 0),
        TankRole.sidemountLeft,
      );
      expect(
        DiveMateValues.tankRole(divePhase: 0, supplyType: 4, sidemountIndex: 1),
        TankRole.sidemountRight,
      );
    });

    test('anything else is back gas', () {
      expect(
        DiveMateValues.tankRole(
          divePhase: null,
          supplyType: 1,
          sidemountIndex: 0,
        ),
        TankRole.backGas,
      );
    });
  });

  group('equipmentType', () {
    test('TypeID first', () {
      expect(DiveMateValues.equipmentTypeFromCode(11), EquipmentType.tank);
      expect(DiveMateValues.equipmentTypeFromCode(12), EquipmentType.weights);
      expect(DiveMateValues.equipmentTypeFromCode(17), EquipmentType.computer);
      expect(DiveMateValues.equipmentTypeFromCode(0), isNull);
    });

    test('German categories', () {
      expect(
        DiveMateValues.equipmentTypeFromCategory('Flaschen'),
        EquipmentType.tank,
      );
      expect(
        DiveMateValues.equipmentTypeFromCategory('Blei'),
        EquipmentType.weights,
      );
      expect(
        DiveMateValues.equipmentTypeFromCategory('Tauchcomputer'),
        EquipmentType.computer,
      );
      expect(
        DiveMateValues.equipmentTypeFromCategory('Wing'),
        EquipmentType.wing,
      );
      expect(
        DiveMateValues.equipmentTypeFromCategory('Flossen'),
        EquipmentType.fins,
      );
      expect(
        DiveMateValues.equipmentTypeFromCategory('Maske'),
        EquipmentType.mask,
      );
      expect(
        DiveMateValues.equipmentTypeFromCategory('Atemregler'),
        EquipmentType.regulator,
      );
      expect(
        DiveMateValues.equipmentTypeFromCategory('Lampen'),
        EquipmentType.light,
      );
      expect(DiveMateValues.equipmentTypeFromCategory('Sonstiges'), isNull);
    });

    test('a suit category reads the kind of suit from the name', () {
      expect(DiveMateValues.suitFromName('Trocki'), EquipmentType.drysuit);
      expect(DiveMateValues.suitFromName('7 Nass'), EquipmentType.wetsuit);
      expect(DiveMateValues.suitFromName('5mm Neo'), EquipmentType.wetsuit);
      expect(DiveMateValues.suitFromName('Shorty'), EquipmentType.wetsuit);
      expect(DiveMateValues.suitFromName('Lycra'), EquipmentType.rashGuard);
      expect(
        DiveMateValues.suitFromName('Halbtrocken 7mm'),
        EquipmentType.wetsuit,
      );
      expect(DiveMateValues.isSuitCategory('Anzug'), isTrue);
      expect(DiveMateValues.isSuitCategory('Tauchanzüge'), isTrue);
      expect(DiveMateValues.isSuitCategory('Wing'), isFalse);
    });
  });
}
