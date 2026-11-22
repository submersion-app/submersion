import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiversCompanion;
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/emergency_contacts_edit_page.dart';
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
    EmergencyContact primary = const EmergencyContact(),
    EmergencyContact secondary = const EmergencyContact(),
  }) async {
    await seedDiver(profileDiver(primary: primary, secondary: secondary));
    await pumpProfilePage(
      tester,
      path: 'emergency',
      page: const EmergencyContactsEditPage(),
    );
  }

  Future<Diver> saved() async => (await storedDiver('diver-1'))!;

  /// Finds a field by label inside the card headed by [cardTitle], so the
  /// primary and secondary contact forms can be told apart.
  Finder fieldIn(String cardTitle, String label) {
    return find.descendant(
      of: find
          .ancestor(of: find.text(cardTitle), matching: find.byType(Card))
          .first,
      matching: find.widgetWithText(TextFormField, label),
    );
  }

  Future<void> typeIn(
    WidgetTester tester,
    String cardTitle,
    String label,
    String text,
  ) async {
    await tester.enterText(fieldIn(cardTitle, label), text);
    await tester.pump();
  }

  testWidgets('populates both contact cards from the existing diver', (
    tester,
  ) async {
    await pump(
      tester,
      primary: const EmergencyContact(
        name: 'Bruna Bravo',
        phone: '555-0100',
        relation: 'Spouse',
      ),
      secondary: const EmergencyContact(
        name: 'Carlos Charlie',
        phone: '555-0200',
        relation: 'Brother',
      ),
    );

    expect(find.text('Emergency Contacts'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Bruna Bravo'), findsOneWidget);
    expect(find.text('555-0200'), findsOneWidget);
    expect(find.text('Brother'), findsOneWidget);
    expect(await sittings(db), isEmpty);
  });

  testWidgets('saving persists the primary contact and leaves the secondary '
      'null when blank', (tester) async {
    await pump(tester);

    await typeIn(tester, 'Primary Contact', 'Contact Name', '  Bruna Bravo  ');
    await typeIn(tester, 'Primary Contact', 'Contact Phone', '555-0100');
    await typeIn(tester, 'Primary Contact', 'Relationship', 'Spouse');
    await tapBar(tester, 'Save');

    final diver = await saved();
    expect(diver.emergencyContact.name, 'Bruna Bravo');
    expect(diver.emergencyContact.phone, '555-0100');
    expect(diver.emergencyContact.relation, 'Spouse');
    expect(diver.emergencyContact2.name, isNull);
    expect(diver.emergencyContact2.phone, isNull);
  });

  testWidgets('saving persists an edited secondary contact independently', (
    tester,
  ) async {
    await pump(
      tester,
      primary: const EmergencyContact(name: 'Bruna Bravo', phone: '555-0100'),
    );

    await typeIn(tester, 'Secondary Contact', 'Contact Name', 'Carlos Charlie');
    await typeIn(tester, 'Secondary Contact', 'Contact Phone', '555-0200');
    await tapBar(tester, 'Save');

    final diver = await saved();
    expect(diver.emergencyContact.name, 'Bruna Bravo');
    expect(diver.emergencyContact2.name, 'Carlos Charlie');
    expect(diver.emergencyContact2.phone, '555-0200');
  });

  testWidgets('clearing a stored contact persists null', (tester) async {
    await pump(
      tester,
      primary: const EmergencyContact(
        name: 'Bruna Bravo',
        phone: '555-0100',
        relation: 'Spouse',
      ),
    );

    await typeIn(tester, 'Primary Contact', 'Contact Name', '');
    await typeIn(tester, 'Primary Contact', 'Contact Phone', '');
    await tapBar(tester, 'Save');

    final diver = await saved();
    expect(diver.emergencyContact.name, isNull);
    expect(diver.emergencyContact.phone, isNull);
    expect(diver.emergencyContact.relation, 'Spouse');
  });

  testWidgets('the bar is the tinted Cancel and Save bar, with no back arrow', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('an untouched page has Save disabled and Back asks nothing', (
    tester,
  ) async {
    await pump(
      tester,
      primary: const EmergencyContact(name: 'Bruna Bravo', phone: '555-0100'),
    );

    expect(barAction(tester, 'Save').onPressed, isNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('Back after a change asks; Discard returns to the hub', (
    tester,
  ) async {
    await pump(tester);
    await typeIn(tester, 'Primary Contact', 'Contact Name', 'Bruna');

    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Hub'), findsOneWidget);
    expect((await saved()).emergencyContact.name, isNull);
  });

  testWidgets('Save writes one change log operation labelled with the diver', (
    tester,
  ) async {
    await pump(tester);
    await typeIn(tester, 'Primary Contact', 'Contact Name', 'Bruna');
    await tapBar(tester, 'Save');

    final written = await sittings(db);
    expect(written, hasLength(1));
    expect(written.single.table, 'divers');
    expect(written.single.id, 'diver-1');
  });

  testWidgets(
    'a secondary contact changed meanwhile survives a primary phone Save',
    (tester) async {
      await pump(
        tester,
        primary: const EmergencyContact(name: 'Bruna', phone: '555-0100'),
      );
      await (db.update(db.divers)..where((t) => t.id.equals('diver-1'))).write(
        const DiversCompanion(
          emergencyContact2Name: Value('Synced'),
          emergencyContact2Phone: Value('555-0300'),
        ),
      );

      await typeIn(tester, 'Primary Contact', 'Contact Phone', '555-0199');
      await tapBar(tester, 'Save');

      final diver = await saved();
      expect(diver.emergencyContact.phone, '555-0199');
      expect(diver.emergencyContact.name, 'Bruna');
      expect(diver.emergencyContact2.name, 'Synced');
      expect(diver.emergencyContact2.phone, '555-0300');
    },
  );
}
