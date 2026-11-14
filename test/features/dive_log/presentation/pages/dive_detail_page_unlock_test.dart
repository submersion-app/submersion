import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_edit_save_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Stands in for the save service: applies the sitting to [stored] and
/// records what it was asked to write, or fails on demand.
class _FakeSave implements DiveEditSaveService {
  _FakeSave(this.stored);

  Dive stored;
  Object? failWith;
  final calls = <({Dive merged, List<String> cards})>[];

  @override
  Future<({Dive before, Dive after})?> save({
    required String diveId,
    required Dive Function(Dive stored) apply,
    required Iterable<String> changedCardIds,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    final before = stored;
    final merged = apply(before);
    calls.add((merged: merged, cards: changedCardIds.toList()));
    stored = merged;
    return (before: before, after: merged);
  }
}

/// The dive page unlocked for editing in place (issue #4527), behind the
/// build switch.
void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2023, 1, 1),
    notes: 'Calm',
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  /// Pumps the page on top of a home route, with only Tags and Notes shown
  /// so both are on screen, and returns the router and the fake service.
  Future<({GoRouter router, _FakeSave save})> pumpPage(
    WidgetTester tester, {
    bool unlockEditing = true,
    bool embedded = false,
    Size size = const Size(700, 1000),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final save = _FakeSave(dive);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        AppSettings(
          hasAcceptedPlanningDisclaimer: true,
          diveDetailSections: [
            for (final id in DiveDetailSectionId.values)
              DiveDetailSectionConfig(
                id: id,
                visible:
                    id == DiveDetailSectionId.tags ||
                    id == DiveDetailSectionId.notes,
              ),
          ],
        ),
      ),
    );
    final router = GoRouter(
      initialLocation: '/home/dive',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('HOME')),
          routes: [
            GoRoute(
              path: 'dive',
              builder: (context, state) => DiveDetailPage(
                diveId: dive.id,
                embedded: embedded,
                unlockEditing: unlockEditing,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) =>
              Scaffold(body: Text('OTHER ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          // Reads the fake's dive, so a save shows on the page as it would
          // from the database.
          diveProvider(dive.id).overrideWith((ref) async => save.stored),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          diveNeighborsProvider(
            dive.id,
          ).overrideWith((ref) => (previousId: null, nextId: 'dive-2')),
          diveEditSaveServiceProvider.overrideWithValue(save),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return (router: router, save: save);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Unlock to edit'));
    await settle(tester);
  }

  Future<void> openNotes(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Edit Notes'));
    await settle(tester);
  }

  AppBarTextAction action(WidgetTester tester, String label) =>
      tester.widget<AppBarTextAction>(
        find.byWidgetPredicate(
          (w) => w is AppBarTextAction && w.label == label,
        ),
      );

  String location(GoRouter router) => router.state.uri.toString();

  testWidgets('switch off: the page has no lock', (tester) async {
    await pumpPage(tester, unlockEditing: false);

    expect(find.text('Calm'), findsOneWidget);
    expect(find.byTooltip('Unlock to edit'), findsNothing);
  });

  testWidgets('in the list pane the page has no lock yet', (tester) async {
    await pumpPage(tester, embedded: true, size: const Size(1200, 900));

    expect(find.byTooltip('Unlock to edit'), findsNothing);
  });

  testWidgets('unlock swaps the bar and moves nothing in the page', (
    tester,
  ) async {
    await pumpPage(tester);
    // The page's own scroll view, not the Add strip's sideways one. The
    // strip sits above it, so what must not move is the page inside it.
    final scroll = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
    );
    Offset notesInScroll() =>
        tester.getTopLeft(find.text('Calm')) - tester.getTopLeft(scroll);
    final before = notesInScroll();
    expect(find.byType(DiveNavButtons), findsOneWidget);

    await unlock(tester);

    expect(find.text('Cancel'), findsOneWidget);
    expect(action(tester, 'Save').onPressed, isNull);
    expect(find.byTooltip('Unlock to edit'), findsNothing);
    expect(find.byType(DiveNavButtons), findsNothing);
    expect(find.byTooltip('Edit Notes'), findsOneWidget);
    expect(notesInScroll(), before);
  });

  testWidgets('the strip offers Tags for a dive with none', (tester) async {
    await pumpPage(tester);
    expect(find.byKey(const ValueKey('addStrip_tags')), findsNothing);

    await unlock(tester);

    expect(find.byKey(const ValueKey('addStrip_tags')), findsOneWidget);
    expect(find.byKey(const ValueKey('addStrip_notes')), findsNothing);
  });

  testWidgets('a note edit is saved and the page locks', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Calm, then current',
    );
    await settle(tester);
    expect(action(tester, 'Save').onPressed, isNotNull);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(page.save.calls.single.merged.notes, 'Calm, then current');
    expect(page.save.calls.single.cards, ['notes']);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(find.text('Calm, then current'), findsOneWidget);
  });

  testWidgets('typing a change and typing it back disables Save again', (
    tester,
  ) async {
    await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    final field = find.descendant(
      of: find.byType(MarkdownNotesField),
      matching: find.byType(TextField),
    );

    await tester.enterText(field, 'Calm!');
    await settle(tester);
    expect(action(tester, 'Save').onPressed, isNotNull);

    await tester.enterText(field, 'Calm');
    await settle(tester);

    expect(action(tester, 'Save').onPressed, isNull);
  });

  testWidgets('Cancel with changes asks, and Discard leaves the dive alone', (
    tester,
  ) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Something else',
    );
    await settle(tester);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(page.save.calls, isEmpty);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Something else'), findsNothing);
  });

  testWidgets('Cancel with no changes locks at once', (tester) async {
    await pumpPage(tester);
    await unlock(tester);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
  });

  testWidgets('a card added from the strip and cancelled leaves no trace', (
    tester,
  ) async {
    final page = await pumpPage(tester);
    await unlock(tester);

    await tester.tap(find.byKey(const ValueKey('addStrip_tags')));
    await settle(tester);
    expect(find.byType(TagFormBlock), findsOneWidget);
    expect(find.byKey(const ValueKey('addStrip_tags')), findsNothing);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.byType(TagFormBlock), findsNothing);
    expect(page.save.calls, isEmpty);

    await unlock(tester);
    expect(find.byKey(const ValueKey('addStrip_tags')), findsOneWidget);
  });

  testWidgets('back with changes asks before leaving', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Something else',
    );
    await settle(tester);

    // The system back gesture.
    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(location(page.router), '/home/dive');

    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(find.text('Something else'), findsOneWidget);
  });

  testWidgets('a failed save stays unlocked and says so', (tester) async {
    final semantics = tester.ensureSemantics();
    final page = await pumpPage(tester);
    page.save.failWith = StateError('gone');
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Something else',
    );
    await settle(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Something else'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Unsaved changes')), findsOneWidget);
    expect(action(tester, 'Save').onPressed, isNotNull);

    semantics.dispose();
  });

  testWidgets('a stored change mid-sitting reaches an untouched card', (
    tester,
  ) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await tester.tap(find.byKey(const ValueKey('addStrip_tags')));
    await settle(tester);

    // A sync changes the notes underneath while the diver is on Tags.
    page.save.stored = dive.copyWith(notes: 'From another device');
    ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).invalidate(diveProvider(dive.id));
    await settle(tester);

    expect(find.text('From another device'), findsOneWidget);
    expect(find.text('Calm'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget, reason: 'still unlocked');
    expect(find.byType(TagFormBlock), findsOneWidget, reason: 'card kept');
  });

  testWidgets('the arrow keys change dive only while locked', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(location(page.router), '/home/dive');

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);

    expect(location(page.router), '/dives/dive-2');
  });
}
