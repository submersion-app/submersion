import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';

/// Qualifies broken rows for cloud-backed repair. No scanning: a row's own
/// contentHash + remoteUploadedAt stamp pair IS the candidate -- the store
/// object is addressed by the hash the row already carries.
///
/// The stamp is read through the attached store (issue #3482): a stamp made
/// in another store says nothing about this one, so a row whose only copy is
/// in a store the device has since changed away from never qualifies. A
/// device attached to no store has no store candidates at all.
///
/// [head] is the store's HEAD call when one is reachable; verification is
/// best-effort (offline stores yield unverified candidates, surfaced as
/// such in review, rather than blocking the repair).
class StoreCandidateSource implements CandidateSource {
  StoreCandidateSource({required this.head, required this.attachedStoreId});

  final Future<StoreObjectInfo?> Function(String key)? head;

  /// The store this device is attached to, or null when detached.
  final Future<String?> Function() attachedStoreId;

  @override
  Future<CandidateHarvest> harvest(List<MediaItem> brokenRows) async {
    final byFilename = <String, List<RepairCandidate>>{};
    final storeId = await attachedStoreId();
    if (storeId == null) return CandidateHarvest(byFilename: byFilename);

    for (final raw in brokenRows) {
      final item = stampsInStore(raw, storeId);
      final hash = item.contentHash;
      if (hash == null || item.remoteUploadedAt == null) continue;
      final filename = item.originalFilename?.toLowerCase();
      if (filename == null || filename.isEmpty) continue;

      var verified = false;
      final headFn = head;
      if (headFn != null) {
        try {
          final info = await headFn(
            StoreKeys.objectKey(
              hash,
              extension: StoreKeys.extensionFor(item.originalFilename),
            ),
          );
          verified = info != null;
        } on Exception {
          // Best-effort: an unreachable store downgrades to unverified.
          verified = false;
        }
      }

      byFilename
          .putIfAbsent(filename, () => [])
          .add(RepairCandidate.store(verified: verified));
    }

    return CandidateHarvest(byFilename: byFilename);
  }
}
