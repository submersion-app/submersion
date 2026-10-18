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
    this.mediaDeferred = false,
  });

  final DateTime scannedAt;
  final int? mediaBytes;
  final int? mediaReclaimableBytes;
  final int? mediaWaitingBytes;
  final int? syncBytes;
  final int? librariesBytes;
  final bool partial;

  /// Whether the last media sweep held its deletes back (this device was
  /// not caught up with sync, or a sync started during it), so the waiting
  /// figure waits on a sync rather than on the safety wait.
  final bool mediaDeferred;

  CloudUsage copyWith({
    DateTime? scannedAt,
    int? mediaBytes,
    int? mediaReclaimableBytes,
    int? mediaWaitingBytes,
    int? syncBytes,
    int? librariesBytes,
    bool? partial,
    bool? mediaDeferred,
  }) => CloudUsage(
    scannedAt: scannedAt ?? this.scannedAt,
    mediaBytes: mediaBytes ?? this.mediaBytes,
    mediaReclaimableBytes: mediaReclaimableBytes ?? this.mediaReclaimableBytes,
    mediaWaitingBytes: mediaWaitingBytes ?? this.mediaWaitingBytes,
    syncBytes: syncBytes ?? this.syncBytes,
    librariesBytes: librariesBytes ?? this.librariesBytes,
    partial: partial ?? this.partial,
    mediaDeferred: mediaDeferred ?? this.mediaDeferred,
  );

  /// Sum of every measured area, or null when no area is set up.
  int? get totalBytes {
    final areas = [mediaBytes, syncBytes, librariesBytes].nonNulls;
    return areas.isEmpty ? null : areas.fold<int>(0, (a, b) => a + b);
  }

  /// This usage without the figures of areas that are not set up now: a
  /// scan from before an area was disconnected still holds its figure.
  CloudUsage onlyAreas({
    required bool media,
    required bool sync,
    required bool libraries,
  }) => CloudUsage(
    scannedAt: scannedAt,
    mediaBytes: media ? mediaBytes : null,
    mediaReclaimableBytes: media ? mediaReclaimableBytes : null,
    mediaWaitingBytes: media ? mediaWaitingBytes : null,
    syncBytes: sync ? syncBytes : null,
    librariesBytes: libraries ? librariesBytes : null,
    partial: partial,
    mediaDeferred: media && mediaDeferred,
  );

  Map<String, Object?> toJson() => {
    'scannedAt': scannedAt.millisecondsSinceEpoch,
    'mediaBytes': mediaBytes,
    'mediaReclaimableBytes': mediaReclaimableBytes,
    'mediaWaitingBytes': mediaWaitingBytes,
    'syncBytes': syncBytes,
    'librariesBytes': librariesBytes,
    'partial': partial,
    'mediaDeferred': mediaDeferred,
  };

  factory CloudUsage.fromJson(Map<String, Object?> json) => CloudUsage(
    scannedAt: DateTime.fromMillisecondsSinceEpoch(json['scannedAt']! as int),
    mediaBytes: json['mediaBytes'] as int?,
    mediaReclaimableBytes: json['mediaReclaimableBytes'] as int?,
    mediaWaitingBytes: json['mediaWaitingBytes'] as int?,
    syncBytes: json['syncBytes'] as int?,
    librariesBytes: json['librariesBytes'] as int?,
    partial: json['partial'] as bool? ?? false,
    mediaDeferred: json['mediaDeferred'] as bool? ?? false,
  );
}
