import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
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
String certificationTitleL10n(
  Certification cert,
  AppLocalizations l10n, {
  CertificationCatalog? catalog,
}) =>
    customNameOrNull(cert, catalog: catalog) ??
    derivedCertificationTitleL10n(
      cert.agency,
      cert.level,
      l10n,
      catalog: catalog,
    );

/// Localized [derivedCertificationTitle].
String derivedCertificationTitleL10n(
  String agency,
  String? level,
  AppLocalizations l10n, {
  CertificationCatalog? catalog,
}) {
  final c = catalog ?? CertificationCatalog.builtInOnly;
  return level != null
      ? c.level(level).localizedName(l10n)
      : c.agency(agency).localizedName(l10n);
}

/// Localized [certificationSubtitle]: the level, but only when the title is a
/// custom name (a derived title already contains it).
String? certificationSubtitleL10n(
  Certification cert,
  AppLocalizations l10n, {
  CertificationCatalog? catalog,
}) {
  final level = cert.level;
  if (level == null || customNameOrNull(cert, catalog: catalog) == null) {
    return null;
  }
  return (catalog ?? CertificationCatalog.builtInOnly)
      .level(level)
      .localizedName(l10n);
}

/// Localized [certificationAgencyAndLevel].
String certificationAgencyAndLevelL10n(
  Certification cert,
  AppLocalizations l10n, {
  CertificationCatalog? catalog,
}) {
  final level = certificationSubtitleL10n(cert, l10n, catalog: catalog);
  final agency = (catalog ?? CertificationCatalog.builtInOnly)
      .agency(cert.agency)
      .localizedName(l10n);
  return level == null ? agency : '$agency - $level';
}

/// Every recognition the card grants, "Agency Level" per credential joined
/// with " · " and no primary among them (e.g. "FFESSM N1 · CMAS 1-star").
/// Falls back to [certificationAgencyAndLevelL10n] for a single-agency card.
String certificationCredentialsLineL10n(
  Certification cert,
  AppLocalizations l10n, {
  CertificationCatalog? catalog,
}) {
  if (!cert.hasMultipleCredentials) {
    return certificationAgencyAndLevelL10n(cert, l10n, catalog: catalog);
  }
  return cert.credentials
      .map((c) => _credentialLine(c, l10n, catalog))
      .join(' · ');
}

String _credentialLine(
  CertificationCredential c,
  AppLocalizations l10n,
  CertificationCatalog? catalog,
) {
  final cat = catalog ?? CertificationCatalog.builtInOnly;
  final agency = cat.agency(c.agency).localizedName(l10n);
  final level = c.level;
  return level == null
      ? agency
      : '$agency ${cat.level(level).localizedName(l10n)}';
}

/// Just the *extra* recognitions on a multi-credential card ("Agency Level"
/// joined with " · "), or null for a single-agency card. The first credential
/// is already the card's title, so surfaces that show a headline plus a
/// secondary line use this for the line.
String? additionalCredentialsLineL10n(
  Certification cert,
  AppLocalizations l10n, {
  CertificationCatalog? catalog,
}) {
  if (!cert.hasMultipleCredentials) return null;
  return cert.additionalCredentials
      .map((c) => _credentialLine(c, l10n, catalog))
      .join(' · ');
}
