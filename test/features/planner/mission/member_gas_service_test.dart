import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';

PlanScheduleRow _row(
  PlanScheduleRowKind kind,
  double depth,
  int seconds,
  int runtime, {
  String tankId = 'back',
}) => PlanScheduleRow(
  kind: kind,
  depthMeters: depth,
  durationSeconds: seconds,
  runtimeSeconds: runtime,
  gasFO2: 0.21,
  gasFHe: 0,
  tankId: tankId,
);

void main() {
  const service = MemberGasService();
  const env = DiveEnvironment.standard;

  test('level rows are charged at their own depth', () {
    final liters = service.litersByTank(
      rows: [_row(PlanScheduleRowKind.level, 20, 600, 600)],
      environment: env,
      sacFor: (_) => 15,
    );
    expect(liters, {'back': closeTo(450, 1e-6)});
  });

  test('travel rows are charged at the mean of start and end depth', () {
    final liters = service.litersByTank(
      rows: [
        _row(PlanScheduleRowKind.descent, 20, 60, 60),
        _row(PlanScheduleRowKind.level, 20, 600, 660),
        _row(PlanScheduleRowKind.ascent, 6, 90, 750),
      ],
      environment: env,
      sacFor: (row) => row.kind == PlanScheduleRowKind.ascent ? 12 : 15,
    );
    expect(liters['back'], closeTo(30 + 450 + 41.4, 1e-6));
  });

  test('rows are split by tank', () {
    final liters = service.litersByTank(
      rows: [
        _row(PlanScheduleRowKind.level, 20, 600, 600),
        _row(PlanScheduleRowKind.stop, 6, 300, 900, tankId: 'deco'),
      ],
      environment: env,
      sacFor: (_) => 10,
    );
    expect(liters, {'back': closeTo(300, 1e-6), 'deco': closeTo(80, 1e-6)});
  });

  test('a row without a tank is ignored', () {
    final liters = service.litersByTank(
      rows: [
        const PlanScheduleRow(
          kind: PlanScheduleRowKind.level,
          depthMeters: 20,
          durationSeconds: 60,
          runtimeSeconds: 60,
          gasFO2: 0.21,
          gasFHe: 0,
        ),
      ],
      environment: env,
      sacFor: (_) => 10,
    );
    expect(liters, isEmpty);
  });

  test('remainingBar inverts the ideal gas volume', () {
    const tank = DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 200,
      gasMix: GasMix(o2: 21),
      role: TankRole.backGas,
    );
    expect(
      service.remainingBar(tank: tank, litersUsed: 1200, model: GasModel.ideal),
      closeTo(150, 1e-9),
    );
  });

  test('remainingBar is null without a start pressure or volume', () {
    const tank = DiveTank(
      id: 'back',
      gasMix: GasMix(o2: 21),
      role: TankRole.backGas,
    );
    expect(
      service.remainingBar(tank: tank, litersUsed: 10, model: GasModel.ideal),
      isNull,
    );
  });
}
