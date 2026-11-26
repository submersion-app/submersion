import 'dart:ui';

import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_artwork.gen.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_paths.dart';

/// Parsed [Path]s per side-view piece, built once per process, as
/// [FigurePaths] does for the gear figure.
abstract final class TrimFigurePaths {
  static final Map<String, List<Path>> _cache = {};

  static List<Path> of(String pieceId) => _cache.putIfAbsent(pieceId, () {
    final piece = trimArtwork[pieceId];
    if (piece == null) {
      throw ArgumentError.value(pieceId, 'pieceId', 'unknown trim piece');
    }
    return List.unmodifiable([
      for (final p in piece.paths) FigurePaths.parseSvgPath(p.d),
    ]);
  });
}
