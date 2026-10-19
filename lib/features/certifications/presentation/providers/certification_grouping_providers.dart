import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';

/// How the diver has grouped the certification list and wallet (#3359).
/// App-wide, not route-scoped, so the choice survives switching between the
/// two views, matching [siteGroupByProvider]'s pattern.
final certificationGroupByProvider = StateProvider<CertificationGroupBy>(
  (ref) => CertificationGroupBy.status,
);
