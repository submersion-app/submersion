import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

/// Detects a wholesale tree move: for suffixes shared between broken and
/// found paths, votes on (fromPrefix, toPrefix) pairs and returns the pair
/// covering the most broken paths. A single coincidental filename is not
/// evidence of a move, so fewer than two covered paths yields null.
PrefixMove? detectPrefixMove({
  required List<String> brokenPaths,
  required Set<String> foundPaths,
}) {
  final votes = <String, ({String from, String to, Set<String> covered})>{};

  // Split each found path ONCE: a folder scan can surface tens of thousands
  // of paths, and splitting inside the nested loop would redo that work per
  // broken row.
  final foundSegmentsByPath = [
    for (final foundPath in foundPaths) foundPath.split('/'),
  ];

  for (final brokenPath in brokenPaths) {
    final brokenSegments = brokenPath.split('/');
    for (final foundSegments in foundSegmentsByPath) {
      // Longest shared trailing-segment run between the two paths.
      var shared = 0;
      while (shared < brokenSegments.length - 1 &&
          shared < foundSegments.length - 1 &&
          brokenSegments[brokenSegments.length - 1 - shared] ==
              foundSegments[foundSegments.length - 1 - shared]) {
        shared++;
      }
      if (shared == 0) continue;
      // Vote at EVERY shared suffix length, not only the maximum: the true
      // move root can sit between the filename and the deepest coincidental
      // overlap (a shared "Dives" segment on both sides would otherwise
      // hide "/old/Dives -> /nas/Dives" behind "/old -> /nas").
      for (var length = 1; length <= shared; length++) {
        final from = brokenSegments
            .sublist(0, brokenSegments.length - length)
            .join('/');
        final to = foundSegments
            .sublist(0, foundSegments.length - length)
            .join('/');
        if (from == to) continue;
        final key = '$from $to';
        final entry = votes.putIfAbsent(
          key,
          () => (from: from, to: to, covered: <String>{}),
        );
        entry.covered.add(brokenPath);
      }
    }
  }

  // Highest coverage wins; at equal coverage the DEEPEST from-prefix wins.
  // The shallower pair also fits the evidence but overstates the move
  // ("/old -> /nas" claims everything under /old moved when only
  // /old/Dives demonstrably did).
  ({String from, String to, Set<String> covered})? best;
  for (final entry in votes.values) {
    if (best == null ||
        entry.covered.length > best.covered.length ||
        (entry.covered.length == best.covered.length &&
            entry.from.length > best.from.length)) {
      best = entry;
    }
  }
  if (best == null || best.covered.length < 2) return null;
  return PrefixMove(
    fromPrefix: best.from,
    toPrefix: best.to,
    coveredCount: best.covered.length,
  );
}

/// The pure match ladder (design spec section 6). Prefix-move relocations
/// are tried first; the filename index covers the rest.
///
/// Hash rules per candidate: candidate hash equal to the row's -> exact;
/// candidate hash differing -> edited; no candidate hash (or no row hash) ->
/// probable. Store candidates address the row's OWN hash, so they are exact
/// by construction.
List<RepairProposal> buildRepairProposals({
  required List<MediaItem> brokenRows,
  required Map<String, List<RepairCandidate>> candidatesByFilename,
  PrefixMove? prefixMove,
  Set<String> foundPaths = const {},
}) {
  final proposals = <RepairProposal>[];

  for (final item in brokenRows) {
    // 1) Whole-tree move: the row's old path re-rooted under the new prefix.
    final oldPath = item.localPath ?? item.filePath;
    if (prefixMove != null &&
        oldPath != null &&
        oldPath.startsWith('${prefixMove.fromPrefix}/')) {
      final relocated =
          prefixMove.toPrefix + oldPath.substring(prefixMove.fromPrefix.length);
      if (foundPaths.contains(relocated)) {
        proposals.add(
          RepairProposal(
            item: item,
            confidence: RepairConfidence.probable,
            candidate: RepairCandidate.file(path: relocated, sizeBytes: null),
            viaPrefixMove: true,
          ),
        );
        continue;
      }
    }

    // 2) Filename index.
    final filename = _filenameOf(item);
    final candidates = filename == null
        ? const <RepairCandidate>[]
        : candidatesByFilename[filename] ?? const <RepairCandidate>[];

    RepairProposal? best;
    for (final candidate in candidates) {
      final RepairConfidence confidence;
      if (candidate.isStore) {
        confidence = RepairConfidence.exact;
      } else if (candidate.hash != null && item.contentHash != null) {
        confidence = candidate.hash == item.contentHash
            ? RepairConfidence.exact
            : RepairConfidence.edited;
      } else {
        confidence = RepairConfidence.probable;
      }
      final proposal = RepairProposal(
        item: item,
        confidence: confidence,
        candidate: candidate,
      );
      if (best == null || confidence.index < best.confidence.index) {
        best = proposal;
      }
    }

    proposals.add(
      best ??
          RepairProposal(item: item, confidence: RepairConfidence.unmatched),
    );
  }

  return proposals;
}

String? _filenameOf(MediaItem item) {
  final name = item.originalFilename;
  if (name != null && name.isNotEmpty) return name.toLowerCase();
  final path = item.localPath ?? item.filePath;
  if (path == null || path.isEmpty) return null;
  final slash = path.lastIndexOf('/');
  return (slash >= 0 ? path.substring(slash + 1) : path).toLowerCase();
}
