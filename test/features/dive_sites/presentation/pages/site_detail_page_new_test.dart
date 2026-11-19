import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_new_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'site_detail_page_unlock_harness.dart';

const _original = DiveSite(
  id: 'site-1',
  diverId: 'me',
  name: 'Salt Pier',
  description: 'Pier pilings',
  location: GeoPoint(12.08, -68.28),
  notes: 'Ask first',
);

const SiteDuplicateSource _duplicate = (
  site: _original,
  types: [],
  tags: [],
  species: [],
  features: [],
  sharing: ItemSharing.none,
);

/// The rules a site created by hand is owed, held until [gate] opens.
class _GatedRules extends Fake implements RuleEngine {
  final gate = Completer<void>();

  @override
  Future<RuleRunResult> run(RuleRunRequest request) async {
    await gate.future;
    throw StateError('no rules here');
  }
}

/// A new site, and a duplicate, open on the site page itself, already
/// unlocked (issue #4527, phase 2, plan 6).
void main() {
  final l = AppLocalizationsEn();

  RecordEditController<DiveSite> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<DiveSite>(
        tester.element(find.byType(RecordCardFrame<DiveSite>).first),
      )!;

  EditSession<DiveSite> sitting(WidgetTester tester) =>
      controllerOf(tester).session!;

  AppBarTextAction saveButton(WidgetTester tester) =>
      tester.widget<AppBarTextAction>(
        find.widgetWithText(AppBarTextAction, l.forms_save),
      );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('a new site opens unlocked with the header and starter cards '
      'open', (tester) async {
    await pumpNewSitePage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.diveSites_edit_appBar_newSite), findsOneWidget);
    expect(
      controllerOf(tester).openCardIds,
      containsAll([siteHeaderCardId, 'location', 'depth', 'notes']),
    );
    expect(
      find.descendant(
        of: find.byType(RecordEditBar),
        matching: find.byType(PopupMenuButton<String>),
      ),
      findsNothing,
    );
  });

  // Every card but the starter set waits in the strip (spec, decision 4),
  // the ones a stored site always shows included, until it is added.
  testWidgets('cards outside the starter set wait in the strip', (
    tester,
  ) async {
    await pumpNewSitePage(tester);
    const waiting = [
      'description',
      'rating',
      'marineLife',
      'media',
      'documents',
    ];
    Finder frame(String id) => find.byWidgetPredicate(
      (w) => w is RecordCardFrame<DiveSite> && w.card.id == id,
      skipOffstage: false,
    );

    final strip = tester.widget<AddStrip>(find.byType(AddStrip));
    expect(strip.entries.map((e) => e.cardId), containsAll(waiting));
    for (final id in waiting) {
      expect(frame(id), findsNothing, reason: id);
    }

    controllerOf(tester).addCard('description');
    await tester.pumpAndSettle();

    expect(frame('description'), findsOneWidget);
    expect(
      tester
          .widget<AddStrip>(find.byType(AddStrip))
          .entries
          .map((e) => e.cardId),
      isNot(contains('description')),
    );
  });

  // The name is required and sits at the top: a new site starts there,
  // not in Notes further down the page.
  testWidgets('a new site starts in the site\'s name', (tester) async {
    await pumpNewSitePage(tester);

    final header = find.byWidgetPredicate(
      (w) => w is RecordCardFrame<DiveSite> && w.card.id == siteHeaderCardId,
    );
    final name = tester.widget<EditableText>(
      find.descendant(of: header, matching: find.byType(EditableText)).first,
    );
    expect(name.focusNode.hasFocus, isTrue);
    expect(
      tester.getTopLeft(header).dy,
      lessThan(tester.view.physicalSize.height / 2),
    );
  });

  testWidgets('Save waits for the first entry', (tester) async {
    await pumpNewSitePage(tester);
    expect(saveButton(tester).onPressed, isNull);

    sitting(tester).set(siteNameField, 'Blue Hole');
    await tester.pumpAndSettle();

    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('a name from the picker is a change', (tester) async {
    await pumpNewSitePage(tester, seed: const NewSiteSeed(name: 'Blue Hole'));

    expect(sitting(tester).changedCardIds, {siteHeaderCardId});
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('calculated cards are not shown', (tester) async {
    await pumpNewSitePage(tester, duplicate: _duplicate);

    expect(find.text(l.recordEdit_calculated), findsNothing);
  });

  // Review Focus 5.
  testWidgets('an untouched new site leaves without asking', (tester) async {
    final page = await pumpNewSitePage(tester);

    await tapText(tester, l.forms_cancel);

    expect(find.byType(AlertDialog), findsNothing);
    expect(page.left, isTrue);
    expect(page.leftWith, isNull);
    expect(page.save.creates, isEmpty);
  });

  testWidgets('a seeded name asks before leaving, and nothing is written', (
    tester,
  ) async {
    final page = await pumpNewSitePage(
      tester,
      seed: const NewSiteSeed(name: 'Blue Hole'),
    );

    await tapText(tester, l.forms_cancel);
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tapText(tester, l.forms_discard_keepEditing);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(page.left, isFalse);

    await tapText(tester, l.forms_cancel);
    await tapText(tester, l.forms_discard_discard);

    expect(page.left, isTrue);
    expect(page.save.creates, isEmpty);
    expect(page.save.calls, isEmpty);
  });

  // Ended while another page covered it (a sitting withdrawn under it):
  // the new site leaves once it is back in view, rather than standing
  // locked over a site that does not exist.
  testWidgets('a sitting ended out of view leaves once back in view', (
    tester,
  ) async {
    final page = await pumpNewSitePage(tester);
    final controller = controllerOf(tester);
    final navigator = Navigator.of(tester.element(find.byType(RecordEditBar)));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('on top')),
      ),
    );
    await tester.pumpAndSettle();

    controller.lock();
    await tester.pumpAndSettle();
    expect(page.left, isFalse);
    navigator.pop();
    await tester.pumpAndSettle();

    expect(page.left, isTrue);
    expect(page.save.creates, isEmpty);
  });

  testWidgets('Save creates the site and leaves with its id', (tester) async {
    final page = await pumpNewSitePage(tester);
    sitting(tester).set(siteNameField, 'Blue Hole');
    await tester.pumpAndSettle();

    await tapText(tester, l.forms_save);

    final create = page.save.creates.single;
    expect(create.site.name, 'Blue Hole');
    expect(create.site.diverId, 'me');
    expect(create.cards, contains(siteHeaderCardId));
    expect(page.left, isTrue);
    expect(page.leftWith, create.site.id);
  });

  // The site exists once Save has written it: Back while it is handed on
  // would leave the picker without it, so it waits.
  testWidgets('Back waits while the created site is handed on', (tester) async {
    final rules = _GatedRules();
    final page = await pumpNewSitePage(
      tester,
      extra: [ruleEngineProvider.overrideWithValue(rules)],
    );
    sitting(tester).set(siteNameField, 'Blue Hole');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_save));
    await tester.pump();
    await tester.pump();
    expect(page.save.creates, hasLength(1));
    expect(find.byType(BackButton), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(page.left, isFalse);

    rules.gate.complete();
    for (var i = 0; i < 20 && !page.left; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(page.leftWith, page.save.creates.single.site.id);
  });

  testWidgets('in the pane, Save hands the new id over', (tester) async {
    final page = await pumpNewSitePage(tester, embedded: true);
    sitting(tester).set(siteNameField, 'Blue Hole');
    await tester.pumpAndSettle();

    // The pane's parent swaps the page for the site; here nothing does,
    // and the page waits on a spinner, so frames are pumped, not settled.
    await tester.tap(find.text(l.forms_save));
    for (var i = 0; i < 20 && page.created == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(page.created, page.save.creates.single.site.id);
  });

  // Review Focus 3.
  testWidgets('a Save that fails keeps everything', (tester) async {
    final page = await pumpNewSitePage(tester);
    sitting(tester).set(siteNameField, 'Blue Hole');
    await tester.pumpAndSettle();
    page.save.failWith = StateError('the database refused it');

    await tapText(tester, l.forms_save);

    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(sitting(tester).valueOf(siteNameField), 'Blue Hole');
    expect(page.left, isFalse);

    page.save.failWith = null;
    await tapText(tester, l.forms_save);

    expect(page.save.creates, hasLength(2));
    expect(page.save.creates.last.site.id, page.save.creates.first.site.id);
    expect(page.leftWith, page.save.creates.last.site.id);
  });

  testWidgets('a duplicate opens titled Duplicate, prefilled as changes', (
    tester,
  ) async {
    await pumpNewSitePage(tester, duplicate: _duplicate);

    expect(find.text(l.diveSites_edit_appBar_duplicateSite), findsOneWidget);
    final session = sitting(tester);
    expect(
      session.valueOf(siteNameField),
      l.diveSites_edit_duplicateName('Salt Pier'),
    );
    expect(session.changedCardIds, contains('description'));
    expect(controllerOf(tester).openCardIds, contains('description'));
    expect(saveButton(tester).onPressed, isNotNull);
  });

  // Review Focus 2 at the page.
  testWidgets('Save on a duplicate at once creates it with the copy', (
    tester,
  ) async {
    final page = await pumpNewSitePage(tester, duplicate: _duplicate);

    await tapText(tester, l.forms_save);

    final created = page.save.creates.single.site;
    expect(created.name, l.diveSites_edit_duplicateName('Salt Pier'));
    expect(created.description, 'Pier pilings');
    expect(created.notes, 'Ask first');
    expect(created.id, isNot('site-1'));
  });

  // Read for the page and let go with it: a later Duplicate of the same
  // site copies it as it is then.
  testWidgets('a duplicate\'s source goes with its page', (tester) async {
    final page = await pumpNewSitePage(tester, duplicate: _duplicate);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecordEditBar)),
    );
    expect(container.exists(siteDuplicateSourceProvider('site-1')), isTrue);

    await tapText(tester, l.forms_cancel);
    await tapText(tester, l.forms_discard_discard);

    expect(page.left, isTrue);
    expect(container.exists(siteDuplicateSourceProvider('site-1')), isFalse);
  });

  testWidgets('a duplicate of a site that is gone says so', (tester) async {
    await pumpNewSitePage(tester, duplicateGone: true);

    expect(find.text(l.diveSites_detail_siteNotFound_body), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
  });
}
