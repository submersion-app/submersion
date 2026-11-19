import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/core/services/shared_library/suggestion_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/site_marine_life_section.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/shared/widgets/record_editing/record_fold_pencil.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_reader_sitting.dart';

import '../../../../helpers/global_test_defaults.dart';
import 'site_detail_page_unlock_harness.dart';

/// A shared site library reader suggests changes from the site page itself
/// (issue #4527, phase 2, plan 5): the unlock reads "Suggest changes", and
/// the sitting is titled so and ends with Send.
void main() {
  final l = AppLocalizationsEn();
  const suggestKey = ValueKey('site_suggest_unlock');
  final librarySite = harnessSite.copyWith(
    diverId: 'other',
    sharedLibraryId: 'L',
  );

  /// The frames of the reader's own cards (notes, rating, attachments).
  Finder ownCard() => find.byWidgetPredicate(
    (w) =>
        w is RecordCardFrame<DiveSite> &&
        siteReaderPrivateCards.contains(w.card.id),
  );

  /// The page's editing controller, from one of its card frames.
  RecordEditController<DiveSite> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<DiveSite>(
        tester.element(find.byType(RecordCardFrame<DiveSite>).first),
      )!;

  /// The open sitting.
  EditSession<DiveSite> sitting(WidgetTester tester) =>
      controllerOf(tester).session!;

  /// The library's overrides, with [role] as the profile's role there.
  List<Override> library({
    Future<SharedLibraryRole> Function()? role,
    bool connected = true,
  }) => [
    libraryRoleProvider('L').overrideWith(
      (ref) => role?.call() ?? Future.value(SharedLibraryRole.reader),
    ),
    libraryConnectedHereProvider('L').overrideWith((ref) async => connected),
    siteLibraryStateProvider('s1').overrideWith((ref) async => null),
    libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
    currentMembershipProvider('L').overrideWith(
      (ref) async => const SharedLibraryMembership(
        id: 'm1',
        diverId: 'me',
        libraryId: 'L',
        memberId: 'mem1',
        displayName: 'Me',
        libraryName: 'Club',
        backendKind: 'folder',
      ),
    ),
  ];

  Future<SiteUnlockHarness> pumpReader(
    WidgetTester tester, {
    Future<SharedLibraryRole> Function()? role,
    bool connected = true,
    DiveSite? site,
  }) => pumpSitePage(
    tester,
    site: site ?? librarySite,
    extra: library(role: role, connected: connected),
  );

  testWidgets('a reader\'s unlock reads Suggest changes', (tester) async {
    await pumpReader(tester);

    expect(find.byKey(suggestKey), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    // The page's separate "Suggest changes" button is gone.
    expect(find.text(l.sharedLibrary_suggest_title), findsOneWidget);
  });

  testWidgets('the reader\'s bar is titled Suggest changes and saves with '
      'Send', (tester) async {
    await pumpReader(tester);
    await tester.tap(find.byKey(suggestKey));
    await tester.pumpAndSettle();

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.sharedLibrary_suggest_title), findsOneWidget);
    expect(find.text(l.sharedLibrary_suggest_send), findsOneWidget);
    expect(find.text(l.forms_save), findsNothing);
  });

  testWidgets('an editor sees the lock', (tester) async {
    await pumpReader(
      tester,
      role: () => Future.value(SharedLibraryRole.editor),
    );

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byKey(suggestKey), findsNothing);
  });

  testWidgets('a library not connected here offers no unlock', (tester) async {
    await pumpReader(tester, connected: false);

    expect(find.byKey(suggestKey), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.text(l.sharedLibrary_site_connectHere), findsOneWidget);
  });

  testWidgets('a role still loading offers no unlock yet', (tester) async {
    final never = Completer<SharedLibraryRole>();
    await pumpReader(tester, role: () => never.future);

    expect(find.byKey(suggestKey), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  // Review Focus 2: a reload (a sync) is not a lost right.
  testWidgets('a role that reloads keeps the reader\'s sitting', (
    tester,
  ) async {
    Completer<SharedLibraryRole>? reload;
    final page = await pumpReader(
      tester,
      role: () => reload?.future ?? Future.value(SharedLibraryRole.reader),
    );
    await tester.tap(find.byKey(suggestKey));
    await tester.pumpAndSettle();

    final waiting = reload = Completer<SharedLibraryRole>();
    page.container.invalidate(libraryRoleProvider('L'));
    await tester.pump();
    // While the role is read again the cards keep the reader's framing.
    expect(find.text(l.recordEdit_onlyYou), findsWidgets);
    waiting.complete(SharedLibraryRole.reader);
    await tester.pumpAndSettle();

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.diveSites_edit_editingWithdrawn), findsNothing);
  });

  // A reader's sitting whose role becomes editor's says so: Save, not Send.
  testWidgets('a reader\'s sitting whose role becomes editor\'s saves with '
      'Save', (tester) async {
    var role = SharedLibraryRole.reader;
    final page = await pumpReader(tester, role: () => Future.value(role));
    await tester.tap(find.byKey(suggestKey));
    await tester.pumpAndSettle();

    role = SharedLibraryRole.editor;
    page.container.invalidate(libraryRoleProvider('L'));
    await tester.pumpAndSettle();

    expect(find.text(l.forms_save), findsOneWidget);
    expect(find.text(l.sharedLibrary_suggest_send), findsNothing);
  });

  // The reader's own card keeps its place in the tree when the page's
  // framing changes, so an editor open in it is not torn down mid-word.
  testWidgets('a reader\'s own card is not rebuilt when the role becomes '
      'editor\'s', (tester) async {
    var role = SharedLibraryRole.reader;
    final page = await pumpReader(tester, role: () => Future.value(role));
    await tester.tap(find.byKey(suggestKey));
    await tester.pumpAndSettle();
    final id = tester
        .widget<RecordCardFrame<DiveSite>>(ownCard().first)
        .card
        .id;
    Element frameOf(String cardId) => tester.element(
      find.byWidgetPredicate(
        (w) => w is RecordCardFrame<DiveSite> && w.card.id == cardId,
      ),
    );
    final before = frameOf(id);

    role = SharedLibraryRole.editor;
    page.container.invalidate(libraryRoleProvider('L'));
    await tester.pumpAndSettle();

    expect(find.text(l.recordEdit_onlyYou), findsNothing);
    expect(identical(frameOf(id), before), isTrue);
  });

  // Question 2: an editor's sitting may hold changes a reader cannot send.
  testWidgets('an editor\'s sitting whose role drops to reader ends '
      'withdrawn', (tester) async {
    var role = SharedLibraryRole.editor;
    final page = await pumpReader(tester, role: () => Future.value(role));
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditBar), findsOneWidget);

    role = SharedLibraryRole.reader;
    page.container.invalidate(libraryRoleProvider('L'));
    await tester.pumpAndSettle();

    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text(l.diveSites_edit_editingWithdrawn), findsOneWidget);
  });

  /// A reader's sitting whose role becomes an editor's and then a
  /// reader's again, with [whileEditor] run in between.
  Future<void> editorInBetween(
    WidgetTester tester,
    void Function() whileEditor,
  ) async {
    var role = SharedLibraryRole.reader;
    final page = await pumpReader(tester, role: () => Future.value(role));
    await tester.tap(find.byKey(suggestKey));
    await tester.pumpAndSettle();
    role = SharedLibraryRole.editor;
    page.container.invalidate(libraryRoleProvider('L'));
    await tester.pumpAndSettle();
    whileEditor();
    await tester.pumpAndSettle();
    role = SharedLibraryRole.reader;
    page.container.invalidate(libraryRoleProvider('L'));
    await tester.pumpAndSettle();
  }

  // Question 2 for a reader's sitting that held an editor's role: a change
  // of the library's cards is not a reader's to send, so it is not kept.
  testWidgets('a reader\'s sitting holding a library card change ends '
      'withdrawn when its editor role drops', (tester) async {
    await editorInBetween(
      tester,
      () => sitting(tester).holdChange(
        'feature',
        cardId: SiteDetailSectionId.features.name,
        write: () async {},
      ),
    );

    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text(l.diveSites_edit_editingWithdrawn), findsOneWidget);
  });

  testWidgets('a reader\'s sitting with only its own changes goes on when '
      'its editor role drops', (tester) async {
    await editorInBetween(
      tester,
      () => sitting(tester).set(siteNotesField, 'Choppy'),
    );

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.diveSites_edit_editingWithdrawn), findsNothing);
  });

  // A library card opened while the profile could edit is drawn with no
  // editor once it cannot; left open it would hold the page's layout.
  testWidgets('a library card left open closes when the editor role drops', (
    tester,
  ) async {
    await editorInBetween(
      tester,
      () => controllerOf(tester).openCard(SiteDetailSectionId.features.name),
    );

    final controller = controllerOf(tester);
    expect(controller.isUnlocked, isTrue);
    expect(controller.openCardIds, isNot(contains('features')));
    expect(controller.layoutRecord, isNull);
  });

  group('the cards in a reader\'s sitting', () {
    Future<void> unlockReader(WidgetTester tester) async {
      await tester.tap(find.byKey(suggestKey));
      await tester.pumpAndSettle();
    }

    testWidgets('expected species fade as Library with no pencil', (
      tester,
    ) async {
      await pumpReader(tester);
      await unlockReader(tester);
      final species = find.byType(SiteMarineLifeSection);
      await tester.ensureVisible(species);
      await tester.pumpAndSettle();

      expect(find.text(l.recordEdit_library), findsWidgets);
      expect(
        find.descendant(
          of: find.ancestor(
            of: species,
            matching: find.byType(RecordCardFade<DiveSite>),
          ),
          matching: find.byType(RecordPencilIcon),
        ),
        findsNothing,
      );
    });

    testWidgets('notes say Only you and keep their pencil', (tester) async {
      await pumpReader(tester);
      await unlockReader(tester);

      expect(find.text(l.recordEdit_onlyYou), findsWidgets);
      expect(
        find.descendant(
          of: ownCard().first,
          matching: find.byType(RecordPencilIcon),
        ),
        findsWidgets,
      );
    });

    testWidgets('the strip offers no Library card', (tester) async {
      await pumpSitePage(
        tester,
        site: librarySite,
        settings: AppSettings(
          siteDetailSections: [
            for (final s in SiteDetailSectionConfig.defaultSections)
              s.id == SiteDetailSectionId.marineLife
                  ? s.copyWith(visible: false)
                  : s,
          ],
        ),
        extra: library(),
      );
      await unlockReader(tester);

      final strip = tester.widget<AddStrip>(find.byType(AddStrip));
      expect(
        strip.entries.map((e) => e.cardId),
        isNot(contains(SiteDetailSectionId.marineLife.name)),
      );
    });

    // In the list layout a folded card has a pencil of its own; the
    // library's cards are no reader's to open.
    testWidgets('the list layout\'s folded Library cards have no pencil', (
      tester,
    ) async {
      await pumpSitePage(
        tester,
        site: librarySite,
        settings: const AppSettings(siteDetailLayout: DiveDetailLayout.list),
        extra: library(),
      );
      await unlockReader(tester);

      final titles = tester
          .widgetList<RecordFoldPencil>(find.byType(RecordFoldPencil))
          .map((p) => p.title)
          .toSet();
      expect(
        titles,
        contains(SiteDetailSectionId.notes.localizedDisplayName(l)),
      );
      for (final id in siteReaderLibraryCards) {
        expect(
          titles,
          isNot(
            contains(
              SiteDetailSectionId.values.byName(id).localizedDisplayName(l),
            ),
          ),
        );
      }
    });

    testWidgets('an editor\'s sitting shows no Library or Only you', (
      tester,
    ) async {
      await pumpSitePage(tester);
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();

      expect(find.text(l.recordEdit_library), findsNothing);
      expect(find.text(l.recordEdit_onlyYou), findsNothing);
    });
  });

  // Send (plan 5): the role as stored decides, a note is asked only when
  // something goes to the owner, and Cancel writes and proposes nothing.
  group('Send', () {
    late _Suggestions suggestions;
    late _Store store;

    Future<SiteUnlockHarness> pumpSend(
      WidgetTester tester, {
      bool editorInStore = false,
      bool storeFails = false,
      bool proposalFails = false,
      bool libraryMissing = false,
      Completer<void>? storeGate,
      SharedLibraryRole shownRole = SharedLibraryRole.reader,
    }) {
      suggestions = _Suggestions(fails: proposalFails);
      return pumpSitePage(
        tester,
        site: librarySite,
        extra: [
          ...library(role: () => Future.value(shownRole)),
          suggestionServiceProvider.overrideWithValue(suggestions),
          sharedLibraryStoreProvider.overrideWithValue(
            store = _Store(
              editor: editorInStore,
              fails: storeFails,
              gate: storeGate,
              missing: libraryMissing,
            ),
          ),
        ],
      );
    }

    Future<void> unlockReader(WidgetTester tester) async {
      await tester.tap(find.byKey(suggestKey));
      await tester.pumpAndSettle();
    }

    Future<void> tapSend(WidgetTester tester) async {
      await tester.tap(find.text(l.sharedLibrary_suggest_send));
      await tester.pumpAndSettle();
    }

    testWidgets('Send asks for a note when something goes to the owner', (
      tester,
    ) async {
      final page = await pumpSend(tester);
      await unlockReader(tester);
      sitting(tester).set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();

      await tapSend(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Please',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.sharedLibrary_suggest_send),
        ),
      );
      await tester.pumpAndSettle();

      expect(suggestions.calls.single.note, 'Please');
      expect(suggestions.calls.single.proposed.name, 'Big Hole');
      expect(page.save.calls, isEmpty);
      expect(find.text(l.sharedLibrary_suggest_sent), findsOneWidget);
      // Sent, the sitting ends with nothing left to discard (the form's
      // case, plan 7).
      expect(find.byType(RecordEditBar), findsNothing);
      expect(find.text(l.forms_discard_title), findsNothing);
    });

    testWidgets('Send with only notes asks nothing and says saved privately', (
      tester,
    ) async {
      final page = await pumpSend(tester);
      await unlockReader(tester);
      sitting(tester).set(siteNotesField, 'Choppy');
      await tester.pumpAndSettle();

      await tapSend(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(page.save.calls.single.privateOnly, isTrue);
      expect(suggestions.calls, isEmpty);
      expect(find.text(l.sharedLibrary_suggest_savedPrivate), findsOneWidget);
    });

    testWidgets('cancelling the note dialog keeps the sitting', (tester) async {
      final page = await pumpSend(tester);
      await unlockReader(tester);
      sitting(tester).set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();

      await tapSend(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.common_action_cancel),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(page.save.calls, isEmpty);
      expect(suggestions.calls, isEmpty);
    });

    // Review Focus 4.
    testWidgets('Cancel writes nothing and proposes nothing', (tester) async {
      final page = await pumpSend(tester);
      await unlockReader(tester);
      sitting(tester)
        ..set(siteNotesField, 'Choppy')
        ..set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.forms_discard_discard));
      await tester.pumpAndSettle();

      expect(find.byType(RecordEditBar), findsNothing);
      expect(page.save.calls, isEmpty);
      expect(suggestions.calls, isEmpty);
    });

    // An editor's sitting is never a Send, whatever the store says at Save:
    // the save goes as an edit, which the save service refuses if the right
    // has gone, keeping the sitting.
    testWidgets('an editor\'s sitting is never sent', (tester) async {
      final page = await pumpSend(tester, shownRole: SharedLibraryRole.editor);
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();
      sitting(tester).set(siteNotesField, 'Choppy');
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.forms_save));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(page.save.calls.single.privateOnly, isFalse);
      expect(suggestions.calls, isEmpty);
    });

    // The second tap lands while the role is still being read from the
    // store, as it does against a real database.
    testWidgets('a second tap on Send asks once', (tester) async {
      final gate = Completer<void>();
      await pumpSend(tester, storeGate: gate);
      await unlockReader(tester);
      sitting(tester).set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.sharedLibrary_suggest_send));
      await tester.pump();
      await tester.tap(find.text(l.sharedLibrary_suggest_send));
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    // As the old form did: a demo profile is told so, and nothing is
    // written or proposed.
    testWidgets('in demo mode Send says so and sends nothing', (tester) async {
      final page = await pumpSend(tester);
      await unlockReader(tester);
      DemoModeGate.instance.debugActive = true;
      addTearDown(applyGlobalTestDefaults);
      sitting(tester)
        ..set(siteNotesField, 'Choppy')
        ..set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();

      await tapSend(tester);

      expect(find.text(l.demo_sealed_note), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(page.save.calls, isEmpty);
      expect(suggestions.calls, isEmpty);
      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    // A Send that did not go through keeps the sitting; the note the reader
    // wrote is offered again rather than lost.
    testWidgets('a failed Send keeps the note for the next one', (
      tester,
    ) async {
      await pumpSend(tester, proposalFails: true);
      await unlockReader(tester);
      sitting(tester).set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();
      final noteField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      final dialogSend = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l.sharedLibrary_suggest_send),
      );

      await tapSend(tester);
      await tester.enterText(noteField, 'The shops call it Big Hole');
      await tester.tap(dialogSend);
      await tester.pumpAndSettle();
      expect(find.text(l.recordEdit_saveFailed), findsOneWidget);

      await tapSend(tester);

      expect(
        tester.widget<TextField>(noteField).controller!.text,
        'The shops call it Big Hole',
      );
    });

    // An attempt refused before the dialog (here demo mode) leaves the kept
    // note for the Send after it.
    testWidgets('a refused attempt after a failed Send keeps the note', (
      tester,
    ) async {
      await pumpSend(tester, proposalFails: true);
      await unlockReader(tester);
      sitting(tester).set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();
      final noteField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tapSend(tester);
      await tester.enterText(noteField, 'The shops call it Big Hole');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.sharedLibrary_suggest_send),
        ),
      );
      await tester.pumpAndSettle();

      DemoModeGate.instance.debugActive = true;
      addTearDown(applyGlobalTestDefaults);
      await tapSend(tester);
      expect(find.byType(AlertDialog), findsNothing);
      DemoModeGate.instance.debugActive = false;
      await tapSend(tester);

      expect(
        tester.widget<TextField>(noteField).controller!.text,
        'The shops call it Big Hole',
      );
    });

    testWidgets('a proposal that fails after the notes are saved says so', (
      tester,
    ) async {
      final page = await pumpSend(tester, proposalFails: true);
      await unlockReader(tester);
      sitting(tester)
        ..set(siteNotesField, 'Choppy')
        ..set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();

      final noteField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tapSend(tester);
      await tester.enterText(noteField, 'The shops call it Big Hole');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.sharedLibrary_suggest_send),
        ),
      );
      await tester.pumpAndSettle();

      expect(page.save.calls.single.privateOnly, isTrue);
      expect(find.text(l.sharedLibrary_suggest_savedNotSent), findsOneWidget);
      // The sitting stays with the suggestion to send again; the notes,
      // saved, are not saved a second time.
      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(sitting(tester).changedCardIds, isNot(contains('notes')));
      await tapSend(tester);
      expect(
        tester.widget<TextField>(noteField).controller!.text,
        'The shops call it Big Hole',
      );
    });

    testWidgets('a role that cannot be read at Send says the save failed', (
      tester,
    ) async {
      final page = await pumpSend(tester, storeFails: true);
      await unlockReader(tester);
      sitting(tester).set(siteNotesField, 'Choppy');
      await tester.pumpAndSettle();

      await tapSend(tester);

      expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(page.save.calls, isEmpty);
    });

    // A library the store no longer has here gives no role: nothing is
    // written or proposed, and the sitting stays.
    testWidgets('a library gone from the store at Send saves nothing', (
      tester,
    ) async {
      final page = await pumpSend(tester, libraryMissing: true);
      await unlockReader(tester);
      sitting(tester)
        ..set(siteNotesField, 'Choppy')
        ..set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();

      await tapSend(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l.diveSites_edit_saveRefused), findsOneWidget);
      expect(page.save.calls, isEmpty);
      expect(suggestions.calls, isEmpty);
      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    // The note is the diver's to take their time over: the role as stored
    // once it is written decides.
    testWidgets('a role that becomes an editor\'s while the note is written '
        'saves as an edit', (tester) async {
      final page = await pumpSend(tester);
      await unlockReader(tester);
      sitting(tester).set(siteNameField, 'Big Hole');
      await tester.pumpAndSettle();

      await tapSend(tester);
      store.editor = true;
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.sharedLibrary_suggest_send),
        ),
      );
      await tester.pumpAndSettle();

      expect(page.save.calls.single.privateOnly, isFalse);
      expect(suggestions.calls, isEmpty);
    });

    testWidgets('a reader\'s sitting that finds the profile an editor at Send '
        'saves as an edit', (tester) async {
      final page = await pumpSend(tester, editorInStore: true);
      await unlockReader(tester);
      sitting(tester).set(siteNotesField, 'Choppy');
      await tester.pumpAndSettle();

      await tapSend(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(page.save.calls.single.privateOnly, isFalse);
      expect(suggestions.calls, isEmpty);
    });
  });
}

/// The library as stored, with this profile listed as an editor or not.
class _Store extends SharedLibraryStore {
  _Store({
    required this.editor,
    this.fails = false,
    this.gate,
    this.missing = false,
  });

  /// Whether this profile is listed as an editor, as stored now.
  bool editor;
  final bool fails;

  /// Whether the library is no longer connected here.
  final bool missing;

  /// While set and not completed, the read waits, as a slow store does.
  final Completer<void>? gate;

  @override
  Future<SharedLibrary?> getLibrary(String id) async {
    await gate?.future;
    if (fails) throw StateError('the library store is out of reach');
    return missing ? null : _library();
  }

  SharedLibrary _library() => SharedLibrary(
    id: 'L',
    name: 'Club',
    connectedAccountId: 'a',
    prefix: 'p',
    roles: SharedLibraryRoles(editors: editor ? {'mem1'} : const {}),
  );

  @override
  Future<SharedLibraryMembership?> membership({
    required String diverId,
    required String libraryId,
  }) async => const SharedLibraryMembership(
    id: 'm1',
    diverId: 'me',
    libraryId: 'L',
    memberId: 'mem1',
    displayName: 'Me',
    libraryName: 'Club',
    backendKind: 'folder',
  );
}

/// Records each proposal.
class _Suggestions extends Fake implements SuggestionService {
  _Suggestions({this.fails = false});

  /// Whether each proposal fails, as one the store refused does.
  final bool fails;

  final calls = <({DiveSite proposed, String note})>[];

  @override
  Future<SharedSiteSuggestion?> propose({
    required DiveSite proposed,
    required String diverId,
    String note = '',
    Map<String, Object?> childFields = const {},
  }) async {
    if (fails) throw StateError('the store refused the suggestion');
    calls.add((proposed: proposed, note: note));
    return SharedSiteSuggestion(
      id: 'g1',
      libraryId: 'L',
      siteId: proposed.id,
      memberId: 'mem1',
      memberName: 'Me',
      note: note,
      fields: const {'name': 'x'},
      createdAt: DateTime.utc(2026),
      direction: SharedSiteSuggestion.outgoing,
    );
  }
}
