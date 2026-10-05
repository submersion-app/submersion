import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
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
  String agency,
  String? level, {
  CertificationCatalog? catalog,
}) {
  final c = catalog ?? CertificationCatalog.builtInOnly;
  return level != null
      ? c.level(level).interchangeName
      : c.agency(agency).interchangeName;
}

String _normalized(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// True when [cert]'s stored name carries no information beyond agency and
/// level -- including an empty name.
bool hasDerivedName(Certification cert, {CertificationCatalog? catalog}) {
  final stored = _normalized(cert.name);
  if (stored.isEmpty) return true;

  final c = catalog ?? CertificationCatalog.builtInOnly;
  final agencyName = c.agency(cert.agency).interchangeName;
  final level = cert.level;
  final levelName = level == null ? null : c.level(level).interchangeName;
  final candidates = <String>[
    agencyName,
    if (levelName != null) ...[
      '$agencyName $levelName',
      '$agencyName: $levelName',
      '$agencyName : $levelName',
      levelName,
    ],
  ];
  return candidates.map(_normalized).contains(stored);
}

/// The stored name when it says something the structured fields do not,
/// otherwise null.
String? customNameOrNull(Certification cert, {CertificationCatalog? catalog}) =>
    hasDerivedName(cert, catalog: catalog) ? null : cert.name.trim();

/// The title to show for [cert] anywhere one is needed. Never empty.
String certificationTitle(
  Certification cert, {
  CertificationCatalog? catalog,
}) =>
    customNameOrNull(cert, catalog: catalog) ??
    derivedCertificationTitle(cert.agency, cert.level, catalog: catalog);

/// The secondary line beneath [certificationTitle]: the level, but only when
/// the title is a custom name. When the title is derived it already contains
/// the level, and showing it again is the duplication this module exists to
/// remove.
String? certificationSubtitle(
  Certification cert, {
  CertificationCatalog? catalog,
}) {
  final level = cert.level;
  if (level == null || customNameOrNull(cert, catalog: catalog) == null) {
    return null;
  }
  return (catalog ?? CertificationCatalog.builtInOnly)
      .level(level)
      .interchangeName;
}

/// The agency line that list surfaces put beneath [certificationTitle],
/// carrying the level as well whenever the title is a custom name.
///
/// A card stored as "Bill Ansell" takes the whole title, so without this the
/// level it was actually issued for (Divemaster) would appear nowhere on the
/// tile. [certificationSubtitle] returns null for a derived title, which
/// already names the level, so this never says it twice.
String certificationAgencyAndLevel(
  Certification cert, {
  CertificationCatalog? catalog,
}) {
  final level = certificationSubtitle(cert, catalog: catalog);
  final agency = (catalog ?? CertificationCatalog.builtInOnly)
      .agency(cert.agency)
      .interchangeName;
  return level == null ? agency : '$agency - $level';
}
