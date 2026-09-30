import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/list_entry_count.dart';

/// The certifications list's entry count (#2669): what the list shows against
/// what it holds with no filter. Null until the list loads.
final certificationListCountProvider = Provider<ListEntryCount?>(
  (ref) => listEntryCount(
    shown: ref.watch(filteredCertificationsProvider),
    isFiltered: ref.watch(certificationQueryProvider) != null,
    total: () => ref.watch(certificationListNotifierProvider),
  ),
);

/// The subtitle under the certifications list's title: "12 certifications", or
/// "3 of 12 certifications" while a filter is active.
String? certificationListCountLabel(BuildContext context, WidgetRef ref) => ref
    .watch(certificationListCountProvider)
    ?.label(
      all: context.l10n.certifications_list_count,
      filtered: context.l10n.certifications_list_countFiltered,
    );
