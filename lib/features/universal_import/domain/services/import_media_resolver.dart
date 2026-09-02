import 'package:submersion/features/media/data/services/repair/folder_candidate_source.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_repair_matcher.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

/// The outcome of resolving a payload's media entries against a folder root.
class ImportMediaResolution {
  const ImportMediaResolution({
    required this.resolvedPathByIndex,
    required this.reRootedCount,
    required this.filenameOnlyCount,
    required this.notFoundCount,
  });

  const ImportMediaResolution.empty()
    : resolvedPathByIndex = const {},
      reRootedCount = 0,
      filenameOnlyCount = 0,
      notFoundCount = 0;

  /// Local path on this machine, keyed by the picture's index in the payload
  /// media list. A picture that resolved to nothing is absent.
  final Map<int, String> resolvedPathByIndex;

  /// Matched by re-rooting the whole moved tree. The strongest signal here:
  /// the picture sits at the same relative position it did on the exporting
  /// machine.
  final int reRootedCount;

  /// Matched on filename alone, somewhere under the root. Weaker: a
  /// reorganised library resolves this way, and so does a coincidence.
  final int filenameOnlyCount;

  /// Found nowhere under the root.
  final int notFoundCount;

  int get matchedCount => resolvedPathByIndex.length;
}

/// Resolves the foreign absolute paths a logbook references against a folder
/// the user picked on this machine.
///
/// Deliberately format-agnostic: it knows only the payload media contract
/// (a `filename` plus a position in the list), so a UDDF `<link ref>` parser
/// can feed the same resolver without changing anything here.
///
/// No matching logic lives in this class. Resolution IS the media repair
/// ladder, reached by dressing each picture as a transient unsaved
/// [MediaItem]: harvest the folder into a filename index, detect a wholesale
/// tree move, then run the ladder. Keeping the two features on one matcher
/// means a moved photo library is read the same way whether the user arrives
/// via import or via repair.
class ImportMediaResolver {
  const ImportMediaResolver();

  Future<ImportMediaResolution> resolve({
    required List<Map<String, dynamic>> media,
    required String rootPath,
  }) async {
    if (media.isEmpty) return const ImportMediaResolution.empty();

    // A picture with no usable filename can never resolve, but it still has
    // to be counted, so it is excluded from the ladder and folded into the
    // not-found tally below.
    final items = <int, MediaItem>{};
    for (var i = 0; i < media.length; i++) {
      final filename = (media[i]['filename'] as String?)?.trim();
      if (filename == null || filename.isEmpty) continue;
      items[i] = _transientItem(filename);
    }

    if (items.isEmpty) {
      return ImportMediaResolution(
        resolvedPathByIndex: const {},
        reRootedCount: 0,
        filenameOnlyCount: 0,
        notFoundCount: media.length,
      );
    }

    final indices = items.keys.toList();
    final rows = [for (final index in indices) items[index]!];

    final harvest = await FolderCandidateSource(
      roots: [rootPath],
    ).harvest(rows);
    final prefixMove = detectPrefixMove(
      brokenPaths: [for (final row in rows) row.filePath!],
      foundPaths: harvest.foundPaths,
    );
    final proposals = buildRepairProposals(
      brokenRows: rows,
      candidatesByFilename: harvest.byFilename,
      prefixMove: prefixMove,
      foundPaths: harvest.foundPaths,
    );

    final resolved = <int, String>{};
    var reRooted = 0;
    var filenameOnly = 0;
    var notFound = media.length - items.length;

    for (var i = 0; i < proposals.length; i++) {
      final proposal = proposals[i];
      final path = proposal.candidate?.path;
      if (proposal.confidence == RepairConfidence.unmatched || path == null) {
        notFound++;
        continue;
      }
      resolved[indices[i]] = path;
      if (proposal.viaPrefixMove) {
        reRooted++;
      } else {
        filenameOnly++;
      }
    }

    return ImportMediaResolution(
      resolvedPathByIndex: resolved,
      reRootedCount: reRooted,
      filenameOnlyCount: filenameOnly,
      notFoundCount: notFound,
    );
  }

  /// A [MediaItem] that is never persisted. It exists only to satisfy the
  /// repair ladder's parameter type; the ladder reads `filePath` and
  /// `originalFilename` and nothing else.
  ///
  /// The path came from another machine, possibly another platform, so both
  /// fields are normalised here rather than left for the ladder to guess.
  /// `originalFilename` is set explicitly because the ladder prefers it over
  /// parsing the path, which spares it the separator question entirely.
  static MediaItem _transientItem(String foreignPath) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      filePath: foreignPath.replaceAll(r'\', '/'),
      originalFilename: foreignBasename(foreignPath),
      takenAt: epoch,
      createdAt: epoch,
      updatedAt: epoch,
    );
  }
}

/// Basename of a path produced by an unknown platform.
///
/// `p.basename` follows the HOST's separator, which is the wrong question for
/// a path that arrived inside a file: a logbook exported from Windows carries
/// `C:\Users\jai\dive.jpg` no matter which platform imports it. Both
/// separators are therefore treated as separators, which is safe in practice
/// because a photo filename containing a literal backslash is vanishingly
/// rare next to the certainty of Windows-exported logbooks.
String foreignBasename(String path) {
  final index = path.lastIndexOf(RegExp(r'[/\\]'));
  return index < 0 ? path : path.substring(index + 1);
}
