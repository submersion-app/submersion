import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_time_suggestions.dart';

const _deco = DiveTank(id: 'deco', role: TankRole.deco);

GasSwitch _sw(String id, int timestamp, {String tankId = 'deco'}) => GasSwitch(
  id: id,
  diveId: 'dive-1',
  timestamp: timestamp,
  tankId: tankId,
  createdAt: DateTime(2026),
);

List<int> _offer({
  required GasSwitch row,
  DiveTank? tank = _deco,
  required List<int> starts,
  List<GasSwitch> others = const [],
  int? maxTimestamp = 3600,
}) => gasSwitchTimeSuggestions(
  row: row,
  tank: tank,
  starts: starts,
  switches: [row, ...others],
  maxTimestamp: maxTimestamp,
);

void main() {
  group('gasSwitchTimeSuggestions', () {
    test('offers the cylinder\'s starts', () {
      expect(_offer(row: _sw('a', 900), starts: [890, 1800]), [890, 1800]);
    });

    test('leaves out the second the row already holds', () {
      expect(_offer(row: _sw('a', 900), starts: [900, 1800]), [1800]);
    });

    test('another row on the cylinder within a minute claims a start', () {
      expect(
        _offer(row: _sw('a', 2400), starts: [900], others: [_sw('b', 960)]),
        isEmpty,
      );
      expect(
        _offer(row: _sw('a', 2400), starts: [900], others: [_sw('b', 961)]),
        [900],
      );
    });

    test('a row on another cylinder claims nothing', () {
      expect(
        _offer(
          row: _sw('a', 2400),
          starts: [900],
          others: [_sw('b', 901, tankId: 'back')],
        ),
        [900],
      );
    });

    test('leaves out the second another row sits on', () {
      expect(
        _offer(
          row: _sw('a', 2400),
          starts: [900],
          others: [_sw('b', 900, tankId: 'back')],
        ),
        isEmpty,
      );
    });

    test('keeps the three nearest the row, in time order', () {
      expect(_offer(row: _sw('a', 1000), starts: [100, 500, 900, 1300, 3000]), [
        500,
        900,
        1300,
      ]);
    });

    test('leaves out a start past the end of the dive', () {
      expect(_offer(row: _sw('a', 900), starts: [890, 4000]), [890]);
      expect(_offer(row: _sw('a', 900), starts: [4000], maxTimestamp: null), [
        4000,
      ]);
    });

    test('a cylinder that feeds the loop has no breathing starts', () {
      expect(hasBreathingStarts(_deco), isTrue);
      expect(hasBreathingStarts(null), isFalse);
      expect(
        hasBreathingStarts(const DiveTank(id: 'd', role: TankRole.diluent)),
        isFalse,
      );
      expect(
        hasBreathingStarts(
          const DiveTank(id: 'o', role: TankRole.oxygenSupply),
        ),
        isFalse,
      );
    });

    test('offers nothing for a cylinder that feeds the loop', () {
      for (final role in [TankRole.diluent, TankRole.oxygenSupply]) {
        expect(
          _offer(
            row: _sw('a', 900),
            tank: DiveTank(id: 'deco', role: role),
            starts: [890],
          ),
          isEmpty,
        );
      }
    });

    test('offers nothing with no cylinder or no starts', () {
      expect(_offer(row: _sw('a', 900), tank: null, starts: [890]), isEmpty);
      expect(_offer(row: _sw('a', 900), starts: const []), isEmpty);
    });
  });
}
