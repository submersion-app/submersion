import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.gen.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';

/// The placement table names artwork by id; the generated map is where the
/// ids come true. A type whose piece is missing would draw nothing and say
/// nothing, so this is the check that closes the loop. The Python generator
/// cannot do it because the table lives in Dart.
void main() {
  /// Every piece id the table can name, across every type, every attribute
  /// variant, and both rig contexts. The doubles tank is named by the
  /// composer rather than the table.
  Set<String> namedByTable() {
    final named = <String>{'tank_doubles_back'};
    for (final type in EquipmentType.values) {
      for (final attributes in FigurePlacement.variantAttributeSets) {
        for (final sidemount in [false, true]) {
          final spec = FigurePlacement.forType(
            type,
            attributes: attributes,
            context: FigureContext(sidemountRig: sidemount),
          );
          for (final pieces in spec.piecesByZone.values) {
            named.addAll(pieces);
          }
        }
      }
    }
    return named;
  }

  test('every piece the placement table names exists', () {
    final missing =
        namedByTable().where((id) => !figureArtwork.containsKey(id)).toList()
          ..sort();
    expect(missing, isEmpty, reason: 'add these to tool/figure and regenerate');
  });

  test('no piece in the artwork is unreachable from the table', () {
    final reachable = {...namedByTable(), 'body_front', 'body_back'};
    final orphans =
        figureArtwork.keys.where((id) => !reachable.contains(id)).toList()
          ..sort();
    expect(
      orphans,
      isEmpty,
      reason: 'artwork nothing places: remove it or place it',
    );
  });
}
