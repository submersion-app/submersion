import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart'
    show airN2Fraction;
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/deco/max_operating_depth.dart'
    show maxOperatingDepthMeters;
import 'package:submersion/core/utils/number_display.dart'
    show floorToFractionDigits;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart'
    show GasDensityTemperature;
import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart'
    show ambientPressureAtDepth;

/// Standard mixes a fill station is likely to have, richest first.
const List<double> _standardO2Percentages = [50, 40, 36, 32, 30, 28, 21];

/// The Best Mix calculator's three modes (issue #3112), mirroring the MOD
/// calculator's Rec/OC-Tec/CCR-Tec split (issue #2342).
enum BestMixMode { rec, ocTec, ccrTec }

/// CCR-Tec's choice of which ppO2 limit the suggestion is built against.
/// Not a loop model: both sources treat the gas as breathed open circuit,
/// either the diluent on a flush or the bailout cylinder.
enum CcrGasSource { diluent, bailout }

/// Why helium was added to the recommended mix, shown to the diver so a
/// number is never presented without the reason behind it.
enum HeliumDriver { none, endLimit, density, both }

class BestMixInputs {
  final double depthMeters;

  /// Rec: one of the three ppO2 chips. OC-Tec, and CCR-Tec with
  /// [CcrGasSource.bailout]: the resolved working ppO2 limit.
  final double ppO2Limit;

  final double endLimitMeters;
  final bool o2Narcotic;

  final BestMixMode mode;

  /// Read only when [mode] is [BestMixMode.ccrTec].
  final CcrGasSource ccrSource;

  /// The diluent's flush ppO2 limit. Read only when [mode] is
  /// [BestMixMode.ccrTec] and [ccrSource] is [CcrGasSource.diluent].
  final double flushPpO2;

  /// Water type for the Tec modes' ambient pressure model. Read only
  /// outside [BestMixMode.rec], which keeps the flat 1 bar/10 m model.
  final WaterType waterType;

  /// Whether the Tec modes also add helium to keep gas density within the
  /// critical limit, not just the END limit. Read only outside
  /// [BestMixMode.rec], which never considers density in the mix itself.
  final bool densityAware;

  /// Gas temperature for the density calculation. Read only outside
  /// [BestMixMode.rec].
  final GasDensityTemperature temperature;

  const BestMixInputs({
    required this.depthMeters,
    required this.ppO2Limit,
    required this.endLimitMeters,
    required this.o2Narcotic,
    this.mode = BestMixMode.rec,
    this.ccrSource = CcrGasSource.diluent,
    this.flushPpO2 = 0,
    this.waterType = WaterType.salt,
    this.densityAware = false,
    this.temperature = GasDensityTemperature.zeroC,
  });

  BestMixInputs copyWith({
    double? depthMeters,
    double? ppO2Limit,
    double? endLimitMeters,
    bool? o2Narcotic,
    BestMixMode? mode,
    CcrGasSource? ccrSource,
    double? flushPpO2,
    WaterType? waterType,
    bool? densityAware,
    GasDensityTemperature? temperature,
  }) => BestMixInputs(
    depthMeters: depthMeters ?? this.depthMeters,
    ppO2Limit: ppO2Limit ?? this.ppO2Limit,
    endLimitMeters: endLimitMeters ?? this.endLimitMeters,
    o2Narcotic: o2Narcotic ?? this.o2Narcotic,
    mode: mode ?? this.mode,
    ccrSource: ccrSource ?? this.ccrSource,
    flushPpO2: flushPpO2 ?? this.flushPpO2,
    waterType: waterType ?? this.waterType,
    densityAware: densityAware ?? this.densityAware,
    temperature: temperature ?? this.temperature,
  );

  bool get _isTec => mode != BestMixMode.rec;

  /// The ppO2 the suggestion is actually built against: [ppO2Limit] for Rec
  /// and OC-Tec, [flushPpO2] for CCR-Tec with the diluent source, and
  /// [ppO2Limit] again for CCR-Tec with the bailout source (the OC working
  /// limit).
  ///
  /// Exposed on [BestMixResult] as `limitPpO2` so the UI reads one resolved
  /// number rather than re-deriving this switch in every card.
  double get limitPpO2 =>
      mode == BestMixMode.ccrTec && ccrSource == CcrGasSource.diluent
      ? flushPpO2
      : ppO2Limit;
}

/// A candidate mix scored against the target depth.
///
/// Every limit here belongs to THIS mix, not to the idealised fraction it was
/// rounded from. Showing a mix without its own MOD is how the previous
/// implementation recommended a gas that was already exceeded at depth.
class MixAssessment {
  final GasMix mix;

  /// MOD of this mix at the requested ppO2 limit.
  final double modMeters;

  /// How much deeper this mix may be taken than the target depth.
  /// Negative means the mix is already exceeded at the target depth.
  final double marginMeters;

  /// END (N2 and O2 narcotic) or EAD (N2 only), whichever the O2-narcotic
  /// setting selects. Unchanged meaning from before the Tec modes existed.
  final double endMeters;

  /// Equivalent air depth (N2 only narcotic), computed alongside
  /// [endMeters] outside Rec so both are visible regardless of the
  /// O2-narcotic setting. Null in Rec, where only the single row the
  /// setting selects is shown, same as before the Tec modes existed.
  final double? eadMeters;

  final bool exceedsEndLimit;

  final double densityGPerL;
  final bool exceedsWarnDensity;
  final bool exceedsCriticalDensity;

  const MixAssessment({
    required this.mix,
    required this.modMeters,
    required this.marginMeters,
    required this.endMeters,
    this.eadMeters,
    required this.exceedsEndLimit,
    required this.densityGPerL,
    required this.exceedsWarnDensity,
    required this.exceedsCriticalDensity,
  });
}

class BestMixResult {
  /// The mix this calculator recommends. Carries helium when the diver's END
  /// limit, or (Tec modes with the density switch on) gas density, requires
  /// it.
  final MixAssessment recommended;

  /// The best mix available without helium, present only when [recommended]
  /// contains helium.
  ///
  /// A recreational diver at 34 m is unlikely to be filling trimix, so the UI
  /// shows this alongside the recommendation with its own END and density so
  /// the trade-off is visible rather than implied.
  final MixAssessment? nitroxAlternative;

  /// The exact, unrounded ideal O2 percentage.
  final double idealO2Percent;

  /// Nearest commonly stocked nitrox whose MOD still covers the target depth.
  /// Advisory only, and never shallower than the dive.
  final GasMix? nearestStandardMix;

  /// Why helium was added to [recommended], [HeliumDriver.none] when none
  /// was needed.
  final HeliumDriver heliumDriver;

  /// The ppO2 the suggestion was built against (see
  /// [BestMixInputs.limitPpO2]), resolved once here so the UI never
  /// re-derives the Rec/OC-Tec/CCR-Tec switch itself.
  final double limitPpO2;

  const BestMixResult({
    required this.recommended,
    required this.nitroxAlternative,
    required this.idealO2Percent,
    required this.nearestStandardMix,
    this.heliumDriver = HeliumDriver.none,
    required this.limitPpO2,
  });
}

/// The Tec modes' ambient pressure model, null for Rec's flat model.
DiveEnvironment? _environmentFor(BestMixInputs inputs) => inputs._isTec
    ? DiveEnvironment.forConditions(waterType: inputs.waterType)
    : null;

/// Absolute ambient pressure at [depthMeters] under [environment], or the
/// flat 1 bar/10 m model when it is null.
double _ambientAt(double depthMeters, DiveEnvironment? environment) =>
    environment == null
    ? ambientPressureAtDepth(depthMeters)
    : environment.pressureAtDepth(depthMeters);

MixAssessment _assess(
  GasMix mix,
  BestMixInputs inputs,
  DiveEnvironment? environment,
) {
  final mod = maxOperatingDepthMeters(
    mix.o2 / 100,
    maxPpO2: inputs.limitPpO2,
    environment: environment,
  );

  final double end;
  double? ead;
  double density;

  if (environment == null) {
    // Rec: today's flat model, unchanged. Note this is a different density
    // formula from the Tec branch below, not just a different ambient
    // model: `gasDensityGPerL`'s fixed 24.04 L/mol molar volume implies a
    // gas temperature of roughly 16 C, where the Tec branch takes an
    // explicit temperature (defaulting to a conservative 0 C). The two
    // branches can therefore show a slightly different density for the
    // same mix and depth; this is the accepted Rec/Tec trade-off already
    // made for the ambient-pressure model, not a new one.
    end = mix.end(inputs.depthMeters, o2Narcotic: inputs.o2Narcotic);
    density = gasDensityGPerL(
      fO2: mix.o2 / 100,
      fHe: mix.he / 100,
      ambientPressureBar: ambientPressureAtDepth(inputs.depthMeters),
    );
  } else {
    final ambient = environment.pressureAtDepth(inputs.depthMeters);
    final fO2 = mix.o2 / 100;
    final fHe = mix.he / 100;
    final fN2 = 1.0 - fO2 - fHe;
    final pO2 = fO2 * ambient;
    final pN2 = fN2 * ambient;
    final pHe = fHe * ambient;
    double depthAt(double bar) =>
        math.max(environment.depthAtPressure(bar), 0.0);
    final endMeters = depthAt(pN2 + pO2);
    final eadMeters = depthAt(pN2 / airN2Fraction);
    end = inputs.o2Narcotic ? endMeters : eadMeters;
    ead = eadMeters;
    density = gasDensityFromPartialPressures(
      pO2Bar: pO2,
      pN2Bar: pN2,
      pHeBar: pHe,
      temperatureC: inputs.temperature.celsius,
    );
  }

  return MixAssessment(
    mix: mix,
    modMeters: mod,
    marginMeters: mod - inputs.depthMeters,
    endMeters: end,
    eadMeters: ead,
    exceedsEndLimit: end > inputs.endLimitMeters + 1e-9,
    densityGPerL: density,
    exceedsWarnDensity: density > gasDensityWarnGPerL,
    exceedsCriticalDensity: density > gasDensityCriticalGPerL,
  );
}

/// Helium percent needed to bring [o2]'s narcotic depth at [endLimit]
/// within limits for a dive to [targetDepthMeters].
///
/// [environment] null delegates to [GasMix.heForMnd]'s flat model
/// unchanged (Rec). Otherwise this is the same algebra, with the flat
/// ambient-pressure formula replaced by [environment]'s own model, so the
/// result is checked against the same pressures [_assess] uses for the Tec
/// modes. [GasMix.heForMnd] always uses the flat model internally, so
/// calling it directly for a Tec mode would compute a requirement against a
/// different ambient pressure than the one the mix is actually assessed
/// against, most visibly in fresh water.
double _heForNarcosisLimit({
  required double targetDepthMeters,
  required double o2,
  required double endLimit,
  required bool o2Narcotic,
  required DiveEnvironment? environment,
}) {
  if (environment == null) {
    return GasMix.heForMnd(
      targetDepthMeters,
      o2,
      endLimit: endLimit,
      o2Narcotic: o2Narcotic,
    );
  }
  final targetPressure = environment.pressureAtDepth(endLimit);
  final maxPressure = environment.pressureAtDepth(targetDepthMeters);
  final he = o2Narcotic
      ? (1 - targetPressure / maxPressure) * 100
      : 100 - o2 - (targetPressure * airN2Fraction / maxPressure * 100);
  return he.clamp(0.0, 100.0 - o2);
}

/// Helium percent needed to bring the density of [o2Percent] nitrox/trimix
/// down to [gasDensityCriticalGPerL] at [ambientBar] and [temperature].
/// Zero when the nitrox mix alone is already compliant.
///
/// Closed form, not a search: at fixed O2 and ambient pressure, density is
/// affine in the helium fraction, since helium displaces nitrogen only:
///
/// `density(fHe) = ambient/(R*T) * [fO2*Mo2 + (1-fO2)*Mn2 + fHe*(Mhe-Mn2)]`
///
/// `Mhe < Mn2`, so the coefficient of `fHe` is negative: density strictly
/// decreases as helium increases, and the mix is compliant for every `fHe`
/// at or above the solution of `density(fHe) = gasDensityCriticalGPerL`.
double _heForDensityLimitAt(
  double ambientBar,
  double o2Percent,
  GasDensityTemperature temperature,
) {
  final fO2 = o2Percent.clamp(0.0, 100.0) / 100;
  final kelvin = temperature.celsius + 273.15;
  final a = ambientBar / (gasConstantLBarPerMolK * kelvin);
  final base = fO2 * o2MolarMassGPerMol + (1 - fO2) * n2MolarMassGPerMol;
  const slope = heMolarMassGPerMol - n2MolarMassGPerMol; // negative
  final fHe = (gasDensityCriticalGPerL / a - base) / slope;
  return (fHe * 100).clamp(0.0, 100.0 - o2Percent);
}

/// Helium percent needed to bring the density of [o2Percent] nitrox/trimix
/// down to [gasDensityCriticalGPerL] at [depthMeters], [temperature] and
/// [waterType]. Zero when the nitrox mix alone is already compliant.
///
/// Public, standalone entry point for [_heForDensityLimitAt]; used directly
/// by tests and by any caller that has not already resolved an ambient
/// pressure. [computeBestMix] calls [_heForDensityLimitAt] instead, reusing
/// the ambient pressure it already computed rather than rebuilding the
/// [DiveEnvironment] a second time for the same depth and water type.
double heForDensityLimit(
  double depthMeters,
  double o2Percent, {
  required GasDensityTemperature temperature,
  required WaterType waterType,
}) {
  final ambient = DiveEnvironment.forConditions(
    waterType: waterType,
  ).pressureAtDepth(math.max(depthMeters, 0.0));
  return _heForDensityLimitAt(ambient, o2Percent, temperature);
}

double _ceilToStep(double value, double step) => (value / step).ceil() * step;

/// Compute the best breathing mix for a target depth.
///
/// Rounding is always toward safety: O2 DOWN to a whole percent, so the
/// recommended mix's MOD is at or beyond the target depth; helium UP to 5%
/// for the END-driven requirement (more helium is less narcosis), and UP to
/// 1% for the density-driven requirement (Tec modes, [BestMixInputs.densityAware]),
/// which does not need the same coarse step since it is not matched against
/// a named fill-station mix.
///
/// The previous implementation bucketed the ideal fraction UP into a named
/// mix, which at 111 ft recommended EAN32 -- whose own MOD at ppO2 1.4 is
/// 110.7 ft, shallower than the dive.
BestMixResult computeBestMix(BestMixInputs inputs) {
  final environment = _environmentFor(inputs);
  final ambient = _ambientAt(inputs.depthMeters, environment);
  final limitPpO2 = inputs.limitPpO2;
  final ideal = limitPpO2 / ambient * 100;

  // Round DOWN so the resulting MOD is at or beyond the target depth.
  final o2 = floorToFractionDigits(ideal, 0).clamp(1.0, 100.0);

  final nitrox = _assess(GasMix(o2: o2), inputs, environment);

  var recommended = nitrox;
  MixAssessment? alternative;
  var driver = HeliumDriver.none;

  final heForEnd = nitrox.exceedsEndLimit
      ? _ceilToStep(
          _heForNarcosisLimit(
            targetDepthMeters: inputs.depthMeters,
            o2: o2,
            endLimit: inputs.endLimitMeters,
            o2Narcotic: inputs.o2Narcotic,
            environment: environment,
          ),
          5,
        ).clamp(0.0, 100.0 - o2)
      : 0.0;

  final heForDensity = inputs.densityAware && inputs._isTec
      ? _ceilToStep(
          _heForDensityLimitAt(ambient, o2, inputs.temperature),
          1,
        ).clamp(0.0, 100.0 - o2)
      : 0.0;

  final he = math.max(heForEnd, heForDensity);
  if (he > 0) {
    recommended = _assess(GasMix(o2: o2, he: he), inputs, environment);
    alternative = nitrox;
    driver = heForEnd > 0 && heForDensity > 0
        ? HeliumDriver.both
        : heForEnd > 0
        ? HeliumDriver.endLimit
        : HeliumDriver.density;
  }

  GasMix? nearest;
  for (final candidate in _standardO2Percentages) {
    final mod = maxOperatingDepthMeters(
      candidate / 100,
      maxPpO2: limitPpO2,
      environment: environment,
    );
    if (mod >= inputs.depthMeters) {
      nearest = GasMix(o2: candidate);
      break;
    }
  }

  return BestMixResult(
    recommended: recommended,
    nitroxAlternative: alternative,
    idealO2Percent: ideal,
    nearestStandardMix: nearest,
    heliumDriver: driver,
    limitPpO2: limitPpO2,
  );
}
