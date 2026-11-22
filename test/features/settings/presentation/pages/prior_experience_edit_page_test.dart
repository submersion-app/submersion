import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/prior_experience_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'diver_profile_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester, {
    int? priorDiveCount,
    int? priorDiveTimeSeconds,
    DateTime? divingSince,
  }) async {
    await seedDiver(
      profileDiver(
        priorDiveCount: priorDiveCount,
        priorDiveTimeSeconds: priorDiveTimeSeconds,
        divingSince: divingSince,
      ),
    );
    await pumpProfilePage(
      tester,
      path: 'prior',
      page: const PriorExperienceEditPage(),
    );
  }

  Future<Diver> saved() async => (await storedDiver('diver-1'))!;

  testWidgets('populates fields from the existing diver', (tester) async {
    await pump(
      tester,
      priorDiveCount: 42,
      priorDiveTimeSeconds: 2 * 3600 + 30 * 60,
      divingSince: DateTime(2008),
    );

    expect(find.widgetWithText(TextFormField, '42'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '2'), findsOneWidget); // hours
    expect(find.widgetWithText(TextFormField, '30'), findsOneWidget); // minutes
    expect(find.textContaining('2008'), findsWidgets);
    expect(await sittings(db), isEmpty);
  });

  testWidgets('entering prior experience saves it onto the diver', (
    tester,
  ) async {
    await pump(tester);

    await typeInto(tester, 'Prior dives', '150');
    await typeInto(tester, 'Prior hours', '75');
    await typeInto(tester, 'Minutes', '45');
    await tapBar(tester, 'Save');

    final diver = await saved();
    expect(diver.priorDiveCount, 150);
    expect(diver.priorDiveTimeSeconds, 75 * 3600 + 45 * 60);
  });

  testWidgets('rejects negative dive counts and does not save', (tester) async {
    await pump(tester);

    await typeInto(tester, 'Prior dives', '-5');
    await tapBar(tester, 'Save');

    expect(find.text('Enter a valid number'), findsOneWidget);
    expect((await saved()).priorDiveCount, isNull);
  });

  testWidgets('rejects minutes greater than 59', (tester) async {
    await pump(tester);

    await typeInto(tester, 'Minutes', '90');
    await tapBar(tester, 'Save');

    expect((await saved()).priorDiveTimeSeconds, isNull);
    expect(find.byType(PriorExperienceEditPage), findsOneWidget);
  });

  testWidgets('tapping "diving since" opens the year picker (#765)', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Diving since'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('a diving-since year after this one still opens the picker', (
    tester,
  ) async {
    // Synced from a device already in the next year (around New Year).
    await pump(tester, divingSince: DateTime(DateTime.now().year + 1));

    await tester.tap(find.text('Diving since'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('clearing a previously-set dive count persists null', (
    tester,
  ) async {
    await pump(tester, priorDiveCount: 80);

    await typeInto(tester, 'Prior dives', '');
    await tapBar(tester, 'Save');

    expect((await saved()).priorDiveCount, isNull);
  });

  testWidgets('the bar is the tinted Cancel and Save bar, with no back arrow', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('90 h 5 m and a diving-since year, left alone, are unchanged', (
    tester,
  ) async {
    await pump(
      tester,
      priorDiveCount: 125,
      priorDiveTimeSeconds: 90 * 3600 + 5 * 60,
      divingSince: DateTime(2001),
    );

    expect(barAction(tester, 'Save').onPressed, isNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('a diver with no prior time, left alone, is unchanged', (
    tester,
  ) async {
    await pump(tester);

    expect(barAction(tester, 'Save').onPressed, isNull);
  });

  testWidgets('typing the minutes back to what they were is no change', (
    tester,
  ) async {
    await pump(tester, priorDiveTimeSeconds: 90 * 3600 + 5 * 60);

    await typeInto(tester, 'Minutes', '10');
    expect(barAction(tester, 'Save').onPressed, isNotNull);
    await typeInto(tester, 'Minutes', '5');
    expect(barAction(tester, 'Save').onPressed, isNull);
  });

  testWidgets('clearing diving since is a change and saves no year', (
    tester,
  ) async {
    await pump(tester, divingSince: DateTime(2001));

    await tester.tap(find.byTooltip('Clear diving since'));
    await tester.pumpAndSettle();
    expect(barAction(tester, 'Save').onPressed, isNotNull);
    await tapBar(tester, 'Save');

    expect((await saved()).divingSince, isNull);
  });

  testWidgets('Back after a change asks; Discard returns to the hub', (
    tester,
  ) async {
    await pump(tester);
    await typeInto(tester, 'Prior dives', '12');

    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Hub'), findsOneWidget);
    expect((await saved()).priorDiveCount, isNull);
  });

  testWidgets('Save writes one change log operation labelled with the diver', (
    tester,
  ) async {
    await pump(tester);
    await typeInto(tester, 'Prior dives', '12');
    await tapBar(tester, 'Save');

    final written = await sittings(db);
    expect(written, hasLength(1));
    expect(written.single.table, 'divers');
    expect(written.single.id, 'diver-1');
  });

  testWidgets('a diving-since year picked is a change and is saved', (
    tester,
  ) async {
    await pump(tester);
    // The picker opens on ten years ago.
    final year = DateTime.now().year - 10;

    await tester.tap(find.text('Diving since'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$year'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('OK'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('$year'), findsOneWidget);
    expect(barAction(tester, 'Save').onPressed, isNotNull);
    await tapBar(tester, 'Save');

    expect((await saved()).divingSince, DateTime(year));
  });
}
