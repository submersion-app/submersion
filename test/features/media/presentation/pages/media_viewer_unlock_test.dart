import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';
import '../../../../helpers/marine_life_id_off.dart';

/// The photo viewer's own lock (issue #4527, plan 10).
void main() {
  // The species tag tests (Task 6) do not depend on it: the viewer's
  // species tag control does not read the flag.
  turnOffMarineLifeIdForEachTest();

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
  });

  tearDown(tearDownTestDatabase);

  /// A held change, made the way any control's change reaches the sitting.
  Future<void> change(WidgetTester tester) async {
    photoController(tester).session!.set(photoPinField, 42);
    await settleViewer(tester);
  }

  /// Pumps a page with an Open button that pushes the viewer on [ids], so
  /// leaving the viewer has somewhere to go.
  Future<void> pumpPushed(
    WidgetTester tester, {
    List<String> ids = const ['p1', 'p2', 'p3'],
    String initial = 'p2',
  }) async {
    final items = await tester.runAsync(() => storedMedia(ids));
    await pumpViewerApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    MediaViewerPage(mediaList: items!, initialMediaId: initial),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settleViewer(tester);
  }

  PhotoViewGallery gallery(WidgetTester tester) =>
      tester.widget<PhotoViewGallery>(find.byType(PhotoViewGallery));

  group('locked', () {
    testWidgets('no species, people or adjust colour; the lock is offered', (
      tester,
    ) async {
      await pumpViewer(tester);

      for (final id in ['species', 'people', 'adjust_color']) {
        expect(find.byKey(ValueKey('viewer_$id')), findsNothing, reason: id);
      }
      expect(find.byKey(const ValueKey('viewer_unlock')), findsOneWidget);
      expect(find.byType(RecordEditBar), findsNothing);
    });

    for (final from in ['a dive', 'the library']) {
      testWidgets(
        'tapping every control writes nothing, opened as from $from',
        (tester) async {
          if (from == 'a dive') {
            await pumpViewerApp(
              tester,
              const PhotoViewerPage(diveId: 'd1', initialMediaId: 'p2'),
            );
          } else {
            await pumpViewer(tester, showGoToDive: true);
          }
          final mark = (await tester.runAsync(() => eventCount(db)))!;

          // The time chip offers no Set time while locked.
          for (final chip in [Icons.timer_outlined, Icons.timer_off_outlined]) {
            if (find.byIcon(chip).evaluate().isNotEmpty) {
              await tester.tap(find.byIcon(chip));
              await settleViewer(tester);
            }
          }
          for (final tooltip in ['Previous media', 'Next media']) {
            if (find.byTooltip(tooltip).evaluate().isNotEmpty) {
              await tester.tap(find.byTooltip(tooltip));
              await settleViewer(tester);
            }
          }

          expect(find.byType(Dialog), findsNothing);
          expect((await tester.runAsync(() => eventCount(db)))!, mark);
          for (final id in ['species', 'people', 'adjust_color']) {
            expect(
              find.byKey(ValueKey('viewer_$id')),
              findsNothing,
              reason: id,
            );
          }
        },
      );
    }

    testWidgets('a photo with no stored row offers no unlock', (tester) async {
      final held = MediaItem(
        id: 'not-stored',
        diveId: 'd1',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        takenAt: DateTime(2024, 1, 10, 9, 2),
        createdAt: DateTime(2024, 1, 10),
        updatedAt: DateTime(2024, 1, 10),
      );
      await pumpViewerApp(
        tester,
        MediaViewerPage(mediaList: [held], initialMediaId: 'not-stored'),
      );

      expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
    });

    testWidgets('a read-only device offers no unlock', (tester) async {
      await pumpViewer(tester, browser: true);

      expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
    });

    testWidgets('a viewer built with only its photos opens locked', (
      tester,
    ) async {
      final items = await tester.runAsync(
        () => storedMedia(const ['p1', 'p2', 'p3']),
      );
      await pumpViewerApp(
        tester,
        MediaViewerPage(mediaList: items!, initialMediaId: 'p2'),
      );

      expect(find.byKey(const ValueKey('viewer_unlock')), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_species')), findsNothing);
      expect(find.byKey(const ValueKey('viewer_adjust_color')), findsNothing);
    });
  });

  group('unlocked', () {
    testWidgets('the bar is Cancel, "Editing photo", the actions and Save; '
        'Save is off with nothing changed', (tester) async {
      await pumpViewer(tester);
      await tapUnlock(tester);

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text('Editing photo'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_species')), findsOneWidget);
      final bar = tester.widget<RecordEditBar>(find.byType(RecordEditBar));
      expect(bar.canSave, isFalse);

      await change(tester);
      expect(
        tester.widget<RecordEditBar>(find.byType(RecordEditBar)).canSave,
        isTrue,
      );
    });

    testWidgets('unlocking moves nothing: the photo keeps its place', (
      tester,
    ) async {
      await pumpViewer(tester);
      final before = tester.getRect(find.byType(PhotoViewGallery));

      await tapUnlock(tester);

      expect(tester.getRect(find.byType(PhotoViewGallery)), before);
    });

    testWidgets('Cancel with changes asks; Keep editing keeps them', (
      tester,
    ) async {
      await pumpViewer(tester);
      await tapUnlock(tester);
      await change(tester);

      await tester.tap(find.text('Cancel'));
      await settleViewer(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await settleViewer(tester);

      expect(photoController(tester).isDirty, isTrue);
    });

    testWidgets('going back with changes asks; with none it locks and closes', (
      tester,
    ) async {
      await pumpPushed(tester);
      await tapUnlock(tester);
      await change(tester);

      await tester.binding.handlePopRoute();
      await settleViewer(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await settleViewer(tester);
      expect(find.byType(MediaViewerPage), findsOneWidget);

      photoController(tester).session!.set(photoPinField, null);
      await settleViewer(tester);
      await tester.binding.handlePopRoute();
      await settleViewer(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MediaViewerPage), findsNothing);
    });

    testWidgets('a swipe down with changes asks; with none it closes', (
      tester,
    ) async {
      await pumpPushed(tester);
      await tapUnlock(tester);
      await change(tester);

      await tester.fling(
        find.byType(PhotoViewGallery),
        const Offset(0, 400),
        1500,
      );
      await settleViewer(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await settleViewer(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MediaViewerPage), findsNothing);
    });

    testWidgets('Escape is Cancel: with changes asks, then locks; the viewer '
        'stays', (tester) async {
      await pumpPushed(tester);
      await tapUnlock(tester);
      await change(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleViewer(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await settleViewer(tester);

      expect(find.byType(MediaViewerPage), findsOneWidget);
      expect(find.byType(RecordEditBar), findsNothing);
    });

    testWidgets('Go to dive with changes asks; Discard locks and goes', (
      tester,
    ) async {
      final items = await tester.runAsync(() => storedMedia(['p1', 'p2']));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => MediaViewerPage(
              mediaList: items!,
              initialMediaId: 'p2',
              showGoToDive: true,
            ),
          ),
          GoRoute(
            path: '/dives/:id',
            builder: (_, _) => const Scaffold(body: Text('The dive')),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs!),
              mediaSourceResolverRegistryProvider.overrideWithValue(
                MediaSourceResolverRegistry({}),
              ),
              diveProvider('d1').overrideWith((ref) async => harnessDive),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
      });
      await settleViewer(tester);
      await tapUnlock(tester);
      final controller = photoController(tester);
      await change(tester);

      await tester.tap(find.byKey(const ValueKey('viewer_go_to_dive')));
      await settleViewer(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await settleViewer(tester);
      expect(find.text('The dive'), findsNothing);
      expect(controller.isDirty, isTrue);

      await tester.tap(find.byKey(const ValueKey('viewer_go_to_dive')));
      await settleViewer(tester);
      await tester.tap(find.text('Discard'));
      await settleViewer(tester);

      expect(find.text('The dive'), findsOneWidget);
      expect(controller.isUnlocked, isFalse);
    });

    testWidgets('next with changes asks; Discard steps and the next photo is '
        'locked', (tester) async {
      await pumpViewer(tester);
      await tapUnlock(tester);
      await change(tester);

      await tester.tap(find.byTooltip('Next media'));
      await settleViewer(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await settleViewer(tester, rounds: 10);

      expect(gallery(tester).pageController!.page, 2);
      expect(find.byType(RecordEditBar), findsNothing);
      expect(find.byKey(const ValueKey('viewer_unlock')), findsOneWidget);
    });

    testWidgets('next with no changes locks and steps', (tester) async {
      await pumpViewer(tester);
      await tapUnlock(tester);

      await tester.tap(find.byTooltip('Next media'));
      await settleViewer(tester, rounds: 10);

      expect(find.byType(AlertDialog), findsNothing);
      expect(gallery(tester).pageController!.page, 2);
      expect(find.byType(RecordEditBar), findsNothing);
    });

    testWidgets('a swipe does not page while unlocked', (tester) async {
      await pumpViewer(tester);
      await tapUnlock(tester);

      await tester.fling(
        find.byType(PhotoViewGallery),
        const Offset(-600, 0),
        2000,
      );
      await settleViewer(tester, rounds: 10);

      expect(gallery(tester).pageController!.page, 1);
      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets('a tap on the photo keeps the bar and the mini profile up; '
        'no fullscreen offered', (tester) async {
      await pumpViewer(tester);
      await tapUnlock(tester);
      photoController(tester).session!.set(photoPinField, 120);
      await settleViewer(tester);

      await tester.tapAt(const Offset(640, 400));
      await settleViewer(tester);

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.byTooltip('Full screen'), findsNothing);
      final profile = find.byType(PositionedMiniProfileOverlay);
      expect(
        tester.widget<PositionedMiniProfileOverlay>(profile).visible,
        isTrue,
      );
    });
  });

  group('the list changing under a sitting', () {
    testWidgets('a photo removed before the current one: the sitting stays on '
        'its photo', (tester) async {
      await pumpViewerApp(
        tester,
        const PhotoViewerPage(diveId: 'd1', initialMediaId: 'p2'),
      );
      await tapUnlock(tester);
      await change(tester);

      await tester.runAsync(() => MediaRepository().deleteMedia('p1'));
      await settleViewer(tester, rounds: 10);

      final controller = photoController(tester);
      expect(controller.isDirty, isTrue);
      expect(controller.session!.stored.item.id, 'p2');
      expect(gallery(tester).pageController!.page, 0);
    });

    testWidgets('the sitting\'s photo leaves the list but still exists: the '
        'sitting stays on it (Eric, 2026-11-16)', (tester) async {
      await pumpViewerApp(
        tester,
        const PhotoViewerPage(diveId: 'd1', initialMediaId: 'p2'),
      );
      await tapUnlock(tester);
      await change(tester);

      // A repository write, so the dive's list hears of it.
      await tester.runAsync(() => MediaRepository().unlinkFromDive(['p2']));
      await settleViewer(tester, rounds: 10);

      final controller = photoController(tester);
      expect(controller.isUnlocked, isTrue);
      expect(controller.isDirty, isTrue);
      expect(controller.session!.stored.item.id, 'p2');
      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(
        find.text('This photo was removed. Your changes were not saved.'),
        findsNothing,
      );
    });

    testWidgets('Next from a photo kept only by its sitting: the photo that '
        'took its place, none skipped', (tester) async {
      await tester.runAsync(
        () => insertTestMedia(
          id: 'p4',
          diveId: 'd1',
          takenAt: DateTime(2024, 1, 10, 9, 3),
        ),
      );
      await pumpViewerApp(
        tester,
        const PhotoViewerPage(diveId: 'd1', initialMediaId: 'p2'),
      );
      await tapUnlock(tester);
      await tester.runAsync(() => MediaRepository().unlinkFromDive(['p2']));
      await settleViewer(tester, rounds: 10);

      await tester.tap(find.byTooltip('Next media'));
      await settleViewer(tester, rounds: 10);

      // [p1, p3, p4] once the sitting ends: p3 is in p2's place.
      expect(find.byType(RecordEditBar), findsNothing);
      expect(gallery(tester).pageController!.page, 1);
    });

    testWidgets('the sitting\'s photo removed: the sitting ends with the '
        'message; nothing written', (tester) async {
      await pumpViewerApp(
        tester,
        const PhotoViewerPage(diveId: 'd1', initialMediaId: 'p2'),
      );
      await tapUnlock(tester);
      await change(tester);

      await tester.runAsync(() => MediaRepository().deleteMedia('p2'));
      final mark = (await tester.runAsync(() => eventCount(db)))!;
      await settleViewer(tester, rounds: 10);

      expect(
        find.text('This photo was removed. Your changes were not saved.'),
        findsOneWidget,
      );
      expect(find.byType(RecordEditBar), findsNothing);
      expect((await tester.runAsync(() => eventCount(db)))!, mark);
    });
  });

  group('species (Task 6)', () {
    testWidgets('tag, Save: the photo is tagged, the dive has the sighting, '
        'one History entry', (tester) async {
      await tester.runAsync(
        () =>
            insertTestSighting(id: 'sg1', diveId: 'd1', speciesId: 'sp_turtle'),
      );
      await pumpViewer(tester);
      await tapUnlock(tester);

      await tester.tap(find.byKey(const ValueKey('viewer_species')));
      await settleViewer(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Turtle'));
      await settleViewer(tester);
      final tags = await tester.runAsync(
        () => db.select(db.mediaSpecies).get(),
      );
      expect(tags, isEmpty, reason: 'held until Save');
      await tester.tapAt(const Offset(640, 20));
      await settleViewer(tester);

      await tester.tap(find.text('Save'));
      await settleViewer(tester, rounds: 10);

      final saved = (await tester.runAsync(
        () => db.select(db.mediaSpecies).get(),
      ))!;
      expect(saved.single.mediaId, 'p2');
      expect(saved.single.speciesId, 'sp_turtle');
      final sightings = (await tester.runAsync(
        () => db.select(db.sightings).get(),
      ))!;
      expect(sightings, hasLength(1));
      await tester.runAsync(() => ChangeLogRepository().settleAll());
      final ops = (await tester.runAsync(
        () => db
            .customSelect(
              'SELECT label FROM change_log_operations WHERE label IS NOT NULL',
            )
            .get(),
      ))!;
      expect(ops.map((r) => r.read<String?>('label')), [
        'record_edit:media:species',
      ]);
      expect(find.byType(RecordEditBar), findsNothing);
    });
  });

  group('time in the dive (Task 8)', () {
    Future<void> pinAt(WidgetTester tester, String text) async {
      await tester.tap(find.byIcon(Icons.timer_off_outlined));
      await settleViewer(tester);
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text('Save').last);
      await settleViewer(tester);
    }

    testWidgets('a pin moves the chip and the depth at once; nothing written '
        'until Save', (tester) async {
      await pumpViewer(tester);
      await tapUnlock(tester);

      await pinAt(tester, '2:00');

      expect(find.text('+2:00'), findsOneWidget);
      expect(find.text('12.0m'), findsOneWidget);
      final before = (await tester.runAsync(
        () => MediaRepository().getMediaById('p2'),
      ))!;
      expect(before.manualElapsedSeconds, isNull);

      await tester.tap(find.text('Save'));
      await settleViewer(tester, rounds: 10);

      final after = (await tester.runAsync(
        () => MediaRepository().getMediaById('p2'),
      ))!;
      expect(after.manualElapsedSeconds, 120);
    });

    testWidgets('the dialog reopened in the sitting starts at the held time', (
      tester,
    ) async {
      await pumpViewer(tester);
      await tapUnlock(tester);
      await pinAt(tester, '2:00');

      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await settleViewer(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '2:00',
      );
    });

    testWidgets('the sitting ending closes the dialog; nothing is written', (
      tester,
    ) async {
      await pumpViewer(tester);
      await tapUnlock(tester);
      await tester.tap(find.byIcon(Icons.timer_off_outlined));
      await settleViewer(tester);
      expect(find.byType(TextField), findsOneWidget);

      photoController(tester).lock();
      await settleViewer(tester);

      expect(find.byType(TextField), findsNothing);

      final after = (await tester.runAsync(
        () => MediaRepository().getMediaById('p2'),
      ))!;
      expect(after.manualElapsedSeconds, isNull);
      expect(photoController(tester).isUnlocked, isFalse);
    });

    testWidgets('locked: the info sheet offers no Set time', (tester) async {
      await pumpViewer(tester);

      await tester.tap(find.byKey(const ValueKey('viewer_info')));
      await settleViewer(tester);

      expect(find.text('Media info'), findsWidgets);
      expect(find.text('Set time in dive'), findsNothing);
      // The photo's own tags (#1970) are a change too.
      expect(find.byKey(const ValueKey('media_info_editTags')), findsNothing);
    });

    testWidgets('unlocked: the info sheet offers Edit tags', (tester) async {
      await pumpViewer(tester);
      await tapUnlock(tester);

      await tester.tap(find.byKey(const ValueKey('viewer_info')));
      await settleViewer(tester);

      expect(find.byKey(const ValueKey('media_info_editTags')), findsOneWidget);
    });
  });

  group('colour (Task 9)', () {
    MediaItem drawn(WidgetTester tester) => tester
        .widgetList<MediaItemView>(find.byType(MediaItemView))
        .map((v) => v.item)
        .firstWhere((item) => item.id == 'p2');

    Future<void> dragWarmth(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('viewer_adjust_color')));
      await settleViewer(tester);
      final slider = find.byKey(const Key('color_slider_warmth'));
      final gesture = await tester.startGesture(tester.getCenter(slider));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await settleViewer(tester);
    }

    testWidgets('a colour is drawn from the sitting, written only at Save', (
      tester,
    ) async {
      await pumpViewer(tester);
      await tapUnlock(tester);

      await dragWarmth(tester);

      expect(drawn(tester).colorAdjustment!.warmth, greaterThan(0));
      final before = (await tester.runAsync(
        () => MediaRepository().getMediaById('p2'),
      ))!;
      expect(before.colorAdjustment, isNull);

      await tester.tap(find.text('Save'));
      await settleViewer(tester, rounds: 10);

      final after = (await tester.runAsync(
        () => MediaRepository().getMediaById('p2'),
      ))!;
      expect(after.colorAdjustment!.warmth, greaterThan(0));
    });

    testWidgets('Cancel draws the stored colour again and closes the panel', (
      tester,
    ) async {
      await pumpViewer(tester);
      await tapUnlock(tester);
      await dragWarmth(tester);

      await tester.tap(find.text('Cancel'));
      await settleViewer(tester);
      await tester.tap(find.text('Discard'));
      await settleViewer(tester);

      expect(find.byType(ColorAdjustPanel), findsNothing);
      expect(drawn(tester).colorAdjustment, isNull);
    });
  });

  testWidgets('pushed over a record page in a sitting: Cancel here leaves that '
      'sitting open', (tester) async {
    final notes = EditField<Dive, String?>(
      id: 'notes',
      cardId: 'notes',
      read: (dive) => dive.notes,
      write: (dive, notes) => dive.copyWith(notes: notes),
    );
    final host = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(harnessDive);
    addTearDown(host.dispose);
    host.session!.set(notes, 'Calm');
    final items = await tester.runAsync(() => storedMedia(['p1', 'p2']));
    await pumpViewerApp(
      tester,
      RecordEditLeaveGuard<Dive>(
        controller: host,
        child: RecordEditScope<Dive>(
          controller: host,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MediaViewerPage(
                      mediaList: items!,
                      initialMediaId: 'p2',
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settleViewer(tester);
    await tapUnlock(tester);
    await change(tester);

    await tester.tap(find.text('Cancel'));
    await settleViewer(tester);
    await tester.tap(find.text('Discard'));
    await settleViewer(tester);
    await tester.binding.handlePopRoute();
    await settleViewer(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Open'), findsOneWidget);
    expect(host.isUnlocked, isTrue);
    expect(host.isDirty, isTrue);
    expect(photoControllerOrNull(tester), isNull, reason: 'the viewer is gone');
  });
}

RecordEditController<PhotoRecord>? photoControllerOrNull(WidgetTester tester) {
  final toolbars = find.byType(MediaViewerPage).evaluate();
  return toolbars.isEmpty ? null : photoController(tester);
}
