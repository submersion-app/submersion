import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The mix an impossible [mix] ([GasMix.isPossible]) was meant to be when an import stored it 100
/// times too high, or null when that does not explain it (issue #4714).
///
/// Imports that read percentages as fractions multiplied every share by 100
/// (UDDF #4705, MacDive #1493), so both shares are divided back. The result
/// must be a possible mix holding at least
/// [QualityThresholds.rescaledMinO2Percent] oxygen; a stored 150% O2 divided
/// is 1.5%, no breathing gas, so something else went wrong there. A possible
/// [mix] needs no correction and also gives null.
GasMix? hundredfoldCorrection(GasMix mix) {
  if (mix.isPossible) return null;
  final divided = GasMix(o2: _hundredth(mix.o2), he: _hundredth(mix.he));
  if (!divided.isPossible ||
      divided.o2 < QualityThresholds.rescaledMinO2Percent) {
    return null;
  }
  return divided;
}

/// [percent] / 100 at ten decimals, as the UDDF reader cleans a percentage,
/// so 3212.5 gives exactly 32.125 rather than its binary neighbour.
double _hundredth(double percent) =>
    double.parse((percent / 100).toStringAsFixed(10)) + 0.0;
