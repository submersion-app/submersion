import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/list_entry_count.dart';

/// The dive centers list's entry count (#2669): what the list shows against
/// what it holds with no filter. Null until the list loads.
final diveCenterListCountProvider = Provider<ListEntryCount?>(
  (ref) => listEntryCount(
    shown: ref.watch(filteredDiveCentersProvider),
    isFiltered: ref.watch(diveCenterQueryProvider) != null,
    total: () => ref.watch(diveCenterListNotifierProvider),
  ),
);

/// The subtitle under the dive centers list's title: "12 dive centers", or
/// "3 of 12 dive centers" while a filter is active.
String? diveCenterListCountLabel(BuildContext context, WidgetRef ref) => ref
    .watch(diveCenterListCountProvider)
    ?.label(
      all: context.l10n.diveCenters_list_count,
      filtered: context.l10n.diveCenters_list_countFiltered,
    );
