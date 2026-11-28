import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/identification_trigger.dart';

import '../../../../helpers/test_database.dart';
import '../../../species_id/presentation/species_id_fakes.dart';
import 'media_viewer_unlock_harness.dart';

/// A photo or clip placed on a site and no dive is named against that
/// site's position (issue #5122): a GoPro clip has no GPS, and the site is
/// the only place it has.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
    await db.customStatement(
      "UPDATE dive_sites SET latitude = 20.5, longitude = -87.25 "
      "WHERE id = 's1'",
    );
  });

  tearDown(tearDownTestDatabase);

  GeoPoint? triggerLocation(WidgetTester tester) => tester
      .widget<IdentificationTrigger>(find.byType(IdentificationTrigger))
      .location;

  Future<void> pump(WidgetTester tester, String id) async {
    final items = await tester.runAsync(() => storedMedia([id]));
    await pumpViewerApp(
      tester,
      MediaViewerPage(mediaList: items!, initialMediaId: id),
      overrides: [
        mediaIdentificationServiceProvider.overrideWithValue(
          RecordingIdentificationService(),
        ),
      ],
    );
    await settleViewer(tester);
  }

  testWidgets('site-only media is located at its site', (tester) async {
    await tester.runAsync(
      () => db.customStatement(
        "UPDATE media SET site_id = 's1' WHERE id = 'lib'",
      ),
    );
    await pump(tester, 'lib');
    expect(triggerLocation(tester), const GeoPoint(20.5, -87.25));
  });

  testWidgets('media with no dive and no site has no location', (tester) async {
    await pump(tester, 'lib');
    expect(triggerLocation(tester), isNull);
  });
}
