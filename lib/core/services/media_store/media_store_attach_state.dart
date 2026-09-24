import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';

/// Which media store this device is attached to, and through which
/// provider. Secret-free; credentials live in the keychain
/// (MediaStoreCredentialsStore) or the providers' own auth stores.
/// SharedPreferences so a database restore cannot silently re-point the
/// device at a different store (same reasoning as the library-epoch
/// mirror).
class MediaStoreAttachState {
  MediaStoreAttachState({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const String storeIdKey = 'media_store_attached_store_id';
  static const String providerTypeKey = 'media_store_provider_type';
  static const String accountIdKey = 'media_store_account_id';
  static const String markerMismatchKey = 'media_store_marker_mismatch';
  static const String generationKey = 'media_store_attach_generation';

  Future<SharedPreferences> get _resolved async =>
      _prefs ?? await SharedPreferences.getInstance();

  static final _markerMismatchChanges = StreamController<void>.broadcast();

  /// Fires when the marker mismatch flag may have changed: set or cleared
  /// by a preflight, or cleared by an attach change. The pending-setup card
  /// listens, so a mismatch found while Settings is open shows at once. Its
  /// own signal rather than the sync event bus, which would also schedule a
  /// sync for what is device-local state.
  static Stream<void> get markerMismatchChanges =>
      _markerMismatchChanges.stream;

  Future<String?> attachedStoreId() async =>
      (await _resolved).getString(storeIdKey);

  /// The connected account driving this attachment, or null for a legacy
  /// attachment made before the accounts layer (resolved via the
  /// provider-type path instead).
  Future<String?> attachedAccountId() async =>
      (await _resolved).getString(accountIdKey);

  /// The attached provider, or null when no store is attached. Attachments
  /// persisted before the provider type existed read as S3 (the only
  /// option back then) - no migration needed.
  Future<CloudProviderType?> attachedProviderType() async {
    final prefs = await _resolved;
    if (prefs.getString(storeIdKey) == null) return null;
    final stored = prefs.getString(providerTypeKey);
    if (stored == null) return CloudProviderType.s3;
    return CloudProviderType.values.byName(stored);
  }

  Future<void> setAttached(
    String storeId, {
    required CloudProviderType providerType,
    String? accountId,
  }) async {
    final prefs = await _resolved;
    await _bumpGeneration(prefs);
    await prefs.setString(storeIdKey, storeId);
    await prefs.setString(providerTypeKey, providerType.name);
    await prefs.remove(markerMismatchKey);
    _markerMismatchChanges.add(null);
    if (accountId != null) {
      await prefs.setString(accountIdKey, accountId);
    } else {
      await prefs.remove(accountIdKey);
    }
  }

  Future<void> clear() async {
    final prefs = await _resolved;
    await _bumpGeneration(prefs);
    await prefs.remove(storeIdKey);
    await prefs.remove(providerTypeKey);
    await prefs.remove(accountIdKey);
    await prefs.remove(markerMismatchKey);
    _markerMismatchChanges.add(null);
  }

  /// Records whether the last preflight found the attached store carrying
  /// another store's marker, or none. Persisted so the pending-setup card
  /// can offer a reconnect without building a runtime; cleared by any attach
  /// change ([setAttached], [clear]), since reconnecting is the fix.
  ///
  /// Writes only on a change: the preflight asks before every transfer, and
  /// the read is served from memory while the write is not.
  ///
  /// With [withinGeneration], writes only while the attachment is still the
  /// one of that [attachGeneration]. The preflight's marker read is a
  /// network call, and any attach change landing during it, a reconnect to
  /// the SAME store included, must not be answered for by its result. The
  /// check and the write happen with no await between them, and every
  /// attach change bumps the generation the same synchronous way before it
  /// clears the flag, so either the write lands first and the change clears
  /// it, or the change lands first and the write is skipped.
  Future<void> setMarkerMismatch(bool mismatch, {int? withinGeneration}) async {
    final prefs = await _resolved;
    if (withinGeneration != null &&
        (prefs.getInt(generationKey) ?? 0) != withinGeneration) {
      return;
    }
    if ((prefs.getBool(markerMismatchKey) ?? false) == mismatch) return;
    if (mismatch) {
      await prefs.setBool(markerMismatchKey, true);
    } else {
      await prefs.remove(markerMismatchKey);
    }
    _markerMismatchChanges.add(null);
  }

  Future<bool> hasMarkerMismatch() async =>
      (await _resolved).getBool(markerMismatchKey) ?? false;

  /// Changes on every attach change ([setAttached], [clear]), a reconnect to
  /// the same store included, which an id comparison cannot see.
  Future<int> attachGeneration() async =>
      (await _resolved).getInt(generationKey) ?? 0;

  // The in-memory value changes within this call, before its first await,
  // which is what setMarkerMismatch's check relies on.
  Future<void> _bumpGeneration(SharedPreferences prefs) =>
      prefs.setInt(generationKey, (prefs.getInt(generationKey) ?? 0) + 1);
}
