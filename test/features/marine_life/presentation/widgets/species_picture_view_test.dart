import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picture_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';

import 'species_picture_test_support.dart';

Widget _sized(Widget child) => SizedBox.square(dimension: 120, child: child);

void main() {
  testWidgets('a crop draws the stored crop', (tester) async {
    await pumpPictures(
      tester,
      _sized(
        SpeciesPictureView(
          picture: CropPicture(testCrop('a')),
          category: SpeciesCategory.fish,
        ),
      ),
    );
    expect(find.byType(IdentificationCrop), findsOneWidget);
    expect(find.byType(MediaItemView), findsNothing);
  });

  testWidgets('a photo draws the media', (tester) async {
    await pumpPictures(
      tester,
      _sized(
        SpeciesPictureView(
          picture: PhotoPicture(testPhoto('p1')),
          category: SpeciesCategory.fish,
        ),
      ),
    );
    expect(find.byType(MediaItemView), findsOneWidget);
  });

  testWidgets('no picture draws the category tile', (tester) async {
    await pumpPictures(
      tester,
      _sized(
        const SpeciesPictureView(
          picture: NoPicture(),
          category: SpeciesCategory.turtle,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('species_category_tile')), findsOneWidget);
    expect(find.byType(IdentificationCrop), findsNothing);
  });
}
