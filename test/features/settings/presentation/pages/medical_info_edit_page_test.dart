import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiversCompanion;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/settings/presentation/pages/medical_info_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'diver_profile_harness.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.now();

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Document clearance(String id, DateTime? expiry) => Document(
    id: id,
    diverId: 'diver-1',
    owner: const DocumentOwner.personal(),
    type: DocumentType.medicalClearance,
    title: 'Clearance $id',
    expiryDate: expiry,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pump(
    WidgetTester tester, {
    String? bloodType,
    String? allergies,
    String? medications,
    String medicalNotes = '',
    List<Document> documents = const [],
    List<Override> overrides = const [],
  }) async {
    await seedDiver(
      profileDiver(
        bloodType: bloodType,
        allergies: allergies,
        medications: medications,
        medicalNotes: medicalNotes,
      ),
    );
    await pumpProfilePage(
      tester,
      path: 'medical',
      page: const MedicalInfoEditPage(),
      documents: documents,
      overrides: overrides,
    );
  }

  testWidgets('populates the medical fields from the existing diver', (
    tester,
  ) async {
    await pump(
      tester,
      bloodType: 'O+',
      allergies: 'Penicillin',
      medications: 'None',
      medicalNotes: 'Cleared for deep diving',
    );

    expect(find.text('Medical Information'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Cleared for deep diving'), findsOneWidget);
    expect(await sittings(db), isEmpty);
  });

  testWidgets('lists medical clearance documents with their badge (#2613)', (
    tester,
  ) async {
    await pump(
      tester,
      documents: [
        clearance('old', now.subtract(const Duration(days: 1))),
        Document(
          id: 'permit',
          diverId: 'diver-1',
          owner: const DocumentOwner.personal(),
          type: DocumentType.permit,
          title: 'Park permit',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    expect(find.text('Medical clearances'), findsOneWidget);
    expect(find.text('Clearance old'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Park permit'), findsNothing);
  });

  testWidgets('with no clearance on record it says so', (tester) async {
    await pump(tester);
    expect(find.text('No medical clearance recorded'), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('Add clearance opens a new clearance document', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add clearance'));
    await tester.pumpAndSettle();
    expect(find.text('NEW type=medicalClearance'), findsOneWidget);
  });

  testWidgets('saving persists the trimmed medical details', (tester) async {
    await pump(tester);

    await typeInto(tester, 'Blood Type', '  AB-  ');
    await typeInto(tester, 'Allergies', 'Latex');
    await typeInto(tester, 'Medications', 'Antihistamine');
    await typeInto(tester, 'Medical Notes', 'Annual physical on file');
    await tapBar(tester, 'Save');

    final saved = (await storedDiver('diver-1'))!;
    expect(saved.bloodType, 'AB-');
    expect(saved.allergies, 'Latex');
    expect(saved.medications, 'Antihistamine');
    expect(saved.medicalNotes, 'Annual physical on file');
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('clearing an optional field persists null', (tester) async {
    await pump(tester, bloodType: 'O+', allergies: 'Penicillin');

    await typeInto(tester, 'Allergies', '');
    await tapBar(tester, 'Save');

    final saved = (await storedDiver('diver-1'))!;
    expect(saved.allergies, isNull);
    expect(saved.bloodType, 'O+');
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
    await pump(tester, bloodType: 'O+', allergies: 'Penicillin');

    expect(barAction(tester, 'Save').onPressed, isNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('Back after typing asks; Keep editing keeps the text', (
    tester,
  ) async {
    await pump(tester);
    await typeInto(tester, 'Allergies', 'Latex');

    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('Latex'), findsOneWidget);
    expect(barAction(tester, 'Save').onPressed, isNotNull);
  });

  testWidgets('Save writes one change log operation labelled with the diver', (
    tester,
  ) async {
    await pump(tester);
    await typeInto(tester, 'Allergies', 'Latex');
    await tapBar(tester, 'Save');

    final written = await sittings(db);
    expect(written, hasLength(1));
    expect(written.single.table, 'divers');
    expect(written.single.id, 'diver-1');
    expect(written.single.cardIds, isEmpty);
    expect(find.text('Hub'), findsOneWidget);
    expect(find.text('Changes saved'), findsOneWidget);
  });

  testWidgets(
    'a blood type changed in storage meanwhile survives an allergies Save',
    (tester) async {
      await pump(tester, bloodType: 'O+');
      await (db.update(db.divers)..where((t) => t.id.equals('diver-1'))).write(
        const DiversCompanion(bloodType: Value('B-')),
      );
      await typeInto(tester, 'Allergies', 'Latex');
      await tapBar(tester, 'Save');

      final saved = (await storedDiver('diver-1'))!;
      expect(saved.bloodType, 'B-');
      expect(saved.allergies, 'Latex');
    },
  );

  testWidgets('an avatar set meanwhile survives Save', (tester) async {
    await pump(tester);
    await (db.update(db.divers)..where((t) => t.id.equals('diver-1'))).write(
      const DiversCompanion(photoPath: Value('avatar.jpg')),
    );
    await typeInto(tester, 'Allergies', 'Latex');
    await tapBar(tester, 'Save');

    expect((await storedDiver('diver-1'))!.photoPath, 'avatar.jpg');
  });

  testWidgets('a diver gone at Save is refused and nothing is written', (
    tester,
  ) async {
    // Held on the diver: no switch closes the page before Save.
    await pump(
      tester,
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      ],
    );
    await typeInto(tester, 'Allergies', 'Latex');
    await deleteDiverRow(db, 'diver-1');
    await tapBar(tester, 'Save');

    expect(find.text('This diver no longer exists.'), findsOneWidget);
    expect(find.byType(MedicalInfoEditPage), findsOneWidget);
    expect(await storedDiver('diver-1'), isNull);
  });

  testWidgets(
    'a clearance document opened and closed keeps the medical edits',
    (tester) async {
      await pump(tester);
      await typeInto(tester, 'Allergies', 'Latex');
      await tester.tap(find.text('Add clearance'));
      await tester.pumpAndSettle();
      expect(find.text('NEW type=medicalClearance'), findsOneWidget);

      // A tab switch from the document page still asks about the edits.
      final guard = profileContainer(tester).read(appExitGuardProvider);
      final leaving = guard.mayLeave();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(await leaving, isFalse);

      await back(tester);
      expect(find.text('Latex'), findsOneWidget);
      expect(barAction(tester, 'Save').onPressed, isNotNull);
    },
  );

  testWidgets('a Save that changes nothing stored writes nothing', (
    tester,
  ) async {
    await pump(tester, allergies: 'Latex');
    await (db.update(db.divers)..where((t) => t.id.equals('diver-1'))).write(
      const DiversCompanion(updatedAt: Value(1)),
    );

    // Changed as typed, the same once trimmed.
    await typeInto(tester, 'Allergies', 'Latex ');
    expect(barAction(tester, 'Save').onPressed, isNotNull);
    await tapBar(tester, 'Save');

    expect(find.text('Hub'), findsOneWidget);
    final row = await (db.select(
      db.divers,
    )..where((t) => t.id.equals('diver-1'))).getSingle();
    expect(row.updatedAt, 1);
    expect(row.allergies, 'Latex');
  });

  testWidgets('a diver that fails to load shows why and opens no sitting', (
    tester,
  ) async {
    await seedDiver(profileDiver());
    await pumpProfilePage(
      tester,
      path: 'medical',
      page: const MedicalInfoEditPage(),
      overrides: [
        currentDiverProvider.overrideWith(
          (ref) async => throw StateError('divers unreadable'),
        ),
      ],
    );

    expect(find.textContaining('divers unreadable'), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    await back(tester);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('opened with nothing under it, Cancel goes to the hub', (
    tester,
  ) async {
    await seedDiver(profileDiver());
    await pumpProfilePage(
      tester,
      path: 'medical',
      page: const MedicalInfoEditPage(),
      alone: true,
    );
    expect(find.byType(MedicalInfoEditPage), findsOneWidget);

    await tapBar(tester, 'Cancel');

    expect(find.text('Hub'), findsOneWidget);
  });
}
