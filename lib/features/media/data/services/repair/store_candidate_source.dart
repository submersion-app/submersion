import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

/// Qualifies broken rows for cloud-backed repair. No scanning: a row's own
/// contentHash + remoteUploadedAt stamp pair IS the candidate -- the store
/// object is addressed by the hash the row already carries.
///
/// [head] is the store's HEAD call when one is reachable; verification is
/// best-effort (offline stores yield unverified candidates, surfaced as
/// such in review, rather than blocking the repair).
class StoreCandidateSource implements CandidateSource {
  StoreCandidateSource({required this.head});

  final Future<StoreObjectInfo?> Function(String key)? head;

  @override
  Future<CandidateHarvest> harvest(List<MediaItem> brokenRows) async {
    final byFilename = <String, List<RepairCandidate>>{};

    for (final item in brokenRows) {
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
