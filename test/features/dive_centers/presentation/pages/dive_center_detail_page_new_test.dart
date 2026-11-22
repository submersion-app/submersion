import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/gear_here_section.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'dive_center_detail_page_unlock_harness.dart';

/// A new dive centre opens on its page, already unlocked (issue #4527,
/// phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Finder nameField() => find.byKey(const ValueKey('dive-center-edit-name'));

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

  testWidgets('a new centre opens unlocked with header, Contact and Map open', (
    tester,
  ) async {
    await pumpNewDiveCenterPage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.diveCenters_title_add), findsOneWidget);
    expect(nameField(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dive-center-edit-phone')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dive-center-edit-pick-map')),
      findsOneWidget,
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byType(GearHereSection), findsNothing);
  });

  testWidgets('Save waits for the first entry, then pops the id', (
    tester,
  ) async {
    final harness = await pumpNewDiveCenterPage(tester);

    await tapSave(tester);
    expect(harness.save.creates, isEmpty);

    await typeName(tester, 'Blue Planet');
    await tapSave(tester);
    final created = harness.save.creates.single.center;
    expect(created.name, 'Blue Planet');
    expect(created.diverId, 'd1');
    expect(harness.popped, created.id);
  });

  /// Opens the time picker on fill hours row [key] and takes its time.
  Future<void> pickTime(WidgetTester tester, String key) async {
    final row = find.byKey(Key(key));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('fill hours picked on a new centre show and are created', (
    tester,
  ) async {
    final harness = await pumpNewDiveCenterPage(tester);
    await typeName(tester, 'Blue Planet');

    await pickTime(tester, 'fill-hours-opens');
    await pickTime(tester, 'fill-hours-closes');
    expect(find.textContaining('8:00'), findsOneWidget);
    expect(find.textContaining('5:00'), findsOneWidget);
    await tapSave(tester);

    final created = harness.save.creates.single.center;
    expect(created.fillOpensAt, 8 * 60);
    expect(created.fillClosesAt, 17 * 60);
  });

  testWidgets('one fill hour alone says so and stops the Save', (tester) async {
    final harness = await pumpNewDiveCenterPage(tester);
    await typeName(tester, 'Blue Planet');

    await pickTime(tester, 'fill-hours-opens');
    expect(find.text(l.diveCenters_fillHours_errorBoth), findsOneWidget);
    await tapSave(tester);

    expect(harness.save.creates, isEmpty);
    expect(find.text(l.recordEdit_fixInvalid), findsOneWidget);
  });

  testWidgets('in the pane, Save hands the id to the pane', (tester) async {
    final harness = await pumpNewDiveCenterPage(tester, embedded: true);
    await typeName(tester, 'Blue Planet');

    await tester.tap(find.text(l.forms_save));
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.createdIds, [harness.save.creates.single.center.id]);
  });

  testWidgets('an address typed with no coordinates looks them up, and Save '
      'waits for it', (tester) async {
    final locations = FakeLocations(
      found: const LocationResult(latitude: 27.2, longitude: 33.8),
    );
    final harness = await pumpNewDiveCenterPage(tester, locations: locations);
    await typeName(tester, 'Blue Planet');
    final street = find.byKey(const ValueKey('dive-center-edit-street'));
    await tester.ensureVisible(street);
    await tester.tap(street);
    await tester.enterText(street, '1 Sea St');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(locations.asked, isNotEmpty);

    await tester.tap(find.text(l.forms_save));
    await tester.pump();
    expect(harness.save.creates, isEmpty);
    locations.answer.complete();
    await tester.pumpAndSettle();

    final created = harness.save.creates.single.center;
    expect(created.street, '1 Sea St');
    expect(created.latitude, 27.2);
    expect(created.longitude, 33.8);
  });

  testWidgets('an untouched new centre leaves without asking', (tester) async {
    final harness = await pumpNewDiveCenterPage(tester);

    await tapCancel(tester);

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
  });

  testWidgets('an entry asks before leaving, and nothing is written', (
    tester,
  ) async {
    final harness = await pumpNewDiveCenterPage(tester);
    await typeName(tester, 'Blue Planet');

    await tapCancel(tester);
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.save.creates, isEmpty);
    expect(harness.save.calls, isEmpty);
  });

  testWidgets('a Save that fails keeps everything', (tester) async {
    final harness = await pumpNewDiveCenterPage(tester);
    await typeName(tester, 'Blue Planet');
    harness.save.failCreate = StateError('the create failed');

    await tapSave(tester);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);

    harness.save.failCreate = null;
    await tapSave(tester);
    expect(harness.save.creates, hasLength(2));
    expect(
      harness.save.creates.last.center.id,
      harness.save.creates.first.center.id,
    );
  });
}
