import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/missing_gas_switches.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/detected_gas_switch_edits.dart';

DiveTank _tank(String id, int order, {double o2 = 21, TankRole? role}) =>
    DiveTank(
      id: id,
      volume: 12,
      gasMix: GasMix(o2: o2),
      order: order,
      role: role ?? TankRole.sidemountLeft,
    );

GasSwitch _sw(String id, int t, String tankId) => GasSwitch(
  id: id,
  diveId: 'd1',
  timestamp: t,
  tankId: tankId,
  createdAt: DateTime.utc(2026, 11, 8),
);

MissedSwitch _at(String tankId, int t, {double depth = 18}) => (
  tankId: tankId,
  tankPosition: 0,
  t: t,
  depth: depth,
  o2Percent: 21,
  hePercent: 0,
);

MissedSwitches _detected(List<MissedSwitch> addable, {String? start}) =>
    (addable: addable, deep: const [], unplaced: null, startingTankId: start);

void main() {
  final left = _tank('t1', 0);
  final right = _tank('t2', 1, role: TankRole.sidemountRight);

  group('detectedGasSwitchEdits', () {
    test('the sidemount dive of issue #4335: re-points the start, adds the '
        'rest', () {
      // The computer logged "Air" at 0:00 against cylinder 2, but cylinder 1
      // fell from the start; the turns at 15:44, 53:08 and 75:30 were never
      // logged.
      final edits = detectedGasSwitchEdits(
        switches: [_sw('start', 0, 't2')],
        tanks: [left, right],
        detected: _detected([
          _at('t2', 944),
          _at('t1', 3188),
          _at('t2', 4530),
        ], start: 't1'),
        diveStart: 0,
      );

      expect(edits.retanked, {'start': 't1'});
      expect(
        [for (final a in edits.added) (a.tankId, a.t)],
        [('t2', 944), ('t1', 3188), ('t2', 4530)],
      );
      expect(gasSwitchEditCount(edits), 4);
    });

    test('a start row on another gas is the computer\'s and stays', () {
      final nitrox = _tank('t2', 1, o2: 32);
      final edits = detectedGasSwitchEdits(
        switches: [_sw('start', 0, 't2')],
        tanks: [left, nitrox],
        detected: _detected(const [], start: 't1'),
        diveStart: 0,
      );

      expect(edits.retanked, isEmpty);
      expect(gasSwitchEditCount(edits), 0);
    });

    test('a start row already right is left alone', () {
      final edits = detectedGasSwitchEdits(
        switches: [_sw('start', 0, 't1')],
        tanks: [left, right],
        detected: _detected([_at('t2', 944)], start: 't1'),
        diveStart: 0,
      );

      expect(edits.retanked, isEmpty);
      expect(edits.added.single.t, 944);
    });

    test('with a start row, a detected switch at the start is not added', () {
      final edits = detectedGasSwitchEdits(
        switches: [_sw('start', -103, 't2')],
        tanks: [left, right],
        detected: _detected([_at('t1', -103), _at('t2', 944)], start: 't1'),
        diveStart: -103,
      );

      expect(edits.retanked, {'start': 't1'});
      expect([for (final a in edits.added) a.t], [944]);
    });

    test('a 0:00 row, not one logged before the start, is re-pointed', () {
      // A second computer logged -1:43; the 0:00 row is what the timeline
      // has in use from the start (#4335 review).
      final edits = detectedGasSwitchEdits(
        switches: [_sw('early', -103, 't2'), _sw('start', 0, 't2')],
        tanks: [left, right],
        detected: _detected([_at('t1', 0), _at('t2', 944)], start: 't1'),
        diveStart: 0,
      );

      expect(edits.retanked, {'start': 't1'});
      expect([for (final a in edits.added) a.t], [944]);
    });

    test('a lone row logged before the start is the starting row', () {
      final edits = detectedGasSwitchEdits(
        switches: [_sw('early', -103, 't2')],
        tanks: [left, right],
        detected: _detected([_at('t1', 0), _at('t2', 944)], start: 't1'),
        diveStart: 0,
      );

      expect(edits.retanked, {'early': 't1'});
      expect([for (final a in edits.added) a.t], [944]);
    });

    test('a profile that starts late still has its starting row', () {
      // The computer's first sample, and its logged start, at 1:30.
      final edits = detectedGasSwitchEdits(
        switches: [_sw('start', 90, 't2')],
        tanks: [left, right],
        detected: _detected([_at('t1', 90), _at('t2', 944)], start: 't1'),
        diveStart: 90,
      );

      expect(edits.retanked, {'start': 't1'});
      expect([for (final a in edits.added) a.t], [944]);
    });

    test('without a start row, a detected start switch is added', () {
      final edits = detectedGasSwitchEdits(
        switches: const [],
        tanks: [left, right],
        detected: _detected([_at('t2', 0, depth: 0)], start: 't2'),
        diveStart: 0,
      );

      expect(edits.retanked, isEmpty);
      expect([for (final a in edits.added) (a.tankId, a.t)], [('t2', 0)]);
    });

    test('a switch a row on the same cylinder already claims is left out', () {
      final edits = detectedGasSwitchEdits(
        switches: [_sw('start', 0, 't1'), _sw('logged', 960, 't2')],
        tanks: [left, right],
        detected: _detected([_at('t2', 944), _at('t1', 3188)], start: 't1'),
        diveStart: 0,
      );

      expect([for (final a in edits.added) a.t], [3188]);
    });

    test('a switch on the second another row sits on is left out', () {
      final edits = detectedGasSwitchEdits(
        switches: [_sw('start', 0, 't1'), _sw('other', 944, 't1')],
        tanks: [left, right],
        detected: _detected([_at('t2', 944)], start: 't1'),
        diveStart: 0,
      );

      expect(edits.added, isEmpty);
    });

    test('a switch to a cylinder no longer on the dive is left out', () {
      final edits = detectedGasSwitchEdits(
        switches: const [],
        tanks: [left],
        detected: _detected([_at('t2', 944)]),
        diveStart: 0,
      );

      expect(edits.added, isEmpty);
    });

    test('nothing detected changes nothing', () {
      final edits = detectedGasSwitchEdits(
        switches: [_sw('start', 0, 't2')],
        tanks: [left, right],
        detected: _detected(const []),
        diveStart: 0,
      );

      expect(gasSwitchEditCount(edits), 0);
    });
  });
}
