import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// Partial-pressure gas blending with real-gas (Van der Waals) behaviour.
///
/// Given a cylinder's starting fill (pressure + mix) and a desired end fill,
/// this computes the fill order and the intermediate pressures to top up to,
/// using up to three fill gases (e.g. oxygen, air, helium). Helium/nitrox are
/// handled by the same solver: a two-gas linear solve for nitrox targets and a
/// three-gas solve for trimix.
///
/// Ported from the Blei-Log blender. All pressures are in bar; the virial
/// coefficients are calibrated for bar, so callers must convert other pressure
/// units before calling and convert results back for display.

// Virial coefficients (bar) for the compressibility factor of each component.
const List<double> _o2Coef = [
  -7.18092073703e-04,
  2.81852572808e-06,
  -1.50290620492e-09,
];
const List<double> _n2Coef = [
  -2.19260353292e-04,
  2.92844845532e-06,
  -2.07613482075e-09,
];
const List<double> _heCoef = [
  4.87320026468e-04,
  -8.83632921053e-08,
  5.33304543646e-11,
];

double _virial(double p, List<double> c) =>
    c[0] * p + c[1] * p * p + c[2] * p * p * p;

double _fO2(GasMix m) => m.o2 / 100;
double _fHe(GasMix m) => m.he / 100;
double _fN2(GasMix m) => (100 - m.o2 - m.he) / 100;

/// Real-gas compressibility factor Z of [m] at pressure [p] bar.
double zFactor(double p, GasMix m) =>
    1 +
    _fO2(m) * _virial(p, _o2Coef) +
    _fHe(m) * _virial(p, _heCoef) +
    _fN2(m) * _virial(p, _n2Coef);

/// Surface-equivalent ("normal") gas volume for [p] bar of mix [m], per unit
/// cylinder volume.
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
}

class BlendException implements Exception {
  const BlendException(this.error);
  final BlendError error;
}

/// One line of the fill procedure.
class BlendStep {
  const BlendStep({
    required this.fillGas,
    required this.pressureBar,
    required this.resultingMix,
    required this.addedVolumePerLiter,
  });

  /// The gas topped up in this step; null for the starting condition.
  final GasMix? fillGas;

  /// Fill the cylinder up to this pressure (bar). For the starting step this
  /// is the pressure already in the cylinder.
  final double pressureBar;

  /// The mix in the cylinder after this step.
  final GasMix resultingMix;

  /// Surface-equivalent volume of [fillGas] added per litre of cylinder
  /// volume; null for the starting step.
  final double? addedVolumePerLiter;
}

class BlendResult {
  const BlendResult({required this.steps});

  /// Starting condition first, then one entry per fill gas.
  final List<BlendStep> steps;
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
  });

  final double startPressureBar;
  final GasMix start;
  final double targetPressureBar;
  final GasMix target;

  /// Fill gases, applied in order. Nitrox targets use the first two; trimix
  /// targets use all three.
  final GasMix fillGas1;
  final GasMix fillGas2;
  final GasMix fillGas3;
}

void _validateMix(GasMix m) {
  if (m.o2 < 0 || m.he < 0 || m.o2 + m.he > 100) {
    throw const BlendException(BlendError.invalidMix);
  }
}

GasMix _blend(GasMix a, double volA, GasMix b, double volB) {
  final total = volA + volB;
  return GasMix(
    o2: 100 * (_fO2(a) * volA + _fO2(b) * volB) / total,
    he: 100 * (_fHe(a) * volA + _fHe(b) * volB) / total,
  );
}

/// Compute the fill procedure to reach the target fill. Throws
/// [BlendException] when the requested blend is not achievable.
BlendResult computeBlend(GasBlenderInputs inputs) {
  final pi = inputs.startPressureBar;
  final pf = inputs.targetPressureBar;
  final gasI = inputs.start;
  final gasF = inputs.target;

  if (pf <= pi) {
    throw const BlendException(BlendError.targetPressureNotHigher);
  }
  _validateMix(gasI);
  _validateMix(gasF);
  _validateMix(inputs.fillGas1);
  _validateMix(inputs.fillGas2);

  final iVol = normalVolume(pi, gasI);
  final fVol = normalVolume(pf, gasF);

  final steps = <BlendStep>[
    BlendStep(
      fillGas: null,
      pressureBar: pi,
      resultingMix: gasI,
      addedVolumePerLiter: null,
    ),
  ];

  if (gasF.he > 0) {
    // Trimix: solve the 3x3 system balancing He/N2/O2 across three fill gases.
    _validateMix(inputs.fillGas3);
    final g1 = inputs.fillGas1;
    final g2 = inputs.fillGas2;
    final g3 = inputs.fillGas3;

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
      _fHe(gasF) * fVol - _fHe(gasI) * iVol,
      _fN2(gasF) * fVol - _fN2(gasI) * iVol,
      _fO2(gasF) * fVol - _fO2(gasI) * iVol,
    ];

    final top1 =
        ((_fN2(g3) * _fO2(g2) - _fN2(g2) * _fO2(g3)) * df[0] +
            (_fHe(g2) * _fO2(g3) - _fHe(g3) * _fO2(g2)) * df[1] +
            (_fHe(g3) * _fN2(g2) - _fHe(g2) * _fN2(g3)) * df[2]) /
        det;
    final top2 =
        ((_fN2(g1) * _fO2(g3) - _fN2(g3) * _fO2(g1)) * df[0] +
            (_fHe(g3) * _fO2(g1) - _fHe(g1) * _fO2(g3)) * df[1] +
            (_fHe(g1) * _fN2(g3) - _fHe(g3) * _fN2(g1)) * df[2]) /
        det;
    final top3 =
        ((_fN2(g2) * _fO2(g1) - _fN2(g1) * _fO2(g2)) * df[0] +
            (_fHe(g1) * _fO2(g2) - _fHe(g2) * _fO2(g1)) * df[1] +
            (_fHe(g2) * _fN2(g1) - _fHe(g1) * _fN2(g2)) * df[2]) /
        det;

    if (top1 < -0.01 || top2 < -0.01 || top3 < -0.01) {
      throw const BlendException(BlendError.negativeAmountRequired);
    }

    final mix1 = _blend(gasI, iVol, g1, top1);
    final p1 = pressureForVolume(mix1, iVol + top1);
    final mix2 = _blend(mix1, iVol + top1, g2, top2);
    final p2 = pressureForVolume(mix2, iVol + top1 + top2);

    steps
      ..add(
        BlendStep(
          fillGas: g1,
          pressureBar: p1,
          resultingMix: mix1,
          addedVolumePerLiter: top1,
        ),
      )
      ..add(
        BlendStep(
          fillGas: g2,
          pressureBar: p2,
          resultingMix: mix2,
          addedVolumePerLiter: top2,
        ),
      )
      ..add(
        BlendStep(
          fillGas: g3,
          pressureBar: pf,
          resultingMix: gasF,
          addedVolumePerLiter: top3,
        ),
      );
  } else {
    // Nitrox: two-gas O2 balance.
    final g1 = inputs.fillGas1;
    final g2 = inputs.fillGas2;
    if ((_fO2(g1) - _fO2(g2)).abs() < 0.001) {
      throw const BlendException(BlendError.identicalNitroxGases);
    }

    final top1 =
        (_fO2(g2) - _fO2(gasF)) / (_fO2(g2) - _fO2(g1)) * fVol -
        (_fO2(g2) - _fO2(gasI)) / (_fO2(g2) - _fO2(g1)) * iVol;
    final top2 =
        (_fO2(g1) - _fO2(gasF)) / (_fO2(g1) - _fO2(g2)) * fVol -
        (_fO2(g1) - _fO2(gasI)) / (_fO2(g1) - _fO2(g2)) * iVol;

    if (top1 <= 0 || top2 < -0.01) {
      throw const BlendException(BlendError.negativeAmountRequired);
    }

    final mix1 = _blend(gasI, iVol, g1, top1);
    final p1 = pressureForVolume(mix1, iVol + top1);

    steps
      ..add(
        BlendStep(
          fillGas: g1,
          pressureBar: p1,
          resultingMix: mix1,
          addedVolumePerLiter: top1,
        ),
      )
      ..add(
        BlendStep(
          fillGas: g2,
          pressureBar: pf,
          resultingMix: gasF,
          addedVolumePerLiter: top2,
        ),
      );
  }

  return BlendResult(steps: steps);
}
