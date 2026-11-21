import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../species_id/data/identification_fixtures.dart';
import '../../../species_id/presentation/species_id_fakes.dart';
import 'media_viewer_unlock_harness.dart';

/// Name pills and dots on a photo in the viewer (issue #4825).
void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
    // The photo's stored size: its labels are placed before it decodes, and
    // the sitting reads the stored row.
    await db.customStatement(
      "UPDATE media SET width = 1600, height = 900 WHERE id = 'p1'",
    );
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
  });

  tearDown(tearDownTestDatabase);

  // A suggestion, and an unnamed fish that looks like something, apart.
  final found = [
    identification('s', mediaId: 'p1').copyWith(
      box: const IdentificationBox(x: 0.1, y: 0.4, width: 0.1, height: 0.1),
    ),
    identification('u', mediaId: 'p1').copyWith(
      suggestable: false,
      specific: true,
      box: const IdentificationBox(x: 0.6, y: 0.4, width: 0.1, height: 0.1),
    ),
  ];

  final pill = find.byKey(const ValueKey('photo_label_pill_s'));
  final dot = find.byKey(const ValueKey('photo_label_dot_u'));

  Future<void> pump(WidgetTester tester) async {
    final items = await tester.runAsync(() => storedMedia(['p1']));
    expect(items!.single.width, 1600);
    await pumpViewerApp(
      tester,
      MediaViewerPage(mediaList: items, initialMediaId: 'p1'),
      overrides: [
        photoDetectionsProvider('p1').overrideWith((ref) async => found),
        mediaIdentificationServiceProvider.overrideWithValue(
          RecordingIdentificationService(),
        ),
      ],
    );
  }

  /// Taps at [at], then lets PhotoView's double-tap recognizer give the
  /// gesture up.
  Future<void> tapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 500));
    await settleViewer(tester);
  }

  testWidgets('a photo in the viewer shows its labels', (tester) async {
    await pump(tester);
    expect(pill, findsOneWidget);
    expect(dot, findsOneWidget);
  });

  testWidgets('locked, a tap on a label toggles the controls, as any tap '
      'on the photo does', (tester) async {
    await pump(tester);
    expect(find.text('1 / 1'), findsOneWidget);
    await tapAt(tester, tester.getCenter(dot));
    expect(find.text('1 / 1'), findsNothing);
    expect(find.byType(SpeciesPickerSheet), findsNothing);
  });

  testWidgets('unlocked, a tap on a dot names the animal there', (
    tester,
  ) async {
    await pump(tester);
    await tapUnlock(tester);
    await tapAt(tester, tester.getCenter(dot));
    expect(find.byType(SpeciesPickerSheet), findsOneWidget);
  });

  testWidgets('unlocked, a tap away from every label still does what it '
      'did', (tester) async {
    await pump(tester);
    await tapUnlock(tester);
    final scaffold = tester.getRect(find.byType(Scaffold).first);
    await tapAt(tester, Offset(scaffold.center.dx, scaffold.top + 200));
    expect(find.byType(SpeciesPickerSheet), findsNothing);
  });

  testWidgets('labels hide in people tag mode', (tester) async {
    await pump(tester);
    await tapUnlock(tester);
    await tester.tap(find.byKey(const ValueKey('viewer_people')));
    await settleViewer(tester);
    expect(pill, findsNothing);
    expect(dot, findsNothing);
  });

  testWidgets('labels follow the labels mode', (tester) async {
    await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaViewerPage)),
    );
    await container.read(labelModeProvider.notifier).setMode(LabelMode.off);
    await settleViewer(tester);
    expect(pill, findsNothing);
    expect(dot, findsNothing);
  });
}
