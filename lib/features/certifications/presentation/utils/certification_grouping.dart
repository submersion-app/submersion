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
List<CertificationGroup> _groupByAgency(
  List<Certification> certifications,
  CertificationCatalog catalog,
  AppLocalizations l10n,
) {
  final buckets = <String, List<Certification>>{};
  for (final cert in certifications) {
    buckets.putIfAbsent(cert.agency, () => []).add(cert);
  }

  final collator = TextCollator();
  final groups = [
    for (final entry in buckets.entries)
      CertificationGroup(
        key: entry.key,
        label: catalog.agency(entry.key).localizedName(l10n),
        certifications: entry.value,
      ),
  ]..sort((a, b) => collator.compare(a.label, b.label));
  return groups;
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
