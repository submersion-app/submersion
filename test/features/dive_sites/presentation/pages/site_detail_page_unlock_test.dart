import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/media/data/services/photo_edit_save_service.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/pages/document_viewer_page.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_header.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_editing_page_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_fold_pencil.dart';

import 'site_detail_page_unlock_harness.dart';

/// Records each run of the rules.
class _RecordingRules extends Fake implements RuleEngine {
  final requests = <RuleRunRequest>[];

  @override
  Future<RuleRunResult> run(RuleRunRequest request) async {
    requests.add(request);
    throw StateError('no rules here');
  }
}

/// A site's page unlocks to edit Description and Notes in place (issue
/// #4527, phase 2, plan 1).
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

  // The old edit address opens the page unlocked (issue #4527, phase 2).
  group('opened unlocked', () {
    testWidgets('with mode=edit the page is unlocked, and its end is told', (
      tester,
    ) async {
      var ended = 0;
      await pumpSitePage(
        tester,
        openUnlocked: true,
        onSittingEnded: () => ended++,
      );
      expect(find.byType(RecordEditBar), findsOneWidget);

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();

      expect(find.byType(RecordEditBar), findsNothing);
      expect(ended, 1);
    });

    // On a desktop window a root visit moves into the list pane: an edit
    // address arrives there still asking for edit mode, once.
    testWidgets('on desktop, mode=edit moves into the pane still asking to '
        'unlock', (tester) async {
      final page = await pumpSitePage(
        tester,
        openUnlocked: true,
        size: const Size(1400, 1000),
        initialLocation: '/root-site',
      );

      final landed = page.router!.routerDelegate.currentConfiguration.uri;
      expect(landed.path, '/sites');
      expect(landed.queryParameters['selected'], 's1');
      expect(landed.queryParameters['mode'], 'edit');
    });
  });

  // A window widened during a sitting keeps the page, and the sitting,
  // until it ends: the move into the pane would drop what is being edited.
  testWidgets('a window widened during a sitting moves into the pane only '
      'once it ends', (tester) async {
    final page = await pumpSitePage(tester, initialLocation: '/root-site');
    await unlock(tester);
    await openNotes(tester);
    await typeNotes(tester, 'Choppy');

    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    final router = page.router!.routerDelegate;
    expect(router.currentConfiguration.uri.path, '/root-site');
    expect(find.text('Choppy'), findsOneWidget);

    await save(tester);

    expect(page.save.calls, hasLength(1));
    final landed = router.currentConfiguration.uri;
    expect(landed.path, '/sites');
    expect(landed.queryParameters['selected'], 's1');
    expect(landed.queryParameters.containsKey('mode'), isFalse);
  });

  // An edit link on a site this profile only reads opens the reader's
  // sitting (plan 5): suggesting, never editing, and not withdrawn.
  testWidgets('a reader asked to open unlocked opens a reader\'s sitting', (
    tester,
  ) async {
    await pumpSitePage(
      tester,
      openUnlocked: true,
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

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.sharedLibrary_suggest_send), findsOneWidget);
    expect(find.text(l.diveSites_edit_editingWithdrawn), findsNothing);
  });

  // History beside the lock where the bar has room, else in the menu, as
  // on a dive (issue #4527).
  group('History', () {
    final inBar = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip(l.changeLog_history),
    );

    testWidgets('sits beside the lock on a wide window', (tester) async {
      await pumpSitePage(tester, size: const Size(900, 1400));
      expect(inBar, findsOneWidget);
    });

    testWidgets('is in the menu on a narrow window', (tester) async {
      await pumpSitePage(tester, size: const Size(400, 1400));
      expect(inBar, findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.changeLog_history), findsOneWidget);
    });
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

  // Unlocked at the top of a page taller than the screen, the Add strip
  // pushes the page down rather than lie over the header card, whose
  // pencil sits in its first row (issue #4756).
  testWidgets('unlocked at the top, the Add strip leaves the header pencil '
      'in view', (tester) async {
    await pumpSitePage(tester, size: const Size(600, 300));
    // The page scrolls: one that fits was always pushed down.
    // The page's own scroll view, not a sideways one such as the strip's.
    final page = tester
        .state<ScrollableState>(
          find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        )
        .position;
    expect(page.maxScrollExtent, greaterThan(0));
    await unlock(tester);

    final strip = tester.getRect(find.byType(AddStrip));
    expect(strip.height, greaterThan(0));
    final pencil = tester.getRect(
      find.byTooltip(
        l.recordEdit_editCardTooltip(l.diveSites_detail_section_header),
      ),
    );
    expect(page.pixels, page.minScrollExtent);
    expect(
      tester.getTopLeft(find.byType(SiteDetailHeader)).dy,
      greaterThanOrEqualTo(strip.bottom),
    );
    expect(pencil.top, greaterThanOrEqualTo(strip.bottom));
  });

  // The lock is the one way in (issue #4527, phase 2, plan 7): no Edit
  // pencil beside it on the bar.
  testWidgets('the locked bar has the lock and no Edit pencil', (tester) async {
    await pumpSitePage(tester);

    final bar = find.byType(AppBar);
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.lock_outline)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.widgetWithIcon(IconButton, Icons.edit),
      ),
      findsNothing,
    );
  });

  // Review Focus 1: an old edit address, bookmarked before the site was
  // deleted, finds the page's not-found state, with no sitting to open.
  testWidgets('an old edit address for a deleted site shows not found, '
      'locked', (tester) async {
    await pumpSitePage(
      tester,
      initialLocation: '/sites/gone/edit',
      extra: [siteProvider('gone').overrideWith((_) async => null)],
    );

    expect(find.text(l.diveSites_detail_siteNotFound_title), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  // The old edit address opens the stored site unlocked.
  testWidgets('an old edit address opens the site unlocked', (tester) async {
    final page = await pumpSitePage(tester, initialLocation: '/sites/s1/edit');

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(
      page.router!.routerDelegate.currentConfiguration.uri.toString(),
      '/sites/s1?mode=edit',
    );
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

  // A site's logbook rules run once, when it is created (#3513); saving a
  // stored site runs none (the form's case, plan 7).
  testWidgets('saving a stored site runs no rules', (tester) async {
    final rules = _RecordingRules();
    final page = await pumpSitePage(
      tester,
      extra: [ruleEngineProvider.overrideWithValue(rules)],
    );
    await unlock(tester);
    await openNotes(tester);
    await typeNotes(tester, 'Choppy');

    await save(tester);

    expect(page.save.calls, hasLength(1));
    expect(rules.requests, isEmpty);
  });

  // Review Focus 2 of plan 4b: an attachment's lock is its own, so a PDF
  // opened from the site being edited, and closed, leaves the site's
  // sitting as it was (issue #4527, phase 2).
  testWidgets('opening a PDF from the site being edited keeps its sitting', (
    tester,
  ) async {
    final at = DateTime.utc(2026);
    final pdf = MediaItem(
      id: 'p1',
      siteId: 's1',
      mediaType: MediaType.document,
      originalFilename: 'reef-map.pdf',
      takenAt: at,
      createdAt: at,
      updatedAt: at,
    );
    await pumpSitePage(
      tester,
      extra: [
        mediaForSiteProvider('s1').overrideWith((_) async => [pdf]),
        mediaBytesProvider(pdf).overrideWith(
          (_) async =>
              const ResolvedAssetResult(status: ResolutionStatus.unavailable),
        ),
        photoRecordProvider('p1').overrideWith(
          (_) async =>
              PhotoRecord(item: pdf, species: const [], people: const []),
        ),
      ],
    );
    await unlock(tester);
    await openNotes(tester);
    await typeNotes(tester, 'Choppy');

    await tester.ensureVisible(find.byType(MediaThumbnailTile));
    await tester.tap(find.byType(MediaThumbnailTile));
    await tester.pumpAndSettle();
    final viewer = tester.widget<DocumentViewerPage>(
      find.byType(DocumentViewerPage),
    );
    expect(viewer.editableSiteId, isNotNull);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentViewerPage), findsNothing);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Choppy'), findsWidgets);
  });

  // The attachment's own Save, made while the site is being edited, writes
  // the attachment alone: the site's sitting carries on.
  testWidgets(
    'saving the details of a PDF from the site being edited keeps its '
    'sitting',
    (tester) async {
      final at = DateTime.utc(2026);
      final pdf = MediaItem(
        id: 'p1',
        siteId: 's1',
        mediaType: MediaType.document,
        originalFilename: 'reef-map.pdf',
        takenAt: at,
        createdAt: at,
        updatedAt: at,
      );
      final saves = <Iterable<String>>[];
      final page = await pumpSitePage(
        tester,
        extra: [
          mediaForSiteProvider('s1').overrideWith((_) async => [pdf]),
          mediaBytesProvider(pdf).overrideWith(
            (_) async =>
                const ResolvedAssetResult(status: ResolutionStatus.unavailable),
          ),
          photoRecordProvider('p1').overrideWith(
            (_) async =>
                PhotoRecord(item: pdf, species: const [], people: const []),
          ),
          photoEditSaveServiceProvider.overrideWithValue(
            _RecordingPhotoSave(saves),
          ),
        ],
      );
      await unlock(tester);
      await openNotes(tester);
      await typeNotes(tester, 'Choppy');
      await tester.ensureVisible(find.byType(MediaThumbnailTile));
      await tester.tap(find.byType(MediaThumbnailTile));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('document_unlock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uncategorized').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Site map').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // The viewer's Save, in its own bar, over the site's.
      await tester.tap(find.text(l.forms_save).last);
      await tester.pumpAndSettle();
      // The attachment's own save, refused if it has left the site since.
      expect(saves.single, ['details', 'site:s1']);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text('Choppy'), findsWidgets);
      expect(page.save.calls, isEmpty);
    },
  );

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

  testWidgets('the pane offers the lock', (tester) async {
    await pumpSitePage(tester, embedded: true);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  // A reader's is "Suggest changes" (plan 5), and the editing keys act on
  // it as on an editor's.
  testWidgets('a library site this profile only reads offers the reader\'s '
      'unlock, not the lock', (tester) async {
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
    expect(find.byKey(const ValueKey('site_suggest_unlock')), findsOneWidget);
    expect(
      page.container.read(recordEditShortcutTargetsProvider).current,
      isNotNull,
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

/// Records each attachment save's changed cards, and writes nothing.
class _RecordingPhotoSave extends Fake implements PhotoEditSaveService {
  _RecordingPhotoSave(this.saves);

  final List<Iterable<String>> saves;

  @override
  Future<({PhotoRecord before, PhotoRecord after})?> save({
    required String mediaId,
    required String? diverId,
    required PhotoRecord Function(PhotoRecord stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    ({String? id})? diveAtStart,
    String? siteAtStart,
  }) async {
    saves.add([...changedCardIds, 'site:$siteAtStart']);
    return null;
  }
}
