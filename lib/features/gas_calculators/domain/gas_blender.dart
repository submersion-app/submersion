import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';

export 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart'
    show BlendGasModel, zFactor, kReferenceTempC, celsiusToKelvin;

/// Partial-pressure gas blending with a selectable equation of state.
///
/// Given a cylinder's starting fill (pressure + mix) and a desired end fill,
/// this computes the fill order and the intermediate pressures to top up to,
/// using up to three fill gases (e.g. oxygen, air, helium). Helium/nitrox are
/// handled by the same solver: a two-gas linear solve for nitrox targets and a
/// three-gas solve for trimix.
///
/// The conserved quantity is molar density, because mixing adds moles exactly
/// while it adds neither pressure nor volume exactly. That is also what makes
/// two temperatures expressible: the solve itself is temperature-free, and
/// temperature enters only when converting a gauge reading to moles and back.
///
/// All pressures are in bar and all temperatures in Celsius; callers convert
/// for display.

/// Surface-equivalent ("normal") gas volume for [p] bar of mix [m], per unit
/// cylinder volume, at [kReferenceTempC].
///
/// Retained for callers that predate the molar-density rewrite. Equal to
/// `molarDensity(zFactor, p, m, T20) * kGasConstant * T20 * zFactor(1, m)`.
double normalVolume(double p, GasMix m) => p * zFactor(1, m) / zFactor(p, m);

/// Inverse of [normalVolume]: the real pressure (bar) holding surface volume
/// [vol] of mix [m]. Fixed-point iteration (Z depends on the pressure sought).
double pressureForVolume(GasMix m, double vol) {
  var p = vol;
  for (var i = 0; i < 100; i++) {
    final pNew = vol * zFactor(p, m) / zFactor(1, m);
    if ((pNew - p).abs() < 0.0001) {
      p = pNew;
      break;
    }
    p = pNew;
  }
  return p;
}

/// Why a blend cannot be produced. Mapped to a localized message by the UI.
enum BlendError {
  targetPressureNotHigher,
  invalidMix,
  identicalNitroxGases,
  linearlyDependentGases,
  negativeAmountRequired,

  /// The cylinder already holds helium that the target mix does not allow.
  /// Topping up dilutes helium but can never remove it.
  cannotRemoveHelium,

  /// A helium-free target needs two helium-free fill gases to blend between.
  insufficientFillGases,

  /// The computed procedure does not land on the requested mix. A guard
  /// against a solver that reports a target it did not actually reach.
  targetNotReached,

  /// The cylinder is said to hold pressure but neither oxygen nor helium,
  /// which is 100% nitrogen. No fill station stocks that, so it is far more
  /// likely to be a half-finished entry than a real cylinder (PR #1215): the
  /// blender reported a confident procedure for exactly this phantom fill,
  /// and it disagreed with every other blending tool.
  implausibleStartMix,
}

class BlendException implements Exception {
  const BlendException(this.error, {this.drainToBar});
  final BlendError error;

  /// For [BlendError.negativeAmountRequired]: the pressure the cylinder must
  /// be drained down to before this blend becomes possible, read at the fill
  /// temperature. Null when the blend fails for a reason draining cannot fix.
  final double? drainToBar;
}

/// One line of the fill procedure.
class BlendStep {
  const BlendStep({
    required this.fillGas,
    required this.fillGasIndex,
    required this.pressureBar,
    required this.addedBar,
    required this.resultingMix,
    required this.addedVolumePerLiter,
  });

  /// The gas topped up in this step; null for the starting condition.
  final GasMix? fillGas;

  /// Which configured bank this came from: 0 for [GasBlenderInputs.fillGas1],
  /// 1 for fillGas2, 2 for fillGas3. Null for the starting condition.
  ///
  /// Carried explicitly because a blend does not always use every bank: a
  /// helium-free target skips the helium source, so the second STEP is the
  /// third BANK. Costing keyed on step order rather than bank charged air at
  /// helium's price (PR #1215 review).
  final int? fillGasIndex;

  /// Fill the cylinder up to this pressure (bar), read at the fill
  /// temperature. For the starting step this is the pressure already in the
  /// cylinder, likewise at the fill temperature.
  final double pressureBar;

  /// How much the gauge moves during this step, in bar. Zero for the starting
  /// step. This is the figure a fill station meters and bills on.
  final double addedBar;

  /// The mix in the cylinder after this step.
  final GasMix resultingMix;

  /// Surface-equivalent volume of [fillGas] added per litre of cylinder
  /// volume, referenced to the settled temperature; null for the starting
  /// step.
  final double? addedVolumePerLiter;
}

class BlendResult {
  const BlendResult({required this.steps, required this.settledPressureBar});

  /// Starting condition first, then one entry per fill gas. Every pressure is
  /// read at the fill temperature.
  final List<BlendStep> steps;

  /// What the cylinder reads once it equalises at the settled temperature.
  /// This is the target pressure the diver requested, verbatim.
  final double settledPressureBar;
}

class GasBlenderInputs {
  const GasBlenderInputs({
    required this.startPressureBar,
    required this.start,
    required this.targetPressureBar,
    required this.target,
    required this.fillGas1,
    required this.fillGas2,
    required this.fillGas3,
    this.model = BlendGasModel.zFactor,
    this.fillTempC = kReferenceTempC,
    this.settledTempC = kReferenceTempC,
  });

  /// Pressure already in the cylinder, as read at [fillTempC]. It is the gauge
  /// in front of the blender.
  final double startPressureBar;
  final GasMix start;

  /// The pressure the diver wants once the cylinder has equalised at
  /// [settledTempC]. It is the only reading they can later verify.
  final double targetPressureBar;
  final GasMix target;

  /// Fill gases, applied in this order. A trimix target uses all three; a
  /// helium-free target uses the first two helium-free ones and skips the
  /// helium source.
  final GasMix fillGas1;
  final GasMix fillGas2;
  final GasMix fillGas3;

  final BlendGasModel model;

  /// Temperature of the cylinder while it is being filled.
  final double fillTempC;

  /// Temperature the cylinder settles to afterwards.
  final double settledTempC;
}

/// Fill amounts smaller than this (mol per litre of cylinder) are treated as
/// nothing. This is the molar equivalent, at [kReferenceTempC], of the 0.01
/// surface litres per litre the blender used before the rewrite: below a
/// hundredth of a bar in a 1 L cylinder, no fill station can meter it and no
/// gauge can show it.
final double _densityTolerance =
    0.01 / (kGasConstant * celsiusToKelvin(kReferenceTempC));

/// Percentage points below which a mix counts as helium-free.
const double _heliumEpsilon = 1e-9;

bool _isHeliumFree(GasMix m) => m.he <= _heliumEpsilon;

double _fO2(GasMix m) => m.o2 / 100;
double _fHe(GasMix m) => m.he / 100;
double _fN2(GasMix m) => (100 - m.o2 - m.he) / 100;

void _validateMix(GasMix m) {
  if (m.o2 < 0 || m.he < 0 || m.o2 + m.he > 100) {
    throw const BlendException(BlendError.invalidMix);
  }
}

GasMix _blend(GasMix a, double volA, GasMix b, double volB) {
  final total = volA + volB;
  if (total <= 0) return a;
  return GasMix(
    o2: 100 * (_fO2(a) * volA + _fO2(b) * volB) / total,
    he: 100 * (_fHe(a) * volA + _fHe(b) * volB) / total,
  );
}

/// Which banks to draw from for [target], in fill order, as indices into
/// [available].
///
/// The configured order is a fill sequence, not a fixed set of roles: the
/// default is O2 -> helium -> air so that the compressor tops off last, which
/// is how a fill station actually works. A helium-free target therefore has to
/// skip the helium source rather than blend with it, otherwise it would report
/// a nitrox mix while producing a trimix.
List<int> _selectFillGases(GasMix target, List<GasMix> available) {
  if (!_isHeliumFree(target)) {
    return [for (var i = 0; i < available.length; i++) i];
  }
  final heliumFree = [
    for (var i = 0; i < available.length; i++)
      if (_isHeliumFree(available[i])) i,
  ];
  if (heliumFree.length < 2) {
    throw const BlendException(BlendError.insufficientFillGases);
  }
  return heliumFree.take(2).toList();
}

/// Molar amount of each gas in [gases] needed to turn [startVol] of [start]
/// into [targetVol] of [target], per litre of cylinder volume.
///
/// Amounts may come back negative: that means the cylinder already holds gas
/// the target cannot accommodate, which the caller turns into drain guidance.
/// Throws only when the gas set cannot produce the target at any amount.
List<double> _solveTops({
  required GasMix start,
  required double startVol,
  required GasMix target,
  required double targetVol,
  required List<GasMix> gases,
}) {
  if (gases.length == 3) {
    final g1 = gases[0];
    final g2 = gases[1];
    final g3 = gases[2];

    final det =
        _fHe(g3) * _fN2(g2) * _fO2(g1) -
        _fHe(g2) * _fN2(g3) * _fO2(g1) -
        _fHe(g3) * _fN2(g1) * _fO2(g2) +
        _fHe(g1) * _fN2(g3) * _fO2(g2) +
        _fHe(g2) * _fN2(g1) * _fO2(g3) -
        _fHe(g1) * _fN2(g2) * _fO2(g3);
    if (det.abs() < 1e-10) {
      throw const BlendException(BlendError.linearlyDependentGases);
    }

    final df = [
      _fHe(target) * targetVol - _fHe(start) * startVol,
      _fN2(target) * targetVol - _fN2(start) * startVol,
      _fO2(target) * targetVol - _fO2(start) * startVol,
    ];

    return [
      ((_fN2(g3) * _fO2(g2) - _fN2(g2) * _fO2(g3)) * df[0] +
              (_fHe(g2) * _fO2(g3) - _fHe(g3) * _fO2(g2)) * df[1] +
              (_fHe(g3) * _fN2(g2) - _fHe(g2) * _fN2(g3)) * df[2]) /
          det,
      ((_fN2(g1) * _fO2(g3) - _fN2(g3) * _fO2(g1)) * df[0] +
              (_fHe(g3) * _fO2(g1) - _fHe(g1) * _fO2(g3)) * df[1] +
              (_fHe(g1) * _fN2(g3) - _fHe(g3) * _fN2(g1)) * df[2]) /
          det,
      ((_fN2(g2) * _fO2(g1) - _fN2(g1) * _fO2(g2)) * df[0] +
              (_fHe(g1) * _fO2(g2) - _fHe(g2) * _fO2(g1)) * df[1] +
              (_fHe(g2) * _fN2(g1) - _fHe(g1) * _fN2(g2)) * df[2]) /
          det,
    ];
  }

  final g1 = gases[0];
  final g2 = gases[1];
  if ((_fO2(g1) - _fO2(g2)).abs() < 0.001) {
    throw const BlendException(BlendError.identicalNitroxGases);
  }
  final top1 =
      (_fO2(g2) - _fO2(target)) / (_fO2(g2) - _fO2(g1)) * targetVol -
      (_fO2(g2) - _fO2(start)) / (_fO2(g2) - _fO2(g1)) * startVol;
  return [top1, (targetVol - startVol) - top1];
}

/// The largest starting amount that still blends, or null when even an empty
/// cylinder cannot produce the target from these gases.
///
/// Every fill amount is affine in the starting amount, so the feasible set is
/// an interval. When an empty cylinder is feasible that interval starts at
/// zero, which makes feasibility monotonic and a bisection exact.
double? _largestFeasibleStartVolume({
  required GasMix start,
  required double startVol,
  required GasMix target,
  required double targetVol,
  required List<GasMix> gases,
}) {
  bool feasible(double v) {
    try {
      return _solveTops(
        start: start,
        startVol: v,
        target: target,
        targetVol: targetVol,
        gases: gases,
      ).every((t) => t >= -_densityTolerance);
    } on BlendException {
      return false;
    }
  }

  if (!feasible(0)) return null;

  var lo = 0.0;
  var hi = startVol;
  for (var i = 0; i < 50; i++) {
    final mid = (lo + hi) / 2;
    if (feasible(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Compute the fill procedure to reach the target fill. Throws
/// [BlendException] when the requested blend is not achievable.
BlendResult computeBlend(GasBlenderInputs inputs) {
  final pi = inputs.startPressureBar;
  final pf = inputs.targetPressureBar;
  final gasI = inputs.start;
  final gasF = inputs.target;
  final model = inputs.model;
  final fillK = celsiusToKelvin(inputs.fillTempC);
  final settledK = celsiusToKelvin(inputs.settledTempC);

  if (pf <= pi) {
    throw const BlendException(BlendError.targetPressureNotHigher);
  }
  _validateMix(gasI);
  _validateMix(gasF);
  _validateMix(inputs.fillGas1);
  _validateMix(inputs.fillGas2);
  _validateMix(inputs.fillGas3);

  // A cylinder that holds pressure holds a gas somebody filled it with. Zero
  // oxygen and zero helium is pure nitrogen, which is not one of those, and
  // solving for it produces a plausible-looking procedure for a cylinder that
  // does not exist. An empty cylinder is exempt: it holds nothing by
  // definition, and starting empty is the common case.
  if (pi > 0 && gasI.o2 <= 0 && gasI.he <= 0) {
    throw const BlendException(BlendError.implausibleStartMix);
  }

  // Topping up dilutes helium; it never removes it. Solving the O2 balance
  // alone would report the requested nitrox while leaving helium in the
  // cylinder, and an O2 analyser would confirm the wrong label.
  if (_isHeliumFree(gasF) && !_isHeliumFree(gasI)) {
    throw const BlendException(BlendError.cannotRemoveHelium);
  }

  final banks = [inputs.fillGas1, inputs.fillGas2, inputs.fillGas3];
  final bankOrder = _selectFillGases(gasF, banks);
  final gases = [for (final i in bankOrder) banks[i]];

  // The start pressure is a gauge reading taken while the cylinder is at the
  // fill temperature; the target is what it must read once settled.
  final iVol = molarDensity(model, pi, gasI, fillK);
  final fVol = molarDensity(model, pf, gasF, settledK);

  final tops = _solveTops(
    start: gasI,
    startVol: iVol,
    target: gasF,
    targetVol: fVol,
    gases: gases,
  );

  if (tops.any((t) => t < -_densityTolerance)) {
    final drainVol = _largestFeasibleStartVolume(
      start: gasI,
      startVol: iVol,
      target: gasF,
      targetVol: fVol,
      gases: gases,
    );
    throw BlendException(
      BlendError.negativeAmountRequired,
      drainToBar: drainVol == null
          ? null
          : pressureAt(model, drainVol, gasI, fillK),
    );
  }

  final steps = <BlendStep>[
    BlendStep(
      fillGas: null,
      fillGasIndex: null,
      pressureBar: pi,
      addedBar: 0,
      resultingMix: gasI,
      addedVolumePerLiter: null,
    ),
  ];

  var mix = gasI;
  var vol = iVol;
  var previousBar = pi;
  for (var i = 0; i < gases.length; i++) {
    final top = tops[i];
    // A gas the blend does not need is left out rather than listed as a fill
    // to the pressure already in the cylinder.
    if (top.abs() < _densityTolerance) continue;
    mix = _blend(mix, vol, gases[i], top);
    vol += top;
    final bar = pressureAt(model, vol, mix, fillK);
    steps.add(
      BlendStep(
        fillGas: gases[i],
        fillGasIndex: bankOrder[i],
        pressureBar: bar,
        addedBar: bar - previousBar,
        resultingMix: mix,
        // Reported as a surface-equivalent volume at the settled temperature,
        // which is the figure a bank gauge and a gas invoice both speak in.
        addedVolumePerLiter: top * kGasConstant * settledK,
      ),
    );
    previousBar = bar;
  }

  // The final reading comes from the exact target state, not from the running
  // total, which carries the drift of every intermediate inversion. When the
  // cylinder is filled at its settled temperature that reading is the pressure
  // the diver typed, so use it verbatim rather than handing back an
  // iteration's approximation of their own number.
  if (steps.length > 1) {
    final last = steps.removeLast();
    final finalBar = inputs.fillTempC == inputs.settledTempC
        ? pf
        : pressureAt(model, fVol, gasF, fillK);
    steps.add(
      BlendStep(
        fillGas: last.fillGas,
        fillGasIndex: last.fillGasIndex,
        pressureBar: finalBar,
        addedBar: finalBar - steps.last.pressureBar,
        resultingMix: last.resultingMix,
        addedVolumePerLiter: last.addedVolumePerLiter,
      ),
    );
  }

  // Never report a mix that was not computed from the gas actually added.
  if ((mix.o2 - gasF.o2).abs() > 0.01 || (mix.he - gasF.he).abs() > 0.01) {
    throw const BlendException(BlendError.targetNotReached);
  }

  return BlendResult(steps: steps, settledPressureBar: pf);
}
