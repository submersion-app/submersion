import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/species_photos_section.dart';

import '../support/media_widget_harness.dart';

Future<void> _pump(
  WidgetTester tester,
  List<MediaItem> items, {
  VoidCallback? onTagPhotos,
  VoidCallback? onAddPhotos,
}) async {
  await tester.pumpWidget(
    await mediaTestApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SpeciesPhotosSection(
            speciesId: 'sp_x',
            onTagPhotos: onTagPhotos,
            onAddPhotos: onAddPhotos,
          ),
        ),
      ),
      overrides: [
        mediaForSpeciesProvider('sp_x').overrideWith((ref) async => items),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final items = [
    testMediaItem(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 11)),
    testMediaItem(id: 'p2', diveId: 'd1', takenAt: DateTime(2024, 1, 10)),
  ];

  testWidgets('renders a titled grid of tagged photos', (tester) async {
    await _pump(tester, items);

    expect(find.text('Photos (2)'), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
    expect(find.byType(MediaEmptyState), findsNothing);
  });

  testWidgets('shows the empty state with the actions still available', (
    tester,
  ) async {
    await _pump(tester, const [], onTagPhotos: () {}, onAddPhotos: () {});

    expect(find.text('Photos (0)'), findsOneWidget);
    expect(find.byType(MediaEmptyState), findsOneWidget);
    expect(find.text('Tag photos'), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
  });

  testWidgets('hides an action whose callback is absent', (tester) async {
    await _pump(tester, items, onAddPhotos: () {});

    expect(find.text('Tag photos'), findsNothing);
    expect(find.text('Add photos'), findsOneWidget);
  });

  testWidgets('the actions call back', (tester) async {
    var tagged = false;
    var added = false;
    await _pump(
      tester,
      items,
      onTagPhotos: () => tagged = true,
      onAddPhotos: () => added = true,
    );

    await tester.tap(find.text('Tag photos'));
    await tester.tap(find.text('Add photos'));

    expect(tagged, isTrue);
    expect(added, isTrue);
  });

  testWidgets('tapping a thumbnail opens the species viewer on that photo', (
    tester,
  ) async {
    await _pump(tester, items);

    await tester.tap(find.byType(MediaThumbnailTile).last);
    await tester.pumpAndSettle();

    final viewer = tester.widget<SpeciesPhotoViewerPage>(
      find.byType(SpeciesPhotoViewerPage),
    );
    expect(viewer.speciesId, 'sp_x');
    expect(viewer.initialMediaId, 'p2');
  });
}
