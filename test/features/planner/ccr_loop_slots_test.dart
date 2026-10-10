import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/services/ccr_loop_slots.dart';

const _slots = CcrLoopSlots();

DiveTank _tank(
  String id, {
  double o2 = 21,
  double he = 0,
  TankRole role = TankRole.backGas,
}) => DiveTank(
  id: id,
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: o2, he: he),
  role: role,
);

PlanSegment _seg(String tankId) => PlanSegment(
  id: 'seg-$tankId',
  targetDepth: 30,
  durationSeconds: 600,
  tankId: tankId,
  gasMix: const GasMix(o2: 21),
  order: 0,
);

var _ids = 0;
String _newId() => 'new-${_ids++}';

Map<String, TankRole> _roles(List<DiveTank> tanks) => {
  for (final t in tanks) t.id: t.role,
};

void main() {
  setUp(() => _ids = 0);

  test('a plan that already holds both slots is returned unchanged', () {
    final tanks = [
      _tank('dil', he: 35, role: TankRole.diluent),
      _tank('o2', o2: 100, role: TankRole.oxygenSupply),
      _tank('bo', o2: 50),
    ];
    final result = _slots.ensure(tanks, segments: const [], newId: _newId);
    expect(result.changed, isFalse);
    expect(result.tanks, tanks);
  });

  group('oxygen slot', () {
    test('adopts the first pure-O2 cylinder not marked diluent, once', () {
      final result = _slots.ensure(
        [
          _tank('dil', he: 35, role: TankRole.diluent),
          _tank('first-o2', o2: 100),
          _tank('second-o2', o2: 100),
        ],
        segments: const [],
        newId: _newId,
      );
      expect(result.changed, isTrue);
      final roles = _roles(result.tanks);
      expect(roles['first-o2'], TankRole.oxygenSupply);
      // The second stays what it is: bailout oxygen (#3220).
      expect(roles['second-o2'], TankRole.backGas);
      expect(result.tanks, hasLength(3));
    });

    test('a 100 % cylinder marked diluent is never taken for the slot', () {
      final result = _slots.ensure(
        [_tank('o2dil', o2: 100, role: TankRole.diluent)],
        segments: const [],
        newId: _newId,
      );
      expect(_roles(result.tanks)['o2dil'], TankRole.diluent);
      final added = result.tanks.last;
      expect(added.role, TankRole.oxygenSupply);
      expect(added.gasMix.o2, 100);
    });

    test('adds a 3 L / 200 bar placeholder when none can be adopted', () {
      final result = _slots.ensure(
        [_tank('dil', he: 35, role: TankRole.diluent)],
        segments: const [],
        newId: _newId,
      );
      expect(result.changed, isTrue);
      final added = result.tanks.last;
      expect(added.id, 'new-0');
      expect(added.role, TankRole.oxygenSupply);
      expect(added.gasMix.o2, 100);
      expect(added.volume, CcrLoopSlots.placeholderVolumeLiters);
      expect(added.startPressure, CcrLoopSlots.placeholderStartPressureBar);
      expect(added.order, 1);
    });
  });

  group('diluent slot', () {
    test('adopts the cylinders the segments breathe', () {
      final result = _slots.ensure(
        [
          _tank('o2', o2: 100, role: TankRole.oxygenSupply),
          _tank('deep', he: 50),
          _tank('bo', o2: 50),
        ],
        segments: [_seg('deep')],
        newId: _newId,
      );
      final roles = _roles(result.tanks);
      expect(roles['deep'], TankRole.diluent);
      expect(roles['bo'], TankRole.backGas);
      expect(result.tanks, hasLength(3));
    });

    test('with no segments yet, the first non-oxygen cylinder becomes the '
        'diluent', () {
      final result = _slots.ensure(
        [_tank('o2', o2: 100, role: TankRole.oxygenSupply), _tank('air')],
        segments: const [],
        newId: _newId,
      );
      expect(_roles(result.tanks)['air'], TankRole.diluent);
      expect(result.tanks, hasLength(2));
    });

    test('the oxygen slot is never adopted as diluent, even when a segment '
        'references it', () {
      final result = _slots.ensure(
        [_tank('o2', o2: 100, role: TankRole.oxygenSupply)],
        segments: [_seg('o2')],
        newId: _newId,
      );
      expect(_roles(result.tanks)['o2'], TankRole.oxygenSupply);
      final added = result.tanks.last;
      expect(added.role, TankRole.diluent);
      expect(added.gasMix, const GasMix(o2: 21));
    });

    test('adds an air placeholder when segments exist but breathe no '
        'carried cylinder', () {
      final result = _slots.ensure(
        [_tank('o2', o2: 100, role: TankRole.oxygenSupply), _tank('bo')],
        segments: [_seg('gone')],
        newId: _newId,
      );
      final roles = _roles(result.tanks);
      expect(roles['bo'], TankRole.backGas);
      expect(result.tanks.last.role, TankRole.diluent);
      expect(result.tanks.last.volume, CcrLoopSlots.placeholderVolumeLiters);
    });
  });

  test('an empty tank list gets both placeholders', () {
    final result = _slots.ensure(const [], segments: const [], newId: _newId);
    expect(result.changed, isTrue);
    expect(result.tanks.map((t) => t.role), [
      TankRole.oxygenSupply,
      TankRole.diluent,
    ]);
    expect(result.tanks.map((t) => t.id), ['new-0', 'new-1']);
  });
}
