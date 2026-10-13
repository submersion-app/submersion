/// Who may do what to a trip or dive site shared between diver profiles
/// (issue #2594). A shared item is owned by its `diver_id` and referenced by
/// every other profile: only the owner destroys it or changes its sharing,
/// and every other profile may hide it from itself. The repositories, the
/// pages and the lists all ask here, so the rule lives in one place, as
/// `equipment_ownership.dart` does for gear.
library;

import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// The two kinds of item shared through an `is_shared` flag.
enum SharedItemKind { trip, site }

/// The active profile may delete, merge away or re-share the item. An
/// ownerless item and a caller that names no profile behave as they did
/// before sharing existed.
bool canDestroySharedItem({
  required String? ownerId,
  required String? activeDiverId,
  bool isLibrarySite = false,
}) =>
    !isLibrarySite &&
    (activeDiverId == null || ownerId == null || ownerId == activeDiverId);

/// The active profile sees the item only because another profile shared
/// it, so it may hide it from itself. For any owned shared item exactly one
/// of this and [canDestroySharedItem] holds.
bool canHideSharedItem({
  required String? ownerId,
  required bool isShared,
  required String? activeDiverId,
  bool isLibrarySite = false,
}) =>
    activeDiverId != null &&
    (isLibrarySite ||
        (isShared && ownerId != null && ownerId != activeDiverId));

/// Splits a bulk-delete selection: the items the active profile may
/// destroy, and the shared items of other profiles it hides instead. An
/// item that fits neither (another profile's private item, which the lists
/// never show) is left out of both.
({List<T> destroy, List<T> hide}) splitForBulkDelete<T>(
  Iterable<T> items, {
  required String? Function(T) ownerOf,
  required bool Function(T) isSharedOf,
  required String? activeDiverId,
  bool Function(T)? isLibraryOf,
}) {
  final destroy = <T>[];
  final hide = <T>[];
  for (final item in items) {
    // A shared site library site is neither destroyed nor hidden by a bulk
    // delete (issue #2567): its own role-gated action removes it.
    if (isLibraryOf?.call(item) ?? false) continue;
    final owner = ownerOf(item);
    if (canDestroySharedItem(ownerId: owner, activeDiverId: activeDiverId)) {
      destroy.add(item);
    } else if (canHideSharedItem(
      ownerId: owner,
      isShared: isSharedOf(item),
      activeDiverId: activeDiverId,
    )) {
      hide.add(item);
    }
  }
  return (destroy: destroy, hide: hide);
}

/// Role-gated actions on a shared site library site (issue #2567). The storage
/// credentials are the hard boundary; these decide what the UI offers.
bool canEditLibrarySite(SharedLibraryRole role) =>
    role != SharedLibraryRole.reader;

bool canDeleteLibrarySite(SharedLibraryRole role) =>
    role != SharedLibraryRole.reader;

bool canManageLibrary(SharedLibraryRole role) =>
    role == SharedLibraryRole.owner;

bool canSuggestOnLibrarySite(SharedLibraryRole role) =>
    role == SharedLibraryRole.reader;
