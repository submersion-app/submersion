import 'package:submersion/core/data/repositories/sync_repository.dart';
// Re-exports flutter_riverpod alongside the invalidateSelfWhen extension, so
// importing both would be redundant.
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// The newest upload row for one media id, reduced to the domain shape.
///
/// Guarded because the repository resolves its database lazily: an
/// uninitialized local cache surfaces a StateError from `watchLatestForMedia`
/// rather than from the watch, so both must sit inside the try. Widget tests
/// routinely run without that database, and a media item's provenance is not
/// worth failing a tree over.
///
/// AUTO-DISPOSING, unlike Riverpod 3's default for StreamProvider. Every
/// rendered grid tile opens one entry here, and each entry holds a live Drift
/// watch on `media_transfer_queue`. Kept forever, a scrolled library
/// accumulated one permanent subscription per row it had ever shown -- and
/// Drift re-runs every registered watch query on every write to that table, so
/// an upload drain cost O(rows ever rendered) queries per row it stamped
/// (#1175). Disposing when the tile scrolls away bounds that to what is
/// on screen.
// no-tick: already reactive on a real change stream (watchLatestForMedia).
final mediaQueueFactsProvider = StreamProvider.family<QueueFacts?, String>((
  ref,
  mediaId,
) {
  try {
    return ref
        .watch(mediaTransferQueueRepositoryProvider)
        .watchLatestForMedia(mediaId)
        .map(
          (row) => row == null
              ? null
              : QueueFacts(state: row.state, error: row.errorMessage),
        );
  } on StateError {
    return Stream.value(null);
  }
}, isAutoDispose: true);

/// Origin and backup facts for one media item.
///
/// Cheap by contract, because PR 3's grid badge derives from this on every
/// visible tile. It may watch [mediaStoreAttachedProvider] and
/// [mediaQueueFactsProvider]; it must NOT watch [mediaStoreRuntimeProvider]
/// or [mediaStoreStatusHintProvider], whose construction does a keychain
/// read, builds the object store, kicks a queue drain and can trigger a
/// verify sweep. A test pins that by overriding the runtime with a throwing
/// builder.
///
/// Both async dependencies are read through `.value` with a safe default, so
/// this never surfaces a loading state to a grid that has to build
/// synchronously. "Not yet known" reads the same as "not attached", which is
/// the conservative direction: it under-claims backup coverage rather than
/// over-claiming it.
///
/// Auto-disposing for the same reason as [mediaQueueFactsProvider], which it
/// keeps alive by watching. The family key is a whole [MediaItem] -- Equatable
/// over ~40 props -- so a retained entry is not free either.
final mediaProvenanceProvider = Provider.family<MediaProvenance, MediaItem>((
  ref,
  item,
) {
  final attached = ref.watch(mediaStoreAttachedProvider).value ?? false;
  final queue = ref.watch(mediaQueueFactsProvider(item.id)).value;
  return MediaProvenance.from(item, storeAttached: attached, queue: queue);
}, isAutoDispose: true);

/// Checks one item's source and persists the outcome.
///
/// no-tick: a service rather than data, so there is no cached query that
/// could go stale.
final mediaItemVerifierProvider = Provider<MediaItemVerifier>(
  (ref) => MediaItemVerifier(
    registry: ref.watch(mediaSourceResolverRegistryProvider),
    repository: ref.watch(mediaRepositoryProvider),
  ),
);

/// This device's sync id, for deciding whether a row was linked here.
///
/// Panel-only, like [mediaStoreIdentityProvider]. Overridable in tests, which
/// is the reason it is a provider rather than a direct call.
final currentDeviceIdProvider = FutureProvider<String>(
  (ref) => SyncRepository().getDeviceId(),
);

/// Which cloud store is attached, for display.
class MediaStoreIdentity {
  const MediaStoreIdentity({
    required this.providerType,
    required this.displayHint,
  });

  /// 's3', 'dropbox', 'googledrive' or 'icloud'.
  final String providerType;

  /// "bucket @ host" for S3; for the managed providers this is just the
  /// provider's own name, because that is all the connect flow records.
  final String displayHint;
}

/// The attached store's identity, or null when none is attached.
///
/// PANEL ONLY. Do not watch this from a grid tile. It reads the active store
/// descriptor, and its dependency chain can construct the store runtime,
/// which is the expensive path [mediaProvenanceProvider] is written to avoid.
///
/// Reads [MediaStoresRepository.getActive] directly rather than reusing
/// [mediaStoreStatusHintProvider], which collapses the provider type into the
/// hint string and loses the distinction the panel wants to show.
final mediaStoreIdentityProvider = FutureProvider<MediaStoreIdentity?>((
  ref,
) async {
  final storesRepository = ref.watch(mediaStoresRepositoryProvider);
  // Without this the panel would keep reporting whatever store was attached
  // when it first resolved: connect or disconnect a store and the Backup
  // block would serve a stale cache. Same tick mediaStoreStatusHintProvider
  // subscribes to.
  ref.invalidateSelfWhen(storesRepository.watchStoresChanges());
  final descriptor = await storesRepository.getActive();
  if (descriptor == null) return null;
  return MediaStoreIdentity(
    providerType: descriptor.providerType,
    displayHint: descriptor.displayHint,
  );
});
