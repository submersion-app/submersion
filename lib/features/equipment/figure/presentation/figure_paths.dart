import 'dart:ui';

import 'package:path_parsing/path_parsing.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.gen.dart';

/// Parsed [Path]s per piece, built once per process.
///
/// Thirty set cards on one list draw the mannequin thirty times; the
/// strings are parsed once.
abstract final class FigurePaths {
  static final Map<String, List<Path>> _cache = {};

  static List<Path> of(String pieceId) {
    return _cache.putIfAbsent(pieceId, () {
      final piece = figureArtwork[pieceId];
      if (piece == null) {
        throw ArgumentError.value(pieceId, 'pieceId', 'unknown figure piece');
      }
      return List.unmodifiable([
        for (final p in piece.paths) parseSvgPath(p.d),
      ]);
    });
  }

  static Path parseSvgPath(String d) {
    final proxy = _UiPathProxy();
    writeSvgPathDataToPath(d, proxy);
    return proxy.path;
  }

  static int get cachedPieceCount => _cache.length;

  static void clearCache() => _cache.clear();
}

class _UiPathProxy extends PathProxy {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}
