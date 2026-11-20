import 'package:submersion/l10n/arb/app_localizations.dart';

/// How long an item has been owned, in days below a month, months below a
/// year, and years and months above: the Owned for row on the item's
/// Details card, read and open alike.
String equipmentOwnedForText(AppLocalizations l10n, Duration duration) {
  final days = duration.inDays;
  if (days < 30) return l10n.equipment_detail_durationDays(days);
  if (days < 365) {
    final months = (days / 30).floor();
    return l10n.equipment_detail_durationMonths(months);
  }
  final years = (days / 365).floor();
  final months = ((days % 365) / 30).floor();
  if (months == 0) {
    return years == 1
        ? l10n.equipment_detail_durationYearsSingular(years)
        : l10n.equipment_detail_durationYearsPlural(years);
  }
  if (years == 1 && months == 1) {
    return l10n.equipment_detail_durationYearsMonthsSingularSingular(
      years,
      months,
    );
  }
  if (years == 1) {
    return l10n.equipment_detail_durationYearsMonthsSingularPlural(
      years,
      months,
    );
  }
  if (months == 1) {
    return l10n.equipment_detail_durationYearsMonthsPluralSingular(
      years,
      months,
    );
  }
  return l10n.equipment_detail_durationYearsMonthsPluralPlural(years, months);
}
