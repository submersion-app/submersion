import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/video_playhead_reporter.dart';

import '../../../../helpers/test_database.dart';
import '../../../species_id/presentation/species_id_fakes.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';
import 'video_viewer_test_harness.dart';

/// The viewer tells the fish scan where the diver is watching (issue #4709)
/// in tag mode too: one reporter lasts while the name labels come and go,
/// so what it was told is not forgotten on the way.
void main() {
  late bool flagBefore;

  setUp(() async {
    flagBefore = marineLifeIdEnabled;
    marineLifeIdEnabled = true;
    await setUpTestDatabase();
    await insertTestDiver('me');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10, 9), diverId: 'me');
    await insertTestMedia(
      id: 'v1',
      diveId: 'd1',
      takenAt: DateTime(2024, 1, 10, 9, 2),
      fileType: 'video',
    );
  });
  tearDown(() async {
    marineLifeIdEnabled = flagBefore;
    await tearDownTestDatabase();
  });

  testWidgets('entering tag mode keeps the playhead reporter and what it '
      'reported', (tester) async {
    final service = RecordingIdentificationService();
    final platform = FakeVideoPlatform();
    useVideoPlatform(platform);
    final items = await tester.runAsync(() => storedMedia(['v1']));
    await pumpViewerApp(
      tester,
      MediaViewerPage(mediaList: items!, initialMediaId: 'v1'),
      overrides: [
        resolvedFilePathProvider.overrideWith(
          (ref, MediaItem arg) async => tempVideoPath('v1'),
        ),
        mediaIdentificationServiceProvider.overrideWithValue(service),
      ],
    );
    await tester.runAsync(() async {
      platform.completeInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleViewer(tester);
    await tapUnlock(tester);
    final reporter = tester.state(find.byType(VideoPlayheadReporter));

    // Tag mode hides the name labels, which sit just before the reporter.
    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    await settleViewer(tester);

    expect(tester.state(find.byType(VideoPlayheadReporter)), same(reporter));
    expect(service.forgotten, isEmpty);
  });
}
