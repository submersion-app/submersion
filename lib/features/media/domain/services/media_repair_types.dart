import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Confidence rungs of the repair match ladder (design spec section 6).
enum RepairConfidence {
  /// Content hash equal (or the store confirms the row's own hash).
  exact,

  /// Name and size agree; hash not yet computed. Promoted to exact or
  /// demoted to changed-on-disk during apply.
  probable,

  /// Name matches, bytes differ. Opt-in: accepting re-uploads new bytes.
  edited,

  /// No candidate anywhere.
  unmatched,
}

/// One found file, gallery asset, or store object that may repair a row.
class RepairCandidate {
  const RepairCandidate.file({
    required String this.path,
    required this.sizeBytes,
    this.hash,
  }) : assetId = null,
       verified = false;

  const RepairCandidate.galleryAsset({
    required String this.assetId,
    required this.sizeBytes,
    this.hash,
  }) : path = null,
       verified = false;

  const RepairCandidate.store({required this.verified})
    : path = null,
      assetId = null,
      sizeBytes = null,
      hash = null;

  final String? path;
  final String? assetId;
  final int? sizeBytes;
  final String? hash;

  /// Store candidates only: the HEAD check confirmed the object exists.
  final bool verified;

  bool get isStore => path == null && assetId == null;
  bool get isGallery => assetId != null;

  RepairCandidate copyWithHash(String hash, int sizeBytes) {
    if (isGallery) {
      return RepairCandidate.galleryAsset(
        assetId: assetId!,
        sizeBytes: sizeBytes,
        hash: hash,
      );
    }
    return RepairCandidate.file(path: path!, sizeBytes: sizeBytes, hash: hash);
  }
}

/// A broken row paired with its best candidate and confidence.
class RepairProposal {
  const RepairProposal({
    required this.item,
    required this.confidence,
    this.candidate,
    this.viaPrefixMove = false,
  });

  final MediaItem item;
  final RepairConfidence confidence;

  /// Null iff [confidence] is [RepairConfidence.unmatched].
  final RepairCandidate? candidate;

  /// True when the candidate came from the detected whole-tree move.
  final bool viaPrefixMove;
}

/// Detected wholesale move: broken paths under [fromPrefix] have
/// same-relative-suffix files under [toPrefix].
class PrefixMove {
  const PrefixMove({
    required this.fromPrefix,
    required this.toPrefix,
    required this.coveredCount,
  });

  final String fromPrefix;
  final String toPrefix;
  final int coveredCount;
}

/// Candidates harvested by one source: an index by lowercase filename plus
/// the full found-path set (folder sources only) for prefix-move detection.
class CandidateHarvest {
  const CandidateHarvest({
    required this.byFilename,
    this.foundPaths = const {},
  });

  final Map<String, List<RepairCandidate>> byFilename;
  final Set<String> foundPaths;
}

/// A place candidates come from (folder scan, photo library, cloud store).
// ignore: one_member_abstracts -- the port shape IS the contract.
abstract class CandidateSource {
  Future<CandidateHarvest> harvest(List<MediaItem> brokenRows);
}
