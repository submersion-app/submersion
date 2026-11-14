import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_log/domain/entities/counterdiffusion_analysis.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart';

/// Rule-of-fifths cautions and violations at the gas switches of
/// [segments], in time order (issue #4530).
///
/// Open circuit to open circuit compares the two mixes as the ICD calculator
/// does. A bailout from the loop compares the mix the loop delivered at the
/// switch: the setpoint's share of O2 at [ambientPressureAt] the switch time,
/// the rest split as the diluent splits it. Switches onto or within the loop
/// are not checked, and a bailout whose ambient pressure is unknown is
/// skipped rather than guessed.
List<IcdSwitchMarker> icdSwitchMarkersOf(
  List<ProfileGasSegment> segments, {
  required double? Function(int timestamp) ambientPressureAt,
}) {
  final markers = <IcdSwitchMarker>[];
  for (var i = 1; i < segments.length; i++) {
    final before = segments[i - 1];
    final after = segments[i];
    if (after.setpoint != null) continue;

    final GasMix from;
    final setpoint = before.setpoint;
    if (setpoint == null) {
      from = _mixOf(before.fN2, before.fHe);
    } else {
      final ambient = ambientPressureAt(after.startTimestamp);
      if (ambient == null || ambient <= 0) continue;
      final loop = _loopMix(before, setpoint, ambient);
      if (loop == null) continue;
      from = loop;
    }
    final to = _mixOf(after.fN2, after.fHe);

    final severity = computeIcd(IcdInputs(gasA: from, gasB: to)).severity;
    if (severity == IcdSeverity.ok) continue;
    markers.add(
      IcdSwitchMarker(
        timestamp: after.startTimestamp,
        severity: severity,
        from: from,
        to: to,
      ),
    );
  }
  return List.unmodifiable(markers);
}

GasMix _mixOf(double fN2, double fHe) =>
    GasMix(o2: _percent(1 - fN2 - fHe), he: _percent(fHe));

/// Steps per percent the mixes are rebuilt at: 0.0001 %, far finer than any
/// blend is analysed to.
const int _percentSteps = 10000;

/// [fraction] as a percentage, snapped to [_percentSteps]. A fraction carries
/// float noise ((1 - 0.55) * 100 is 45.00000000000001), which tips a switch
/// sitting exactly on the rule-of-fifths limit, such as Tx 25/25 to EAN45,
/// into a violation the ICD calculator grades as a caution on the same
/// whole-number gases. Dividing the rounded steps yields the same double as
/// the decimal the calculator is fed.
double _percent(double fraction) =>
    (fraction * 100 * _percentSteps).round() / _percentSteps;

/// The loop's mix at [ambient] bar on [setpoint], or null when the diluent
/// carries no inert gas to split.
GasMix? _loopMix(ProfileGasSegment loop, double setpoint, double ambient) {
  final diluentInert = loop.fN2 + loop.fHe;
  if (diluentInert <= 0) return null;
  final fO2 = (setpoint / ambient).clamp(0.0, 1.0);
  final inert = 1 - fO2;
  final fHe = inert * loop.fHe / diluentInert;
  return GasMix(o2: _percent(fO2), he: _percent(fHe));
}
