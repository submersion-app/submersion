import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_hero.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';

import 'species_picture_test_support.dart';

const _grouper = Species(
  id: 'grouper',
  commonName: 'Nassau Grouper',
  scientificName: 'Epinephelus striatus',
  category: SpeciesCategory.fish,
);

Widget _hero(SpeciesHero hero) =>
    SizedBox(width: 400, height: 300, child: hero);

void main() {
  group('heroSourceRect', () {
    test('pads by 15% of the longer side', () {
      final rect = heroSourceRect(
        const IdentificationBox(x: 0.4, y: 0.4, width: 0.2, height: 0.1),
      );
      expect(rect.left, closeTo(0.37, 1e-9));
      expect(rect.top, closeTo(0.37, 1e-9));
      expect(rect.width, closeTo(0.26, 1e-9));
      expect(rect.height, closeTo(0.16, 1e-9));
    });

    test('clamps at the edges', () {
      final rect = heroSourceRect(
        const IdentificationBox(x: 0, y: 0.9, width: 0.2, height: 0.1),
      );
      expect(rect.left, 0);
      expect(rect.bottom, 1);
      expect(rect.right, closeTo(0.23, 1e-9));
    });
  });

  testWidgets('shows the names over the picture', (tester) async {
    await pumpPictures(
      tester,
      _hero(
        SpeciesHero(species: _grouper, picture: CropPicture(testCrop('a'))),
      ),
    );
    expect(find.text('Nassau Grouper'), findsOneWidget);
    expect(find.text('Epinephelus striatus'), findsOneWidget);
  });

  testWidgets('no picture shows the category tile and the empty action', (
    tester,
  ) async {
    await pumpPictures(
      tester,
      _hero(
        const SpeciesHero(
          species: _grouper,
          picture: NoPicture(),
          emptyAction: Text('FIND PHOTOS'),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('species_category_tile')), findsOneWidget);
    expect(find.text('FIND PHOTOS'), findsOneWidget);
  });

  testWidgets('a crop on a video draws the stored crop', (tester) async {
    await pumpPictures(
      tester,
      _hero(
        SpeciesHero(
          species: _grouper,
          picture: CropPicture(testCrop('a', video: true, mediaId: 'v1')),
          cropMedia: testPhoto('v1', video: true),
        ),
      ),
    );
    expect(find.byType(IdentificationCrop), findsOneWidget);
    expect(find.byType(MediaItemView), findsNothing);
  });

  testWidgets('a photo crop draws the original over the stored crop', (
    tester,
  ) async {
    await pumpPictures(
      tester,
      _hero(
        SpeciesHero(
          species: _grouper,
          picture: CropPicture(testCrop('a', mediaId: 'p1')),
          cropMedia: testPhoto('p1'),
        ),
      ),
    );
    expect(find.byType(IdentificationCrop), findsOneWidget);
    expect(find.byType(MediaItemView), findsOneWidget);
  });

  testWidgets('a photo crop that fails to load falls back to the stored crop', (
    tester,
  ) async {
    await pumpPictures(
      tester,
      _hero(
        SpeciesHero(
          species: _grouper,
          picture: CropPicture(testCrop('a', mediaId: 'p1')),
          cropMedia: testPhoto('p1'),
        ),
      ),
      resolverData: const UnavailableData(kind: UnavailableKind.notFound),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IdentificationCrop), findsOneWidget);
    expect(find.byType(MediaItemView), findsNothing);
  });
}
