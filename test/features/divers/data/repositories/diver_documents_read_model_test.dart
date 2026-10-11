import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

import '../../../../helpers/test_database.dart';

/// A diver's insurance and medical clearance are read from documents
/// (issue #2613): the diver row's own insurance and clearance columns are
/// never read or written again.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Diver diver({
    DiverInsurance insurance = const DiverInsurance(),
    DateTime? clearance,
  }) => Diver(
    id: 'd1',
    name: 'Ana',
    insurance: insurance,
    medicalClearanceExpiryDate: clearance,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<Object?> rawColumn(String column) async =>
      (await db
              .customSelect("SELECT $column AS v FROM divers WHERE id = 'd1'")
              .getSingle())
          .data['v'];

  test('insurance comes from the primary insurance document', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        issuer: 'DAN',
        referenceNumber: 'P-9',
        emergencyPhone: '+1 911',
        phone: '+1 555',
        expiryDate: DateTime(2027, 5, 1),
        isPrimary: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    final d = (await divers.getDiverById('d1'))!;
    expect(d.insurance.providerLabel, 'DAN');
    expect(d.insurance.policyLabel, 'P-9');
    expect(d.insurance.assistanceLine, '+1 911');
    expect(d.insurance.officeLine, '+1 555');
    expect(d.insurance.expiryDate, DateTime(2027, 5, 1));
    expect((await divers.getAllDivers()).single.insurance.providerLabel, 'DAN');
    expect((await divers.getDefaultDiver())!.insurance.providerLabel, 'DAN');
  });

  test('a lone unmarked insurance stands in as the diver insurance', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        issuer: 'Travel',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    expect(
      (await divers.getDiverById('d1'))!.insurance.providerLabel,
      'Travel',
    );
  });

  test('an insurance without an issuer falls back to its title', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        title: 'DAN Gold',
        isPrimary: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    expect(
      (await divers.getDiverById('d1'))!.insurance.providerLabel,
      'DAN Gold',
    );
  });

  test('clearance expiry comes from the latest clearance document', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    for (final y in [2025, 2027]) {
      await DocumentRepository().save(
        Document(
          id: '',
          diverId: 'd1',
          owner: const DocumentOwner.personal(),
          type: DocumentType.medicalClearance,
          expiryDate: DateTime(y),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        const [],
      );
    }
    expect(
      (await divers.getDiverById('d1'))!.medicalClearanceExpiryDate,
      DateTime(2027),
    );
  });

  test('legacy row columns are never read', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    await db.customStatement(
      "UPDATE divers SET insurance_provider = 'Stale', "
      "medical_clearance_expiry_date = 1 WHERE id = 'd1'",
    );
    final d = (await divers.getDiverById('d1'))!;
    expect(d.insurance.providerLabel, isNull);
    expect(d.medicalClearanceExpiryDate, isNull);
  });

  test('updateDiver writes no insurance or clearance columns', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    await divers.updateDiver(
      diver(
        insurance: const DiverInsurance(provider: 'Stale'),
        clearance: DateTime(2030),
      ),
    );
    expect(await rawColumn('insurance_provider'), isNull);
    expect(await rawColumn('medical_clearance_expiry_date'), isNull);
    expect((await divers.getDiverById('d1'))!.insurance.providerLabel, isNull);
  });

  test(
    'createDiver with insurance files a primary insurance document',
    () async {
      await DiverRepository().createDiver(
        diver(
          insurance: const DiverInsurance(provider: 'DAN', policyNumber: '7'),
        ),
      );
      final doc = await DocumentRepository().getById(documentInsuranceId('d1'));
      expect(doc!.isPrimary, isTrue);
      expect(doc.issuer, 'DAN');
      expect(doc.referenceNumber, '7');
      expect(await rawColumn('insurance_provider'), isNull);
    },
  );

  test('createDiver without insurance files no document', () async {
    await DiverRepository().createDiver(diver());
    expect(
      await DocumentRepository().getById(documentInsuranceId('d1')),
      isNull,
    );
  });

  test('the diver tick fires when a document changes', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    final ticks = <void>[];
    final sub = divers.watchDiversChanges().listen(ticks.add);
    addTearDown(sub.cancel);
    await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        isPrimary: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    await pumpEventQueue();
    expect(ticks, isNotEmpty);
  });
}
