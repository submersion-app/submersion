import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Where the active profile stands on a shared trip or site, for a page
/// choosing which actions to offer (issue #2594).
enum SharedItemStanding {
  /// May delete the item and change its sharing ([canDestroySharedItem]).
  owner,

  /// Sees the item because another profile owns it: may only remove it from
  /// itself.
  other,

  /// The active profile is not settled: still being read, being read again
  /// after a profile switch, or failed. While it reloads, the provider's
  /// `.value` still holds the previous profile, so a page offers neither
  /// owner nor other-profile actions until it settles, as the equipment
  /// pages do until the active diver is known.
  unknown,
}

/// The active profile's [SharedItemStanding] on an item owned by [ownerId].
/// Watches the active profile, so call it during build.
SharedItemStanding watchSharedItemStanding(
  WidgetRef ref, {
  required String? ownerId,
}) {
  final active = ref.watch(validatedCurrentDiverIdProvider);
  if (!active.hasValue || active.isLoading || active.hasError) {
    return SharedItemStanding.unknown;
  }
  return canDestroySharedItem(ownerId: ownerId, activeDiverId: active.value)
      ? SharedItemStanding.owner
      : SharedItemStanding.other;
}
