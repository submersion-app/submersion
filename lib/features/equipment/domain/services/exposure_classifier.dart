import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';

/// Turns exposure samples into per-unit amounts. Pure and threshold-driven,
/// so a changed setting changes every total on the next read with nothing
/// to rebuild.
///
/// Two item-level rules ride on the classifier because they depend on what
/// the item is, not on the dive:
/// - [loopTimeOnly]: rebreathers (and their children) accrue
///   [ExposureUnit.hours] on CCR and SCR mode dives only. Salt hours still
///   count every dive: the unit was wet whatever the loop did.
/// - [hasBatteryChild]: a parent whose battery is modelled as a child item
///   accrues no [ExposureUnit.cycles]; the child does.
class ExposureClassifier {
  final ExposureThresholds thresholds;
  final bool loopTimeOnly;
  final bool hasBatteryChild;

  const ExposureClassifier({
    this.thresholds = ExposureThresholds.defaults,
    this.loopTimeOnly = false,
    this.hasBatteryChild = false,
  });

  double contribution(EquipmentExposureSample s, ExposureUnit unit) {
    switch (unit) {
      case ExposureUnit.days:
        return 0; // The date trigger is evaluated from the anchor, not usage.
      case ExposureUnit.dives:
        return 1;
      case ExposureUnit.hours:
        if (loopTimeOnly &&
            s.diveMode != DiveMode.ccr &&
            s.diveMode != DiveMode.scr) {
          return 0;
        }
        return s.durationHours;
      case ExposureUnit.saltHours:
        return s.waterType == WaterType.salt ||
                s.waterType == WaterType.brackish
            ? s.durationHours
            : 0;
      case ExposureUnit.coldDives:
        final t = s.minTemperature;
        return t != null && t < thresholds.coldWaterC ? 1 : 0;
      case ExposureUnit.o2Hours:
        final o2 = s.contactO2Fraction;
        return o2 != null && o2 > thresholds.highO2Fraction
            ? s.durationHours
            : 0;
      case ExposureUnit.deepCycles:
        final depth = s.maxDepth;
        return depth != null && depth >= thresholds.deepDiveM ? 1 : 0;
      case ExposureUnit.cycles:
        return hasBatteryChild ? 0 : 1;
    }
  }

  Map<ExposureUnit, double> totals(Iterable<EquipmentExposureSample> samples) {
    final out = {for (final u in ExposureUnit.values) u: 0.0};
    for (final s in samples) {
      for (final u in ExposureUnit.values) {
        out[u] = out[u]! + contribution(s, u);
      }
    }
    return out;
  }
}
