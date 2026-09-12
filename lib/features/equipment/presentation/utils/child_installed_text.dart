import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// "Installed {date}, {age}" for a part installed in a parent; days under
/// two months, months after. Null when the part has neither an install
/// date nor a creation time to count from.
///
/// Shared by the host's children card and the part's own detail page, so
/// both say the same thing about the same part. [now] defaults to the
/// current time.
String? childInstalledText(
  AppLocalizations l10n,
  UnitFormatter units,
  EquipmentItem child, {
  DateTime? now,
}) {
  // The date its exposure counts from: the install date, else when the
  // part was created, as parentDivesFrom reads it.
  final installed = child.parentDivesFrom;
  if (installed == null) return null;
  final today = now ?? DateTime.now();
  // Whole calendar days, both ends in the dive frame parentDivesFrom uses
  // (a local day as UTC midnight): a local instant minus it is off by the
  // device's UTC offset.
  final days = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(installed.year, installed.month, installed.day))
      .inDays;
  // Completed calendar months: an average month length undercounts, so
  // a part installed a year ago read "11 months".
  var months =
      (today.year - installed.year) * 12 + today.month - installed.month;
  if (today.day < installed.day) months--;
  // Days through day 60, calendar months after (the phase plan).
  final age = days <= 60
      ? l10n.equipmentCondition_children_ageDays(days < 0 ? 0 : days)
      : l10n.equipmentCondition_children_ageMonths(months);
  return l10n.equipmentCondition_children_installed(
    units.formatDate(installed),
    age,
  );
}
