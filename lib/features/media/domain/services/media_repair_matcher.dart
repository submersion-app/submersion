import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

/// Either path separator. `localPath` syncs, so one library holds `\` rows
/// written on Windows beside `/` rows written on a Mac, whichever platform is
/// reading them: splitting on the host separator would strand the other kind
/// (issue #2279).
final _separator = RegExp(r'[/\\]');

/// A path pre-split for suffix voting.
///
/// Prefixes are cut from the original string rather than rejoined from
/// segments, because rejoining has to pick one separator and would rewrite
/// the other kind of path.
class _SplitPath {
  _SplitPath(this.path)
    : segments = path.split(_separator),
      _separatorOffsets = [
        for (final match in _separator.allMatches(path)) match.start,
      ];

  final String path;
  final List<String> segments;
  final List<int> _separatorOffsets;

  /// [path] with its trailing [length] segments removed.
  String prefixDropping(int length) =>
      path.substring(0, _separatorOffsets[_separatorOffsets.length - length]);
}

/// Whether [path] sits inside [prefix], under either separator.
bool _isUnder(String path, String prefix) =>
    path.length > prefix.length &&
    path.startsWith(prefix) &&
    (path[prefix.length] == '/' || path[prefix.length] == '\\');

/// The separator [path] is written with. A bare drive root such as `C:`
/// carries no separator of its own but is a Windows path all the same.
String _separatorStyleOf(String path) =>
    _bareDriveRoot.hasMatch(path) ||
        (path.contains('\\') && !path.contains('/'))
    ? '\\'
    : '/';

final _bareDriveRoot = RegExp(r'^[A-Za-z]:$');

/// [oldPath] re-rooted from [move.fromPrefix] onto [move.toPrefix].
///
/// The surviving remainder carries the separators of the device that wrote the
/// broken row, which need not be the destination's, so it is restyled to
/// match. A wrong guess costs nothing: the caller only accepts the result if a
/// real scanned path equals it.
String _relocate(String oldPath, PrefixMove move) {
  final remainder = oldPath.substring(move.fromPrefix.length);
  return move.toPrefix +
      remainder.replaceAll(_separator, _separatorStyleOf(move.toPrefix));
}

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
  final foundSplits = [
    for (final foundPath in foundPaths) _SplitPath(foundPath),
  ];

  for (final brokenPath in brokenPaths) {
    final brokenSplit = _SplitPath(brokenPath);
    final brokenSegments = brokenSplit.segments;
    for (final foundSplit in foundSplits) {
      final foundSegments = foundSplit.segments;
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
        final from = brokenSplit.prefixDropping(length);
        final to = foundSplit.prefixDropping(length);
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
        _isUnder(oldPath, prefixMove.fromPrefix)) {
      final relocated = _relocate(oldPath, prefixMove);
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
  final cut = path.lastIndexOf(_separator);
  return (cut >= 0 ? path.substring(cut + 1) : path).toLowerCase();
}
