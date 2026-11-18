import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveProfileEvent, DivesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_focus_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_placement_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/annotation_edits.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_annotation_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';
import '../../../../../helpers/unlock_for_operation.dart';

/// Annotations from the dive detail page (#4109): the pin button enters
/// placement mode, a tap on the profile opens the sheet, Add writes the row
/// and the Notes paragraph, and the marker's popup can move or remove it.
void main() {
  late DiveRepository repository;
  late String? previousLocale;
  const diveId = 'dive-flow';

  final profile = List.generate(41, (i) {
    final t = i * 30;
    final depth = t < 180
        ? 30.0 * t / 180
        : t < 900
        ? 30.0
        : 30.0 * (1200 - t) / 300;
    return DiveProfilePoint(timestamp: t, depth: depth);
  });

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  AppDatabase db() => DatabaseService.instance.database;

  Future<Dive> seedDive({bool withProfile = true, String notes = 'First.'}) =>
      repository.createDive(
        Dive(
          id: diveId,
          dateTime: DateTime.utc(2026, 5, 3, 10),
          runtime: const Duration(seconds: 1200),
          maxDepth: 30,
          profile: withProfile ? profile : const [],
          notes: notes,
        ),
      );

  Future<void> seedAnnotation({
    String id = 'a1',
    int timestamp = 600,
    String words = 'felt sick',
  }) async {
    await db().customStatement(
      'INSERT INTO dive_profile_events '
      '(id, dive_id, timestamp, event_type, source, description, depth, '
      'created_at) '
      "VALUES (?, '$diveId', ?, 'annotation', 'user', ?, 30, 1)",
      [id, timestamp, words],
    );
    await (db().update(db().dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(notes: Value('First.\n\n[$words](annotation:$id)')),
    );
  }

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveDetailPage(diveId: diveId, embedded: true)),
        ),
      ),
    );
    await settle(tester);
  }

  Future<List<DiveProfileEvent>> rows() =>
      (db().select(db().diveProfileEvents)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Future<String> notes() async => (await (db().select(
    db().dives,
  )..where((t) => t.id.equals(diveId))).getSingle()).notes;

  Finder pin() => find.byTooltip('Add annotation');

  /// Annotations change only in the open Profile card, held until Save
  /// (issue #4527): unlocks the page and opens the card.
  Future<void> openProfileCard(WidgetTester tester) async {
    await unlockForOperation(tester);
    await tester.tap(find.byTooltip('Edit Dive Profile'));
    await settle(tester, frames: 6);
  }

  /// Saves the sitting from the pane's bar.
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save').last);
    await settle(tester);
  }

  Future<void> tapChartAt(WidgetTester tester, double fraction) async {
    final plot = tester.getRect(find.byType(LineChart).first);
    await tester.tapAt(
      Offset(plot.left + plot.width * fraction, plot.center.dy),
    );
    await settle(tester, frames: 4);
  }

  Future<Offset> dotCenter(WidgetTester tester, String id) async {
    final layerFinder = find.byType(AnnotationMarkerLayer);
    final layer = tester.widget<AnnotationMarkerLayer>(layerFinder);
    final index = layer.annotations.indexWhere((a) => a.id == id);
    final centers = annotationDotCenters(
      annotations: layer.annotations,
      size: tester.getSize(layerFinder),
      insets: layer.insets,
      visibleMinSeconds: layer.visibleMinSeconds,
      visibleMaxSeconds: layer.visibleMaxSeconds,
      visibleMinDepth: layer.visibleMinDepth,
      visibleMaxDepth: layer.visibleMaxDepth,
      depthAt: layer.depthAt,
    );
    return tester.getTopLeft(layerFinder) + centers[index]!;
  }

  testWidgets('cancelling the sheet leaves placement mode with nothing added', (
    tester,
  ) async {
    await seedDive();
    await pumpDetail(tester);
    await openProfileCard(tester);
    await tester.tap(pin());
    await settle(tester, frames: 3);
    await tapChartAt(tester, 0.5);
    // The sheet's Cancel, not the banner's.
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Cancel'),
      ),
    );
    await settle(tester, frames: 4);
    expect(await rows(), isEmpty);
    expect(find.byType(AnnotationPlacementBanner), findsNothing);
  });

  testWidgets('Remove from the popup deletes the row and keeps the words', (
    tester,
  ) async {
    await seedDive();
    await seedAnnotation();
    await pumpDetail(tester);
    await openProfileCard(tester);
    expect(find.byType(AnnotationMarkerLayer), findsOneWidget);

    await tester.tapAt(await dotCenter(tester, 'a1'));
    await settle(tester, frames: 4);
    expect(find.text('felt sick'), findsWidgets);
    await tester.tap(find.text('Remove'));
    await settle(tester);
    await save(tester);

    expect(await rows(), isEmpty);
    expect(await notes(), 'First.\n\nfelt sick');
  });

  testWidgets('Move re-enters placement and the next tap updates the time', (
    tester,
  ) async {
    await seedDive();
    await seedAnnotation(timestamp: 300);
    await pumpDetail(tester);
    await openProfileCard(tester);

    await tester.tapAt(await dotCenter(tester, 'a1'));
    await settle(tester, frames: 4);
    await tester.tap(find.text('Move'));
    await settle(tester, frames: 4);
    expect(find.text('Tap the new spot for this annotation.'), findsOneWidget);

    await tapChartAt(tester, 0.8);
    await settle(tester);
    expect(find.byType(AnnotationPlacementBanner), findsNothing);
    await save(tester);

    final row = (await rows()).single;
    expect(row.id, 'a1');
    expect(row.timestamp, inInclusiveRange(800, 1200));
    expect(await notes(), 'First.\n\n[felt sick](annotation:a1)');
  });

  testWidgets('the popup\'s time opens the time sheet and Save moves the '
      'marker', (tester) async {
    await seedDive();
    await seedAnnotation(timestamp: 300);
    await pumpDetail(tester);
    await openProfileCard(tester);

    await tester.tapAt(await dotCenter(tester, 'a1'));
    await settle(tester, frames: 4);
    await tester.tap(find.textContaining(RegExp(r'^5:00')));
    await settle(tester, frames: 4);
    expect(find.text('Change the time'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(MinutesSecondsField),
        matching: find.byType(TextFormField),
      ),
      '7:30',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    await save(tester);

    expect((await rows()).single.timestamp, 450);
    expect(await notes(), 'First.\n\n[felt sick](annotation:a1)');
  });

  testWidgets('Open in Notes highlights the passage, and the Notes link '
      'opens the marker popup', (tester) async {
    await seedDive();
    await seedAnnotation();
    await pumpDetail(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    );
    // The Notes card draws the linked passage with its pin.
    expect(find.byIcon(Icons.push_pin), findsWidgets);

    await tester.tapAt(await dotCenter(tester, 'a1'));
    await settle(tester, frames: 4);
    await tester.tap(find.text('Open in Notes'));
    await settle(tester, frames: 4);
    expect(container.read(annotationNotesHighlightProvider(diveId)), 'a1');
    await tester.pump(const Duration(milliseconds: 1600));
    await settle(tester, frames: 2);
    expect(container.read(annotationNotesHighlightProvider(diveId)), isNull);

    // Back the other way: the Notes link lights the marker and opens its
    // popup, then the focus request is spent.
    await tester.tapOnText(find.textRange.ofSubstring('felt sick').first);
    await settle(tester, frames: 6);
    // The locked page's popup reads only: no Remove (issue #4527).
    expect(find.text('Open in Notes'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
    expect(container.read(annotationFocusProvider(diveId)), isNull);
  });

  testWidgets('Open in Notes from the fullscreen profile lands on the passage '
      'in the page underneath', (tester) async {
    await seedDive();
    await seedAnnotation();
    await pumpDetail(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    );

    await tester.tap(find.byIcon(Icons.fullscreen));
    await settle(tester);
    expect(find.byType(FullscreenProfilePage), findsOneWidget);
    await tester.tapAt(await dotCenter(tester, 'a1'));
    await settle(tester, frames: 4);
    await tester.tap(find.text('Open in Notes'));
    await settle(tester, frames: 6);

    expect(find.byType(FullscreenProfilePage), findsNothing);
    expect(container.read(annotationNotesHighlightProvider(diveId)), 'a1');
    await tester.pump(const Duration(milliseconds: 1600));
    await settle(tester, frames: 2);
  });

  testWidgets('Open in Notes reaching a page that has gone does nothing', (
    tester,
  ) async {
    await seedDive();
    await seedAnnotation();
    await pumpDetail(tester);
    await tester.tap(find.byIcon(Icons.fullscreen));
    await settle(tester);
    final open = tester
        .widget<FullscreenProfilePage>(find.byType(FullscreenProfilePage))
        .onOpenInNotes!;

    await tester.pumpWidget(const SizedBox());
    open('a1');
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the Notes link turns hidden annotations back on and opens the '
      'popup', (tester) async {
    await seedDive();
    await seedAnnotation();
    await pumpDetail(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    );
    container.read(profileLegendProvider.notifier).toggleAnnotations();
    await settle(tester, frames: 3);
    expect(find.byType(AnnotationMarkerLayer), findsNothing);

    await tester.tapOnText(find.textRange.ofSubstring('felt sick').first);
    await settle(tester, frames: 6);

    expect(container.read(profileLegendProvider).showAnnotations, isTrue);
    expect(find.text('Open in Notes'), findsOneWidget);
  });
  AppSettings hiding(DiveDetailSectionId section) => AppSettings(
    diveDetailSections: [
      for (final s in DiveDetailSectionConfig.defaultSections)
        s.id == section ? s.copyWith(visible: false) : s,
    ],
  );
  testWidgets(
    'the popup offers no Open in Notes with the Notes section hidden',
    (tester) async {
      await seedDive();
      await seedAnnotation();
      await pumpDetail(tester, settings: hiding(DiveDetailSectionId.notes));

      await tester.tapAt(await dotCenter(tester, 'a1'));
      await settle(tester, frames: 4);

      // The popup is open: its words show, with no Notes card to show them.
      expect(find.text('felt sick'), findsOneWidget);
      expect(find.text('Open in Notes'), findsNothing);
    },
  );

  testWidgets('a dive with no profile accepts an annotation by typed time', (
    tester,
  ) async {
    // The detail page shows no profile card without samples, so the pin is
    // not there; the actions object still takes one by typed time, as the
    // fullscreen page and the notes editor do.
    final dive = await seedDive(withProfile: false);
    // Annotations are placed in the open Profile card's sitting, held until
    // Save (issue #4527).
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    final reader = ProviderContainer();
    addTearDown(reader.dispose);
    loadDiveAnnotations(session, reader.read);
    await tester.runAsync(session.settled);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(const AppSettings()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => DiveDetailAnnotationActions(
                  ref: ref,
                  context: context,
                  dive: dive,
                  edits: SittingAnnotationEdits(session),
                ).onPinPressed(),
                child: const Text('pin'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('pin'));
    await tester.pumpAndSettle();
    expect(find.text('New annotation'), findsOneWidget);
    expect(
      find.text('This dive has no profile to point at. Type the time instead.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(MinutesSecondsField),
        matching: find.byType(TextFormField),
      ),
      '5:00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened'),
      'Lost the buddy',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    final placed = sittingAnnotations(session)!.placed.single;
    expect((placed.timestamp, placed.depth), (300, null));
    // Nothing is written until Save.
    expect(await rows(), isEmpty);
  });
}
