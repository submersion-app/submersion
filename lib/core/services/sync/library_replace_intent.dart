import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_device_metadata.dart';

/// Arms a library replacement: mints the epoch marker and persists it as the
/// pending intent.
///
/// The cloud side is deliberately NOT executed here. SyncService's epoch gate
/// checks the pending intent before anything else and runs the replacement on
/// the next sync, which is what makes an interrupted replace resumable: the
/// intent survives a crash and the launch sync picks it up.
class LibraryReplaceIntent {
  const LibraryReplaceIntent(this._resolveIdentity, this._store);

  final DeviceIdentityResolver _resolveIdentity;
  final LibraryEpochStore _store;

  static const _uuid = Uuid();

  Future<LibraryEpochMarker> mint() async {
    final identity = await _resolveIdentity();
    final marker = LibraryEpochMarker(
      epochId: _uuid.v4(),
      replacedAt: DateTime.now().millisecondsSinceEpoch,
      deviceId: identity.id,
      deviceName: identity.name,
      appVersion: identity.appVersion,
    );
    await _store.setPendingReplace(marker);
    return marker;
  }
}
