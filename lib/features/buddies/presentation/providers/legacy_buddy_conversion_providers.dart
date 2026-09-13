import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/services/legacy_buddy_conversion_service.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final legacyBuddyConversionServiceProvider =
    Provider<LegacyBuddyConversionService>(
      (ref) => LegacyBuddyConversionService(ref.watch(buddyRepositoryProvider)),
    );

/// The bulk page's dives; null when there is no diver. Auto-disposed, so
/// every visit re-plans from the database: a kept result would show a stale
/// empty state after the diver imports dives with buddy text.
final linkBuddyNamesDataProvider =
    FutureProvider.autoDispose<LinkBuddyNamesData?>((ref) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return null;
      return ref
          .watch(legacyBuddyConversionServiceProvider)
          .planCandidates(diverId);
    });

/// Refreshes everything a conversion or its undo can change (#1831).
///
/// Explicit, because the table-change streams miss it: the paginated dive
/// list's stream does not watch `dive_buddies`, and the buddy count
/// providers tick only on `buddies` and `dives`, which a links-only
/// conversion never writes. Takes the [ProviderContainer], not a
/// `WidgetRef`, because Undo can run after the page that converted is gone.
///
/// The paginated list's buddy filters and the detail page's neighbor ids
/// read `dive_buddies`. The list reloads in place rather than being
/// invalidated: on a wide layout it sits beside the dive being linked, and
/// an invalidate would drop it back to page one after every link. It is
/// reloaded only when something already holds it.
void refreshAfterLegacyBuddyConversion(ProviderContainer container) {
  container
    ..invalidate(buddiesForDiveProvider)
    ..invalidate(buddyStatsProvider)
    ..invalidate(diveIdsForBuddyProvider)
    ..invalidate(divesForBuddyProvider)
    ..invalidate(allBuddiesProvider)
    ..invalidate(allBuddiesWithDiveCountProvider)
    ..invalidate(divesProvider)
    ..invalidate(diveListNotifierProvider)
    ..invalidate(orderedDiveIdsProvider)
    ..invalidate(linkBuddyNamesDataProvider);
  if (container.exists(paginatedDiveListProvider)) {
    unawaited(
      container.read(paginatedDiveListProvider.notifier).reloadLoadedPages(),
    );
  }
}
