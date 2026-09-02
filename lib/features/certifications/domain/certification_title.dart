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
String derivedCertificationTitle(
  CertificationAgency agency,
  CertificationLevel? level,
) => level?.displayName ?? agency.displayName;

String _normalized(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// True when [cert]'s stored name carries no information beyond agency and
/// level -- including an empty name.
bool hasDerivedName(Certification cert) {
  final stored = _normalized(cert.name);
  if (stored.isEmpty) return true;

  final agencyName = cert.agency.displayName;
  final level = cert.level;
  final candidates = <String>[
    agencyName,
    if (level != null) ...[
      '$agencyName ${level.displayName}',
      '$agencyName: ${level.displayName}',
      '$agencyName : ${level.displayName}',
      level.displayName,
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
    derivedCertificationTitle(cert.agency, cert.level);

/// The secondary line beneath [certificationTitle]: the level, but only when
/// the title is a custom name. When the title is derived it already contains
/// the level, and showing it again is the duplication this module exists to
/// remove.
String? certificationSubtitle(Certification cert) =>
    customNameOrNull(cert) == null ? null : cert.level?.displayName;

/// The agency line that list surfaces put beneath [certificationTitle],
/// carrying the level as well whenever the title is a custom name.
///
/// A card stored as "Bill Ansell" takes the whole title, so without this the
/// level it was actually issued for (Divemaster) would appear nowhere on the
/// tile. [certificationSubtitle] returns null for a derived title, which
/// already names the level, so this never says it twice.
String certificationAgencyAndLevel(Certification cert) {
  final level = certificationSubtitle(cert);
  final agency = cert.agency.displayName;
  return level == null ? agency : '$agency - $level';
}
