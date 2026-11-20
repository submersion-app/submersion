import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'equipment_set_detail_page_unlock_harness.dart';

/// A new set and a set clone open on the set page, already unlocked (issue
/// #4527, phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async => seedSetPage());
  tearDown(tearDownTestDatabase);

  Finder nameField() => find.byKey(const ValueKey('set-edit-name'));

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('a new set opens unlocked, and Save creates it and pops its id', (
    tester,
  ) async {
    final harness = await pumpNewSetPage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.equipment_setEdit_appBar_newTitle), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);

    await tester.enterText(nameField(), 'Travel kit');
    await tester.pumpAndSettle();
    await save(tester);

    final id = harness.popped! as String;
    final created = await storedSet(tester, id);
    expect(created.name, 'Travel kit');
    expect(created.showFigure, isTrue);
    expect(created.diverId, 'd1');
  });

  testWidgets('an untouched new set leaves without asking', (tester) async {
    final harness = await pumpNewSetPage(tester);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
  });

  testWidgets('a clone opens named as a copy, and saving leaves the source '
      'as it was', (tester) async {
    final harness = await pumpNewSetPage(tester, cloneFromId: 's1');

    expect(find.text(l.equipment_setEdit_appBar_cloneTitle), findsOneWidget);
    expect(find.text(l.equipment_clone_nameCopy('Cold water')), findsWidgets);
    await save(tester);

    final clone = await storedSet(tester, harness.popped! as String);
    expect(clone.name, l.equipment_clone_nameCopy('Cold water'));
    expect(clone.equipmentIds.toSet(), {'e1', 'e2'});
    // Not the default, no geofence: a clone does not compete.
    expect(clone.isDefault, isFalse);
    expect(clone.geofences, isEmpty);
    final source = await storedSet(tester);
    expect(source.name, 'Cold water');
    expect(source.geofences.single.id, 'g1');
  });

  testWidgets('a clone of a set that is gone opens as not found', (
    tester,
  ) async {
    await pumpNewSetPage(tester, cloneFromId: 'gone');

    expect(find.text(l.equipment_setDetail_notFoundMessage), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
  });
  testWidgets('a profile switch before Save drops the clone', (tester) async {
    final harness = await pumpNewSetPage(tester, cloneFromId: 's1');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecordEditBar)),
    );

    container.read(newSetPageDiverProvider.notifier).state = 'other';
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
  });
}
