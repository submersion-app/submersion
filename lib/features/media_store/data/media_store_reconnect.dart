import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/domain/media_store_reconnect_situation.dart';

/// The guided way out of a marker mismatch (issue #2303, guided reconnect
/// design): look at what the attached account's folder holds now, then
/// adopt it, start it again, or stop keeping copies here.
///
/// Adopting and starting again are one call. The marker check
/// ([StoreMarkerStore.ensure]) joins a marker that is there and mints one
/// only where there is none, so it never writes over another store's
/// identity: a "start again" that races another device's fresh marker
/// joins it instead. Stamps made in the store being left are claimed for it
/// by the attach (issue #3482), so they stop counting as copies in the new
/// one; the backfill then queues every photo, and the upload pipeline's HEAD
/// check keeps what the new store already holds and uploads what it lacks.
///
/// Nothing here runs the Verify sweep: it deletes what the logbook does not
/// reference, and a folder the logbook has no record of may be another
/// logbook's.
class MediaStoreReconnect {
  MediaStoreReconnect({
    required MediaStoreAttachState attachState,
    required MediaStoreService service,
    required MediaBackfillService backfill,
    required MediaStoresRepository stores,
    required MediaRepository mediaRepository,
    required Future<ConnectedAccount?> Function(String accountId) accountById,
    required Future<MediaObjectStore?> Function(ConnectedAccount account)
    storeFor,
  }) : _attachState = attachState,
       _service = service,
       _backfill = backfill,
       _stores = stores,
       _mediaRepository = mediaRepository,
       _accountById = accountById,
       _storeFor = storeFor;

  final MediaStoreAttachState _attachState;
  final MediaStoreService _service;
  final MediaBackfillService _backfill;
  final MediaStoresRepository _stores;
  final MediaRepository _mediaRepository;
  final Future<ConnectedAccount?> Function(String accountId) _accountById;
  final Future<MediaObjectStore?> Function(ConnectedAccount account) _storeFor;

  /// Reads the attached account's marker afresh and says what it found. A
  /// marker that matches again clears the mismatch flag, within the
  /// attachment the read began in, the way the preflight writes it.
  Future<MediaStoreReconnectSituation> inspect() async {
    final generation = await _attachState.attachGeneration();
    final storeId = await _attachState.attachedStoreId();
    if (storeId == null) return const ReconnectDetached();
    final held = await _mediaRepository.countHeldOnlyInStore(storeId);
    final target = await _target();
    if (target == null) return ReconnectNeedsAccount(heldOnlyInCloud: held);
    final StoreMarker? marker;
    try {
      marker = await _readMarker(target.store);
    } on MediaStoreException catch (e) {
      return ReconnectUnreadable(e.message, heldOnlyInCloud: held);
    }
    // The read is a network call: an attach change landing during it makes
    // this answer about an attachment the device has left. Look again.
    if (await _attachState.attachGeneration() != generation) return inspect();
    if (marker == null) return ReconnectNoMarker(heldOnlyInCloud: held);
    if (marker.storeId == storeId) {
      await _attachState.setMarkerMismatch(false, withinGeneration: generation);
      return const ReconnectResolved();
    }
    return ReconnectOtherStore(
      storeId: marker.storeId,
      knownToLibrary: await _stores.getById(marker.storeId) != null,
      heldOnlyInCloud: held,
    );
  }

  /// Attaches this device to whatever the account's folder holds now
  /// (adopt), or to a new store there when it holds none (start again), and
  /// queues every photo for the new store. [queued] is how many were queued.
  /// Throws [MediaStoreAccountUnusable] with nothing changed when the
  /// attachment names no account this device can use.
  ///
  /// Refused, with nothing changed, when the folder's marker is there but
  /// cannot be read (the marker check would mint over it), or when the
  /// attachment changes while this runs.
  Future<({MediaStoreConnectResult result, int queued})> reconnect() async {
    final generation = await _attachState.attachGeneration();
    final target = await _target();
    if (target == null) {
      throw const MediaStoreAccountUnusable(
        'The account holding the photo copies is not usable on this device',
      );
    }
    // Throws for a marker that is there but unreadable; an absent one is
    // what the marker check below may mint.
    await _readMarker(target.store);
    final result = await _service.attachToAccountRow(
      target.account,
      target.store,
      withinGeneration: generation,
    );
    return (result: result, queued: await _backfill.enqueueAll());
  }

  /// The folder's marker, or null when there is none. [StoreMarkerStore.read]
  /// also answers null for a marker that is there but malformed, which must
  /// not read as absent: starting again would mint over it, splitting any
  /// device attached to it. That one throws.
  Future<StoreMarker?> _readMarker(MediaObjectStore store) async {
    final marker = await StoreMarkerStore(store: store).read();
    if (marker != null) return marker;
    if (await store.head(StoreKeys.markerKey) == null) return null;
    throw const MediaStoreException(
      'The photo copies\' marker (smv1/store.json) is there but cannot be '
      'read',
      kind: MediaStoreErrorKind.fatal,
    );
  }

  /// Stops keeping copies on this device; nothing in the account goes.
  Future<void> detach() => _service.disconnect();

  /// The attached account row and its store, or null when there is no
  /// account to reconnect through: a pre-accounts attachment, a removed
  /// row, or one with no keys here.
  Future<({ConnectedAccount account, MediaObjectStore store})?>
  _target() async {
    final accountId = await _attachState.attachedAccountId();
    if (accountId == null) return null;
    final account = await _accountById(accountId);
    if (account == null) return null;
    final store = await _storeFor(account);
    if (store == null) return null;
    return (account: account, store: store);
  }
}
