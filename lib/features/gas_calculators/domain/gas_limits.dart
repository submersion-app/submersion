import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';

/// The MOD calculator's three modes (issue #2342).
enum ModCalculatorMode {
  /// Nitrox for recreational diving: MOD and EAD, flat 1 bar per 10 m.
  rec,

  /// Trimix on open circuit: MOD, minimum depth, narcosis and density.
  ocTec,

  /// CCR: the mix is the diluent, the loop holds a setpoint.
  ccrTec,
}

/// Depth beyond which recreational training ends.
const double recreationalDepthLimitMeters = 40;

/// ppO2 of the contingency MOD shown beside the working MOD in Rec.
const double recContingencyPpO2 = 1.6;

/// The nitrox range Rec offers.
const double recMinO2Percent = 21;
const double recMaxO2Percent = 40;

/// Deepest depth the MND search looks at. A mix still within the END limit
/// there has no practical narcotic limit.
const double _mndSearchCeilingMeters = 300;

class GasLimitsInputs {
  final ModCalculatorMode mode;

  /// O2 of the breathing gas, or of the diluent on CCR, in percent.
  final double o2Percent;

  /// He in percent. Ignored in Rec.
  final double hePercent;

  /// Working ppO2 limit (Rec and OC Tec).
  final double workingPpO2;

  /// Deco ppO2 limit (OC Tec).
  final double decoPpO2;

  /// ppO2 the diluent may reach on a flush, which sets its MOD (CCR Tec).
  final double flushPpO2;

  /// CCR setpoint in bar (CCR Tec).
  final double setpointBar;

  /// Lowest ppO2 a hypoxic mix may be breathed at (Tec modes).
  final double minPpO2;

  final double endLimitMeters;

  /// Whether O2 counts as narcotic: picks END or EAD for the END limit and
  /// the MND.
  final bool o2Narcotic;

  /// Optional second depth to assess besides the MOD.
  final double? targetDepthMeters;

  /// Water type of the Tec modes. Rec always uses the flat model.
  final WaterType waterType;

  const GasLimitsInputs({
    required this.mode,
    required this.o2Percent,
    required this.hePercent,
    required this.workingPpO2,
    required this.decoPpO2,
    required this.flushPpO2,
    required this.setpointBar,
    required this.minPpO2,
    required this.endLimitMeters,
    required this.o2Narcotic,
    required this.targetDepthMeters,
    required this.waterType,
  });
}

/// The breathed gas assessed at one depth.
class DepthAssessment {
  final double depthMeters;
  final double pO2Bar;
  final double pN2Bar;
  final double pHeBar;

  /// Equivalent air depth, N2 alone narcotic. Never negative.
  final double eadMeters;

  /// Equivalent narcotic depth, N2 and O2 narcotic. Never negative.
  final double endMeters;

  /// [endMeters] or [eadMeters], whichever the O2-narcotic setting selects.
  final double narcoticDepthMeters;

  final bool exceedsEndLimit;

  /// Gas density at 0 C and its level; Tec modes only.
  final double? densityGPerL;
  final GasDensityLevel? densityLevel;

  /// Equivalent air density depth; Tec modes only.
  final double? eaddMeters;

  /// CCR: the setpoint is above ambient pressure, the loop is pure oxygen.
  final bool setpointCapped;

  /// CCR: the diluent alone carries more oxygen than the setpoint.
  final bool diluentAboveSetpoint;

  const DepthAssessment({
    required this.depthMeters,
    required this.pO2Bar,
    required this.pN2Bar,
    required this.pHeBar,
    required this.eadMeters,
    required this.endMeters,
    required this.narcoticDepthMeters,
    required this.exceedsEndLimit,
    required this.densityGPerL,
    required this.densityLevel,
    required this.eaddMeters,
    required this.setpointCapped,
    required this.diluentAboveSetpoint,
  });
}

class GasLimitsResult {
  final ModCalculatorMode mode;

  /// The mix actually computed, after the mode's clamping.
  final double o2Percent;
  final double hePercent;

  /// The ppO2 the headline MOD is computed for.
  final double modPpO2;

  /// Rec and OC Tec: MOD at the working ppO2. CCR Tec: diluent MOD at the
  /// flush ppO2. Exact; round down for display.
  final double modMeters;

  /// Rec: contingency MOD at 1.6. OC Tec: MOD at the deco ppO2. Null on CCR.
  final double? secondaryModMeters;
  final double? secondaryPpO2;

  /// Tec modes: shallowest depth the mix may be breathed at, 0 when it is
  /// breathable from the surface. Null in Rec.
  final double? minDepthMeters;

  /// Tec modes: deepest depth within the END limit. Null in Rec, and when
  /// the mix stays within the limit to any practical depth.
  final double? mndMeters;

  final DepthAssessment atMod;
  final DepthAssessment? atTarget;

  /// Rec: the MOD lies deeper than [recreationalDepthLimitMeters].
  final bool beyondRecreationalLimit;

  final bool targetBeyondMod;
  final bool targetShallowerThanMinDepth;

  /// CCR: the setpoint is not below the flush ppO2.
  final bool setpointNotBelowFlushPpO2;

  const GasLimitsResult({
    required this.mode,
    required this.o2Percent,
    required this.hePercent,
    required this.modPpO2,
    required this.modMeters,
    required this.secondaryModMeters,
    required this.secondaryPpO2,
    required this.minDepthMeters,
    required this.mndMeters,
    required this.atMod,
    required this.atTarget,
    required this.beyondRecreationalLimit,
    required this.targetBeyondMod,
    required this.targetShallowerThanMinDepth,
    required this.setpointNotBelowFlushPpO2,
  });
}

/// Every limit of a breathing gas for the MOD calculator.
///
/// Rec keeps the flat 1 bar per 10 m model the dive log uses. The Tec modes
/// follow [DiveEnvironment] for the water type and take the gas at depth,
/// its density and EADD from [computeGasDensity], so the CCR loop model and
/// the density match the gas density calculator exactly.
GasLimitsResult computeGasLimits(GasLimitsInputs inputs) {
  final isRec = inputs.mode == ModCalculatorMode.rec;
  final isCcr = inputs.mode == ModCalculatorMode.ccrTec;
  final o2 = isRec
      ? inputs.o2Percent.clamp(recMinO2Percent, recMaxO2Percent).toDouble()
      : inputs.o2Percent.clamp(1.0, 100.0).toDouble();
  final he = isRec ? 0.0 : inputs.hePercent.clamp(0.0, 100.0 - o2).toDouble();
  final fO2 = o2 / 100;
  final environment = isRec
      ? null
      : DiveEnvironment.forConditions(waterType: inputs.waterType);

  final modPpO2 = isCcr ? inputs.flushPpO2 : inputs.workingPpO2;
  final mod = maxOperatingDepthMeters(
    fO2,
    maxPpO2: modPpO2,
    environment: environment,
  );

  final secondaryPpO2 = switch (inputs.mode) {
    ModCalculatorMode.rec => recContingencyPpO2,
    ModCalculatorMode.ocTec => inputs.decoPpO2,
    ModCalculatorMode.ccrTec => null,
  };
  final secondaryMod = secondaryPpO2 == null
      ? null
      : maxOperatingDepthMeters(
          fO2,
          maxPpO2: secondaryPpO2,
          environment: environment,
        );

  final minDepth = isRec
      ? null
      : minimumOperatingDepthMeters(
          fO2,
          minPpO2: inputs.minPpO2,
          environment: environment,
        );

  DepthAssessment assess(double depth) => _assess(
    inputs: inputs,
    o2: o2,
    he: he,
    depth: depth,
    environment: environment,
  );

  final target = inputs.targetDepthMeters;
  final atTarget = target == null ? null : assess(math.max(target, 0.0));

  return GasLimitsResult(
    mode: inputs.mode,
    o2Percent: o2,
    hePercent: he,
    modPpO2: modPpO2,
    modMeters: mod,
    secondaryModMeters: secondaryMod,
    secondaryPpO2: secondaryPpO2,
    minDepthMeters: minDepth,
    mndMeters: isRec ? null : _mnd(inputs.endLimitMeters, assess),
    atMod: assess(math.max(mod, 0.0)),
    atTarget: atTarget,
    beyondRecreationalLimit: isRec && mod > recreationalDepthLimitMeters,
    targetBeyondMod: target != null && target > mod,
    targetShallowerThanMinDepth:
        target != null && minDepth != null && target < minDepth,
    setpointNotBelowFlushPpO2: isCcr && inputs.setpointBar >= inputs.flushPpO2,
  );
}

DepthAssessment _assess({
  required GasLimitsInputs inputs,
  required double o2,
  required double he,
  required double depth,
  required DiveEnvironment? environment,
}) {
  final double pO2;
  final double pN2;
  final double pHe;
  GasDensityResult? density;

  if (environment == null) {
    // Rec: open circuit on the flat model, no density.
    final ambient = 1.0 + depth / 10.0;
    pO2 = o2 / 100 * ambient;
    pN2 = (100.0 - o2 - he) / 100 * ambient;
    pHe = he / 100 * ambient;
  } else {
    density = computeGasDensity(
      GasDensityInputs(
        o2Percent: o2,
        hePercent: he,
        depthMeters: depth,
        setpointBar: inputs.mode == ModCalculatorMode.ccrTec
            ? inputs.setpointBar
            : null,
        temperature: GasDensityTemperature.zeroC,
        waterType: inputs.waterType,
      ),
    );
    pO2 = density.pO2Bar;
    pN2 = density.pN2Bar;
    pHe = density.pHeBar;
  }

  double depthAt(double bar) {
    final meters = environment == null
        ? (bar - 1.0) * 10.0
        : environment.depthAtPressure(bar);
    return math.max(meters, 0.0);
  }

  final ead = depthAt(pN2 / airN2Fraction);
  final end = depthAt(pN2 + pO2);
  final narcotic = inputs.o2Narcotic ? end : ead;

  return DepthAssessment(
    depthMeters: depth,
    pO2Bar: pO2,
    pN2Bar: pN2,
    pHeBar: pHe,
    eadMeters: ead,
    endMeters: end,
    narcoticDepthMeters: narcotic,
    exceedsEndLimit: narcotic > inputs.endLimitMeters,
    densityGPerL: density?.densityGPerL,
    densityLevel: density == null
        ? null
        : gasDensityLevelForDisplay(density.densityGPerL, 2),
    eaddMeters: density?.eaddMeters,
    setpointCapped: density?.setpointCapped ?? false,
    diluentAboveSetpoint: density?.diluentAboveSetpoint ?? false,
  );
}

/// Deepest depth whose narcotic depth stays within [endLimit].
///
/// Bisection rather than a closed form, because on a CCR loop the gas
/// changes with depth: the narcotic depth still only grows with depth, so
/// the search is well defined for every mode.
double? _mnd(double endLimit, DepthAssessment Function(double) assess) {
  if (assess(_mndSearchCeilingMeters).narcoticDepthMeters <= endLimit) {
    return null;
  }
  var low = 0.0;
  var high = _mndSearchCeilingMeters;
  if (assess(low).narcoticDepthMeters > endLimit) return 0;
  for (var i = 0; i < 60; i++) {
    final mid = (low + high) / 2;
    if (assess(mid).narcoticDepthMeters > endLimit) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return low;
}
