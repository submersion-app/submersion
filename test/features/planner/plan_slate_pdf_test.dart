import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/services/plan_slate_pdf_service.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _air = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);
const _airTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);
const _decoTank = DiveTank(
  id: 'tank-2',
  volume: 7.0,
  startPressure: 200.0,
  gasMix: _ean50,
  role: TankRole.deco,
);
const _bailoutTank = DiveTank(
  id: 'tank-3',
  volume: 11.1,
  startPressure: 232.0,
  gasMix: _air,
  role: TankRole.bailout,
);

final _labels = PlanSlateLabels(
  runtimeTable: 'Deco schedule',
  gasPlan: 'Gas plan',
  contingencies: 'Contingencies',
  lostGasLabel: (gas) => 'Lost $gas',
  rangeTable: 'Range table',
  bailout: 'Bailout',
  stop: 'Stop',
  depth: 'Depth',
  runtime: 'RT',
  gas: 'Gas',
  turnAt: 'Turn',
  minGas: 'Min gas',
  base: 'Base',
);

domain.DivePlan _plan({domain.PlanMode mode = domain.PlanMode.oc}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Slate test',
    gfLow: 40,
    gfHigh: 80,
    mode: mode,
    turnPressureRule: domain.TurnPressureRule.thirds,
    segments: [
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: 45.0,
        tankId: 'tank-1',
        gasMix: _air,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'seg-2',
        depth: 45.0,
        durationMinutes: 25,
        tankId: 'tank-1',
        gasMix: _air,
        order: 1,
      ),
    ],
    tanks: const [_airTank, _decoTank, _bailoutTank],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

Future<List<int>> _build(domain.DivePlan plan) {
  const engine = PlanEngine();
  const contingency = ContingencyService();
  const rangeService = RangeTableService();
  final outcome = engine.compute(plan);
  return const PlanSlatePdfService().buildSlate(
    plan: plan,
    outcome: outcome,
    deviations: contingency.deviations(plan),
    lostGas: contingency.lostGas(plan),
    rangeTable: rangeService.compute(plan),
    bailout: const BailoutSolver().solve(plan),
    units: const UnitFormatter(AppSettings()),
    labels: _labels,
  );
}

void main() {
  test('OC slate renders a parseable PDF with all sections', () async {
    final bytes = await _build(_plan());
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('CCR slate (bailout section) renders without throwing', () async {
    final bytes = await _build(_plan(mode: domain.PlanMode.ccr));
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
