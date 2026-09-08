import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized name for a [CertificationAgency].
///
/// [CertificationAgency.displayName] stays hardcoded English on purpose: it
/// feeds data interchange (UDDF import/export, the field extractor, the PDF
/// templates). This getter drives on-screen UI so the same values honor the
/// active locale (issue #1608). In practice only [CertificationAgency.other]
/// differs per locale -- every other value is an acronym that passes through.
///
/// The switch is exhaustive by enum value, so adding a value is a compile error
/// until its localization key is wired in.
extension CertificationAgencyDisplay on CertificationAgency {
  String localizedName(AppLocalizations l10n) => switch (this) {
    CertificationAgency.padi => l10n.enum_certificationAgency_padi,
    CertificationAgency.ssi => l10n.enum_certificationAgency_ssi,
    CertificationAgency.naui => l10n.enum_certificationAgency_naui,
    CertificationAgency.sdi => l10n.enum_certificationAgency_sdi,
    CertificationAgency.tdi => l10n.enum_certificationAgency_tdi,
    CertificationAgency.gue => l10n.enum_certificationAgency_gue,
    CertificationAgency.raid => l10n.enum_certificationAgency_raid,
    CertificationAgency.bsac => l10n.enum_certificationAgency_bsac,
    CertificationAgency.cmas => l10n.enum_certificationAgency_cmas,
    CertificationAgency.iantd => l10n.enum_certificationAgency_iantd,
    CertificationAgency.psai => l10n.enum_certificationAgency_psai,
    CertificationAgency.ffessm => l10n.enum_certificationAgency_ffessm,
    CertificationAgency.other => l10n.enum_certificationAgency_other,
  };
}
