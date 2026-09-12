import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';

/// A modelled buoyancy outcome for a short salt-water dive, so a test can make
/// the Buoyancy card render without running the twin assembler.
BuoyancyTwinOutcome buoyancyOutcome({
  double leadKg = 6.0,
  double droppableLeadKg = 4.0,
  double minDitchableKg = 2.0,
  double peakLiftDemandKg = 3.0,
  double? wingLiftCapacityKg,
  double verdictNet = 1.8,
}) {
  final env = DiveEnvironment.forConditions(waterType: WaterType.salt);
  final input = TwinInput(
    profile: const [
      TwinProfileSample(timestamp: 0, depthM: 0),
      TwinProfileSample(timestamp: 60, depthM: 5),
    ],
    tanks: const [],
    suit: const TwinSuitInput(
      kind: TwinSuitKind.wetsuit,
      anchorKg: 3.0,
      source: TermSource.typeDefault,
    ),
    staticTerms: const [
      TwinStaticTerm(label: 'personal', kg: 5.0, source: TermSource.measured),
    ],
    leadKg: leadKg,
    droppableLeadKg: droppableLeadKg,
    environment: env,
  );
  final result = BuoyancyTwinResult(
    samples: const [
      TwinSample(timestamp: 0, depthM: 0, suitKg: 3, tanksKg: 0, netKg: 2),
      TwinSample(timestamp: 60, depthM: 5, suitKg: 3, tanksKg: 0, netKg: 1.8),
    ],
    staticKg: 5.0,
    suitSurfaceKg: 3.9,
    drysuitGasLiters: 0,
    pressuresEstimated: false,
    input: input,
  );
  final verdict = TwinVerdict(
    anchor: const TwinAnchor(
      kind: TwinAnchorKind.detectedStop,
      timestamp: 60,
      depthM: 5,
    ),
    netKg: verdictNet,
    terms: [
      const TwinStaticTerm(
        label: 'suit',
        kg: 3.0,
        source: TermSource.typeDefault,
      ),
      const TwinStaticTerm(
        label: 'personal',
        kg: 5.0,
        source: TermSource.measured,
      ),
      TwinStaticTerm(label: 'lead', kg: -leadKg, source: TermSource.measured),
    ],
  );
  final outputs = TwinOutputs(
    beginNetKg: 2.0,
    endNetKg: 1.8,
    peakLiftDemandKg: peakLiftDemandKg,
    minDitchableKg: minDitchableKg,
    droppableLeadKg: droppableLeadKg,
    idealLeadKg: leadKg + verdictNet,
    verdict: verdict,
    drysuitGasLiters: 0,
  );
  return BuoyancyTwinOutcome(
    result: result,
    outputs: outputs,
    wingLiftCapacityKg: wingLiftCapacityKg,
  );
}
