import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/presentation/certification_agency_display.dart';
import 'package:submersion/features/certifications/presentation/certification_level_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// On-screen agency names (issue #690): built-ins localize, custom names and
/// slug fallbacks show verbatim, and an unknown UUID reads "Unknown agency".
extension AgencyEntryDisplay on AgencyEntry {
  String localizedName(AppLocalizations l10n) {
    final b = builtIn;
    if (b != null) return b.localizedName(l10n);
    if (isFallback && !isSlugFallback) {
      return l10n.certificationAgencies_unknownAgency;
    }
    return name;
  }
}

/// On-screen certification (level) names, with the same rules.
extension LevelEntryDisplay on LevelEntry {
  String localizedName(AppLocalizations l10n) {
    final b = builtIn;
    if (b != null) return b.localizedName(l10n);
    if (isFallback && !isSlugFallback) {
      return l10n.certificationAgencies_unknownCertification;
    }
    return name;
  }
}
