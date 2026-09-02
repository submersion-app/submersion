import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

/// Harvests repair candidates from user-picked folders (local disks and
/// mounted network shares alike -- both are just paths on desktop).
///
/// Harvest indexes by lowercase basename with sizes only; hashing is
/// strictly on-demand via [withHash] because a full-tree hash pass over a
/// NAS could take hours the match ladder rarely needs.
class FolderCandidateSource implements CandidateSource {
  FolderCandidateSource({required this.roots});

  /// Absolute directory paths to scan recursively.
  final List<String> roots;

  static const _log = LoggerService('FolderCandidateSource');

  @override
  Future<CandidateHarvest> harvest(List<MediaItem> brokenRows) async {
    final byFilename = <String, List<RepairCandidate>>{};
    final foundPaths = <String>{};

    for (final root in roots) {
      final dir = Directory(root);
      if (!await dir.exists()) {
        _log.warning('Repair scan root missing: $root');
        continue;
      }
      try {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final stat = await entity.stat();
          final path = entity.path;
          // p.basename follows the HOST's separator. A hand-rolled
          // lastIndexOf('/') indexed the entire path as the key on Windows,
          // where Directory.list yields backslash-separated paths, so every
          // filename lookup missed.
          final name = p.basename(path).toLowerCase();
          foundPaths.add(path);
          byFilename
              .putIfAbsent(name, () => [])
              .add(RepairCandidate.file(path: path, sizeBytes: stat.size));
        }
      } on FileSystemException catch (e) {
        // Partial harvests are fine: an unreadable subtree just contributes
        // nothing, and the wizard reports what stayed unmatched.
        _log.warning('Repair scan failed under $root: $e');
      }
    }

    return CandidateHarvest(byFilename: byFilename, foundPaths: foundPaths);
  }

  /// Hashes [candidate]'s file with the store's own digest so hash
  /// comparisons and later upload dedup agree byte-for-byte.
  static Future<RepairCandidate> withHash(RepairCandidate candidate) async {
    final digest = await sha256OfFile(File(candidate.path!));
    return candidate.copyWithHash(digest.hash, digest.sizeBytes);
  }
}
