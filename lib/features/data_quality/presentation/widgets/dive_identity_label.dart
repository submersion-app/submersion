import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Separator between identity segments. Distinct from the bullet used inside
/// `UnitFormatter.formatDateTimeBullet` so a date and its time never look like
/// two separate facts about the dive.
const String kDiveIdentitySeparator = ' · ';

/// How a dive is named to a diver: a headline that identifies *which* dive,
/// and an optional stats line that says what it was.
class DiveIdentityLabel {
  const DiveIdentityLabel({required this.headline, this.stats});

  /// Always non-empty. Falls back through dive number, name or site, and the
  /// entry time, so a dive with none of the first three still reads as a dive
  /// rather than as a database id.
  final String headline;

  /// Max depth and duration, when either is recorded. Null when neither is.
  final String? stats;
}

/// Builds the identity of [summary] as a diver reads it.
///
/// Facts in, prose out: the numbers are routed through [formatters] so the
/// same dive reads in metres or feet, and on a 12- or 24-hour clock, according
/// to the active diver's settings.
///
/// A null [summary] means the finding outlived its dive (deleted, or folded
/// into another by a merge). That says so in words; it never falls back to the
/// dive id, which identifies nothing to the person reading it.
DiveIdentityLabel buildDiveIdentityLabel({
  required DiveSummary? summary,
  required AppLocalizations l10n,
  required QualityUnitFormatters formatters,
}) {
  if (summary == null) {
    return DiveIdentityLabel(headline: l10n.dataQuality_dive_unknown);
  }

  final number = summary.diveNumber;
  // The dive's own name, else the site it was logged at. Both are optional and
  // frequently unset on freshly downloaded dives, which is how the inbox came
  // to render bare uuids.
  final place = summary.effectiveName ?? _trimToNull(summary.siteName);
  // `entryTime` is the wall-clock the diver entered the water; `dateTime` is
  // the stored dive date. One of them is always present, which is what lets
  // the headline never be empty.
  final when = summary.entryTime ?? summary.dateTime;

  final headline = [
    if (number != null) l10n.dataQuality_dive_number(number),
    ?place,
    formatters.dateTime(when),
  ].join(kDiveIdentitySeparator);

  // Runtime is the full submerged time and matches what the dive list shows;
  // bottom time stands in for the dives that only recorded that.
  final duration = summary.runtime ?? summary.bottomTime;
  final stats = [
    if (summary.maxDepth != null) formatters.depth(summary.maxDepth!),
    if (duration != null) l10n.diveLog_sources_minutes(duration.inMinutes),
  ].join(kDiveIdentitySeparator);

  return DiveIdentityLabel(
    headline: headline,
    stats: stats.isEmpty ? null : stats,
  );
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
