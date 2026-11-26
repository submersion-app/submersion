import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_gallery_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_hero.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_where_seen_section.dart';
import 'package:submersion/features/media/presentation/pages/species_tag_picker_page.dart';
import 'package:submersion/features/media/presentation/widgets/species_photos_section.dart';

import '../widgets/species_picture_test_support.dart';
import 'species_detail_page_unlock_harness.dart';

/// The species page's field-guide layout (issue #5027).
void main() {
  testWidgets('order of sections', (tester) async {
    await pumpSpeciesPage(tester);

    double top(Type type) => tester.getTopLeft(find.byType(type)).dy;
    expect(top(SpeciesHero), lessThan(top(SpeciesWhereSeenSection)));
    expect(top(SpeciesWhereSeenSection), lessThan(top(SpeciesPhotosSection)));
    expect(find.text('Manta'), findsOneWidget);
  });

  testWidgets('two columns at 1280', (tester) async {
    await pumpSpeciesPage(tester);
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    final hero = tester.getRect(find.byType(SpeciesHero));
    final where = tester.getRect(find.byType(SpeciesWhereSeenSection));
    expect(where.left, greaterThan(hero.right));
    expect(where.top, lessThan(hero.bottom));
  });

  testWidgets('Find photos only with candidates, and it opens the picker', (
    tester,
  ) async {
    await pumpSpeciesPage(tester);
    final find_ = find.byKey(const ValueKey('species_find_photos'));
    expect(find_, findsOneWidget);

    await tester.tap(find_);
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesTagPickerPage), findsOneWidget);
  });

  testWidgets('a species with a picture offers no Find photos', (tester) async {
    await pumpSpeciesPage(
      tester,
      extra: [
        speciesPicturesProvider.overrideWith(
          (ref) async => {'manta': CropPicture(testCrop('i1'))},
        ),
      ],
    );
    expect(find.byKey(const ValueKey('species_find_photos')), findsNothing);
  });
}
