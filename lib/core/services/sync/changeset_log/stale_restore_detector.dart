import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

/// Network-time backstop to the primary restore detector
/// (`SyncInitializer.reconcileDeviceIdentity`, the edit-robust instanceToken
/// anchor): a device whose local data sits BELOW what its own cloud manifest
/// says it published has been rewound by a restore.
///
/// This signal is masked by a post-restore edit (which lifts the local HLC
/// high-water back above the watermark) -- that case is caught by the
/// instanceToken anchor -- so this only needs to catch the no-edit-yet restore
/// that predates the anchors (today's "manual Reset Sync State" gap).
class StaleRestoreDetector {
  StaleRestoreDetector(this._repo);

  final SyncRepository _repo;

  Future<bool> isStaleRestore({
    required CloudStorageProvider provider,
    required String deviceId,
    required String folderId,
  }) async {
    final manifest = await _readOwnManifest(provider, folderId, deviceId);
    final published = manifest?.publishedHlcHigh;
    if (published == null) return false; // never published anything
    final localHigh = await _repo.maxRowHlc();
    if (localHigh == null) return true; // cloud has data, local has none
    return localHigh.compareTo(published) < 0;
  }

  Future<SyncManifest?> _readOwnManifest(
    CloudStorageProvider provider,
    String folderId,
    String deviceId,
  ) async {
    final name = ChangesetLogLayout.manifestName(deviceId);
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    final matches = files.where((f) => f.name == name).toList();
    if (matches.isEmpty) return null;
    try {
      return SyncManifest.fromBytes(
        await provider.downloadFile(matches.first.id),
      );
    } catch (_) {
      return null;
    }
  }
}
