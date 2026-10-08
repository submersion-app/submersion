import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.gen.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_paths.dart';

void main() {
  setUp(FigurePaths.clearCache);

  test('a piece parses into one path per shape and is cached', () {
    final piece = figureArtwork['body_front']!;
    final paths = FigurePaths.of('body_front');
    expect(paths.length, piece.paths.length);
    expect(FigurePaths.cachedPieceCount, 1);
    expect(identical(FigurePaths.of('body_front'), paths), isTrue);
    expect(FigurePaths.cachedPieceCount, 1);
  });

  test('the head circle has the bounds its arc describes', () {
    final head = FigurePaths.of('body_front').first.getBounds();
    expect(head.left, closeTo(78, 0.5));
    expect(head.right, closeTo(122, 0.5));
    expect(head.top, closeTo(20, 0.5));
    expect(head.bottom, closeTo(64, 0.5));
  });

  test('an unknown piece throws rather than drawing nothing', () {
    expect(() => FigurePaths.of('no_such_piece'), throwsArgumentError);
  });
}
