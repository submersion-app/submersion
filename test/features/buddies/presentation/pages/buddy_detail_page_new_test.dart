import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_new_sitting.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_gear_section.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'buddy_detail_page_unlock_harness.dart';

/// A new buddy opens on the buddy page, already unlocked (issue #4527,
/// phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Finder nameField() => find.byKey(const ValueKey('buddy-edit-name'));

  Future<void> typeName(WidgetTester tester, String name) async {
    await tester.enterText(nameField(), name);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  Future<void> tapCancel(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a new buddy opens unlocked with header, Contact and Notes open',
    (tester) async {
      await pumpNewBuddyPage(tester);

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text(l.buddies_title_add), findsOneWidget);
      expect(nameField(), findsOneWidget);
      expect(find.byKey(const ValueKey('buddy-edit-email')), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    },
  );

  testWidgets('gear lent is not offered for a buddy not yet created', (
    tester,
  ) async {
    await pumpNewBuddyPage(tester);

    expect(find.byType(BuddyGearSection), findsNothing);
    // Nor in the strip: lending needs a buddy that exists.
    expect(find.text(l.buddies_editCard_gear), findsNothing);
  });

  testWidgets('Save waits for the first entry', (tester) async {
    final harness = await pumpNewBuddyPage(tester);

    await tapSave(tester);
    expect(harness.save.creates, isEmpty);

    await typeName(tester, 'Kai');
    await tapSave(tester);
    final created = harness.save.creates.single.buddy;
    expect(created.name, 'Kai');
    expect(created.diverId, 'd1');
  });

  testWidgets('Save pops the buddy itself, as the pickers expect', (
    tester,
  ) async {
    final harness = await pumpNewBuddyPage(tester);
    await typeName(tester, 'Kai');

    await tapSave(tester);

    expect(harness.popped, isA<Buddy>());
    expect((harness.popped! as Buddy).id, harness.save.creates.single.buddy.id);
  });

  testWidgets('in the pane, Save hands the id to the pane', (tester) async {
    final harness = await pumpNewBuddyPage(tester, embedded: true);
    await typeName(tester, 'Kai');

    await tester.tap(find.text(l.forms_save));
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.createdIds, [harness.save.creates.single.buddy.id]);
  });

  testWidgets('a seed from contacts is a change, a photo alone included', (
    tester,
  ) async {
    final harness = await pumpNewBuddyPage(
      tester,
      seed: NewBuddySeed(
        name: 'Kai',
        email: 'kai@example.com',
        phone: '555',
        photo: Uint8List.fromList([1, 2, 3]),
      ),
    );

    await tapSave(tester);

    final created = harness.save.creates.single;
    expect(created.buddy.email, 'kai@example.com');
    expect(created.buddy.phone, '555');
    expect(created.buddy.photo, [1, 2, 3]);
    expect(created.cards, containsAll(['header', 'contact']));
  });

  testWidgets('a new buddy starts ranked and can be excluded', (tester) async {
    final harness = await pumpNewBuddyPage(tester);
    await typeName(tester, 'Kai');

    await tester.tap(
      find.byTooltip(
        l.recordEdit_editCardTooltip(l.buddies_section_diveStatistics),
      ),
    );
    await tester.pumpAndSettle();
    final rankings = find.byKey(const ValueKey('buddy-edit-rankings'));
    expect(tester.widget<SwitchListTile>(rankings).value, isFalse);
    await tester.tap(rankings);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(harness.save.creates.single.buddy.excludedFromRankings, isTrue);
  });

  testWidgets('an untouched new buddy leaves without asking', (tester) async {
    final harness = await pumpNewBuddyPage(tester);

    await tapCancel(tester);

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
  });

  testWidgets('a seeded buddy asks before leaving, and writes nothing', (
    tester,
  ) async {
    final harness = await pumpNewBuddyPage(
      tester,
      seed: const NewBuddySeed(name: 'Kai'),
    );

    await tapCancel(tester);
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.poppedAtAll, isTrue);
    expect(harness.save.creates, isEmpty);
    expect(harness.save.calls, isEmpty);
  });

  testWidgets('a Save that fails keeps everything', (tester) async {
    final harness = await pumpNewBuddyPage(tester);
    await typeName(tester, 'Kai');
    harness.save.throwing = StateError('the create failed');

    await tapSave(tester);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);

    harness.save.throwing = null;
    await tapSave(tester);
    expect(harness.save.creates, hasLength(2));
    expect(
      harness.save.creates.last.buddy.id,
      harness.save.creates.first.buddy.id,
    );
  });

  test('the route extra reads as a seed', () {
    final seed = NewBuddySeed.fromRouteExtra({
      'name': 'Kai',
      'email': '',
      'photo': Uint8List(0),
    });

    expect(seed?.name, 'Kai');
    expect(seed?.email, isNull);
    expect(seed?.photo, isNull);
    expect(NewBuddySeed.fromRouteExtra(null), isNull);
    expect(NewBuddySeed.fromRouteExtra(const {'name': ' '}), isNull);

    final picked = NewBuddySeed.fromRouteExtra({
      'phone': '555',
      'photo': Uint8List.fromList([1, 2, 3]),
    });
    expect(picked?.phone, '555');
    expect(picked?.photo, [1, 2, 3]);
    // A contact with only a photo still seeds the page.
    expect(
      NewBuddySeed.fromRouteExtra({
        'photo': Uint8List.fromList([1]),
      })?.photo,
      [1],
    );
  });
}
