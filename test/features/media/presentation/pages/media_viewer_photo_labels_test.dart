import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/photo_identification_layer.dart';
import 'package:submersion/shared/widgets/size_reporter.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
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

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    List<Override> extra = const [],
  }) async {
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
        ...extra,
      ],
      size: size,
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

  testWidgets('unlocked, the labels keep above the panel as it grows', (
    tester,
  ) async {
    await tester.runAsync(
      () => insertTestSighting(id: 'sg1', diveId: 'd1', speciesId: 'sp_turtle'),
    );
    await pump(tester);
    await tapUnlock(tester);
    double inset() => tester
        .widget<PhotoIdentificationLayer>(find.byType(PhotoIdentificationLayer))
        .bottomInset;
    double panel() => tester.getSize(find.byType(SizeReporter)).height;
    final before = panel();

    // A species tagged in the sitting adds its chip to the panel.
    await tester.tap(find.byKey(const ValueKey('viewer_species')));
    await settleViewer(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Turtle'));
    await settleViewer(tester);
    await tester.tapAt(const Offset(640, 20));
    await settleViewer(tester);

    expect(panel(), greaterThan(before));
    expect(inset(), panel());
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
    await container
        .read(labelModeNotifierProvider.notifier)
        .setMode(LabelMode.off);
    await settleViewer(tester);
    expect(pill, findsNothing);
    expect(dot, findsNothing);
  });

  testWidgets('the toolbar\'s labels button opens the menu, and a mode '
      'picked there is drawn', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('viewer_marine_life_labels')));
    // The status read waits for its database read, or gives up after 2 s.
    await tester.pump(const Duration(seconds: 3));
    await settleViewer(tester);
    expect(find.byKey(const ValueKey('labels_menu_names')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('labels_menu_off')));
    await settleViewer(tester);
    expect(pill, findsNothing);
    expect(dot, findsNothing);
  });

  testWidgets('locked, "+N" opens the read-only list of every species', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(390, 844),
      extra: [
        mediaTagChipsProvider('p1').overrideWith(
          (ref) async => [
            for (var i = 0; i < 12; i++)
              SpeciesTagChip(
                speciesId: 'sp_$i',
                storedName: 'Striped species $i',
                category: SpeciesCategory.fish,
                isBuiltIn: false,
              ),
          ],
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('media_species_more')));
    await settleViewer(tester);
    expect(
      find.byKey(const ValueKey('media_species_list_sheet')),
      findsOneWidget,
    );
    expect(find.text('Unlock to add or dismiss'), findsOneWidget);
  });
}
