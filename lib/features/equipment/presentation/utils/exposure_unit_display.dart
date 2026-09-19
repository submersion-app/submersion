import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for exposure units. Both switches are exhaustive, so a
/// new unit is a compile error until its keys exist.
extension ExposureUnitDisplay on ExposureUnit {
  String intervalLabel(AppLocalizations l10n) => switch (this) {
    ExposureUnit.days => l10n.equipment_scheduleDialog_intervalDays,
    ExposureUnit.dives => l10n.equipment_scheduleDialog_intervalDives,
    ExposureUnit.hours => l10n.equipment_scheduleDialog_intervalHours,
    ExposureUnit.saltHours => l10n.equipment_scheduleDialog_intervalSaltHours,
    ExposureUnit.coldDives => l10n.equipment_scheduleDialog_intervalColdDives,
    ExposureUnit.o2Hours => l10n.equipment_scheduleDialog_intervalO2Hours,
    ExposureUnit.deepCycles => l10n.equipment_scheduleDialog_intervalDeepCycles,
    ExposureUnit.cycles => l10n.equipment_scheduleDialog_intervalCycles,
  };

  /// The "N used, N of M units left" clock line. [days] has no usage line.
  String usedAndLeftText(
    AppLocalizations l10n, {
    required String used,
    required String remaining,
    required String total,
  }) => switch (this) {
    ExposureUnit.days => '',
    ExposureUnit.dives => l10n.equipment_serviceClocks_divesUsedAndLeft(
      int.parse(used),
      int.parse(remaining),
      int.parse(total),
    ),
    ExposureUnit.hours => l10n.equipment_serviceClocks_hoursUsedAndLeft(
      used,
      remaining,
      total,
    ),
    ExposureUnit.saltHours => l10n.equipment_serviceClocks_saltHoursUsedAndLeft(
      used,
      remaining,
      total,
    ),
    ExposureUnit.coldDives => l10n.equipment_serviceClocks_coldDivesUsedAndLeft(
      used,
      remaining,
      total,
    ),
    ExposureUnit.o2Hours => l10n.equipment_serviceClocks_o2HoursUsedAndLeft(
      used,
      remaining,
      total,
    ),
    ExposureUnit.deepCycles =>
      l10n.equipment_serviceClocks_deepCyclesUsedAndLeft(
        used,
        remaining,
        total,
      ),
    ExposureUnit.cycles => l10n.equipment_serviceClocks_cyclesUsedAndLeft(
      used,
      remaining,
      total,
    ),
  };
}
