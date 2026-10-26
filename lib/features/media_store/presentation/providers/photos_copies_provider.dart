import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';

/// The kinds that can keep photo copies (spec section 8.3): Git never holds
/// media, and Lightroom is a source, not a store.
const photoAccountKinds = {
  AccountKind.icloud,
  AccountKind.googledrive,
  AccountKind.dropbox,
  AccountKind.s3,
  AccountKind.webdav,
};

/// Where this device's photo copies are, for the Photos page's Using row.
///
/// [store] is the attached store, else the one the library announces;
/// [group] is the account it lives on when known (null for a store
/// announced before stores recorded their account, or an account this
/// device cannot list); [label] names it either way.
typedef PhotosCopies = ({
  bool attached,
  MediaStoreDescriptor? store,
  AccountGroup? group,
  String? label,
});

/// Reads the account groups, which probe every account, so only the Photos
/// page watches it.
final photosCopiesProvider = FutureProvider.autoDispose<PhotosCopies>((
  ref,
) async {
  final attachState = ref.watch(mediaStoreAttachStateProvider);
  final stores = ref.watch(mediaStoresRepositoryProvider);
  ref
    ..invalidateSelfWhen(stores.watchStoresChanges())
    ..invalidateSelfWhen(MediaStoreAttachState.markerMismatchChanges);
  final attached = await ref.watch(mediaStoreAttachedProvider.future);
  final attachedId = attached ? await attachState.attachedStoreId() : null;
  // Attached: that store only, even before its descriptor syncs in, so the
  // row never names (or rejoins) another store the library announces.
  final store = attachedId == null
      ? await stores.getActive()
      : await stores.getById(attachedId);
  final accountId = attached
      ? await attachState.attachedAccountId()
      : store?.accountId;
  // The groups only name the account. A probe that fails (a locked
  // keychain) must not make an attached device read as not set up, so the
  // copies fall back to the store's own name.
  List<AccountGroup> groups;
  try {
    groups = await ref.watch(accountGroupsProvider.future);
  } on Object {
    groups = const [];
  }
  final group = groups.holding(accountId);
  return (
    attached: attached,
    store: store,
    group: group,
    label: group?.label ?? store?.displayHint,
  );
}, retry: (_, _) => null);

/// Whether the attached store could be opened with this device's keys:
/// null while that is being checked. Resolving the runtime is also what
/// resumes the upload queue on opening the page.
final photosStoreReachableProvider = Provider.autoDispose<bool?>((ref) {
  final runtime = ref.watch(mediaStoreRuntimeProvider);
  return runtime.isLoading ? null : runtime.value != null;
});
