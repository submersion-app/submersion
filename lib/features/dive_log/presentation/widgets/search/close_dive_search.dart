import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Closes the search row (#2773). With anything searched or filtered it
/// also clears the search, offering Undo. With [collapse] false (the chip
/// row's Clear all) it only clears, the same way.
void closeDiveSearch(
  BuildContext context,
  WidgetRef ref, {
  bool collapse = true,
}) {
  // The container, not [ref]: Undo runs from the snackbar, possibly after
  // the diver has left the list and the widget owning [ref] is gone.
  final container = ProviderScope.containerOf(context, listen: false);
  final snapshot = container.read(diveFilterProvider);
  container.read(diveSearchClearTickProvider.notifier).state++;
  if (collapse) {
    container.read(diveSearchBarOpenProvider.notifier).state = false;
  }
  if (!snapshot.hasActiveFilters) return;
  container.read(diveFilterProvider.notifier).state = const DiveFilterState();
  final l10n = context.l10n;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.diveLog_search_cleared),
        action: SnackBarAction(
          label: l10n.diveLog_search_undo,
          onPressed: () {
            container.read(diveFilterProvider.notifier).state = snapshot;
          },
        ),
      ),
    );
}
