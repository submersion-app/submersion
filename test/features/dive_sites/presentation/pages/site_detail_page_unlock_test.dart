import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_editing_page_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_fold_pencil.dart';

import 'site_detail_page_unlock_harness.dart';

/// A site's page unlocks to edit Description and Notes in place, behind
/// the switch (issue #4527, phase 2, plan 1).
void main() {
  final l = AppLocalizationsEn();

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openNotes(WidgetTester tester) async {
    await tester.ensureVisible(find.text(l.diveSites_detail_section_notes));
    await tester.tap(find.text(l.diveSites_detail_section_notes));
    await tester.pumpAndSettle();
  }

  Future<void> typeNotes(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextFormField).last, text);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  List<SiteDetailSectionConfig> hideNotes() => [
    for (final s in SiteDetailSectionConfig.defaultSections)
      s.id == SiteDetailSectionId.notes ? s.copyWith(visible: false) : s,
  ];

  testWidgets('with the switch off there is no lock', (tester) async {
    final page = await pumpSitePage(tester, unlockEditing: false);

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byTooltip(l.diveSites_detail_editTooltip), findsOneWidget);
    expect(
      page.container.read(recordEditShortcutTargetsProvider).current,
      isNull,
    );
  });

  // A file dropped on the window finds the page: locked, it has no
  // sitting; unlocked, the sitting a drop is held in (issue #4527).
  testWidgets('the page tells a drop whether the site is unlocked', (
    tester,
  ) async {
    final page = await pumpSitePage(tester);
    SiteEditingPage? told() => page.container.read(siteEditingPageProvider);
    expect(told()?.siteId, 's1');
    expect(told()?.session, isNull);

    await unlock(tester);
    expect(told()?.session, isNotNull);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
    expect(told()?.session, isNull);
  });

  testWidgets('with the switch off a drop finds no page', (tester) async {
    final page = await pumpSitePage(tester, unlockEditing: false);
    expect(page.container.read(siteEditingPageProvider), isNull);
  });

  testWidgets('locked shows no pencil', (tester) async {
    await pumpSitePage(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
  });

  testWidgets('unlocking titles the bar and marks the editable cards', (
    tester,
  ) async {
    await pumpSitePage(tester);
    await unlock(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.recordEdit_editingTitle('Blue Hole')), findsOneWidget);
    // The header block, Description, Location and Notes each have one.
    for (final title in [
      l.diveSites_detail_section_header,
      l.diveSites_detail_section_description,
      l.diveSites_detail_section_location,
      l.diveSites_detail_section_notes,
    ]) {
      expect(
        find.byTooltip(l.recordEdit_editCardTooltip(title)),
        findsOneWidget,
        reason: title,
      );
    }
  });

  testWidgets('the old edit form cannot be opened over an open sitting', (
    tester,
  ) async {
    // The app bar's button to the form, not a card's pencil.
    final oldEdit = find.descendant(
      of: find.byType(AppBar),
      matching: find.widgetWithIcon(IconButton, Icons.edit),
    );
    await pumpSitePage(tester);
    expect(oldEdit, findsOneWidget);

    await unlock(tester);

    // The form would save over the sitting: not offered while it is open.
    expect(oldEdit, findsNothing);
  });

  testWidgets('editing Notes and saving writes one sitting and locks', (
    tester,
  ) async {
    final page = await pumpSitePage(tester);
    await unlock(tester);
    await openNotes(tester);
    await typeNotes(tester, 'Choppy');

    await save(tester);

    expect(page.save.calls, hasLength(1));
    final call = page.save.calls.single;
    expect(call.cards, ['notes']);
    expect(call.actingDiverId, 'me');
    expect(call.apply(page.stored).notes, 'Choppy');
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Choppy'), findsOneWidget);
  });

  testWidgets('a failed save stays unlocked and says so', (tester) async {
    final page = await pumpSitePage(tester);
    page.save.failWith = StateError('the save failed');
    await unlock(tester);
    await openNotes(tester);
    await typeNotes(tester, 'Choppy');

    await save(tester);

    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Choppy'), findsWidgets);
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpSitePage(tester);
    await unlock(tester);
    await openNotes(tester);
    await typeNotes(tester, 'Choppy');

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Calm'), findsOneWidget);
  });

  testWidgets('a rename underneath keeps the notes being edited', (
    tester,
  ) async {
    final page = await pumpSitePage(tester);
    await unlock(tester);
    await openNotes(tester);
    await typeNotes(tester, 'Choppy');

    page.store(page.stored.copyWith(name: 'Pond'));
    await tester.pumpAndSettle();

    expect(find.text('Pond'), findsWidgets);
    await save(tester);
    final merged = page.save.calls.single.apply(page.stored);
    expect(merged.name, 'Pond');
    expect(merged.notes, 'Choppy');
  });

  testWidgets(
    'a hidden Notes card is offered in the strip, and hidden again after Save',
    (tester) async {
      await pumpSitePage(
        tester,
        settings: AppSettings(siteDetailSections: hideNotes()),
      );
      expect(find.text('Calm'), findsNothing);
      await unlock(tester);

      expect(find.byType(AddStrip), findsOneWidget);
      final chip = find.descendant(
        of: find.byType(AddStrip),
        matching: find.text(l.diveSites_detail_section_notes),
      );
      expect(chip, findsOneWidget);
      // The strip scrolls: empty cards are offered beside the hidden one.
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      await typeNotes(tester, 'Choppy');
      await save(tester);

      expect(find.byType(RecordEditBar), findsNothing);
      expect(find.text('Choppy'), findsNothing);
    },
  );

  testWidgets(
    'in the list layout the fold row has the pencil and opening unfolds it',
    (tester) async {
      final page = await pumpSitePage(
        tester,
        settings: const AppSettings(siteDetailLayout: DiveDetailLayout.list),
      );
      final foldedBefore = page.settings.state.siteDetailSections;
      await unlock(tester);

      // Every card with an editor has a pencil on its folded row.
      expect(find.byType(RecordFoldPencil), findsWidgets);
      final notesPencil = find.byTooltip(
        l.recordEdit_editCardTooltip(l.diveSites_detail_section_notes),
      );
      expect(notesPencil, findsOneWidget);
      await tester.ensureVisible(notesPencil);
      await tester.tap(notesPencil);
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(page.settings.state.siteDetailSections, foldedBefore);
    },
  );

  testWidgets('the pane offers no lock yet', (tester) async {
    await pumpSitePage(tester, embedded: true);

    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('a library site this profile only reads offers no lock', (
    tester,
  ) async {
    final page = await pumpSitePage(
      tester,
      site: harnessSite.copyWith(sharedLibraryId: 'L'),
      extra: [
        libraryRoleProvider(
          'L',
        ).overrideWith((ref) async => SharedLibraryRole.reader),
        libraryConnectedHereProvider('L').overrideWith((ref) async => true),
        siteLibraryStateProvider('s1').overrideWith((ref) async => null),
        libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
      ],
    );

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    // Nor do the editing keys act on it.
    expect(
      page.container.read(recordEditShortcutTargetsProvider).current,
      isNull,
    );
  });

  // A reload of the role or the connection (a library's details changing,
  // a sync) is not a loss of the right to edit: only a settled answer that
  // says so ends the sitting.
  for (final fails in [false, true]) {
    testWidgets('a role that reloads${fails ? ' and fails' : ''} keeps the '
        'sitting', (tester) async {
      Completer<SharedLibraryRole>? reload;
      final page = await pumpSitePage(
        tester,
        site: harnessSite.copyWith(sharedLibraryId: 'L'),
        extra: [
          libraryRoleProvider('L').overrideWith(
            (ref) => reload?.future ?? Future.value(SharedLibraryRole.editor),
          ),
          libraryConnectedHereProvider('L').overrideWith((ref) async => true),
          siteLibraryStateProvider('s1').overrideWith((ref) async => null),
          libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
        ],
      );
      await unlock(tester);
      await openNotes(tester);
      await typeNotes(tester, 'Choppy');

      final waiting = reload = Completer<SharedLibraryRole>();
      page.container.invalidate(libraryRoleProvider('L'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(RecordEditBar), findsOneWidget);

      if (fails) {
        waiting.completeError(StateError('offline'));
      } else {
        waiting.complete(SharedLibraryRole.editor);
      }
      await tester.pumpAndSettle();

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text(l.diveSites_edit_editingWithdrawn), findsNothing);
      expect(find.text('Choppy'), findsWidgets);
    });
  }

  testWidgets('losing the right to edit during a sitting locks the page', (
    tester,
  ) async {
    var role = SharedLibraryRole.editor;
    final page = await pumpSitePage(
      tester,
      site: harnessSite.copyWith(sharedLibraryId: 'L'),
      extra: [
        libraryRoleProvider('L').overrideWith((ref) async => role),
        libraryConnectedHereProvider('L').overrideWith((ref) async => true),
        siteLibraryStateProvider('s1').overrideWith((ref) async => null),
        libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
      ],
    );
    await unlock(tester);
    await openNotes(tester);
    await typeNotes(tester, 'Choppy');

    role = SharedLibraryRole.reader;
    page.container.invalidate(libraryRoleProvider('L'));
    await tester.pumpAndSettle();

    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.text('Calm'), findsOneWidget);
    expect(page.save.calls, isEmpty);
    // The diver is told why the page locked and the typing went.
    expect(find.text(l.diveSites_edit_editingWithdrawn), findsOneWidget);
    // Nothing is left open to ask about on the way out.
    final leaving = page.container.read(appExitGuardProvider).mayLeave();
    await tester.pumpAndSettle();
    expect(find.text(l.forms_discard_title), findsNothing);
    expect(await leaving, isTrue);
  });
}
