import 'package:submersion/core/models/sort_state_codec.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// How the diver has grouped the certification list and wallet (#3359).
/// App-wide, not route-scoped, so the choice survives switching between the
/// two views, matching [siteGroupByProvider]'s pattern.
///
/// Comes back as the diver left it (issue #3748): the active diver's saved
/// grouping, or by status when there is none. Change it through
/// `ListArrangementWrites.setCertificationGroupBy`.
final certificationGroupByProvider = Provider<CertificationGroupBy>(
  (ref) =>
      decodeEnumName(
        ref.watch(
          settingsProvider.select(
            (s) => s.listArrangements.certificationGroupBy,
          ),
        ),
        CertificationGroupBy.values,
      ) ??
      CertificationGroupBy.status,
);
