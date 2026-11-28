import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_piece_ids.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_placement.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_artwork.gen.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.gen.dart';

/// Every drawing the trim figure names exists (issue #5028), and every
/// gear-figure drawing has a side-view counterpart.
void main() {
  test('every gear figure piece has side pieces that exist', () {
    for (final id in figureArtwork.keys) {
      if (id.startsWith('body_')) continue;
      final side = trimPieceIdsForGearPieces([id]);
      expect(side, isNotEmpty, reason: id);
      for (final s in side) {
        expect(trimArtwork, contains(s), reason: '$id -> $s');
      }
    }
  });

  test('a shorty wetsuit draws the shorty pieces', () {
    final full = trimPieceIdsForGearPieces(['wetsuit_front']);
    final shorty = trimPieceIdsForGearPieces(['wetsuit_front'], shorty: true);
    expect(shorty, isNot(full));
    for (final s in shorty) {
      expect(trimArtwork, contains(s));
    }
  });

  test('every weight and tank placement names pieces that exist', () {
    for (final type in [...WeightType.values, null]) {
      for (final id in trimPlacementForWeight(type, null).pieceIds) {
        expect(trimArtwork, contains(id), reason: '$type');
      }
    }
    for (final role in TankRole.values) {
      for (final id in trimPlacementForTank(role).pieceIds) {
        expect(trimArtwork, contains(id), reason: '$role');
      }
    }
  });

  test('a front and back pair maps to one set of side pieces', () {
    expect(
      trimPieceIdsForGearPieces(['wetsuit_front', 'wetsuit_back']),
      trimPieceIdsForGearPieces(['wetsuit_front']),
    );
  });
}
