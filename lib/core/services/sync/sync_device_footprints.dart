import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/core/services/sync/sync_device_footprint.dart';

/// Read-only survey of every device's footprint on a sync backend, plus the
/// user-driven removal of one device's files.
///
/// Sync itself only ever reads peer manifests as part of a pull, and only for
/// peers it intends to merge. A user asking "what are all these files on my
/// Dropbox?" needs the opposite: everything present, including devices sync
/// deliberately ignores (stale epochs, unreadable publishes). Issue #1032 --
/// hundreds of files accumulated from a single device and nothing in the app
/// could account for them.
class SyncDeviceFootprints {
  SyncDeviceFootprints({this.cloudCallTimeout = const Duration(seconds: 8)});

  /// Ceiling on every individual cloud call here.
  ///
  /// Both entry points run in front of a user who cannot leave: [list] behind
  /// a page-filling spinner, and [retirePeer] behind a deliberately
  /// non-dismissible progress dialog with no back button. An unbounded call
  /// against a stalled connection strands them there indefinitely -- the exact
  /// "app is hung, force-quit it" failure this whole change set exists to end,
  /// and force-quitting mid-retire is what leaves a half-deleted device.
  ///
  /// 8s matches the ceiling `SyncService`'s cleanup helpers already use, so
  /// the two paths fail on the same schedule. Injectable so tests can drive a
  /// timeout without waiting one out.
  final Duration cloudCallTimeout;

  final _log = LoggerService.forClass(SyncDeviceFootprints);

  /// Every device with files in the sync folder, newest first.
  ///
  /// Groups by the device id encoded in each filename rather than by manifest,
  /// so a device whose manifest is missing still appears -- that IS the
  /// interrupted-publish case a user most needs to see.
  ///
  /// Manifest reads are per-device and best-effort: one unreadable manifest
  /// (corrupt, or encrypted without a key) downgrades that device to
  /// [SyncDeviceFootprintState.unreadable] instead of failing the survey.
  Future<List<SyncDeviceFootprint>> list({
    required CloudStorageProvider provider,
    required String selfDeviceId,
    String? currentEpochId,
    String? folderId,
  }) async {
    final files = await provider
        .listFiles(
          folderId: folderId,
          namePattern: ChangesetLogLayout.listPattern,
        )
        .timeout(cloudCallTimeout);

    final grouped = <String, List<CloudFileInfo>>{};
    for (final f in files) {
      final id = ChangesetLogLayout.deviceIdOf(f.name);
      if (id == null) continue;
      grouped.putIfAbsent(id, () => []).add(f);
    }

    final out = <SyncDeviceFootprint>[];
    for (final entry in grouped.entries) {
      out.add(
        await _describe(
          provider: provider,
          deviceId: entry.key,
          deviceFiles: entry.value,
          selfDeviceId: selfDeviceId,
          currentEpochId: currentEpochId,
        ),
      );
    }

    out.sort((a, b) {
      // This device first, then most recently touched. A user scanning for
      // what to delete wants "mine" anchored and the rest ordered by staleness.
      if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
      final at = a.publishedAt ?? a.lastModified;
      final bt = b.publishedAt ?? b.lastModified;
      if (at == null || bt == null) return at == null ? 1 : -1;
      return bt.compareTo(at);
    });
    return out;
  }

  Future<SyncDeviceFootprint> _describe({
    required CloudStorageProvider provider,
    required String deviceId,
    required List<CloudFileInfo> deviceFiles,
    required String selfDeviceId,
    String? currentEpochId,
  }) async {
    final retired = deviceFiles.any(
      (f) => ChangesetLogLayout.isRetiredMarker(f.name),
    );
    final bytes = deviceFiles.fold<int>(0, (a, f) => a + (f.sizeBytes ?? 0));
    final lastModified = deviceFiles
        .map((f) => f.modifiedTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    SyncManifest? manifest;
    final manifestFile = deviceFiles
        .where((f) => ChangesetLogLayout.isManifest(f.name))
        .firstOrNull;
    if (manifestFile != null) {
      try {
        manifest = SyncManifest.fromBytes(
          await provider
              .downloadFile(manifestFile.id)
              .timeout(cloudCallTimeout),
        );
      } catch (e) {
        // Encrypted without a key, corrupt, or a torn write. Reported as
        // unreadable rather than swallowed as "no devices".
        _log.warning('Could not read manifest for $deviceId: $e');
      }
    }

    final SyncDeviceFootprintState state;
    if (retired) {
      state = SyncDeviceFootprintState.retired;
    } else if (manifest == null) {
      state = SyncDeviceFootprintState.unreadable;
    } else if (currentEpochId != null && manifest.epochId != currentEpochId) {
      state = SyncDeviceFootprintState.staleEpoch;
    } else {
      state = SyncDeviceFootprintState.active;
    }

    return SyncDeviceFootprint(
      deviceId: deviceId,
      state: state,
      fileCount: deviceFiles.length,
      byteCount: bytes,
      deviceName: manifest?.deviceName,
      isSelf: deviceId == selfDeviceId,
      lastModified: lastModified,
      publishedAt: manifest == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(manifest.updatedAt),
      schemaVersion: manifest?.schemaVersion,
      epochId: manifest?.epochId,
    );
  }

  /// Retire one PEER device and delete its files, reporting progress.
  ///
  /// Writes the retirement marker BEFORE deleting anything, and never deletes
  /// the marker itself. That ordering is load-bearing: a device that comes back
  /// online later must find the marker and rejoin through the retirement fence,
  /// or its stale local rows would resurrect fleet-wide. This is why removing a
  /// peer cannot reuse `SyncService.deleteDeviceSyncFile`, which writes no
  /// marker -- that one is only correct for retiring THIS install's own
  /// identity, where the device id is being abandoned anyway.
  ///
  /// Refuses [selfDeviceId]: fencing yourself off would make this install
  /// rebuild from the cloud on its next sync.
  Future<SyncCleanupOutcome> retirePeer({
    required CloudStorageProvider provider,
    required String deviceId,
    required String selfDeviceId,
    String? folderId,
    SyncCleanupProgress? onProgress,
  }) async {
    if (deviceId == selfDeviceId) {
      throw ArgumentError.value(
        deviceId,
        'deviceId',
        'refusing to retire this device through the peer path',
      );
    }

    try {
      await provider
          .uploadFile(
            RetirementMarker(
              deviceId: deviceId,
              retiredAt: DateTime.now().millisecondsSinceEpoch,
            ).toBytes(),
            ChangesetLogLayout.retiredMarkerName(deviceId),
            folderId: folderId,
          )
          .timeout(cloudCallTimeout);
    } catch (e) {
      // Without a durable marker the fence does not exist, so deleting now
      // would be actively unsafe. Report nothing done and let the user retry.
      _log.warning('Could not write retirement marker for $deviceId: $e');
      return const SyncCleanupOutcome(listIncomplete: true);
    }

    final List<CloudFileInfo> files;
    try {
      files = await provider
          .listFiles(
            folderId: folderId,
            namePattern: ChangesetLogLayout.listPattern,
          )
          .timeout(cloudCallTimeout);
    } catch (e) {
      _log.warning('Could not list files to retire $deviceId: $e');
      return const SyncCleanupOutcome(listIncomplete: true);
    }

    final targets = files
        .where((f) => ChangesetLogLayout.deviceIdOf(f.name) == deviceId)
        .where((f) => !ChangesetLogLayout.isRetiredMarker(f.name))
        .toList();

    var deleted = 0;
    var failed = 0;
    onProgress?.call(0, targets.length);
    for (final f in targets) {
      try {
        await provider.deleteFile(f.id).timeout(cloudCallTimeout);
        deleted++;
      } catch (e) {
        failed++;
        _log.warning('Could not delete ${f.name}: $e');
      }
      onProgress?.call(deleted + failed, targets.length);
    }
    _log.info('Retired peer $deviceId: removed $deleted files, $failed failed');
    return SyncCleanupOutcome(deleted: deleted, failed: failed);
  }
}
