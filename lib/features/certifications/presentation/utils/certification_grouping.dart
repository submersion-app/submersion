import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How the certification list and wallet are grouped (#3359). App-wide,
/// session-only, shared by both views.
///
/// Lives in presentation, not domain, because agency grouping orders by
/// [AppLocalizations]-dependent display names (like
/// `applyCertificationSorting`'s own agency sort does).
enum CertificationGroupBy { status, agency, none }

/// Key of the status group a certification falls into.
const String certificationExpiredGroupKey = 'expired';
const String certificationExpiringSoonGroupKey = 'expiringSoon';
const String certificationValidGroupKey = 'valid';

/// Key of the group holding [agencyId]'s professional ratings when
/// grouping by agency (issue #730). The agency's own group keeps the bare
/// agency id as its key.
String certificationProfessionalGroupKey(String agencyId) =>
    '$agencyId#professional';

/// One group of certifications sharing a status or a primary agency. Color
/// is a presentation concern -- the caller decides, from [key], whether and
/// how to show one.
class CertificationGroup {
  const CertificationGroup({
    required this.key,
    required this.label,
    required this.certifications,
  });

  final String key;
  final String label;
  final List<Certification> certifications;
}

/// The groups [groupBy] asks for, over [sortedCertifications] (expected
/// already sorted -- certifications keep that order inside each group).
///
/// Returns an empty list for [CertificationGroupBy.none]: callers render
/// [sortedCertifications] flat, with no section headers, rather than call
/// this at all.
List<CertificationGroup> groupCertificationsFor(
  CertificationGroupBy groupBy,
  List<Certification> sortedCertifications, {
  required AppLocalizations l10n,
  CertificationCatalog? catalog,
}) => switch (groupBy) {
  CertificationGroupBy.none => const [],
  CertificationGroupBy.status => _groupByStatus(sortedCertifications),
  CertificationGroupBy.agency => _groupByAgency(
    sortedCertifications,
    catalog ?? CertificationCatalog.builtInOnly,
    l10n,
  ),
};

/// Fixed Expired / Expiring Soon / Valid order, matching the certification
/// list's historical (pre-#3359) behavior. A status with no certifications
/// in it contributes no group (issue's "empty groups are hidden").
List<CertificationGroup> _groupByStatus(List<Certification> certifications) {
  final expired = <Certification>[];
  final expiringSoon = <Certification>[];
  final valid = <Certification>[];

  for (final cert in certifications) {
    if (cert.isExpired) {
      expired.add(cert);
    } else if (cert.expiresWithin(90)) {
      expiringSoon.add(cert);
    } else {
      valid.add(cert);
    }
  }

  return [
    if (expired.isNotEmpty)
      CertificationGroup(
        key: certificationExpiredGroupKey,
        label: '',
        certifications: expired,
      ),
    if (expiringSoon.isNotEmpty)
      CertificationGroup(
        key: certificationExpiringSoonGroupKey,
        label: '',
        certifications: expiringSoon,
      ),
    if (valid.isNotEmpty)
      CertificationGroup(
        key: certificationValidGroupKey,
        label: '',
        certifications: valid,
      ),
  ];
}

/// One group per primary agency (the card's own [Certification.agency];
/// [Certification.additionalCredentials] never create or join a group --
/// a card with a cross-over credential groups only under its primary
/// agency, per the issue's scope decision). Groups order alphabetically by
/// the agency's localized name, case/accent folded.
///
/// A card whose primary level is a professional rating (divemaster,
/// instructor and up) goes in a separate "`<agency>` Professional" group
/// placed right after that agency's own group (issue #730). An agency with
/// no professional ratings shows no such group, and one with only
/// professional ratings shows only that group.
List<CertificationGroup> _groupByAgency(
  List<Certification> certifications,
  CertificationCatalog catalog,
  AppLocalizations l10n,
) {
  final buckets = <(String, bool), List<Certification>>{};
  for (final cert in certifications) {
    final level = cert.level;
    final professional =
        level != null && catalog.level(level).isProfessionalLevel;
    buckets.putIfAbsent((cert.agency, professional), () => []).add(cert);
  }

  final collator = TextCollator();
  final agencyNames = <String, String>{
    for (final (agency, _) in buckets.keys)
      agency: catalog.agency(agency).localizedName(l10n),
  };
  final keys = buckets.keys.toList()
    ..sort((a, b) {
      final byName = collator.compare(agencyNames[a.$1]!, agencyNames[b.$1]!);
      if (byName != 0) return byName;
      // Two distinct agency ids with the same display name stay apart, and
      // each agency's professional group follows its own group.
      final byId = a.$1.compareTo(b.$1);
      if (byId != 0) return byId;
      return (a.$2 ? 1 : 0) - (b.$2 ? 1 : 0);
    });
  return [
    for (final key in keys)
      CertificationGroup(
        key: key.$2 ? certificationProfessionalGroupKey(key.$1) : key.$1,
        label: key.$2
            ? l10n.certifications_list_section_professional(
                agencyNames[key.$1]!,
              )
            : agencyNames[key.$1]!,
        certifications: buckets[key]!,
      ),
  ];
}

/// [sortedCertifications] unchanged for [CertificationGroupBy.none], else
/// the certifications of [groupCertificationsFor]'s groups, concatenated in
/// group order. Used for keyboard navigation order and for the wallet
/// grid's card order (which shows no group headers at all).
List<Certification> flattenCertificationGroups(
  CertificationGroupBy groupBy,
  List<Certification> sortedCertifications, {
  required AppLocalizations l10n,
  CertificationCatalog? catalog,
}) {
  if (groupBy == CertificationGroupBy.none) return sortedCertifications;
  return [
    for (final group in groupCertificationsFor(
      groupBy,
      sortedCertifications,
      l10n: l10n,
      catalog: catalog,
    ))
      ...group.certifications,
  ];
}
