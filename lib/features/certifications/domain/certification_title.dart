import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// What a certification is called on screen, and whether its stored
/// [Certification.name] adds anything to the structured fields.
///
/// Until 2026-08 the edit form auto-filled `name` from agency + level
/// ("PADI : Open Water"), so most stored names merely repeat what `agency`
/// and `level` already say, and surfaces rendered the same string twice.
/// Rather than rewrite those rows, the display layer recognises a derived
/// name and suppresses it. That is why [hasDerivedName] must keep matching
/// the legacy spaced-colon format for as long as such rows can exist.

/// The title to show when no custom name is stored: the certification alone
/// ("Open Water"), falling back to the agency when there is no certification.
///
/// Deliberately does NOT prefix the agency. Every surface that shows a
/// certification already shows its agency on a separate line or column -- the
/// detail page's Agency row, the picker's subtitle, the PDF's agency line, the
/// list's Agency column -- so prefixing here would just trade one duplication
/// for another.
/// The agency label to show: the free-text custom agency when [agency] is
/// [CertificationAgency.other] and a custom name was entered, otherwise the
/// enum's display name.
String effectiveAgencyLabel(CertificationAgency agency, String? agencyCustom) {
  if (agency == CertificationAgency.other) {
    final custom = agencyCustom?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
  }
  return agency.displayName;
}

/// The level label to show: the free-text custom level when [level] is
/// [CertificationLevel.other] and a custom name was entered, otherwise the
/// enum's display name. Null when there is no level.
String? effectiveLevelLabel(CertificationLevel? level, String? levelCustom) {
  if (level == CertificationLevel.other) {
    final custom = levelCustom?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
  }
  return level?.displayName;
}

String derivedCertificationTitle(
  CertificationAgency agency,
  CertificationLevel? level, {
  String? agencyCustom,
  String? levelCustom,
}) =>
    effectiveLevelLabel(level, levelCustom) ??
    effectiveAgencyLabel(agency, agencyCustom);

String _normalized(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// True when [cert]'s stored name carries no information beyond agency and
/// level -- including an empty name.
bool hasDerivedName(Certification cert) {
  final stored = _normalized(cert.name);
  if (stored.isEmpty) return true;

  final agencyName = effectiveAgencyLabel(cert.agency, cert.agencyCustom);
  final level = effectiveLevelLabel(cert.level, cert.levelCustom);
  final candidates = <String>[
    agencyName,
    if (level != null) ...[
      '$agencyName $level',
      '$agencyName: $level',
      '$agencyName : $level',
      level,
    ],
  ];
  return candidates.map(_normalized).contains(stored);
}

/// The stored name when it says something the structured fields do not,
/// otherwise null.
String? customNameOrNull(Certification cert) =>
    hasDerivedName(cert) ? null : cert.name.trim();

/// The title to show for [cert] anywhere one is needed. Never empty.
String certificationTitle(Certification cert) =>
    customNameOrNull(cert) ??
    derivedCertificationTitle(
      cert.agency,
      cert.level,
      agencyCustom: cert.agencyCustom,
      levelCustom: cert.levelCustom,
    );

/// The secondary line beneath [certificationTitle]: the level, but only when
/// the title is a custom name. When the title is derived it already contains
/// the level, and showing it again is the duplication this module exists to
/// remove.
String? certificationSubtitle(Certification cert) =>
    customNameOrNull(cert) == null
    ? null
    : effectiveLevelLabel(cert.level, cert.levelCustom);
