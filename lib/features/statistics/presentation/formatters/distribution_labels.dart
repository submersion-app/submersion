import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// On-screen text for the distribution keys the statistics repository emits.
///
/// The repository returns stable, locale-independent keys rather than display
/// text -- the contract the visibility distribution already follows (see
/// `visibilityDistributionLabel`). Two reasons:
///
/// 1. The time-of-day buckets come out of a SQL CASE expression whose literals
///    are also the ORDER BY sort keys, so translating them in SQL would reorder
///    the chart per locale and desynchronise the fixed legend colours.
/// 2. Water type, entry method and dive type are stored enum names and slugs,
///    which sync, CSV export and the field extractor all carry verbatim.
///
/// An unrecognized key can only come from a repository change, so it is
/// surfaced verbatim rather than mapped onto some other bucket.

/// Localized name for a time-of-day bucket key.
///
/// Keys are `Morning`, `Afternoon`, `Evening` and `Night`; see
/// `StatisticsRepository.getDivesByTimeOfDay`.
String timeOfDayDistributionLabel(String key, AppLocalizations l10n) =>
    switch (key) {
      'Morning' => l10n.statistics_timePatterns_timeOfDay_morning,
      'Afternoon' => l10n.statistics_timePatterns_timeOfDay_afternoon,
      'Evening' => l10n.statistics_timePatterns_timeOfDay_evening,
      'Night' => l10n.statistics_timePatterns_timeOfDay_night,
      _ => key,
    };

/// Localized name for a stored [WaterType] enum name.
String waterTypeDistributionLabel(String key, AppLocalizations l10n) =>
    WaterType.values
        .where((w) => w.name == key)
        .firstOrNull
        ?.localizedName(l10n) ??
    key;

/// Localized name for a stored [EntryMethod] enum name.
String entryMethodDistributionLabel(String key, AppLocalizations l10n) =>
    EntryMethod.values
        .where((e) => e.name == key)
        .firstOrNull
        ?.localizedName(l10n) ??
    key;

/// Localized name for a dive-type id.
///
/// Built-in slugs resolve through the shared translation table; a custom type
/// keeps the diver's own slug. An empty id means the join row carries no type.
String diveTypeDistributionLabel(String key, AppLocalizations l10n) =>
    key.isEmpty
    ? l10n.statistics_summary_diveTypes_unknown
    : diveTypeLabel(l10n, key);

/// [segments] with every label replaced by [label] applied to its key.
List<DistributionSegment> localizeDistribution(
  List<DistributionSegment> segments,
  String Function(String key) label,
) => [
  for (final segment in segments)
    DistributionSegment(
      label: label(segment.label),
      count: segment.count,
      percentage: segment.percentage,
    ),
];
