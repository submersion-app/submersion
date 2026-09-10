import 'package:submersion/features/data_quality/domain/entities/diver_data_summary.dart';
import 'package:submersion/features/data_quality/presentation/widgets/dive_identity_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What [summary] holds, as one line a diver can read: counts for the things
/// there can be several of, a word for the things that are simply there.
///
/// Joined with [kDiveIdentitySeparator], the way the dive editor's own
/// collapsed section summaries read ("3 species · notes"), so a destructive
/// confirmation says what it is about to take without inventing a new shape
/// for it. Ordered from the work that takes longest to redo to the marks that
/// take a tap.
///
/// Null when there is nothing to say: an untouched recording, or a dive the
/// query could not find. Both leave the dialog exactly as it was before
/// (#1729).
String? describeDiverData(DiverDataSummary? summary, AppLocalizations l10n) {
  if (summary == null || summary.isEmpty) return null;
  final parts = [
    if (summary.gear > 0) l10n.dataQuality_carries_gear(summary.gear),
    if (summary.weights > 0) l10n.dataQuality_carries_weights(summary.weights),
    if (summary.buddies > 0) l10n.dataQuality_carries_buddies(summary.buddies),
    if (summary.tags > 0) l10n.dataQuality_carries_tags(summary.tags),
    // The dive editor already says "N species" in its own summary line; the
    // dialog says it the same way rather than in a second vocabulary.
    if (summary.sightings > 0)
      l10n.diveLog_edit_summary_species(summary.sightings),
    if (summary.media > 0) l10n.dataQuality_carries_media(summary.media),
    if (summary.customFields > 0)
      l10n.dataQuality_carries_customFields(summary.customFields),
    if (summary.hasNotes) l10n.diveLog_edit_summary_notes,
    if (summary.hasRating) l10n.dataQuality_carries_rating,
    if (summary.isFavorite) l10n.dataQuality_carries_favorite,
    if (summary.hasSite) l10n.dataQuality_carries_site,
    if (summary.hasTrip) l10n.dataQuality_carries_trip,
    if (summary.hasDiveCenter) l10n.dataQuality_carries_diveCenter,
    if (summary.hasCourse) l10n.dataQuality_carries_course,
  ];
  return parts.join(kDiveIdentitySeparator);
}
