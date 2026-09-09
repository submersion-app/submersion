import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/certification_agency_display.dart';
import 'package:submersion/features/certifications/presentation/certification_level_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Locale-aware counterparts of the helpers in `certification_title.dart`.
///
/// The domain versions stay English: they feed the CSV/Excel field extractor
/// and the (English) certification PDF, where a stable value is wanted, and
/// [hasDerivedName]'s legacy stored-name matching must keep comparing against
/// the English `displayName`. These wrap the same "is the stored name derived?"
/// decision but render agency and level through the active locale, for every
/// on-screen surface and the localized certification card.

/// Localized [certificationTitle]: the custom stored name, else the level
/// ("Open Water"), else the agency.
String certificationTitleL10n(Certification cert, AppLocalizations l10n) =>
    customNameOrNull(cert) ??
    derivedCertificationTitleL10n(cert.agency, cert.level, l10n);

/// Localized [derivedCertificationTitle].
String derivedCertificationTitleL10n(
  CertificationAgency agency,
  CertificationLevel? level,
  AppLocalizations l10n,
) => level?.localizedName(l10n) ?? agency.localizedName(l10n);

/// Localized [certificationSubtitle]: the level, but only when the title is a
/// custom name (a derived title already contains it).
String? certificationSubtitleL10n(Certification cert, AppLocalizations l10n) =>
    customNameOrNull(cert) == null ? null : cert.level?.localizedName(l10n);

/// Localized [certificationAgencyAndLevel].
String certificationAgencyAndLevelL10n(
  Certification cert,
  AppLocalizations l10n,
) {
  final level = certificationSubtitleL10n(cert, l10n);
  final agency = cert.agency.localizedName(l10n);
  return level == null ? agency : '$agency - $level';
}

/// Every recognition the card grants, "Agency Level" per credential joined
/// with " · " and no primary among them (e.g. "FFESSM N1 · CMAS 1-star").
/// Falls back to [certificationAgencyAndLevelL10n] for a single-agency card.
String certificationCredentialsLineL10n(
  Certification cert,
  AppLocalizations l10n,
) {
  if (!cert.hasMultipleCredentials) {
    return certificationAgencyAndLevelL10n(cert, l10n);
  }
  return cert.credentials
      .map((c) {
        final agency = c.agency.localizedName(l10n);
        final level = c.level?.localizedName(l10n);
        return level == null ? agency : '$agency $level';
      })
      .join(' · ');
}

/// Just the *extra* recognitions on a multi-credential card ("Agency Level"
/// joined with " · "), or null for a single-agency card. The first credential
/// is already the card's title, so surfaces that show a headline plus a
/// secondary line use this for the line.
String? additionalCredentialsLineL10n(
  Certification cert,
  AppLocalizations l10n,
) {
  if (!cert.hasMultipleCredentials) return null;
  return cert.additionalCredentials
      .map((c) {
        final agency = c.agency.localizedName(l10n);
        final level = c.level?.localizedName(l10n);
        return level == null ? agency : '$agency $level';
      })
      .join(' · ');
}
