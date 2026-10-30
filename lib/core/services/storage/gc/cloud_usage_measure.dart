import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';

/// Bytes the database sync uses on [provider]: every `ssv1.` file that names
/// a device, across every device. [partial] is set when a file reported no
/// size, so the figure is a floor. Measurement only; nothing is deleted.
Future<({int bytes, bool partial})> measureSyncFolderBytes(
  CloudStorageProvider provider, {
  String? folderId,
}) async {
  final files = await provider.listFiles(
    folderId: folderId,
    namePattern: ChangesetLogLayout.listPattern,
  );
  var bytes = 0;
  var partial = false;
  for (final f in files) {
    if (ChangesetLogLayout.deviceIdOf(f.name) == null) continue;
    final size = f.sizeBytes;
    if (size == null) {
      partial = true;
    } else {
      bytes += size;
    }
  }
  return (bytes: bytes, partial: partial);
}

/// Why this device holds its cloud media deletes back.
enum CloudDeleteHold {
  /// Not caught up with sync, or a sync is running or started meanwhile.
  sync,

  /// This dive log never registered the attached store (a fresh dive log, a
  /// restore from before it was connected), so it cannot tell which objects
  /// are its own. Connecting the store again registers it.
  unregistered,

  /// An upload is transferring, and its object may look unreferenced.
  uploads,
}

/// What the last cloud scan found, kept device-locally between scans
/// (storage GC design, Storage usage page).
///
/// A null area is one this device has not set up, so the page hides its row.
/// [partial] is set when an area that is set up could not be measured fully,
/// so the page labels the total as partial rather than presenting a short
/// sum as the truth.
class CloudUsage {
  const CloudUsage({
    required this.scannedAt,
    this.mediaBytes,
    this.mediaReclaimableBytes,
    this.mediaWaitingBytes,
    this.syncBytes,
    this.librariesBytes,
    this.partial = false,
    this.mediaHold,
    this.mediaStoreId,
  });

  final DateTime scannedAt;
  final int? mediaBytes;
  final int? mediaReclaimableBytes;
  final int? mediaWaitingBytes;
  final int? syncBytes;
  final int? librariesBytes;
  final bool partial;

  /// Why the last media sweep held its deletes back, or null when it did
  /// not: the waiting figure then waits on that, not on the safety wait.
  final CloudDeleteHold? mediaHold;

  /// The media store the media figures describe: after a switch to another
  /// store they are not that store's figures.
  final String? mediaStoreId;

  CloudUsage copyWith({
    DateTime? scannedAt,
    int? mediaBytes,
    int? mediaReclaimableBytes,
    int? mediaWaitingBytes,
    int? syncBytes,
    int? librariesBytes,
    bool? partial,
  }) => CloudUsage(
    scannedAt: scannedAt ?? this.scannedAt,
    mediaBytes: mediaBytes ?? this.mediaBytes,
    mediaReclaimableBytes: mediaReclaimableBytes ?? this.mediaReclaimableBytes,
    mediaWaitingBytes: mediaWaitingBytes ?? this.mediaWaitingBytes,
    syncBytes: syncBytes ?? this.syncBytes,
    librariesBytes: librariesBytes ?? this.librariesBytes,
    partial: partial ?? this.partial,
    mediaHold: mediaHold,
    mediaStoreId: mediaStoreId,
  );

  /// Sum of every measured area, or null when no area is set up.
  int? get totalBytes {
    final areas = [mediaBytes, syncBytes, librariesBytes].nonNulls;
    return areas.isEmpty ? null : areas.fold<int>(0, (a, b) => a + b);
  }

  /// This usage without the figures of areas that are not set up now: a
  /// scan from before an area was disconnected still holds its figure. The
  /// media figures show only for the store attached now ([mediaStoreId],
  /// null when none is).
  CloudUsage onlyAreas({
    required String? mediaStoreId,
    required bool sync,
    required bool libraries,
  }) {
    final media = mediaStoreId != null && mediaStoreId == this.mediaStoreId;
    return CloudUsage(
      scannedAt: scannedAt,
      mediaBytes: media ? mediaBytes : null,
      mediaReclaimableBytes: media ? mediaReclaimableBytes : null,
      mediaWaitingBytes: media ? mediaWaitingBytes : null,
      syncBytes: sync ? syncBytes : null,
      librariesBytes: libraries ? librariesBytes : null,
      partial: partial,
      mediaHold: media ? mediaHold : null,
      mediaStoreId: media ? mediaStoreId : null,
    );
  }

  Map<String, Object?> toJson() => {
    'scannedAt': scannedAt.millisecondsSinceEpoch,
    'mediaBytes': mediaBytes,
    'mediaReclaimableBytes': mediaReclaimableBytes,
    'mediaWaitingBytes': mediaWaitingBytes,
    'syncBytes': syncBytes,
    'librariesBytes': librariesBytes,
    'partial': partial,
    'mediaHold': mediaHold?.name,
    'mediaStoreId': mediaStoreId,
  };

  factory CloudUsage.fromJson(Map<String, Object?> json) => CloudUsage(
    scannedAt: DateTime.fromMillisecondsSinceEpoch(json['scannedAt']! as int),
    mediaBytes: json['mediaBytes'] as int?,
    mediaReclaimableBytes: json['mediaReclaimableBytes'] as int?,
    mediaWaitingBytes: json['mediaWaitingBytes'] as int?,
    syncBytes: json['syncBytes'] as int?,
    librariesBytes: json['librariesBytes'] as int?,
    partial: json['partial'] as bool? ?? false,
    mediaHold: CloudDeleteHold.values.asNameMap()[json['mediaHold']],
    mediaStoreId: json['mediaStoreId'] as String?,
  );
}
