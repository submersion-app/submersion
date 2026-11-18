import 'package:submersion/core/services/export/uddf/uddf_gas_mix_writers.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The mix an impossible [mix] ([GasMix.isPossible]) was meant to be when
/// an import stored it 100 times too high, or null when that does not
/// explain it (issue #4714).
///
/// Imports that read percentages as fractions multiplied every share by 100
/// (UDDF #4705, MacDive #1493), so both shares are divided back, and only
/// when neither was left within 0..100 by a hand correction. The result
/// must be a gas a diver breathes: a possible mix holding at least
/// [QualityThresholds.rescaledMinO2Percent] oxygen, and helium too when it is
/// hypoxic. A stored 150% O2 divided is 1.5%, and a typed 100% with an extra
/// zero divided is 10% O2 in nitrogen; neither is a diving gas, so something
/// else went wrong and the diver corrects it. A possible [mix] needs no
/// correction and also gives null.
GasMix? hundredfoldCorrection(GasMix mix) {
  if (mix.isPossible) return null;
  // The importers multiplied both shares, so one still within 0..100 beside
  // an inflated one was not: the diver put it right by hand, say the helium
  // of a Tx 18/45 stored as 1800/4500, and dividing it again would turn
  // their 45% helium into 0.45%. Only a share of none is the same either way.
  bool inRange(double share) => share > 0 && share <= 100;
  if (inRange(mix.o2) || inRange(mix.he)) return null;
  final divided = GasMix(o2: _hundredth(mix.o2), he: _hundredth(mix.he));
  // Under 1% helium makes no hypoxic mix breathable: a typed 1000% O2 on a
  // Tx 10/50 cylinder divides to 10% O2 with 0.5% helium, which is not what
  // the diver had, and the launch repair writes it unasked.
  final hypoxicNitrox =
      divided.o2 < QualityThresholds.hypoxicFo2 * 100 && divided.he < 1;
  if (!divided.isPossible ||
      divided.o2 < QualityThresholds.rescaledMinO2Percent ||
      hypoxicNitrox) {
    return null;
  }
  return divided;
}

/// [percent] / 100, cleaned as the UDDF reader cleans a percentage, so
/// 3212.5 gives exactly 32.125 rather than its binary neighbour.
double _hundredth(double percent) =>
    UddfGasMixWriters.cleanPercent(percent / 100);
