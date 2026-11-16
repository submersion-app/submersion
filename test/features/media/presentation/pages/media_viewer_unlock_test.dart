import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
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
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';

import '../../../../helpers/test_database.dart';
import 'media_viewer_unlock_harness.dart';

/// The photo viewer's own lock (issue #4527, plan 10).
void main() {
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
                builder: (_) => MediaViewerPage(
                  mediaList: items!,
                  initialMediaId: initial,
                  unlockEditing: true,
                ),
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
              const PhotoViewerPage(
                diveId: 'd1',
                initialMediaId: 'p2',
                unlockEditing: true,
              ),
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
        MediaViewerPage(
          mediaList: [held],
          initialMediaId: 'not-stored',
          unlockEditing: true,
        ),
      );

      expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
    });

    testWidgets('a read-only device offers no unlock', (tester) async {
      await pumpViewer(tester, browser: true);

      expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
    });

    testWidgets('switch off: no lock, and every write action as today', (
      tester,
    ) async {
      await pumpViewer(tester, unlockEditing: false);

      expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
      expect(find.byKey(const ValueKey('viewer_species')), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_adjust_color')), findsOneWidget);
      expect(find.byTooltip('Close photo viewer'), findsOneWidget);
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
              unlockEditing: true,
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

    testWidgets('a tap on the photo keeps the bar up; no fullscreen offered', (
      tester,
    ) async {
      await pumpViewer(tester);
      await tapUnlock(tester);

      await tester.tapAt(const Offset(640, 400));
      await settleViewer(tester);

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.byTooltip('Full screen'), findsNothing);
    });
  });

  group('the list changing under a sitting', () {
    testWidgets('a photo removed before the current one: the sitting stays on '
        'its photo', (tester) async {
      await pumpViewerApp(
        tester,
        const PhotoViewerPage(
          diveId: 'd1',
          initialMediaId: 'p2',
          unlockEditing: true,
        ),
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

    testWidgets('the sitting\'s photo removed: the sitting ends with the '
        'message; nothing written', (tester) async {
      await pumpViewerApp(
        tester,
        const PhotoViewerPage(
          diveId: 'd1',
          initialMediaId: 'p2',
          unlockEditing: true,
        ),
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
                      unlockEditing: true,
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
