import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for [CertificationGroupBy].
///
/// The switch is exhaustive by enum value, so adding a grouping is a compile
/// error until its localization key is wired in.
extension CertificationGroupByDisplay on CertificationGroupBy {
  String localizedName(AppLocalizations l10n) => switch (this) {
    CertificationGroupBy.status => l10n.certifications_list_groupBy_status,
    CertificationGroupBy.agency => l10n.certifications_list_groupBy_agency,
    CertificationGroupBy.none => l10n.certifications_list_groupBy_none,
  };
}
