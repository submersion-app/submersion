import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_gas_switches.dart';

const _air = GasMix(o2: 21);
const _ean40 = GasMix(o2: 40);
const _ean80 = GasMix(o2: 80);

PlanScheduleRow _row(
  double depth,
  int seconds,
  int runtime,
  double fO2, {
  String? tankId,
  bool gasSwitch = false,
  PlanScheduleRowKind kind = PlanScheduleRowKind.descent,
}) => PlanScheduleRow(
  kind: kind,
  depthMeters: depth,
  durationSeconds: seconds,
  runtimeSeconds: runtime,
  gasFO2: fO2,
  gasFHe: 0,
  tankId: tankId,
  gasSwitch: gasSwitch,
  ppO2: 1,
  endMeters: 0,
);

/// The plan in the report: air, EAN40 on the fly from 30 m, EAN80 at 6 m.
List<PlanScheduleRow> _schedule() => [
  _row(38, 60, 60, .21, tankId: 'p-air', gasSwitch: true),
  _row(39, 780, 840, .21, tankId: 'p-air'),
  _row(30, 60, 900, .21, tankId: 'p-air'),
  _row(10, 120, 1020, .40, tankId: 'p-40', gasSwitch: true),
  _row(6, 60, 1080, .80, tankId: 'p-80', gasSwitch: true),
  _row(6, 60, 1140, .80, tankId: 'p-80'),
  _row(0, 360, 1500, .80, tankId: 'p-80'),
];

const _planTanks = [
  DiveTank(id: 'p-air', gasMix: _air),
  DiveTank(id: 'p-40', gasMix: _ean40),
  DiveTank(id: 'p-80', gasMix: _ean80),
];

const _entryTanks = [
  DiveTank(id: 'e-air', gasMix: _air),
  DiveTank(id: 'e-40', gasMix: _ean40),
  DiveTank(id: 'e-80', gasMix: _ean80),
];

void main() {
  final now = DateTime(2026, 11, 1);

  List<({int at, String tank, double? depth})> switches(
    List<PlanScheduleRow> schedule, {
    List<DiveTank> planTanks = _planTanks,
    List<DiveTank> entryTanks = _entryTanks,
  }) => [
    for (final s in plannedGasSwitches(
      schedule,
      planTanks: planTanks,
      entryTanks: entryTanks,
      diveId: 'd',
      createdAt: now,
    ))
      (at: s.timestamp, tank: s.tankId, depth: s.depth),
  ];

  test('finds a switch on the fly as well as one at a stop', () {
    expect(switches(_schedule()), [
      (at: 900, tank: 'e-40', depth: 30.0),
      (at: 1020, tank: 'e-80', depth: 10.0),
    ]);
  });

  test('the gas the dive starts on is not a switch', () {
    final result = switches([_schedule().first]);

    expect(result, isEmpty);
  });

  test('a plan on one gas has none', () {
    final result = switches([
      _row(30, 120, 120, .21, tankId: 'p-air', gasSwitch: true),
      _row(0, 300, 420, .21, tankId: 'p-air'),
    ]);

    expect(result, isEmpty);
  });

  test('two tanks of one gas: the line\'s own tank, by position', () {
    const planTanks = [
      DiveTank(id: 'p-air', gasMix: _air),
      DiveTank(id: 'p-a', gasMix: _ean40),
      DiveTank(id: 'p-b', gasMix: _ean40),
    ];
    const entryTanks = [
      DiveTank(id: 'e-air', gasMix: _air),
      DiveTank(id: 'e-a', gasMix: _ean40),
      DiveTank(id: 'e-b', gasMix: _ean40),
    ];

    final result = switches(
      [
        _row(30, 60, 60, .21, tankId: 'p-air', gasSwitch: true),
        _row(10, 60, 120, .40, tankId: 'p-b', gasSwitch: true),
      ],
      planTanks: planTanks,
      entryTanks: entryTanks,
    );

    expect(result.single.tank, 'e-b');
  });

  test('tanks in another order still find the gas', () {
    final result = switches(
      _schedule(),
      entryTanks: const [
        DiveTank(id: 'e-80', gasMix: _ean80),
        DiveTank(id: 'e-air', gasMix: _air),
        DiveTank(id: 'e-40', gasMix: _ean40),
      ],
    );

    expect(result.map((s) => s.tank), ['e-40', 'e-80']);
  });

  test('a gas no tank holds is left out', () {
    final result = switches(
      _schedule(),
      entryTanks: const [
        DiveTank(id: 'e-air', gasMix: _air),
        DiveTank(id: 'e-80', gasMix: _ean80),
      ],
    );

    expect(result.map((s) => s.tank), ['e-80']);
  });
}
