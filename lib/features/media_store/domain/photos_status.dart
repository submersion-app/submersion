import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';

/// What the Photos page's status line says (spec section 8.3). Pure data:
/// the widget turns it into words.
sealed class PhotosStatus {
  const PhotosStatus();
}

/// No store attached here and none announced by the library.
final class PhotosNotSetUp extends PhotosStatus {
  const PhotosNotSetUp();
}

/// The library has a store this device has not joined. An attached device
/// never reads this: what is true of its own copies comes first, even when
/// the library announces another store.
final class PhotosFinishSettingUp extends PhotosStatus {
  const PhotosFinishSettingUp();
}

/// Attached; whether the store can be opened is not known yet.
final class PhotosChecking extends PhotosStatus {
  const PhotosChecking();
}

/// Attached, but the store could not be opened with this device's keys.
final class PhotosUnreachable extends PhotosStatus {
  const PhotosUnreachable();
}

/// The transfer drain is holding for a reason the diver is told about, or a
/// reconnect is pending (a marker mismatch, which suspends the drain).
final class PhotosPaused extends PhotosStatus {
  const PhotosPaused(this.kind);
  final MediaTransferHoldKind kind;
}

/// Held because there is no network: nothing is wrong with the store.
final class PhotosWaitingConnection extends PhotosStatus {
  const PhotosWaitingConnection();
}

/// Rows deferred to a later attempt after a failure.
final class PhotosWaitingRetry extends PhotosStatus {
  const PhotosWaitingRetry(this.count);
  final int count;
}

/// Uploads moving now; [copied] and [total] are null until counted.
final class PhotosUploading extends PhotosStatus {
  const PhotosUploading({
    required this.copied,
    required this.total,
    required this.count,
  });
  final int? copied;
  final int? total;
  final int count;
}

/// Nothing moving: [copied] of [total] are in the store.
final class PhotosAllCopied extends PhotosStatus {
  const PhotosAllCopied({required this.copied, required this.total});
  final int copied;
  final int total;
}

/// The one status line, in order of what the diver most needs to know.
///
/// [reachable] is the runtime fact that the attached store could be opened
/// (null while checking); [reconnect] is a pending reconnect item, which
/// the preflight raises whenever it finds a marker mismatch; [progress] is
/// the copied-of-total count (null until counted); [summary] is the
/// transfer queue.
///
/// A pending attach item is no input: unattached, the announced store
/// already reads as finishing setup, and attached, an attach item for
/// another store must not mask reachability, holds or progress here.
PhotosStatus photosStatus({
  required bool attached,
  required bool announced,
  required bool reconnect,
  required bool? reachable,
  required ({int copied, int total})? progress,
  required MediaTransferSummary? summary,
}) {
  if (!attached && !announced) return const PhotosNotSetUp();
  if (!attached) return const PhotosFinishSettingUp();
  if (reachable == null) return const PhotosChecking();
  if (!reachable) return const PhotosUnreachable();
  if (reconnect) {
    return const PhotosPaused(MediaTransferHoldKind.markerMismatch);
  }
  final hold = summary?.hold;
  if (hold != null) {
    return hold.suspends
        ? PhotosPaused(hold.kind)
        : const PhotosWaitingConnection();
  }
  if (summary != null && summary.isBusy) {
    return PhotosUploading(
      copied: progress?.copied,
      total: progress?.total,
      count: summary.transferring + summary.queued,
    );
  }
  if (summary != null && summary.waiting > 0) {
    return PhotosWaitingRetry(summary.waiting);
  }
  if (progress == null) return const PhotosChecking();
  return PhotosAllCopied(copied: progress.copied, total: progress.total);
}
