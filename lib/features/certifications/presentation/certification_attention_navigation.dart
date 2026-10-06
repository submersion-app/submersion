import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';

/// Opens the certification list scoped to what needs attention, as the home
/// certifications chip does (issue #2267).
///
/// The scope REPLACES any query rather than merging with it: a leftover
/// narrowing would hide certifications the chip just counted. Pushed, so
/// back returns to Home, as the gear service chips do.
void openCertificationsNeedingAttention(BuildContext context, WidgetRef ref) {
  ref.read(certificationQueryProvider.notifier).state = null;
  ref.read(certificationAttentionFilterProvider.notifier).state = true;
  context.push('/certifications');
}
