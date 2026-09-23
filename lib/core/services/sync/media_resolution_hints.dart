import 'package:submersion/core/services/sync/sync_fact_groups.dart';

/// Whether applying a peer's media row gives this device something new to
/// find the photo by, so a search that gave up on it should run again
/// (media sync program spec 6.2): a cloud id it did not have, or an upload
/// fact it did not have. [applied] is the row as the merge will write it;
/// [rowFromRemote] is whether the peer's row fields (the cloud id among
/// them) were taken.
///
/// Compares values rather than asking which fact groups the peer won: a
/// group with no clock of its own falls back to the row clock, so a plain
/// edit can win the upload group while changing no upload fact at all. A
/// row this device has never seen ([local] null) has no cached search to
/// retry. An empty cloud id, or a cleared fact, is never a hint.
bool bringsMediaResolutionHint({
  required Map<String, dynamic>? local,
  required Map<String, dynamic> applied,
  required bool rowFromRemote,
}) {
  if (local == null) return false;
  for (final key in SyncFactGroups.mediaUpload.columns.keys) {
    final value = applied[key];
    if (value != null && value != local[key]) return true;
  }
  if (!rowFromRemote) return false;
  final cloudId = applied['cloudAssetId'];
  return cloudId is String &&
      cloudId.isNotEmpty &&
      cloudId != local['cloudAssetId'];
}
