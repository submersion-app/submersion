import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/tank_cylinder_matching.dart';

EquipmentItem _cylinder(
  String id, {
  double? volume,
  double? pressure,
  String? material,
  bool suit = false,
}) => EquipmentItem(
  id: id,
  name: id,
  type: EquipmentType.tank,
  attributes: [
    if (volume != null)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.volumeL,
        valueNum: volume,
      ),
    if (pressure != null)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: pressure,
      ),
    if (material != null)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.tankMaterial,
        valueText: material,
      ),
    if (suit)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.cylinderUse,
        valueText: 'suit_inflation',
      ),
  ],
);

DiveTank _tank(
  String id, {
  double? volume = 11.1,
  double? pressure,
  TankMaterial? material,
  TankRole role = TankRole.backGas,
  int order = 0,
  String? name,
  String? equipmentId,
}) => DiveTank(
  id: id,
  name: name,
  volume: volume,
  workingPressure: pressure,
  material: material,
  role: role,
  order: order,
  equipmentId: equipmentId,
);

void main() {
  final al80 = _cylinder(
    'al80',
    volume: 11.1,
    pressure: 207,
    material: 'aluminum',
  );

  group('cylinderMatchesTank', () {
    test('a logged 0 working pressure is an unknown rating', () {
      final tank = _tank(
        't',
        volume: 11.1,
        pressure: 0,
        material: TankMaterial.aluminum,
      );
      expect(cylinderMatchesTank(al80, tank), isTrue);
      final proposal = proposalForTank(TankRef(diveId: 'd', tank: tank));
      expect(proposal.workingPressureBar, isNull);
    });

    test('matches within 0.2 L and 2 bar', () {
      expect(
        cylinderMatchesTank(
          al80,
          _tank(
            't',
            volume: 11.0,
            pressure: 207,
            material: TankMaterial.aluminum,
          ),
        ),
        isTrue,
      );
      expect(cylinderMatchesTank(al80, _tank('t', volume: 10.8)), isFalse);
      expect(
        cylinderMatchesTank(al80, _tank('t', volume: 11.1, pressure: 232)),
        isFalse,
      );
    });

    test('absent pressure or material is a wildcard', () {
      expect(cylinderMatchesTank(al80, _tank('t', volume: 11.1)), isTrue);
      final bare = _cylinder('bare', volume: 11.1);
      expect(
        cylinderMatchesTank(
          bare,
          _tank('t', pressure: 207, material: TankMaterial.steel),
        ),
        isTrue,
      );
    });

    test('material mismatch does not match', () {
      expect(
        cylinderMatchesTank(al80, _tank('t', material: TankMaterial.steel)),
        isFalse,
      );
    });

    test('a cylinder with no volume matches nothing', () {
      expect(cylinderMatchesTank(_cylinder('x'), _tank('t')), isFalse);
    });

    test('suit inflation matches only suit inflation', () {
      final argon = _cylinder('argon', volume: 0.85, suit: true);
      final small = _cylinder('small', volume: 0.85);
      final suitTank = _tank('t', volume: 0.85, role: TankRole.suitInflation);
      expect(cylinderMatchesTank(small, suitTank), isFalse);
      expect(cylinderMatchesTank(argon, suitTank), isTrue);
      expect(cylinderMatchesTank(argon, _tank('b', volume: 0.85)), isFalse);
    });
  });

  group('twin pairs', () {
    final a = _cylinder('a', volume: 12, pressure: 232, material: 'steel');
    final b = _cylinder('b', volume: 12, pressure: 232, material: 'steel');
    final doubles = _tank(
      't',
      volume: 24,
      pressure: 232,
      material: TankMaterial.steel,
    );

    test('pair matches the combined volume', () {
      expect(pairMatchesTank(a, b, doubles), isTrue);
      expect(pairMatchesTank(a, b, _tank('s', volume: 12)), isFalse);
    });

    test('a pair holding a suit inflation bottle matches no tank', () {
      final argon = _cylinder('argon', volume: 0.85, suit: true);
      final al80 = _cylinder('al80', volume: 11.1);
      final tank = _tank('t', volume: 11.95);
      expect(pairMatchesTank(argon, al80, tank), isFalse);
      expect(pairMatchesTank(al80, argon, tank), isFalse);
    });

    test('an owned pair keeps the doubles tank off the proposals', () {
      final proposals = proposeCylinders(
        [TankRef(diveId: 'd1', tank: doubles)],
        owned: [a, b],
        ownedPairs: [(a, b)],
      );
      expect(proposals, isEmpty);
    });
  });

  group('proposeCylinders', () {
    test('skips linked, volumeless and matched tanks', () {
      final proposals = proposeCylinders(
        [
          TankRef(
            diveId: 'd1',
            tank: _tank('linked', equipmentId: 'x'),
          ),
          TankRef(diveId: 'd1', tank: _tank('none', volume: null, order: 1)),
          TankRef(diveId: 'd1', tank: _tank('zero', volume: 0, order: 2)),
          TankRef(diveId: 'd2', tank: _tank('owned')),
        ],
        owned: [al80],
        ownedPairs: const [],
      );
      expect(proposals, isEmpty);
    });

    test('40 dives on one AL80 is one row', () {
      final proposals = proposeCylinders(
        [
          for (var i = 0; i < 40; i++)
            TankRef(
              diveId: 'd$i',
              tank: _tank(
                't$i',
                pressure: 206.843,
                material: TankMaterial.aluminum,
              ),
            ),
        ],
        owned: const [],
        ownedPairs: const [],
      );
      expect(proposals, hasLength(1));
      expect(proposals.single.cylinderCount, 1);
      expect(proposals.single.diveCount, 40);
      expect(proposals.single.allTanks, hasLength(40));
    });

    test('a tank with only a volume groups apart from a full spec', () {
      final proposals = proposeCylinders(
        [
          TankRef(diveId: 'd1', tank: _tank('bare')),
          TankRef(
            diveId: 'd2',
            tank: _tank('full', pressure: 207, material: TankMaterial.steel),
          ),
          TankRef(diveId: 'd3', tank: _tank('bare2')),
        ],
        owned: const [],
        ownedPairs: const [],
      );
      expect(proposals, hasLength(2));
      expect(proposals.first.diveCount, 2);
      expect(proposals.first.workingPressureBar, isNull);
      expect(proposals.first.material, isNull);
    });

    test('sidemount pair makes two cylinders split by tank order', () {
      final proposals = proposeCylinders(
        [
          for (var i = 0; i < 3; i++) ...[
            // Listed out of order: the split goes by tank order.
            TankRef(diveId: 'd$i', tank: _tank('d$i-right', order: 1)),
            TankRef(diveId: 'd$i', tank: _tank('d$i-left')),
          ],
          TankRef(diveId: 'd3', tank: _tank('d3-left')),
        ],
        owned: const [],
        ownedPairs: const [],
      );
      expect(proposals, hasLength(1));
      final p = proposals.single;
      expect(p.cylinderCount, 2);
      expect(p.diveCount, 4);
      expect(
        p.tanksByCylinder[0].map((r) => r.tank.id),
        unorderedEquals(['d0-left', 'd1-left', 'd2-left', 'd3-left']),
      );
      expect(
        p.tanksByCylinder[1].map((r) => r.tank.id),
        unorderedEquals(['d0-right', 'd1-right', 'd2-right']),
      );
    });

    test('suit inflation tanks group apart and keep the flag', () {
      final proposals = proposeCylinders(
        [
          TankRef(
            diveId: 'd1',
            tank: _tank('argon', volume: 0.85, role: TankRole.suitInflation),
          ),
          TankRef(diveId: 'd1', tank: _tank('small', volume: 0.85, order: 1)),
        ],
        owned: const [],
        ownedPairs: const [],
      );
      expect(proposals, hasLength(2));
      expect(proposals.where((p) => p.suitInflation), hasLength(1));
    });

    test('Twin Set tanks group apart and keep the flag (#4641)', () {
      final proposals = proposeCylinders(
        [
          TankRef(
            diveId: 'd1',
            tank: _tank('doubles', volume: 24, role: TankRole.twinSet),
          ),
          TankRef(diveId: 'd2', tank: _tank('big', volume: 24)),
        ],
        owned: const [],
        ownedPairs: const [],
      );
      expect(proposals, hasLength(2));
      final twin = proposals.where((p) => p.twinSet).toList();
      expect(twin, hasLength(1));
      expect(twin.single.allTanks.single.tank.id, 'doubles');
      expect(twin.single.suitInflation, isFalse);
    });

    test('rows are ordered by dive count, most first', () {
      final proposals = proposeCylinders(
        [
          TankRef(diveId: 'd1', tank: _tank('stage', volume: 5.7, order: 1)),
          TankRef(diveId: 'd1', tank: _tank('a')),
          TankRef(diveId: 'd2', tank: _tank('b')),
        ],
        owned: const [],
        ownedPairs: const [],
      );
      expect(proposals.map((p) => p.diveCount), [2, 1]);
    });
  });

  group('per-dive capacity', () {
    test('one owned AL80 covers one tank of a sidemount dive', () {
      final proposals = proposeCylinders(
        [
          TankRef(diveId: 'd1', tank: _tank('right', order: 1)),
          TankRef(diveId: 'd1', tank: _tank('left')),
        ],
        owned: [al80],
        ownedPairs: const [],
      );
      expect(proposals, hasLength(1));
      expect(proposals.single.cylinderCount, 1);
      expect(proposals.single.allTanks.single.tank.id, 'right');
    });

    test('one owned AL80 covers a single tank on every dive', () {
      final proposals = proposeCylinders(
        [
          for (var i = 0; i < 3; i++)
            TankRef(diveId: 'd$i', tank: _tank('t$i')),
        ],
        owned: [al80],
        ownedPairs: const [],
      );
      expect(proposals, isEmpty);
    });

    test('a tank linked to the owned cylinder uses it on that dive', () {
      final proposals = proposeCylinders(
        [
          TankRef(
            diveId: 'd1',
            tank: _tank('linked', equipmentId: 'al80'),
          ),
          TankRef(diveId: 'd1', tank: _tank('free', order: 1)),
        ],
        owned: [al80],
        ownedPairs: const [],
      );
      expect(proposals.single.allTanks.single.tank.id, 'free');
    });

    test('a looser cylinder goes to the tank only it fits', () {
      final any = _cylinder('any', volume: 11.1);
      final alu = _cylinder('alu', volume: 11.1, material: 'aluminum');
      final proposals = proposeCylinders(
        [
          TankRef(
            diveId: 'd1',
            tank: _tank('alu-tank', material: TankMaterial.aluminum),
          ),
          TankRef(
            diveId: 'd1',
            tank: _tank('steel-tank', material: TankMaterial.steel, order: 1),
          ),
        ],
        owned: [any, alu],
        ownedPairs: const [],
      );
      expect(proposals, isEmpty);
    });

    test(
      'a single cylinder takes the stage so the twin set takes the doubles',
      () {
        final a = _cylinder('a', volume: 12, pressure: 232, material: 'steel');
        final b = _cylinder('b', volume: 12, pressure: 232, material: 'steel');
        final c = _cylinder('c', volume: 12, pressure: 232, material: 'steel');
        final proposals = proposeCylinders(
          [
            TankRef(
              diveId: 'd1',
              tank: _tank(
                'doubles',
                volume: 24,
                pressure: 232,
                material: TankMaterial.steel,
              ),
            ),
            TankRef(
              diveId: 'd1',
              tank: _tank(
                'stage',
                volume: 12,
                pressure: 232,
                material: TankMaterial.steel,
                order: 1,
              ),
            ),
          ],
          owned: [a, b, c],
          ownedPairs: [(a, b)],
        );
        expect(proposals, isEmpty);
      },
    );

    test('one owned twin set covers one doubles tank per dive', () {
      final a = _cylinder('a', volume: 12, pressure: 232, material: 'steel');
      final b = _cylinder('b', volume: 12, pressure: 232, material: 'steel');
      DiveTank doubles(String id, int order) => _tank(
        id,
        volume: 24,
        pressure: 232,
        material: TankMaterial.steel,
        order: order,
      );
      final proposals = proposeCylinders(
        [
          TankRef(diveId: 'd1', tank: doubles('first', 0)),
          TankRef(diveId: 'd1', tank: doubles('second', 1)),
        ],
        owned: [a, b],
        ownedPairs: [(a, b)],
      );
      expect(proposals.single.allTanks.single.tank.id, 'second');
    });
  });

  group('suggestedName', () {
    test('a tank name wins', () {
      final p = proposeCylinders(
        [
          TankRef(
            diveId: 'd',
            tank: _tank('t', name: 'Blue 12'),
          ),
        ],
        owned: const [],
        ownedPairs: const [],
      ).single;
      expect(p.suggestedName, 'Blue 12');
    });

    test('a matching preset names it', () {
      final p = proposeCylinders(
        [
          TankRef(
            diveId: 'd',
            tank: _tank('t', pressure: 207, material: TankMaterial.aluminum),
          ),
        ],
        owned: const [],
        ownedPairs: const [],
      ).single;
      expect(p.suggestedName, 'AL80');
    });

    test('no name and no preset gives null', () {
      final p = proposeCylinders(
        [TankRef(diveId: 'd', tank: _tank('t', volume: 9.3))],
        owned: const [],
        ownedPairs: const [],
      ).single;
      expect(p.suggestedName, isNull);
    });
  });

  test('proposalForTank ignores owned matches', () {
    final ref = TankRef(diveId: 'd', tank: _tank('t'));
    final p = proposalForTank(ref);
    expect(p.cylinderCount, 1);
    expect(p.allTanks.single.tank.id, 't');
    expect(p.volumeL, 11.1);
  });

  test('specs within the matching tolerance share one row', () {
    final proposals = proposeCylinders(
      [
        TankRef(diveId: 'a', tank: _tank('ta', volume: 11.14, pressure: 206.4)),
        TankRef(diveId: 'b', tank: _tank('tb', volume: 11.16, pressure: 206.6)),
      ],
      owned: const [],
      ownedPairs: const [],
    );
    expect(proposals, hasLength(1));
    expect(proposals.single.diveCount, 2);
  });
}
