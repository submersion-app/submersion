import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized label for [MatchConfidence] -- how a media item's depth and
/// temperature were matched to the dive profile.
///
/// [MatchConfidence.displayName] stays hardcoded English (data interchange);
/// this drives the media viewer badge (issue #1608).
extension MatchConfidenceDisplay on MatchConfidence {
  String localizedName(AppLocalizations l10n) => switch (this) {
    MatchConfidence.exact => l10n.enum_matchConfidence_exact,
    MatchConfidence.interpolated => l10n.enum_matchConfidence_interpolated,
    MatchConfidence.estimated => l10n.enum_matchConfidence_estimated,
    MatchConfidence.noProfile => l10n.enum_matchConfidence_noProfile,
    MatchConfidence.manual => l10n.enum_matchConfidence_manual,
  };
}
