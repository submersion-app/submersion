import 'package:submersion/l10n/arb/app_localizations.dart';

/// The two-unit shape an elapsed time is shown in (issue #3119).
enum ElapsedTier { minutes, hoursMinutes, daysHours, yearsDays }

/// An elapsed time reduced to its two largest units.
///
/// [major] is the larger unit of [tier] and [minor] the next one down. In the
/// [ElapsedTier.minutes] tier [minor] is always 0.
typedef ElapsedSpan = ({ElapsedTier tier, int major, int minor});

const _minutesPerHour = 60;
const _hoursPerDay = 24;
const _minutesPerDay = _hoursPerDay * _minutesPerHour;
const _daysPerYear = 365;
const _minutesPerYear = _daysPerYear * _minutesPerDay;

/// Splits [elapsed] into its two largest units.
///
/// Works in whole minutes ([Duration.inMinutes]) and cuts every lower unit
/// off rather than rounding it up, so "it has been 6d 13h" never overstates
/// the time. A year is a fixed 365 days. A negative span reads as zero; a
/// caller that must show a negative value keeps its own branch for it.
ElapsedSpan splitElapsed(Duration elapsed) {
  final total = elapsed.isNegative ? 0 : elapsed.inMinutes;
  if (total < _minutesPerHour) {
    return (tier: ElapsedTier.minutes, major: total, minor: 0);
  }
  if (total < _minutesPerDay) {
    return (
      tier: ElapsedTier.hoursMinutes,
      major: total ~/ _minutesPerHour,
      minor: total % _minutesPerHour,
    );
  }
  if (total < _minutesPerYear) {
    return (
      tier: ElapsedTier.daysHours,
      major: total ~/ _minutesPerDay,
      minor: (total % _minutesPerDay) ~/ _minutesPerHour,
    );
  }
  return (
    tier: ElapsedTier.yearsDays,
    major: total ~/ _minutesPerYear,
    minor: (total % _minutesPerYear) ~/ _minutesPerDay,
  );
}

/// [elapsed] as "42 min", "5h 12m", "6d 13h" or "1y 35d", in the diver's
/// language.
String formatElapsed(AppLocalizations l10n, Duration elapsed) {
  final span = splitElapsed(elapsed);
  return switch (span.tier) {
    ElapsedTier.minutes => l10n.common_elapsed_minutes(span.major),
    ElapsedTier.hoursMinutes => l10n.common_elapsed_hoursMinutes(
      span.major,
      span.minor,
    ),
    ElapsedTier.daysHours => l10n.common_elapsed_daysHours(
      span.major,
      span.minor,
    ),
    ElapsedTier.yearsDays => l10n.common_elapsed_yearsDays(
      span.major,
      span.minor,
    ),
  };
}

/// [formatElapsed] with the unit it drops added back past a day: "6d 13h 42m"
/// and "1y 35d 5h".
///
/// For the sync conflict dialog, where two versions that differ only inside
/// the dropped unit must not read the same.
String formatElapsedExact(AppLocalizations l10n, Duration elapsed) {
  final span = splitElapsed(elapsed);
  final total = elapsed.isNegative ? 0 : elapsed.inMinutes;
  return switch (span.tier) {
    ElapsedTier.minutes ||
    ElapsedTier.hoursMinutes => formatElapsed(l10n, elapsed),
    ElapsedTier.daysHours => l10n.common_elapsed_daysHoursMinutes(
      span.major,
      span.minor,
      total % _minutesPerHour,
    ),
    ElapsedTier.yearsDays => l10n.common_elapsed_yearsDaysHours(
      span.major,
      span.minor,
      (total % _minutesPerDay) ~/ _minutesPerHour,
    ),
  };
}

/// The same tiers as [formatElapsed] with fixed English letters ("45min",
/// "1h 5m", "6d 13h", "1y 35d").
///
/// For code paths that have no [AppLocalizations] and already print English
/// letters, such as the dive table's duration columns.
String formatElapsedEnglish(Duration elapsed) {
  final span = splitElapsed(elapsed);
  return switch (span.tier) {
    ElapsedTier.minutes => '${span.major}min',
    ElapsedTier.hoursMinutes => '${span.major}h ${span.minor}m',
    ElapsedTier.daysHours => '${span.major}d ${span.minor}h',
    ElapsedTier.yearsDays => '${span.major}y ${span.minor}d',
  };
}

/// A whole-day count of a year or more as "1y 35d", or null under a year so
/// the caller keeps its own day-count wording.
String? formatElapsedDays(AppLocalizations l10n, int days) {
  if (days < _daysPerYear) return null;
  return l10n.common_elapsed_yearsDays(
    days ~/ _daysPerYear,
    days % _daysPerYear,
  );
}
