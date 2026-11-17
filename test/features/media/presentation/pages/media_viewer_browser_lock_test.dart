import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';

/// With the switch on, a browser cannot unlock a photo (issue #4527): it
/// reads only, and nothing falls back to writing at once.
void main() {
  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
    await insertTestMedia(
      id: 'a1',
      siteId: 's1',
      takenAt: DateTime(2024, 1, 10, 9),
    );
  });
  tearDown(tearDownTestDatabase);

  testWidgets('the dive viewer: no Set time, and the info sheet reads only', (
    tester,
  ) async {
    await pumpViewer(tester, browser: true);

    expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
    expect(find.byIcon(Icons.timer_off_outlined), findsNothing);
    await tester.tap(find.byKey(const ValueKey('viewer_info')));
    await settleViewer(tester);
    expect(find.byKey(const ValueKey('media_info_editTags')), findsNothing);
  });

  testWidgets('the site viewer: no Adjust color or Edit details', (
    tester,
  ) async {
    await pumpViewerApp(
      tester,
      const SiteMediaViewerPage(
        siteId: 's1',
        initialMediaId: 'a1',
        scope: SiteViewerScope.attachments,
      ),
      browser: true,
    );

    expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
    expect(find.byTooltip('Adjust color'), findsNothing);
    expect(find.byTooltip('Edit details'), findsNothing);
  });
}
