import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiversCompanion;
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/personal_info_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'diver_profile_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, Diver diver) async {
    await seedDiver(diver);
    await pumpProfilePage(
      tester,
      path: 'personal',
      page: const PersonalInfoEditPage(),
    );
  }

  Diver makeDiver({String? email, String? phone}) =>
      profileDiver(email: email).copyWith(phone: phone);

  Future<Diver> saved() async => (await storedDiver('diver-1'))!;

  testWidgets('populates the fields from the existing diver', (tester) async {
    await pump(
      tester,
      makeDiver(email: 'alice@example.com', phone: '555-0100'),
    );

    expect(find.text('Personal Info'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Alice Alpha'), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('555-0100'), findsOneWidget);
    expect(await sittings(db), isEmpty);
  });

  testWidgets('saving persists the edited name, email and phone', (
    tester,
  ) async {
    await pump(tester, makeDiver());

    await typeInto(tester, 'Name *', '  Bruna Bravo  ');
    await typeInto(tester, 'Email', 'bruna@example.com');
    await typeInto(tester, 'Phone', '555-0199');
    await tapBar(tester, 'Save');

    final diver = await saved();
    expect(diver.name, 'Bruna Bravo');
    expect(diver.email, 'bruna@example.com');
    expect(diver.phone, '555-0199');
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('saving persists the social handle (#3728)', (tester) async {
    await pump(tester, makeDiver().copyWith(socialHandle: '@old'));
    expect(find.text('@old'), findsOneWidget);

    await typeInto(tester, 'Social handle', '  @jordan  ');
    await tapBar(tester, 'Save');

    expect((await saved()).socialHandle, '@jordan');
  });

  testWidgets('clearing an optional field persists null', (tester) async {
    await pump(
      tester,
      makeDiver(email: 'alice@example.com', phone: '555-0100'),
    );

    await typeInto(tester, 'Email', '');
    await tapBar(tester, 'Save');

    final diver = await saved();
    expect(diver.email, isNull);
    expect(diver.phone, '555-0100');
  });

  testWidgets('an empty name keeps the page open and writes nothing', (
    tester,
  ) async {
    await pump(tester, makeDiver());

    await typeInto(tester, 'Name *', '   ');
    await tapBar(tester, 'Save');

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.byType(PersonalInfoEditPage), findsOneWidget);
    expect((await saved()).name, 'Alice Alpha');
    expect(await sittings(db), isEmpty);
  });

  testWidgets('a malformed email blocks the save', (tester) async {
    await pump(tester, makeDiver());

    await typeInto(tester, 'Email', 'not-an-email');
    await tapBar(tester, 'Save');

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect((await saved()).email, isNull);
  });

  testWidgets('the bar is the tinted Cancel and Save bar, with no back arrow', (
    tester,
  ) async {
    await pump(tester, makeDiver());

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('an untouched page with no sex set has Save disabled', (
    tester,
  ) async {
    await pump(tester, makeDiver(email: 'alice@example.com'));

    expect(barAction(tester, 'Save').onPressed, isNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('a name changed in storage meanwhile survives an email Save', (
    tester,
  ) async {
    await pump(tester, makeDiver());
    await (db.update(db.divers)..where((t) => t.id.equals('diver-1'))).write(
      const DiversCompanion(name: Value('Alice Synced')),
    );

    await typeInto(tester, 'Email', 'alice@example.com');
    await tapBar(tester, 'Save');

    final diver = await saved();
    expect(diver.name, 'Alice Synced');
    expect(diver.email, 'alice@example.com');
  });

  group('sex and birth year (issue #4525)', () {
    Future<void> pickSex(WidgetTester tester, String option) async {
      await tester.tap(find.byKey(const Key('personalInfo_sex')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    testWidgets('both save to the diver', (tester) async {
      await pump(tester, makeDiver());
      expect(
        find.text(
          'Used only to estimate body composition for weight '
          'prediction.',
        ),
        findsOneWidget,
      );

      await pickSex(tester, 'Female');
      await typeInto(tester, 'Birth year', '1984');
      await tapBar(tester, 'Save');

      final diver = await saved();
      expect(diver.sex, DiverSex.female);
      expect(diver.birthYear, 1984);
    });

    testWidgets('the fields show what the diver has', (tester) async {
      await pump(
        tester,
        makeDiver().copyWith(sex: DiverSex.male, birthYear: 1980),
      );
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('1980'), findsOneWidget);

      // Saved with only the name changed, they stay as they were.
      await typeInto(tester, 'Name *', 'Alice Beta');
      await tapBar(tester, 'Save');
      final diver = await saved();
      expect(diver.sex, DiverSex.male);
      expect(diver.birthYear, 1980);
    });

    testWidgets('picking a sex is a change; picking it back is not', (
      tester,
    ) async {
      await pump(tester, makeDiver());

      await pickSex(tester, 'Female');
      expect(barAction(tester, 'Save').onPressed, isNotNull);
      await pickSex(tester, 'Not set');
      expect(barAction(tester, 'Save').onPressed, isNull);
    });

    testWidgets('clearing both saves nulls', (tester) async {
      await pump(
        tester,
        makeDiver().copyWith(sex: DiverSex.male, birthYear: 1980),
      );

      await pickSex(tester, 'Not set');
      await typeInto(tester, 'Birth year', '');
      await tapBar(tester, 'Save');

      final diver = await saved();
      expect(diver.sex, isNull);
      expect(diver.birthYear, isNull);
    });

    testWidgets('a birth year outside 1900 to this year is rejected', (
      tester,
    ) async {
      await pump(tester, makeDiver());
      final thisYear = DateTime.now().year;

      for (final bad in ['${thisYear + 1}', '1899']) {
        await typeInto(tester, 'Birth year', bad);
        await tapBar(tester, 'Save');
        expect(
          find.text('Enter a year from 1900 to $thisYear'),
          findsOneWidget,
        );
      }
      expect((await saved()).birthYear, isNull);
    });
  });
}
