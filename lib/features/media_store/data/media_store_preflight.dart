import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';

/// The admission check [MediaStoreWorker] runs before every transfer (design
/// spec section 13): this device must still be attached to the store the
/// runtime was built for, and the store must still carry that store's
/// marker. A refusal ([check] answering a kind) suspends the drain.
///
/// Attach state is re-read on every call, not captured: a disconnect can
/// land while a drain is running, and the rest of that drain must stop.
///
/// A marker that is present but not the attached one means the store was
/// wiped and re-minted, or repointed, and this check deliberately does NOT
/// resolve that on its own. Adopting the store the container happens to hold
/// looked attractive for iCloud, where the container is fixed per Apple ID,
/// but `media` rows carry no store id: their `remoteUploadedAt` stamps would
/// survive an adoption and keep reading "backed up" while pointing at
/// objects the new store never held. Spec section 13 makes adopt one of
/// three GUIDED choices (adopt / rebuild / detach) for that reason. Until
/// those exist, suspending and telling the user is the honest answer.
class MediaStorePreflight {
  MediaStorePreflight({
    required MediaStoreAttachState attachState,
    required MediaObjectStore store,
    required String attachedStoreId,
  }) : _attachState = attachState,
       _store = store,
       _attachedStoreId = attachedStoreId;

  final MediaStoreAttachState _attachState;
  final MediaObjectStore _store;
  final String _attachedStoreId;

  /// Null when the drain may proceed, else why it may not. Throws when the
  /// marker cannot be read; the worker separates that from a refusal.
  ///
  /// A marker answer is remembered on the attach state, so the pending-setup
  /// card can offer a reconnect for a mismatch and drop it once the marker
  /// matches again. A throw remembers nothing: it says nothing about the
  /// marker. Neither does an answer that outlived its attachment: any attach
  /// change during the read (a reconnect to the same store included) makes
  /// it detached, and the flag is written only within the attachment the
  /// check began in.
  Future<MediaTransferHoldKind?> check() async {
    // Read first: every attach change after this point moves it.
    final generation = await _attachState.attachGeneration();
    final currentId = await _attachState.attachedStoreId();
    if (currentId == null || currentId != _attachedStoreId) {
      return MediaTransferHoldKind.detached;
    }
    final marker = await StoreMarkerStore(store: _store).read();
    // The read is a network call: the attachment may have changed under it,
    // and then this answer is about an attachment this device has left.
    if (await _attachState.attachGeneration() != generation) {
      return MediaTransferHoldKind.detached;
    }
    final mismatch = marker == null || marker.storeId != currentId;
    await _attachState.setMarkerMismatch(
      mismatch,
      withinGeneration: generation,
    );
    return mismatch ? MediaTransferHoldKind.markerMismatch : null;
  }

  /// Whether the drain may proceed, for callers that need only that.
  Future<bool> call() async => await check() == null;
}
