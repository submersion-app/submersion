import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/list_entry_count.dart';

/// The buddies list's entry count (#2669): what the list shows against
/// what it holds with no filter. Null until the list loads.
final buddyListCountProvider = Provider<ListEntryCount?>(
  (ref) => listEntryCount(
    shown: ref.watch(filteredBuddiesWithDiveCountProvider),
    isFiltered: ref.watch(buddyQueryProvider) != null,
    total: () => ref.watch(allBuddiesWithDiveCountProvider),
  ),
);

/// The subtitle under the buddies list's title: "12 buddies", or
/// "3 of 12 buddies" while a filter is active.
String? buddyListCountLabel(BuildContext context, WidgetRef ref) => ref
    .watch(buddyListCountProvider)
    ?.label(
      all: context.l10n.buddies_list_count,
      filtered: context.l10n.buddies_list_countFiltered,
    );
