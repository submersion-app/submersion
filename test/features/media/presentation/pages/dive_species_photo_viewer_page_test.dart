import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/pages/dive_species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';

import '../support/media_widget_harness.dart';

void main() {
  const key = (diveId: 'd1', speciesId: 'sp_x');

  testWidgets('opens the dive\'s photos of the species on the first one', (
    tester,
  ) async {
    final items = [
      testMediaItem(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 10)),
      testMediaItem(id: 'p2', diveId: 'd1', takenAt: DateTime(2024, 1, 11)),
    ];
    await tester.pumpWidget(
      await mediaTestApp(
        home: const DiveSpeciesPhotoViewerPage(diveId: 'd1', speciesId: 'sp_x'),
        overrides: [
          mediaForDiveSpeciesProvider(key).overrideWith((ref) async => items),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<MediaViewerPage>(find.byType(MediaViewerPage));
    expect(viewer.mediaList.map((m) => m.id).toList(), ['p1', 'p2']);
    expect(viewer.initialMediaId, 'p1');
    expect(viewer.showGoToDive, isFalse);
  });

  testWidgets('honours an explicit initial photo', (tester) async {
    final items = [
      testMediaItem(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 10)),
      testMediaItem(id: 'p2', diveId: 'd1', takenAt: DateTime(2024, 1, 11)),
    ];
    await tester.pumpWidget(
      await mediaTestApp(
        home: const DiveSpeciesPhotoViewerPage(
          diveId: 'd1',
          speciesId: 'sp_x',
          initialMediaId: 'p2',
        ),
        overrides: [
          mediaForDiveSpeciesProvider(key).overrideWith((ref) async => items),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<MediaViewerPage>(find.byType(MediaViewerPage));
    expect(viewer.initialMediaId, 'p2');
  });

  testWidgets('shows no viewer when the list has emptied', (tester) async {
    await tester.pumpWidget(
      await mediaTestApp(
        home: const DiveSpeciesPhotoViewerPage(diveId: 'd1', speciesId: 'sp_x'),
        overrides: [
          mediaForDiveSpeciesProvider(key).overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MediaViewerPage), findsNothing);
    expect(find.text('No photos available'), findsOneWidget);
    // The back affordance must stay visible on the black scaffold under the
    // light theme too.
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.foregroundColor, Colors.white);
  });
}
