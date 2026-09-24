import 'package:submersion/core/services/sync/sync_fact_groups.dart';

/// What applying a peer's media row means for this device's cached search
/// for the photo (media sync program spec 6.2).
enum MediaResolutionHint {
  /// Something new to find the photo by (a cloud id or an upload fact it
  /// did not have): a search that gave up should run again, while a
  /// mapping already found stays.
  retry,

  /// The row now names another photo (a relink): any mapping this device
  /// cached, found or not, is about the old one.
  remap,
}

/// The hint for one applied media row, or null when it changes nothing
/// about how this device finds the photo. [applied] is the row as the
/// merge will write it; [rowFromRemote] is whether the peer's row fields
/// (the asset id and cloud id among them) were taken.
///
/// Compares values rather than asking which fact groups the peer won: a
/// group with no clock of its own falls back to the row clock, so a plain
/// edit can win the upload group while changing no upload fact at all. A
/// row this device has never seen ([local] null) has no cached search. An
/// empty cloud id, or a cleared fact, is never a hint.
MediaResolutionHint? mediaResolutionHintFor({
  required Map<String, dynamic>? local,
  required Map<String, dynamic> applied,
  required bool rowFromRemote,
}) {
  if (local == null) return null;
  if (rowFromRemote && applied['platformAssetId'] != local['platformAssetId']) {
    return MediaResolutionHint.remap;
  }
  for (final key in SyncFactGroups.mediaUpload.columns.keys) {
    final value = applied[key];
    if (value != null && value != local[key]) return MediaResolutionHint.retry;
  }
  if (!rowFromRemote) return null;
  final cloudId = applied['cloudAssetId'];
  final newCloudId =
      cloudId is String &&
      cloudId.isNotEmpty &&
      cloudId != local['cloudAssetId'];
  return newCloudId ? MediaResolutionHint.retry : null;
}

/// The media rows one merge gave a hint, by kind.
class MediaResolutionHints {
  const MediaResolutionHints({required this.retry, required this.remap});

  /// Sorts [hinted] rows by kind. A row hinted both ways is a remap, which
  /// drops everything a retry would.
  factory MediaResolutionHints.of(
    Iterable<(String, MediaResolutionHint)> hinted,
  ) {
    final remap = {
      for (final (id, hint) in hinted)
        if (hint == MediaResolutionHint.remap) id,
    };
    return MediaResolutionHints(
      retry: {
        for (final (id, hint) in hinted)
          if (hint == MediaResolutionHint.retry && !remap.contains(id)) id,
      },
      remap: remap,
    );
  }

  /// Rows whose `unresolved` cache entry should be dropped.
  final Set<String> retry;

  /// Rows whose cache entry should be dropped whatever it says.
  final Set<String> remap;

  bool get isEmpty => retry.isEmpty && remap.isEmpty;
}
