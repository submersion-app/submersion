/// Varying-Permeability Model with Boyle's-law compensation (VPM-B).
///
/// This is a faithful Dart port of Erik C. Baker's canonical FORTRAN VPMDECO
/// as expressed by the BSD-2 licensed `bwaite/vpmb` Python reference. It is
/// deliberately a close, almost line-by-line translation: variable names,
/// operation order, and the (occasionally quirky) unit conventions are
/// preserved so the output can be validated against independently generated
/// golden vectors in `test/core/deco/golden/vpmb_golden.json`.
///
/// Everything here works internally in msw (meters of seawater) at sea level,
/// matching the app's internal metric and the golden generator. The wrapper in
/// `vpm_b.dart` adapts this to the [DecoModel] seam.
///
/// A subtle convention worth flagging: pressure<->atm conversion uses
/// [_unitsFactor] = 10.1325 msw/atm, but sea-level barometric pressure is
/// modeled as exactly 10.0 msw (the European "1 bar per 10 m" convention).
/// This mismatch is inherited from the reference and is required for parity.
library;

import 'dart:math' as math;

const int _arrayLength = 16;

/// ln(2), precomputed (dart:math has no ln2 constant).
final double _ln2 = math.log(2.0);

/// Raised when a numerical root search cannot bracket a solution. In practice
/// never thrown for well-formed recreational/technical square profiles; a throw
/// signals the inputs left the model's valid domain.
class VpmRootException implements Exception {
  VpmRootException(this.message);
  final String message;
  @override
  String toString() => 'VpmRootException: $message';
}

/// Raised when a root search exceeds its iteration budget.
class VpmMaxIterationException implements Exception {
  VpmMaxIterationException(this.message);
  final String message;
  @override
  String toString() => 'VpmMaxIterationException: $message';
}

/// Raised when the chosen ascent step size is too coarse to decompress.
class VpmDecompressionStepException implements Exception {
  VpmDecompressionStepException(this.message);
  final String message;
  @override
  String toString() => 'VpmDecompressionStepException: $message';
}

/// Raised when off-gassing at a stop is too weak to reach the next stop.
class VpmOffGassingException implements Exception {
  VpmOffGassingException(this.message);
  final String message;
  @override
  String toString() => 'VpmOffGassingException: $message';
}

/// VPM-B tuning constants. Defaults match the reference's "standard" settings;
/// only the two critical nucleus radii vary with conservatism.
class VpmBSettings {
  const VpmBSettings({
    required this.criticalRadiusN2Microns,
    required this.criticalRadiusHeMicrons,
    this.surfaceTensionGamma = 0.0179,
    this.skinCompressionGammaC = 0.257,
    this.critVolumeParameterLambda = 7500.0,
    this.regenerationTimeConstant = 20160.0,
    this.gradientOnsetOfImpermAtm = 8.2,
    this.minimumDecoStopTime = 1.0,
    this.criticalVolumeAlgorithmOn = true,
    this.pressureOtherGasesMmHg = 102.0,
  });

  final double criticalRadiusN2Microns;
  final double criticalRadiusHeMicrons;
  final double surfaceTensionGamma;
  final double skinCompressionGammaC;
  final double critVolumeParameterLambda;
  final double regenerationTimeConstant;
  final double gradientOnsetOfImpermAtm;
  final double minimumDecoStopTime;
  final bool criticalVolumeAlgorithmOn;
  final double pressureOtherGasesMmHg;

  /// Subsurface-equivalent conservatism (+0..+4) mapped to critical nucleus
  /// radii. Base 0.55/0.45 micron scaled by {1.0, 1.05, 1.12, 1.22, 1.35}.
  /// Higher level -> larger radius -> smaller allowable gradient -> more deco.
  factory VpmBSettings.forConservatism(int level) {
    const table = <int, (double, double)>{
      0: (0.550, 0.450),
      1: (0.578, 0.473),
      2: (0.616, 0.504),
      3: (0.671, 0.549),
      4: (0.743, 0.608),
    };
    final (rn2, rhe) = table[level.clamp(0, 4)]!;
    return VpmBSettings(
      criticalRadiusN2Microns: rn2,
      criticalRadiusHeMicrons: rhe,
    );
  }
}

/// A breathing mix as inert-gas fractions (O2 is the remainder).
class VpmGasMix {
  const VpmGasMix({required this.fN2, required this.fHe});
  final double fN2;
  final double fHe;
}

/// One leg of the descent/bottom profile fed to the algorithm.
sealed class VpmProfileSegment {
  const VpmProfileSegment();
}

/// A linear ascent or descent at a constant rate (msw/min). Descent (ending
/// deeper than starting) triggers crushing-pressure accumulation.
class VpmDepthChangeSegment extends VpmProfileSegment {
  const VpmDepthChangeSegment({
    required this.startingDepth,
    required this.endingDepth,
    required this.rate,
    required this.mixNumber,
  });
  final double startingDepth;
  final double endingDepth;
  final double rate;
  final int mixNumber;
}

/// A constant-depth (bottom) leg ending at [runTimeAtEndOfSegment] minutes.
class VpmConstantSegment extends VpmProfileSegment {
  const VpmConstantSegment({
    required this.depth,
    required this.runTimeAtEndOfSegment,
    required this.mixNumber,
  });
  final double depth;
  final double runTimeAtEndOfSegment;
  final int mixNumber;
}

/// One entry in the ascent plan: from [startingDepth], breathe [mixNumber] and
/// ascend at [rate] (negative msw/min) using [stepSize] (msw) stop increments.
class VpmAscentChange {
  const VpmAscentChange({
    required this.startingDepth,
    required this.mixNumber,
    required this.rate,
    required this.stepSize,
  });
  final double startingDepth;
  final int mixNumber;
  final double rate;
  final double stepSize;
}

/// A required decompression stop: whole [depth] (msw) for whole [time] (min).
class VpmStop {
  const VpmStop(this.depth, this.time);
  final int depth;
  final int time;

  @override
  String toString() => '[$depth, $time]';
}

/// Schreiner equation: gas loading for a linear (ascent/descent) segment.
double _schreinerEquation(
  double initialInspiredGasPressure,
  double rateChangeInspGasPressure,
  double intervalTime,
  double gasTimeConstant,
  double initialGasPressure,
) {
  return initialInspiredGasPressure +
      rateChangeInspGasPressure * (intervalTime - 1.0 / gasTimeConstant) -
      (initialInspiredGasPressure -
              initialGasPressure -
              rateChangeInspGasPressure / gasTimeConstant) *
          math.exp(-gasTimeConstant * intervalTime);
}

/// Haldane equation: gas loading at constant depth.
double _haldaneEquation(
  double initialGasPressure,
  double inspiredGasPressure,
  double gasTimeConstant,
  double intervalTime,
) {
  return initialGasPressure +
      (inspiredGasPressure - initialGasPressure) *
          (1.0 - math.exp(-gasTimeConstant * intervalTime));
}

/// Python 3 `round()`: round half to even (banker's rounding). Preserved
/// because the reference's stop-time rounding depends on this exact rule.
int _pyRound(double x) {
  final floor = x.floorToDouble();
  final diff = x - floor;
  if (diff < 0.5) return floor.toInt();
  if (diff > 0.5) return floor.toInt() + 1;
  final f = floor.toInt();
  return f.isEven ? f : f + 1;
}

/// Truncate toward zero (Python `int()`/`trunc()` on positive floats).
double _trunc(double x) => x.truncateToDouble();

/// Hybrid bisection / Newton-Raphson root finder for the cubic
/// `A*r^3 - B*r^2 - C = 0`. Faithful port of "Numerical Recipes" rtsafe.
double _radiusRootFinder(
  double a,
  double b,
  double c,
  double lowBound,
  double highBound,
) {
  final functionAtLowBound = lowBound * (lowBound * (a * lowBound - b)) - c;
  final functionAtHighBound = highBound * (highBound * (a * highBound - b)) - c;

  if (functionAtLowBound > 0.0 && functionAtHighBound > 0.0) {
    throw VpmRootException('ROOT IS NOT WITHIN BRACKETS');
  }
  if (functionAtLowBound < 0.0 && functionAtHighBound < 0.0) {
    throw VpmRootException('ROOT IS NOT WITHIN BRACKETS');
  }

  if (functionAtLowBound == 0.0) return lowBound;
  if (functionAtHighBound == 0.0) return highBound;

  double radiusAtLowBound;
  double radiusAtHighBound;
  if (functionAtLowBound < 0.0) {
    radiusAtLowBound = lowBound;
    radiusAtHighBound = highBound;
  } else {
    radiusAtHighBound = lowBound;
    radiusAtLowBound = highBound;
  }

  double endingRadius = 0.5 * (lowBound + highBound);
  double lastDiffChange = (highBound - lowBound).abs();
  double differentialChange = lastDiffChange;

  double function = endingRadius * (endingRadius * (a * endingRadius - b)) - c;
  double derivativeOfFunction =
      endingRadius * (endingRadius * 3.0 * a - 2.0 * b);

  for (var i = 0; i < 100; i++) {
    final aCheck =
        ((endingRadius - radiusAtHighBound) * derivativeOfFunction - function) *
            ((endingRadius - radiusAtLowBound) * derivativeOfFunction -
                function) >=
        0.0;
    final bCheck =
        (2.0 * function).abs() > (lastDiffChange * derivativeOfFunction).abs();

    if (aCheck || bCheck) {
      lastDiffChange = differentialChange;
      differentialChange = 0.5 * (radiusAtHighBound - radiusAtLowBound);
      endingRadius = radiusAtLowBound + differentialChange;
      if (radiusAtLowBound == endingRadius) return endingRadius;
    } else {
      lastDiffChange = differentialChange;
      differentialChange = function / derivativeOfFunction;
      final lastEndingRadius = endingRadius;
      endingRadius -= differentialChange;
      if (lastEndingRadius == endingRadius) return endingRadius;
    }
    if (differentialChange.abs() < 1.0e-12) return endingRadius;

    function = endingRadius * (endingRadius * (a * endingRadius - b)) - c;
    derivativeOfFunction = endingRadius * (endingRadius * 3.0 * a - 2.0 * b);

    if (function < 0.0) {
      radiusAtLowBound = endingRadius;
    } else {
      radiusAtHighBound = endingRadius;
    }
  }
  throw VpmMaxIterationException('ROOT SEARCH EXCEEDED MAXIMUM ITERATIONS');
}

/// Stateful VPM-B engine. Drive it with [computeDive]; it accumulates crushing
/// pressure over the descent, then runs the Critical Volume Algorithm to emit
/// a staged decompression schedule.
class VpmBAlgorithm {
  VpmBAlgorithm(this.settings);

  final VpmBSettings settings;

  // Buhlmann ZH-L16 half-times, shared with the dissolved-gas model but used
  // here only to seed the tissue time constants.
  static const List<double> _heliumHalfTime = [
    1.88, 3.02, 4.72, 6.99, 10.21, 14.48, 20.53, 29.11, //
    41.20, 55.19, 70.69, 90.34, 115.29, 147.42, 188.24, 240.03,
  ];
  static const List<double> _nitrogenHalfTime = [
    5.0, 8.0, 12.5, 18.5, 27.0, 38.3, 54.3, 77.0, //
    109.0, 146.0, 187.0, 239.0, 305.0, 390.0, 498.0, 635.0,
  ];

  // Physical constants (sea level, msw).
  static const double _atm = 101325.0;
  static const double _fractionInertGas = 0.79;
  static const double _unitsFactor = 10.1325;
  static const double _waterVaporPressure = 0.493;
  static const double _barometricPressure = 10.0;

  late double _constantPressureOtherGases;

  // Per-compartment state.
  final _heliumTimeConstant = List<double>.filled(_arrayLength, 0.0);
  final _nitrogenTimeConstant = List<double>.filled(_arrayLength, 0.0);
  final _heliumPressure = List<double>.filled(_arrayLength, 0.0);
  final _nitrogenPressure = List<double>.filled(_arrayLength, 0.0);
  final _initialHeliumPressure = List<double>.filled(_arrayLength, 0.0);
  final _initialNitrogenPressure = List<double>.filled(_arrayLength, 0.0);
  final _initialCriticalRadiusHe = List<double>.filled(_arrayLength, 0.0);
  final _initialCriticalRadiusN2 = List<double>.filled(_arrayLength, 0.0);
  final _adjustedCriticalRadiusHe = List<double>.filled(_arrayLength, 0.0);
  final _adjustedCriticalRadiusN2 = List<double>.filled(_arrayLength, 0.0);
  final _maxCrushingPressureHe = List<double>.filled(_arrayLength, 0.0);
  final _maxCrushingPressureN2 = List<double>.filled(_arrayLength, 0.0);
  final _ambPressureOnsetOfImperm = List<double>.filled(_arrayLength, 0.0);
  final _gasTensionOnsetOfImperm = List<double>.filled(_arrayLength, 0.0);
  final _regeneratedRadiusHe = List<double>.filled(_arrayLength, 0.0);
  final _regeneratedRadiusN2 = List<double>.filled(_arrayLength, 0.0);
  final _adjustedCrushingPressureHe = List<double>.filled(_arrayLength, 0.0);
  final _adjustedCrushingPressureN2 = List<double>.filled(_arrayLength, 0.0);
  final _initialAllowableGradientHe = List<double>.filled(_arrayLength, 0.0);
  final _initialAllowableGradientN2 = List<double>.filled(_arrayLength, 0.0);
  final _allowableGradientHe = List<double>.filled(_arrayLength, 0.0);
  final _allowableGradientN2 = List<double>.filled(_arrayLength, 0.0);
  final _decoGradientHe = List<double>.filled(_arrayLength, 0.0);
  final _decoGradientN2 = List<double>.filled(_arrayLength, 0.0);
  final _surfacePhaseVolumeTime = List<double>.filled(_arrayLength, 0.0);
  final _phaseVolumeTime = List<double>.filled(_arrayLength, 0.0);
  final _lastPhaseVolumeTime = List<double>.filled(_arrayLength, 0.0);
  final _maxActualGradient = List<double>.filled(_arrayLength, 0.0);
  final _hePressureStartOfAscent = List<double>.filled(_arrayLength, 0.0);
  final _n2PressureStartOfAscent = List<double>.filled(_arrayLength, 0.0);
  final _hePressureStartOfDecoZone = List<double>.filled(_arrayLength, 0.0);
  final _n2PressureStartOfDecoZone = List<double>.filled(_arrayLength, 0.0);

  // Scalar run state.
  double _runTime = 0.0;
  int _segmentNumber = 0;
  double _segmentTime = 0.0;

  // Gas mixes (1-based mix numbers index these minus one).
  late List<VpmGasMix> _gasMixes;
  int _mixNumber = 1;

  double get _fractionHelium => _gasMixes[_mixNumber - 1].fHe;
  double get _fractionNitrogen => _gasMixes[_mixNumber - 1].fN2;

  // Ascent-plan state.
  int _numberOfChanges = 0;
  late List<double> _depthChange;
  late List<int> _mixChange;
  late List<double> _rateChange;
  late List<double> _stepSizeChange;

  double _startingDepth = 0.0;
  double _rate = 0.0;
  double _stepSize = 0.0;
  double _depthStartOfDecoZone = 0.0;
  double _firstStopDepth = 0.0;
  double _decoStopDepth = 0.0;
  double _ascentCeilingDepth = 0.0;
  double _runTimeStartOfAscent = 0.0;
  int _segmentNumberStartOfAscent = 0;
  double _runTimeStartOfDecoZone = 0.0;
  double _decoPhaseVolumeTime = 0.0;
  double _lastRunTime = 0.0;
  double _nextStop = 0.0;
  double _stopTime = 0.0;
  bool _scheduleConverged = false;

  final List<VpmStop> _stops = [];

  double get _gammaC => settings.skinCompressionGammaC;
  double get _gamma => settings.surfaceTensionGamma;

  /// Dive-independent setup: tissue time constants, critical radii, and the
  /// "other gases" partial pressure — everything derivable from [settings]
  /// alone. Also zeroes the crushing-pressure accumulators. Split out of
  /// [_initialize] so state can be restored (loadings + crushing history) for
  /// the incremental [DecoModel] wrapper without re-seeding surface loadings.
  void _initializeConstants() {
    _constantPressureOtherGases =
        (settings.pressureOtherGasesMmHg / 760.0) * _unitsFactor;
    _runTime = 0.0;
    _segmentNumber = 0;

    for (var i = 0; i < _arrayLength; i++) {
      _heliumTimeConstant[i] = _ln2 / _heliumHalfTime[i];
      _nitrogenTimeConstant[i] = _ln2 / _nitrogenHalfTime[i];
      _maxCrushingPressureHe[i] = 0.0;
      _maxCrushingPressureN2[i] = 0.0;
      _maxActualGradient[i] = 0.0;
      _surfacePhaseVolumeTime[i] = 0.0;
      _ambPressureOnsetOfImperm[i] = 0.0;
      _gasTensionOnsetOfImperm[i] = 0.0;
      _initialCriticalRadiusN2[i] = settings.criticalRadiusN2Microns * 1.0e-6;
      _initialCriticalRadiusHe[i] = settings.criticalRadiusHeMicrons * 1.0e-6;

      // Altitude algorithm off: adjusted critical radius == initial.
      _adjustedCriticalRadiusN2[i] = _initialCriticalRadiusN2[i];
      _adjustedCriticalRadiusHe[i] = _initialCriticalRadiusHe[i];
    }
  }

  /// Initialize constants and surface-equilibrated state (single sea-level
  /// dive, altitude algorithm off).
  void _initialize() {
    _initializeConstants();
    for (var i = 0; i < _arrayLength; i++) {
      _heliumPressure[i] = 0.0;
      _nitrogenPressure[i] =
          (_barometricPressure - _waterVaporPressure) * _fractionInertGas;
    }
  }

  /// Schreiner update for a linear depth change at [rate] (msw/min).
  void _gasLoadingsAscentDescent(
    double startingDepth,
    double endingDepth,
    double rate,
  ) {
    _segmentTime = (endingDepth - startingDepth) / rate;
    _runTime += _segmentTime;
    _segmentNumber += 1;

    final startingAmbientPressure = startingDepth + _barometricPressure;
    final initialInspiredHe =
        (startingAmbientPressure - _waterVaporPressure) * _fractionHelium;
    final initialInspiredN2 =
        (startingAmbientPressure - _waterVaporPressure) * _fractionNitrogen;
    final heliumRate = rate * _fractionHelium;
    final nitrogenRate = rate * _fractionNitrogen;

    for (var i = 0; i < _arrayLength; i++) {
      _initialHeliumPressure[i] = _heliumPressure[i];
      _initialNitrogenPressure[i] = _nitrogenPressure[i];
      _heliumPressure[i] = _schreinerEquation(
        initialInspiredHe,
        heliumRate,
        _segmentTime,
        _heliumTimeConstant[i],
        _initialHeliumPressure[i],
      );
      _nitrogenPressure[i] = _schreinerEquation(
        initialInspiredN2,
        nitrogenRate,
        _segmentTime,
        _nitrogenTimeConstant[i],
        _initialNitrogenPressure[i],
      );
    }
  }

  /// Haldane update for a constant-depth leg ending at [runTimeEndOfSegment].
  void _gasLoadingsConstantDepth(double depth, double runTimeEndOfSegment) {
    _segmentTime = runTimeEndOfSegment - _runTime;
    _runTime = runTimeEndOfSegment;
    _segmentNumber += 1;
    final ambientPressure = depth + _barometricPressure;
    final inspiredHe =
        (ambientPressure - _waterVaporPressure) * _fractionHelium;
    final inspiredN2 =
        (ambientPressure - _waterVaporPressure) * _fractionNitrogen;

    for (var i = 0; i < _arrayLength; i++) {
      _heliumPressure[i] = _haldaneEquation(
        _heliumPressure[i],
        inspiredHe,
        _heliumTimeConstant[i],
        _segmentTime,
      );
      _nitrogenPressure[i] = _haldaneEquation(
        _nitrogenPressure[i],
        inspiredN2,
        _nitrogenTimeConstant[i],
        _segmentTime,
      );
    }
  }

  double _crushingPressureHelper(
    double radiusOnsetOfImpermMolecule,
    double endingAmbientPressurePa,
    double ambPressOnsetOfImpermPa,
    double gasTensionOnsetOfImpermPa,
    double gradientOnsetOfImpermPa,
  ) {
    final a =
        endingAmbientPressurePa -
        ambPressOnsetOfImpermPa +
        gasTensionOnsetOfImpermPa +
        (2.0 * (_gammaC - _gamma)) / radiusOnsetOfImpermMolecule;
    final b = 2.0 * (_gammaC - _gamma);
    final c =
        gasTensionOnsetOfImpermPa *
        (radiusOnsetOfImpermMolecule *
            radiusOnsetOfImpermMolecule *
            radiusOnsetOfImpermMolecule);

    final highBound = radiusOnsetOfImpermMolecule;
    final lowBound = b / a;

    final endingRadius = _radiusRootFinder(a, b, c, lowBound, highBound);
    final crushingPressurePascals =
        gradientOnsetOfImpermPa +
        endingAmbientPressurePa -
        ambPressOnsetOfImpermPa +
        gasTensionOnsetOfImpermPa *
            (1.0 -
                (radiusOnsetOfImpermMolecule *
                        radiusOnsetOfImpermMolecule *
                        radiusOnsetOfImpermMolecule) /
                    (endingRadius * endingRadius * endingRadius));
    return (crushingPressurePascals / _atm) * _unitsFactor;
  }

  /// Effective crushing pressure over a descent segment; accumulates the max
  /// per compartment (permeable branch is linear, impermeable solves a cubic).
  void _calcCrushingPressure(
    double startingDepth,
    double endingDepth,
    double rate,
  ) {
    final gradientOnsetOfImperm =
        settings.gradientOnsetOfImpermAtm * _unitsFactor;
    final gradientOnsetOfImpermPa = settings.gradientOnsetOfImpermAtm * _atm;

    final startingAmbientPressure = startingDepth + _barometricPressure;
    final endingAmbientPressure = endingDepth + _barometricPressure;

    for (var i = 0; i < _arrayLength; i++) {
      final startingGasTension =
          _initialHeliumPressure[i] +
          _initialNitrogenPressure[i] +
          _constantPressureOtherGases;
      final startingGradient = startingAmbientPressure - startingGasTension;
      final endingGasTension =
          _heliumPressure[i] +
          _nitrogenPressure[i] +
          _constantPressureOtherGases;
      final endingGradient = endingAmbientPressure - endingGasTension;

      final radiusOnsetOfImpermHe =
          1.0 /
          (gradientOnsetOfImpermPa / (2.0 * (_gammaC - _gamma)) +
              1.0 / _adjustedCriticalRadiusHe[i]);
      final radiusOnsetOfImpermN2 =
          1.0 /
          (gradientOnsetOfImpermPa / (2.0 * (_gammaC - _gamma)) +
              1.0 / _adjustedCriticalRadiusN2[i]);

      double crushingPressureHe;
      double crushingPressureN2;

      if (endingGradient <= gradientOnsetOfImperm) {
        // Permeable range: crushing pressure is the plain gradient.
        crushingPressureHe = endingAmbientPressure - endingGasTension;
        crushingPressureN2 = endingAmbientPressure - endingGasTension;
      } else {
        // Impermeable range: need ambient pressure and gas tension at onset.
        if (startingGradient == gradientOnsetOfImperm) {
          _ambPressureOnsetOfImperm[i] = startingAmbientPressure;
          _gasTensionOnsetOfImperm[i] = startingGasTension;
        }
        if (startingGradient < gradientOnsetOfImperm) {
          _onsetOfImpermeability(
            startingAmbientPressure,
            endingAmbientPressure,
            rate,
            i,
          );
        }

        final endingAmbientPressurePa =
            (endingAmbientPressure / _unitsFactor) * _atm;
        final ambPressOnsetPa =
            (_ambPressureOnsetOfImperm[i] / _unitsFactor) * _atm;
        final gasTensionOnsetPa =
            (_gasTensionOnsetOfImperm[i] / _unitsFactor) * _atm;

        crushingPressureHe = _crushingPressureHelper(
          radiusOnsetOfImpermHe,
          endingAmbientPressurePa,
          ambPressOnsetPa,
          gasTensionOnsetPa,
          gradientOnsetOfImpermPa,
        );
        crushingPressureN2 = _crushingPressureHelper(
          radiusOnsetOfImpermN2,
          endingAmbientPressurePa,
          ambPressOnsetPa,
          gasTensionOnsetPa,
          gradientOnsetOfImpermPa,
        );
      }

      _maxCrushingPressureHe[i] = math.max(
        _maxCrushingPressureHe[i],
        crushingPressureHe,
      );
      _maxCrushingPressureN2[i] = math.max(
        _maxCrushingPressureN2[i],
        crushingPressureN2,
      );
    }
  }

  /// Bisection to find ambient pressure and gas tension at the onset of
  /// impermeability for compartment [i] during a descent segment.
  void _onsetOfImpermeability(
    double startingAmbientPressure,
    double endingAmbientPressure,
    double rate,
    int i,
  ) {
    final gradientOnsetOfImperm =
        settings.gradientOnsetOfImpermAtm * _unitsFactor;

    final initialInspiredHe =
        (startingAmbientPressure - _waterVaporPressure) * _fractionHelium;
    final initialInspiredN2 =
        (startingAmbientPressure - _waterVaporPressure) * _fractionNitrogen;
    final heliumRate = rate * _fractionHelium;
    final nitrogenRate = rate * _fractionNitrogen;
    const lowBound = 0.0;
    final highBound = (endingAmbientPressure - startingAmbientPressure) / rate;

    final startingGasTension =
        _initialHeliumPressure[i] +
        _initialNitrogenPressure[i] +
        _constantPressureOtherGases;
    final functionAtLowBound =
        startingAmbientPressure - startingGasTension - gradientOnsetOfImperm;

    final highBoundHeliumPressure = _schreinerEquation(
      initialInspiredHe,
      heliumRate,
      highBound,
      _heliumTimeConstant[i],
      _initialHeliumPressure[i],
    );
    final highBoundNitrogenPressure = _schreinerEquation(
      initialInspiredN2,
      nitrogenRate,
      highBound,
      _nitrogenTimeConstant[i],
      _initialNitrogenPressure[i],
    );
    final endingGasTension =
        highBoundHeliumPressure +
        highBoundNitrogenPressure +
        _constantPressureOtherGases;
    final functionAtHighBound =
        endingAmbientPressure - endingGasTension - gradientOnsetOfImperm;

    if (functionAtHighBound * functionAtLowBound >= 0.0) {
      throw VpmRootException('ROOT IS NOT WITHIN BRACKETS');
    }

    double time;
    double differentialChange;
    if (functionAtLowBound < 0.0) {
      time = lowBound;
      differentialChange = highBound - lowBound;
    } else {
      time = highBound;
      differentialChange = lowBound - highBound;
    }

    double midRangeAmbientPressure = 0.0;
    double gasTensionAtMidRange = 0.0;
    for (var j = 0; j < 100; j++) {
      final lastDiffChange = differentialChange;
      differentialChange = lastDiffChange * 0.5;
      final midRangeTime = time + differentialChange;

      midRangeAmbientPressure = startingAmbientPressure + rate * midRangeTime;
      final midRangeHeliumPressure = _schreinerEquation(
        initialInspiredHe,
        heliumRate,
        midRangeTime,
        _heliumTimeConstant[i],
        _initialHeliumPressure[i],
      );
      final midRangeNitrogenPressure = _schreinerEquation(
        initialInspiredN2,
        nitrogenRate,
        midRangeTime,
        _nitrogenTimeConstant[i],
        _initialNitrogenPressure[i],
      );
      gasTensionAtMidRange =
          midRangeHeliumPressure +
          midRangeNitrogenPressure +
          _constantPressureOtherGases;
      final functionAtMidRange =
          midRangeAmbientPressure -
          gasTensionAtMidRange -
          gradientOnsetOfImperm;

      if (functionAtMidRange <= 0.0) {
        time = midRangeTime;
      }
      if (differentialChange.abs() < 1.0e-3 || functionAtMidRange == 0.0) {
        break;
      }
    }

    _ambPressureOnsetOfImperm[i] = midRangeAmbientPressure;
    _gasTensionOnsetOfImperm[i] = gasTensionAtMidRange;
  }

  /// Regenerate critical radii over the dive time and derive adjusted crushing
  /// pressures (negligible for normal dives, dominant for saturation dives).
  void _nuclearRegeneration(double diveTime) {
    for (var i = 0; i < _arrayLength; i++) {
      final crushingPressurePascalsHe =
          (_maxCrushingPressureHe[i] / _unitsFactor) * _atm;
      final crushingPressurePascalsN2 =
          (_maxCrushingPressureN2[i] / _unitsFactor) * _atm;

      final endingRadiusHe =
          1.0 /
          (crushingPressurePascalsHe / (2.0 * (_gammaC - _gamma)) +
              1.0 / _adjustedCriticalRadiusHe[i]);
      final endingRadiusN2 =
          1.0 /
          (crushingPressurePascalsN2 / (2.0 * (_gammaC - _gamma)) +
              1.0 / _adjustedCriticalRadiusN2[i]);

      _regeneratedRadiusHe[i] =
          _adjustedCriticalRadiusHe[i] +
          (endingRadiusHe - _adjustedCriticalRadiusHe[i]) *
              math.exp(-diveTime / settings.regenerationTimeConstant);
      _regeneratedRadiusN2[i] =
          _adjustedCriticalRadiusN2[i] +
          (endingRadiusN2 - _adjustedCriticalRadiusN2[i]) *
              math.exp(-diveTime / settings.regenerationTimeConstant);

      final crushPressureAdjustRatioHe =
          (endingRadiusHe *
              (_adjustedCriticalRadiusHe[i] - _regeneratedRadiusHe[i])) /
          (_regeneratedRadiusHe[i] *
              (_adjustedCriticalRadiusHe[i] - endingRadiusHe));
      final crushPressureAdjustRatioN2 =
          (endingRadiusN2 *
              (_adjustedCriticalRadiusN2[i] - _regeneratedRadiusN2[i])) /
          (_regeneratedRadiusN2[i] *
              (_adjustedCriticalRadiusN2[i] - endingRadiusN2));

      final adjCrushPressureHePascals =
          crushingPressurePascalsHe * crushPressureAdjustRatioHe;
      final adjCrushPressureN2Pascals =
          crushingPressurePascalsN2 * crushPressureAdjustRatioN2;

      _adjustedCrushingPressureHe[i] =
          (adjCrushPressureHePascals / _atm) * _unitsFactor;
      _adjustedCrushingPressureN2[i] =
          (adjCrushPressureN2Pascals / _atm) * _unitsFactor;
    }
  }

  /// Initial allowable supersaturation gradients ("PssMin") from regenerated
  /// radii. These seed the deco ceiling before the Critical Volume relaxation.
  void _calcInitialAllowableGradient() {
    for (var i = 0; i < _arrayLength; i++) {
      final initialAllowableGradN2Pa =
          (2.0 * _gamma * (_gammaC - _gamma)) /
          (_regeneratedRadiusN2[i] * _gammaC);
      final initialAllowableGradHePa =
          (2.0 * _gamma * (_gammaC - _gamma)) /
          (_regeneratedRadiusHe[i] * _gammaC);

      _initialAllowableGradientN2[i] =
          (initialAllowableGradN2Pa / _atm) * _unitsFactor;
      _initialAllowableGradientHe[i] =
          (initialAllowableGradHePa / _atm) * _unitsFactor;

      _allowableGradientHe[i] = _initialAllowableGradientHe[i];
      _allowableGradientN2[i] = _initialAllowableGradientN2[i];
    }
  }

  /// Bisection for the depth at which the leading compartment enters the deco
  /// zone (gas tension equals ambient pressure).
  void _calcStartOfDecoZone(double startingDepth, double rate) {
    _depthStartOfDecoZone = 0.0;
    final startingAmbientPressure = startingDepth + _barometricPressure;

    final initialInspiredHe =
        (startingAmbientPressure - _waterVaporPressure) * _fractionHelium;
    final initialInspiredN2 =
        (startingAmbientPressure - _waterVaporPressure) * _fractionNitrogen;
    final heliumRate = rate * _fractionHelium;
    final nitrogenRate = rate * _fractionNitrogen;

    const lowBound = 0.0;
    final highBound = -1.0 * (startingAmbientPressure / rate);

    for (var i = 0; i < _arrayLength; i++) {
      final initialHeliumPressure = _heliumPressure[i];
      final initialNitrogenPressure = _nitrogenPressure[i];

      final functionAtLowBound =
          initialHeliumPressure +
          initialNitrogenPressure +
          _constantPressureOtherGases -
          startingAmbientPressure;

      final highBoundHeliumPressure = _schreinerEquation(
        initialInspiredHe,
        heliumRate,
        highBound,
        _heliumTimeConstant[i],
        initialHeliumPressure,
      );
      final highBoundNitrogenPressure = _schreinerEquation(
        initialInspiredN2,
        nitrogenRate,
        highBound,
        _nitrogenTimeConstant[i],
        initialNitrogenPressure,
      );
      final functionAtHighBound =
          highBoundHeliumPressure +
          highBoundNitrogenPressure +
          _constantPressureOtherGases;

      if (functionAtHighBound * functionAtLowBound >= 0.0) {
        throw VpmRootException('ROOT IS NOT WITHIN BRACKETS');
      }

      double timeToStartOfDecoZone;
      double differentialChange;
      if (functionAtLowBound < 0.0) {
        timeToStartOfDecoZone = lowBound;
        differentialChange = highBound - lowBound;
      } else {
        timeToStartOfDecoZone = highBound;
        differentialChange = lowBound - highBound;
      }

      for (var j = 0; j < 100; j++) {
        final lastDiffChange = differentialChange;
        differentialChange = lastDiffChange * 0.5;
        final midRangeTime = timeToStartOfDecoZone + differentialChange;

        final midRangeHeliumPressure = _schreinerEquation(
          initialInspiredHe,
          heliumRate,
          midRangeTime,
          _heliumTimeConstant[i],
          initialHeliumPressure,
        );
        final midRangeNitrogenPressure = _schreinerEquation(
          initialInspiredN2,
          nitrogenRate,
          midRangeTime,
          _nitrogenTimeConstant[i],
          initialNitrogenPressure,
        );
        final functionAtMidRange =
            midRangeHeliumPressure +
            midRangeNitrogenPressure +
            _constantPressureOtherGases -
            (startingAmbientPressure + rate * midRangeTime);

        if (functionAtMidRange <= 0.0) {
          timeToStartOfDecoZone = midRangeTime;
        }
        if (differentialChange.abs() < 1.0e-3 || functionAtMidRange == 0.0) {
          break;
        }
      }

      final cptDepthStartOfDecoZone =
          (startingAmbientPressure + rate * timeToStartOfDecoZone) -
          _barometricPressure;
      _depthStartOfDecoZone = math.max(
        _depthStartOfDecoZone,
        cptDepthStartOfDecoZone,
      );
    }
  }

  /// Ascent ceiling from allowable gradients (Buhlmann/Keller weighting).
  void _calcAscentCeiling() {
    final compartmentAscentCeiling = List<double>.filled(_arrayLength, 0.0);
    for (var i = 0; i < _arrayLength; i++) {
      final gasLoading = _heliumPressure[i] + _nitrogenPressure[i];
      double toleratedAmbientPressure;
      if (gasLoading > 0.0) {
        final weightedAllowableGradient =
            (_allowableGradientHe[i] * _heliumPressure[i] +
                _allowableGradientN2[i] * _nitrogenPressure[i]) /
            (_heliumPressure[i] + _nitrogenPressure[i]);
        toleratedAmbientPressure =
            (gasLoading + _constantPressureOtherGases) -
            weightedAllowableGradient;
      } else {
        final weightedAllowableGradient = math.min(
          _allowableGradientHe[i],
          _allowableGradientN2[i],
        );
        toleratedAmbientPressure =
            _constantPressureOtherGases - weightedAllowableGradient;
      }
      if (toleratedAmbientPressure < 0.0) toleratedAmbientPressure = 0.0;
      compartmentAscentCeiling[i] =
          toleratedAmbientPressure - _barometricPressure;
    }
    _ascentCeilingDepth = compartmentAscentCeiling.reduce(math.max);
  }

  /// Simulated ascent to the projected first stop; deepen it by step size
  /// until on-gassing during the ascent won't violate the ceiling.
  void _projectedAscent(double startingDepth, double rate, double stepSize) {
    var newAmbientPressure = _decoStopDepth + _barometricPressure;
    final startingAmbientPressure = startingDepth + _barometricPressure;

    final initialInspiredHe =
        (startingAmbientPressure - _waterVaporPressure) * _fractionHelium;
    final initialInspiredN2 =
        (startingAmbientPressure - _waterVaporPressure) * _fractionNitrogen;
    final heliumRate = rate * _fractionHelium;
    final nitrogenRate = rate * _fractionNitrogen;

    final tempGasLoading = List<double>.filled(_arrayLength, 0.0);
    final allowableGasLoading = List<double>.filled(_arrayLength, 0.0);
    final initialHeliumPressure = List<double>.filled(_arrayLength, 0.0);
    final initialNitrogenPressure = List<double>.filled(_arrayLength, 0.0);
    for (var i = 0; i < _arrayLength; i++) {
      initialHeliumPressure[i] = _heliumPressure[i];
      initialNitrogenPressure[i] = _nitrogenPressure[i];
    }

    while (true) {
      final endingAmbientPressure = newAmbientPressure;
      final segmentTime =
          (endingAmbientPressure - startingAmbientPressure) / rate;

      for (var i = 0; i < _arrayLength; i++) {
        final tempHeliumPressure = _schreinerEquation(
          initialInspiredHe,
          heliumRate,
          segmentTime,
          _heliumTimeConstant[i],
          initialHeliumPressure[i],
        );
        final tempNitrogenPressure = _schreinerEquation(
          initialInspiredN2,
          nitrogenRate,
          segmentTime,
          _nitrogenTimeConstant[i],
          initialNitrogenPressure[i],
        );
        tempGasLoading[i] = tempHeliumPressure + tempNitrogenPressure;
        double weightedAllowableGradient;
        if (tempGasLoading[i] > 0.0) {
          weightedAllowableGradient =
              (_allowableGradientHe[i] * tempHeliumPressure +
                  _allowableGradientN2[i] * tempNitrogenPressure) /
              tempGasLoading[i];
        } else {
          weightedAllowableGradient = math.min(
            _allowableGradientHe[i],
            _allowableGradientN2[i],
          );
        }
        allowableGasLoading[i] =
            endingAmbientPressure +
            weightedAllowableGradient -
            _constantPressureOtherGases;
      }

      var endSub = true;
      for (var j = 0; j < _arrayLength; j++) {
        if (tempGasLoading[j] > allowableGasLoading[j]) {
          newAmbientPressure = endingAmbientPressure + stepSize;
          _decoStopDepth = _decoStopDepth + stepSize;
          endSub = false;
          break;
        }
      }
      if (!endSub) continue;
      break;
    }
  }

  double _calculateDecoGradient(
    double allowableGradientMolecule,
    double ambPressFirstStopPascals,
    double ambPressNextStopPascals,
  ) {
    final allowGradFirstStopPa =
        (allowableGradientMolecule / _unitsFactor) * _atm;
    final radiusFirstStop = (2.0 * _gamma) / allowGradFirstStopPa;

    final a = ambPressNextStopPascals;
    final b = -2.0 * _gamma;
    final c =
        (ambPressFirstStopPascals + (2.0 * _gamma) / radiusFirstStop) *
        radiusFirstStop *
        (radiusFirstStop * radiusFirstStop);
    final lowBound = radiusFirstStop;
    final highBound =
        radiusFirstStop *
        math.pow(ambPressFirstStopPascals / ambPressNextStopPascals, 1.0 / 3.0);

    final endingRadius = _radiusRootFinder(
      a,
      b,
      c,
      lowBound,
      highBound.toDouble(),
    );
    final decoGradientPascals = (2.0 * _gamma) / endingRadius;
    return (decoGradientPascals / _atm) * _unitsFactor;
  }

  /// Boyle's-law reduction of allowable gradients with decreasing pressure.
  void _boylesLawCompensation(
    double firstStopDepth,
    double decoStopDepth,
    double stepSize,
  ) {
    final nextStop = decoStopDepth - stepSize;
    final ambientPressureFirstStop = firstStopDepth + _barometricPressure;
    final ambientPressureNextStop = nextStop + _barometricPressure;

    final ambPressFirstStopPascals =
        (ambientPressureFirstStop / _unitsFactor) * _atm;
    final ambPressNextStopPascals =
        (ambientPressureNextStop / _unitsFactor) * _atm;

    for (var i = 0; i < _arrayLength; i++) {
      _decoGradientHe[i] = _calculateDecoGradient(
        _allowableGradientHe[i],
        ambPressFirstStopPascals,
        ambPressNextStopPascals,
      );
      _decoGradientN2[i] = _calculateDecoGradient(
        _allowableGradientN2[i],
        ambPressFirstStopPascals,
        ambPressNextStopPascals,
      );
    }
  }

  /// Time required at [decoStopDepth] before the ceiling clears the next stop.
  void _decompressionStop(double decoStopDepth, double stepSize) {
    final lastRunTime = _runTime;
    final roundUpOperation =
        _pyRound(lastRunTime / settings.minimumDecoStopTime + 0.5) *
        settings.minimumDecoStopTime;
    _segmentTime = roundUpOperation - _runTime;
    _runTime = roundUpOperation;
    var tempSegmentTime = _segmentTime;
    _segmentNumber += 1;
    final ambientPressure = decoStopDepth + _barometricPressure;
    final nextStop = decoStopDepth - stepSize;

    final inspiredHeliumPressure =
        (ambientPressure - _waterVaporPressure) * _fractionHelium;
    final inspiredNitrogenPressure =
        (ambientPressure - _waterVaporPressure) * _fractionNitrogen;

    for (var i = 0; i < _arrayLength; i++) {
      if ((inspiredHeliumPressure + inspiredNitrogenPressure) > 0.0) {
        final weightedAllowableGradient =
            (_decoGradientHe[i] * inspiredHeliumPressure +
                _decoGradientN2[i] * inspiredNitrogenPressure) /
            (inspiredHeliumPressure + inspiredNitrogenPressure);
        if ((inspiredHeliumPressure +
                inspiredNitrogenPressure +
                _constantPressureOtherGases -
                weightedAllowableGradient) >
            (nextStop + _barometricPressure)) {
          throw VpmOffGassingException(
            'OFF-GASSING GRADIENT IS TOO SMALL TO DECOMPRESS AT THE '
            '$decoStopDepth STOP. Next stop: $nextStop',
          );
        }
      }
    }

    while (true) {
      for (var i = 0; i < _arrayLength; i++) {
        _heliumPressure[i] = _haldaneEquation(
          _heliumPressure[i],
          inspiredHeliumPressure,
          _heliumTimeConstant[i],
          _segmentTime,
        );
        _nitrogenPressure[i] = _haldaneEquation(
          _nitrogenPressure[i],
          inspiredNitrogenPressure,
          _nitrogenTimeConstant[i],
          _segmentTime,
        );
      }
      final decoCeilingDepth = _calcDecoCeiling();
      if (decoCeilingDepth > nextStop) {
        _segmentTime = settings.minimumDecoStopTime;
        final timeCounter = tempSegmentTime;
        tempSegmentTime = timeCounter + settings.minimumDecoStopTime;
        _runTime = _runTime + settings.minimumDecoStopTime;
        continue;
      }
      break;
    }
    _segmentTime = tempSegmentTime;
  }

  /// Deco ceiling from Boyle-compensated deco gradients.
  double _calcDecoCeiling() {
    final compartmentDecoCeiling = List<double>.filled(_arrayLength, 0.0);
    for (var i = 0; i < _arrayLength; i++) {
      final gasLoading = _heliumPressure[i] + _nitrogenPressure[i];
      double toleratedAmbientPressure;
      if (gasLoading > 0.0) {
        final weightedAllowableGradient =
            (_decoGradientHe[i] * _heliumPressure[i] +
                _decoGradientN2[i] * _nitrogenPressure[i]) /
            (_heliumPressure[i] + _nitrogenPressure[i]);
        toleratedAmbientPressure =
            (gasLoading + _constantPressureOtherGases) -
            weightedAllowableGradient;
      } else {
        final weightedAllowableGradient = math.min(
          _decoGradientHe[i],
          _decoGradientN2[i],
        );
        toleratedAmbientPressure =
            _constantPressureOtherGases - weightedAllowableGradient;
      }
      if (toleratedAmbientPressure < 0.0) toleratedAmbientPressure = 0.0;
      compartmentDecoCeiling[i] =
          toleratedAmbientPressure - _barometricPressure;
    }
    return compartmentDecoCeiling.reduce(math.max);
  }

  /// Critical Volume Algorithm: relax the allowable gradients based on the
  /// integrated supersaturation-gradient-x-time (phase volume).
  void _criticalVolume(double decoPhaseVolumeTime) {
    final parameterLambdaPascals =
        (settings.critVolumeParameterLambda / 33.0) * _atm;

    for (var i = 0; i < _arrayLength; i++) {
      final phaseVolumeTime = decoPhaseVolumeTime + _surfacePhaseVolumeTime[i];

      // Helium.
      final adjCrushPressureHePascals =
          (_adjustedCrushingPressureHe[i] / _unitsFactor) * _atm;
      final initialAllowableGradHePa =
          (_initialAllowableGradientHe[i] / _unitsFactor) * _atm;
      var b =
          initialAllowableGradHePa +
          (parameterLambdaPascals * _gamma) / (_gammaC * phaseVolumeTime);
      var c =
          (_gamma *
              (_gamma * (parameterLambdaPascals * adjCrushPressureHePascals))) /
          (_gammaC * (_gammaC * phaseVolumeTime));
      final newAllowableGradHePascals = (b + math.sqrt(b * b - 4.0 * c)) / 2.0;
      _allowableGradientHe[i] =
          (newAllowableGradHePascals / _atm) * _unitsFactor;

      // Nitrogen.
      final adjCrushPressureN2Pascals =
          (_adjustedCrushingPressureN2[i] / _unitsFactor) * _atm;
      final initialAllowableGradN2Pa =
          (_initialAllowableGradientN2[i] / _unitsFactor) * _atm;
      b =
          initialAllowableGradN2Pa +
          (parameterLambdaPascals * _gamma) / (_gammaC * phaseVolumeTime);
      c =
          (_gamma *
              (_gamma * (parameterLambdaPascals * adjCrushPressureN2Pascals))) /
          (_gammaC * (_gammaC * phaseVolumeTime));
      final newAllowableGradN2Pascals = (b + math.sqrt(b * b - 4.0 * c)) / 2.0;
      _allowableGradientN2[i] =
          (newAllowableGradN2Pascals / _atm) * _unitsFactor;
    }
  }

  /// Surface portion of the phase-volume-time integration (post-dive
  /// supersaturation while off-gassing at the surface).
  void _calcSurfacePhaseVolumeTime() {
    const surfaceInspiredN2Pressure =
        (_barometricPressure - _waterVaporPressure) * _fractionInertGas;
    for (var i = 0; i < _arrayLength; i++) {
      if (_nitrogenPressure[i] > surfaceInspiredN2Pressure) {
        _surfacePhaseVolumeTime[i] =
            (_heliumPressure[i] / _heliumTimeConstant[i] +
                (_nitrogenPressure[i] - surfaceInspiredN2Pressure) /
                    _nitrogenTimeConstant[i]) /
            (_heliumPressure[i] +
                _nitrogenPressure[i] -
                surfaceInspiredN2Pressure);
      } else if (_nitrogenPressure[i] <= surfaceInspiredN2Pressure &&
          (_heliumPressure[i] + _nitrogenPressure[i]) >=
              surfaceInspiredN2Pressure) {
        final decayTimeToZeroGradient =
            1.0 /
            (_nitrogenTimeConstant[i] - _heliumTimeConstant[i]) *
            math.log(
              (surfaceInspiredN2Pressure - _nitrogenPressure[i]) /
                  _heliumPressure[i],
            );
        final integralGradientXTime =
            _heliumPressure[i] /
                _heliumTimeConstant[i] *
                (1.0 -
                    math.exp(
                      -_heliumTimeConstant[i] * decayTimeToZeroGradient,
                    )) +
            (_nitrogenPressure[i] - surfaceInspiredN2Pressure) /
                _nitrogenTimeConstant[i] *
                (1.0 -
                    math.exp(
                      -_nitrogenTimeConstant[i] * decayTimeToZeroGradient,
                    ));
        _surfacePhaseVolumeTime[i] =
            integralGradientXTime /
            (_heliumPressure[i] +
                _nitrogenPressure[i] -
                surfaceInspiredN2Pressure);
      } else {
        _surfacePhaseVolumeTime[i] = 0.0;
      }
    }
  }

  /// Max actual supersaturation gradient during ascent (repetitive-dive
  /// bookkeeping only; does not affect the single-dive schedule).
  void _calcMaxActualGradient(double decoStopDepth) {
    for (var i = 0; i < _arrayLength; i++) {
      var compartmentGradient =
          (_heliumPressure[i] +
              _nitrogenPressure[i] +
              _constantPressureOtherGases) -
          (decoStopDepth + _barometricPressure);
      if (compartmentGradient <= 0.0) compartmentGradient = 0.0;
      _maxActualGradient[i] = math.max(
        _maxActualGradient[i],
        compartmentGradient,
      );
    }
  }

  /// The inner ascent loop used during Critical Volume iteration to size the
  /// in-water phase-volume time (no schedule output).
  void _decoStopLoopBlockWithinCriticalVolumeLoop() {
    while (true) {
      _gasLoadingsAscentDescent(_startingDepth, _decoStopDepth, _rate);
      if (_decoStopDepth <= 0.0) break;

      if (_numberOfChanges > 1) {
        for (var i = 1; i < _numberOfChanges; i++) {
          if (_depthChange[i] >= _decoStopDepth) {
            _mixNumber = _mixChange[i];
            _rate = _rateChange[i];
            _stepSize = _stepSizeChange[i];
          }
        }
      }

      _boylesLawCompensation(_firstStopDepth, _decoStopDepth, _stepSize);
      _decompressionStop(_decoStopDepth, _stepSize);

      _startingDepth = _decoStopDepth;
      _nextStop = _decoStopDepth - _stepSize;
      _decoStopDepth = _nextStop;
      _lastRunTime = _runTime;
    }
  }

  /// The final ascent that emits the deco schedule to [_stops].
  void _criticalVolumeDecisionTree() {
    for (var i = 0; i < _arrayLength; i++) {
      _heliumPressure[i] = _hePressureStartOfAscent[i];
      _nitrogenPressure[i] = _n2PressureStartOfAscent[i];
    }
    _runTime = _runTimeStartOfAscent;
    _segmentNumber = _segmentNumberStartOfAscent;
    _startingDepth = _depthChange[0];
    _mixNumber = _mixChange[0];
    _rate = _rateChange[0];
    _stepSize = _stepSizeChange[0];
    _decoStopDepth = _firstStopDepth;
    _lastRunTime = 0.0;

    while (true) {
      _gasLoadingsAscentDescent(_startingDepth, _decoStopDepth, _rate);
      _calcMaxActualGradient(_decoStopDepth);

      if (_decoStopDepth <= 0.0) break;

      if (_numberOfChanges > 1) {
        for (var i = 1; i < _numberOfChanges; i++) {
          if (_depthChange[i] >= _decoStopDepth) {
            _mixNumber = _mixChange[i];
            _rate = _rateChange[i];
            _stepSize = _stepSizeChange[i];
          }
        }
      }

      _boylesLawCompensation(_firstStopDepth, _decoStopDepth, _stepSize);
      _decompressionStop(_decoStopDepth, _stepSize);

      if (_lastRunTime == 0.0) {
        _stopTime =
            _pyRound(_segmentTime / settings.minimumDecoStopTime + 0.5) *
            settings.minimumDecoStopTime;
      } else {
        _stopTime = _runTime - _lastRunTime;
      }

      if (_trunc(settings.minimumDecoStopTime) ==
          settings.minimumDecoStopTime) {
        _stops.add(VpmStop(_decoStopDepth.toInt(), _stopTime.toInt()));
      } else {
        // Sub-minute stops: keep the (rounded-down) integer schedule so the
        // public contract stays whole-number; fractional support is unused.
        _stops.add(VpmStop(_decoStopDepth.floor(), _stopTime.floor()));
      }

      _startingDepth = _decoStopDepth;
      _nextStop = _decoStopDepth - _stepSize;
      _decoStopDepth = _nextStop;
      _lastRunTime = _runTime;
    }
  }

  /// Iterate the Critical Volume Loop to convergence (or once, if the CVA is
  /// off), then emit the final schedule via the decision tree.
  void _criticalVolumeLoop() {
    while (true) {
      _calcAscentCeiling();
      if (_ascentCeilingDepth <= 0.0) {
        _decoStopDepth = 0.0;
      } else {
        final roundingOperation2 = (_ascentCeilingDepth / _stepSize) + 0.5;
        _decoStopDepth = _pyRound(roundingOperation2) * _stepSize;
      }

      if (_decoStopDepth > _depthStartOfDecoZone) {
        throw VpmDecompressionStepException(
          'STEP SIZE IS TOO LARGE TO DECOMPRESS',
        );
      }

      _projectedAscent(_depthStartOfDecoZone, _rate, _stepSize);

      if (_decoStopDepth > _depthStartOfDecoZone) {
        throw VpmDecompressionStepException(
          'STEP SIZE IS TOO LARGE TO DECOMPRESS',
        );
      }

      if (_decoStopDepth == 0.0) {
        for (var i = 0; i < _arrayLength; i++) {
          _heliumPressure[i] = _hePressureStartOfAscent[i];
          _nitrogenPressure[i] = _n2PressureStartOfAscent[i];
        }
        _runTime = _runTimeStartOfAscent;
        _segmentNumber = _segmentNumberStartOfAscent;
        _startingDepth = _depthChange[0];
        _gasLoadingsAscentDescent(_startingDepth, 0.0, _rate);
        break;
      }

      _startingDepth = _depthStartOfDecoZone;
      _firstStopDepth = _decoStopDepth;
      _decoStopLoopBlockWithinCriticalVolumeLoop();

      _decoPhaseVolumeTime = _runTime - _runTimeStartOfDecoZone;
      _calcSurfacePhaseVolumeTime();

      for (var i = 0; i < _arrayLength; i++) {
        _phaseVolumeTime[i] = _decoPhaseVolumeTime + _surfacePhaseVolumeTime[i];
        final criticalVolumeComparison =
            (_phaseVolumeTime[i] - _lastPhaseVolumeTime[i]).abs();
        if (criticalVolumeComparison <= 1.0) {
          _scheduleConverged = true;
        }
      }

      if (_scheduleConverged || !settings.criticalVolumeAlgorithmOn) {
        _criticalVolumeDecisionTree();
      } else {
        _criticalVolume(_decoPhaseVolumeTime);
        _decoPhaseVolumeTime = 0.0;
        _runTime = _runTimeStartOfDecoZone;
        _startingDepth = _depthStartOfDecoZone;
        _mixNumber = _mixChange[0];
        _rate = _rateChange[0];
        _stepSize = _stepSizeChange[0];
        for (var i = 0; i < _arrayLength; i++) {
          _lastPhaseVolumeTime[i] = _phaseVolumeTime[i];
          _heliumPressure[i] = _hePressureStartOfDecoZone[i];
          _nitrogenPressure[i] = _n2PressureStartOfDecoZone[i];
        }
        continue;
      }
      break;
    }
  }

  /// Ascent driver: regeneration -> initial gradients -> critical volume loop.
  void _decompressionLoop(List<VpmAscentChange> ascentChanges) {
    _nuclearRegeneration(_runTime);
    _calcInitialAllowableGradient();

    for (var i = 0; i < _arrayLength; i++) {
      _hePressureStartOfAscent[i] = _heliumPressure[i];
      _n2PressureStartOfAscent[i] = _nitrogenPressure[i];
    }
    _runTimeStartOfAscent = _runTime;
    _segmentNumberStartOfAscent = _segmentNumber;

    _numberOfChanges = ascentChanges.length;
    _depthChange = List<double>.filled(_numberOfChanges, 0.0);
    _mixChange = List<int>.filled(_numberOfChanges, 0);
    _rateChange = List<double>.filled(_numberOfChanges, 0.0);
    _stepSizeChange = List<double>.filled(_numberOfChanges, 0.0);
    for (var i = 0; i < _numberOfChanges; i++) {
      _depthChange[i] = ascentChanges[i].startingDepth;
      _mixChange[i] = ascentChanges[i].mixNumber;
      _rateChange[i] = ascentChanges[i].rate;
      _stepSizeChange[i] = ascentChanges[i].stepSize;
    }
    _startingDepth = _depthChange[0];
    _mixNumber = _mixChange[0];
    _rate = _rateChange[0];
    _stepSize = _stepSizeChange[0];

    _calcStartOfDecoZone(_startingDepth, _rate);

    // (Deepest possible stop depth is informational in the reference and not
    // needed for the schedule; omitted.)

    _gasLoadingsAscentDescent(_startingDepth, _depthStartOfDecoZone, _rate);
    _runTimeStartOfDecoZone = _runTime;
    _decoPhaseVolumeTime = 0.0;
    _lastRunTime = 0.0;
    _scheduleConverged = false;

    for (var i = 0; i < _arrayLength; i++) {
      _lastPhaseVolumeTime[i] = 0.0;
      _hePressureStartOfDecoZone[i] = _heliumPressure[i];
      _n2PressureStartOfDecoZone[i] = _nitrogenPressure[i];
      _maxActualGradient[i] = 0.0;
    }

    _criticalVolumeLoop();
  }

  /// Compute the staged decompression schedule for a single dive.
  ///
  /// [gasMixes] are indexed by the 1-based mix numbers referenced in
  /// [profile] and [ascentChanges]. [profile] is the descent/bottom sequence;
  /// [ascentChanges] describes how to ascend (deep-to-shallow entries with
  /// gas/rate/step changes). Returns the stops deepest-first.
  List<VpmStop> computeDive({
    required List<VpmGasMix> gasMixes,
    required List<VpmProfileSegment> profile,
    required List<VpmAscentChange> ascentChanges,
  }) {
    _gasMixes = gasMixes;
    _stops.clear();
    _initialize();

    for (final segment in profile) {
      switch (segment) {
        case VpmDepthChangeSegment():
          _startingDepth = segment.startingDepth;
          _rate = segment.rate;
          _mixNumber = segment.mixNumber;
          _gasLoadingsAscentDescent(
            segment.startingDepth,
            segment.endingDepth,
            segment.rate,
          );
          if (segment.endingDepth > segment.startingDepth) {
            _calcCrushingPressure(
              segment.startingDepth,
              segment.endingDepth,
              segment.rate,
            );
          }
        case VpmConstantSegment():
          _mixNumber = segment.mixNumber;
          _gasLoadingsConstantDepth(
            segment.depth,
            segment.runTimeAtEndOfSegment,
          );
      }
    }

    _decompressionLoop(ascentChanges);
    return List<VpmStop>.unmodifiable(_stops);
  }

  // ---------------------------------------------------------------------------
  // Incremental API for the [DecoModel] wrapper (vpm_b.dart).
  //
  // These expose the algorithm as restore -> step -> capture, mirroring how
  // BuhlmannGf drives BuhlmannAlgorithm. The wrapper restores an opaque state
  // before every call, so intermediate mutation of the shared arrays is safe.
  // Driving a whole dive through applyDepthChange/applyConstantDepth then
  // runAscent produces the SAME schedule as computeDive (verified by test).
  // ---------------------------------------------------------------------------

  /// Sea-level barometric pressure used internally (msw).
  static double get barometricPressure => _barometricPressure;

  /// Alveolar water vapor pressure used internally (msw).
  static double get waterVaporPressure => _waterVaporPressure;

  /// Inert-gas fraction of the surface atmosphere (0.79).
  static double get fractionInertGas => _fractionInertGas;

  double get runTime => _runTime;

  List<double> get heliumPressure => _heliumPressure;
  List<double> get nitrogenPressure => _nitrogenPressure;
  List<double> get maxCrushingPressureHe => _maxCrushingPressureHe;
  List<double> get maxCrushingPressureN2 => _maxCrushingPressureN2;

  /// Reset to constants plus surface-equilibrated loadings (zero crushing).
  void initializeToSurface() {
    _gasMixes = const [VpmGasMix(fN2: _fractionInertGas, fHe: 0.0)];
    _stops.clear();
    _initialize();
  }

  /// Restore dynamic dive state; constants are re-derived from [settings].
  void loadState({
    required List<double> heliumPressure,
    required List<double> nitrogenPressure,
    required List<double> maxCrushingPressureHe,
    required List<double> maxCrushingPressureN2,
    required double runTime,
  }) {
    _stops.clear();
    _initializeConstants();
    for (var i = 0; i < _arrayLength; i++) {
      _heliumPressure[i] = heliumPressure[i];
      _nitrogenPressure[i] = nitrogenPressure[i];
      _maxCrushingPressureHe[i] = maxCrushingPressureHe[i];
      _maxCrushingPressureN2[i] = maxCrushingPressureN2[i];
    }
    _runTime = runTime;
  }

  /// Apply one linear depth-change leg on [gas] (rate in msw/min; descent
  /// accumulates crushing pressure).
  void applyDepthChange(
    double startDepth,
    double endDepth,
    double rate,
    VpmGasMix gas,
  ) {
    _gasMixes = [gas];
    _mixNumber = 1;
    _gasLoadingsAscentDescent(startDepth, endDepth, rate);
    if (endDepth > startDepth) {
      _calcCrushingPressure(startDepth, endDepth, rate);
    }
  }

  /// Apply one constant-depth leg on [gas] ending at [runTimeEndOfSegment].
  void applyConstantDepth(
    double depth,
    double runTimeEndOfSegment,
    VpmGasMix gas,
  ) {
    _gasMixes = [gas];
    _mixNumber = 1;
    _gasLoadingsConstantDepth(depth, runTimeEndOfSegment);
  }

  /// Run the ascent (regeneration -> initial gradients -> critical volume
  /// loop) from the current state and return the staged stops.
  List<VpmStop> runAscent(
    List<VpmGasMix> gasMixes,
    List<VpmAscentChange> ascentChanges,
  ) {
    _gasMixes = gasMixes;
    _stops.clear();
    _decompressionLoop(ascentChanges);
    return List<VpmStop>.unmodifiable(_stops);
  }

  /// The deepest ascent ceiling (msw, >= 0) from the current state using the
  /// initial (un-relaxed) allowable gradients. This is the pre-Critical-Volume
  /// ceiling — a conservative "can I ascend?" metric, not the final first-stop
  /// depth. Mutates internal gradient arrays; restore state before reuse.
  double ascentCeilingDepthMeters() {
    _nuclearRegeneration(_runTime);
    _calcInitialAllowableGradient();
    _calcAscentCeiling();
    return _ascentCeilingDepth < 0.0 ? 0.0 : _ascentCeilingDepth;
  }
}
