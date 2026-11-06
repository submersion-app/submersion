import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
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

    // The log would start this entry on EAN80, its first cylinder, so the
    // air it really starts on is written at the start.
    expect(result.map((s) => (s.at, s.tank)), [
      (0, 'e-air'),
      (900, 'e-40'),
      (1020, 'e-80'),
    ]);
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

  group('travel folded into a stop', () {
    PlanScheduleRow stop(
      double depth,
      int seconds,
      int runtime,
      double fO2,
      String tankId, {
      List<PlanFoldedTravel> folded = const [],
    }) => PlanScheduleRow(
      kind: PlanScheduleRowKind.stop,
      depthMeters: depth,
      durationSeconds: seconds,
      runtimeSeconds: runtime,
      gasFO2: fO2,
      gasFHe: 0,
      tankId: tankId,
      gasSwitch: true,
      foldedTravel: folded,
    );

    final bottom = [
      _row(30, 100, 100, .21, tankId: 'p-air', gasSwitch: true),
      _row(30, 1100, 1200, .21, tankId: 'p-air'),
      _row(9, 70, 1270, .21, tankId: 'p-air', kind: PlanScheduleRowKind.ascent),
      stop(9, 60, 1330, .21, 'p-air'),
    ];

    test('a switch at a stop is written there, at its depth', () {
      final result = switches([
        ...bottom,
        // The leg up from 9 m is still on air: the switch is on arrival.
        stop(
          6,
          120,
          1480,
          .80,
          'p-80',
          folded: const [
            PlanFoldedTravel(
              fromDepthMeters: 9,
              toDepthMeters: 6,
              seconds: 30,
              tankId: 'p-air',
            ),
          ],
        ),
      ]);

      expect(result, [(at: 1360, tank: 'e-80', depth: 6.0)]);
    });

    test('a switch partway up a folded leg is written where it falls', () {
      final result = switches([
        ...bottom,
        stop(
          3,
          180,
          1570,
          .40,
          'p-40',
          folded: const [
            PlanFoldedTravel(
              fromDepthMeters: 9,
              toDepthMeters: 6,
              seconds: 30,
              tankId: 'p-air',
            ),
            PlanFoldedTravel(
              fromDepthMeters: 6,
              toDepthMeters: 3,
              seconds: 30,
              tankId: 'p-40',
            ),
          ],
        ),
      ]);

      expect(result, [(at: 1360, tank: 'e-40', depth: 6.0)]);
    });
  });

  test('a dive descending on a travel gas starts on it in the log', () {
    const trimix = GasMix(o2: 10, he: 70);
    const travel = GasMix(o2: 32);
    PlanScheduleRow line(double depth, int runtime, GasMix gas, String id) =>
        PlanScheduleRow(
          kind: PlanScheduleRowKind.descent,
          depthMeters: depth,
          durationSeconds: 60,
          runtimeSeconds: runtime,
          gasFO2: gas.o2 / 100,
          gasFHe: gas.he / 100,
          tankId: id,
          gasSwitch: true,
        );

    final result = switches(
      [line(30, 60, travel, 'p-travel'), line(90, 300, trimix, 'p-back')],
      planTanks: const [
        DiveTank(id: 'p-back', gasMix: trimix),
        DiveTank(id: 'p-travel', gasMix: travel, role: TankRole.stage),
      ],
      entryTanks: const [
        DiveTank(id: 'e-back', gasMix: trimix),
        DiveTank(id: 'e-travel', gasMix: travel, role: TankRole.stage),
      ],
    );

    expect(result, [
      (at: 0, tank: 'e-travel', depth: 0.0),
      (at: 240, tank: 'e-back', depth: 30.0),
    ]);
  });
}
