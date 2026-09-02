import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/pages/species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';

import '../support/media_widget_harness.dart';

void main() {
  testWidgets('resolves the species gallery and hands off to the viewer', (
    tester,
  ) async {
    final items = [
      testMediaItem(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 10)),
      testMediaItem(id: 'p2', diveId: 'd1', takenAt: DateTime(2024, 1, 11)),
    ];
    await tester.pumpWidget(
      await mediaTestApp(
        home: const SpeciesPhotoViewerPage(
          speciesId: 'sp_x',
          initialMediaId: 'p2',
        ),
        overrides: [
          mediaForSpeciesProvider('sp_x').overrideWith((ref) async => items),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<MediaViewerPage>(find.byType(MediaViewerPage));
    expect(viewer.mediaList.map((m) => m.id).toList(), ['p1', 'p2']);
    expect(viewer.initialMediaId, 'p2');
    expect(viewer.showGoToDive, isTrue);
  });
}
