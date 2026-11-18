import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// Edit profile on the Profile card, and Draw a profile in the menu: the
/// profile editor saves on its own page, so both are whole-record
/// operations (issue #4527, plan 7).
void main() {
  final profile = List.generate(
    21,
    (i) => DiveProfilePoint(timestamp: i * 60, depth: i < 10 ? i * 3.0 : 30.0),
  );
  late Dive profiled;

  setUp(() async {
    await setUpTestDatabase();
    profiled = dive.copyWith(
      profile: profile,
      runtime: const Duration(seconds: 1200),
      maxDepth: 30,
    );
    await DiveRepository().createDive(profiled);
  });
  tearDown(tearDownTestDatabase);

  const sections = {DiveDetailSectionId.profile, DiveDetailSectionId.notes};
  const size = Size(1000, 1600);

  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  RecordEditController<Dive> controller(WidgetTester tester) => tester
      .widget<RecordEditScope<Dive>>(
        find.byWidgetPredicate((w) => w is RecordEditScope<Dive>).first,
      )
      .notifier!;

  Finder editProfile() => find.byIcon(Icons.edit_note);

  IconButton editButton(WidgetTester tester) => tester.widget<IconButton>(
    find.ancestor(of: editProfile(), matching: find.byType(IconButton)),
  );

  testWidgets('the Profile card offers Edit profile, disabled while locked', (
    tester,
  ) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);

    expect(editProfile(), findsOneWidget);
    expect(editButton(tester).onPressed, isNull);
    expect(find.byTooltip('Unlock to use this'), findsOneWidget);
    // One tooltip, the reason: a second one, the button's own label, would
    // compete with it on hover.
    expect(editButton(tester).tooltip, 'Unlock to use this');
    expect(find.byTooltip('Edit profile'), findsNothing);
  });

  testWidgets('unlocked and clean, Edit profile pushes the editor; its save '
      'starts the sitting again', (tester) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);
    await unlock(tester);
    await settleLong(tester);
    final before = controller(tester).session;

    await tester.tap(editProfile());
    await settleLong(tester);
    expect(find.text('PROFILE EDITOR null'), findsOneWidget);
    await tester.tap(find.text('SAVE PROFILE'));
    await settleLong(tester);

    expect(controller(tester).isUnlocked, isTrue);
    expect(controller(tester).session, isNot(same(before)));
  });

  testWidgets('a cancelled editor leaves the sitting as it was', (
    tester,
  ) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);
    await unlock(tester);
    await settleLong(tester);
    final before = controller(tester).session;

    await tester.tap(editProfile());
    await settleLong(tester);
    await tester.tap(find.text('LEAVE PROFILE'));
    await settleLong(tester);

    expect(controller(tester).session, same(before));
    expect(controller(tester).isOperating, isFalse);
  });

  // The card's own pencil comes in on unlock (plan 6) and moves the
  // toolbar along the header; the toolbar itself keeps its buttons.
  testWidgets('Edit profile keeps its place in the toolbar on unlock', (
    tester,
  ) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);
    double gap() =>
        tester.getTopLeft(find.byIcon(Icons.fullscreen).first).dx -
        tester.getTopLeft(editProfile()).dx;
    final locked = gap();

    await unlock(tester);
    await settleLong(tester);
    expect(gap(), locked);
  });

  testWidgets('Draw a profile is listed for a dive with no profile and '
      'pushes draw mode', (tester) async {
    await pumpPage(tester);
    await unlock(tester);

    await tester.tap(
      find.byWidgetPredicate((w) => w is PopupMenuButton<String>).last,
    );
    await settle(tester);
    await tester.tap(find.text('Draw a profile'));
    await settle(tester);

    expect(find.text('PROFILE EDITOR draw'), findsOneWidget);
  });
}
