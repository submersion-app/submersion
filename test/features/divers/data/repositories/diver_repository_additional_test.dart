import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide Diver;
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

/// Success-path coverage for repository methods not covered elsewhere:
///   updateDiver, setDefaultDiver, getDiveCountForDiver,
///   getTotalBottomTimeForDiver, getActiveDiverIdFromSettings,
///   setActiveDiverIdInSettings.
void main() {
  late DiverRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiverRow(
    String id, {
    String name = 'Test Diver',
    bool isDefault = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(name),
            isDefault: Value(isDefault),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDiveRow(
    String id, {
    required String diverId,
    int bottomTime = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: Value(diverId),
            diveDateTime: now,
            bottomTime: Value(bottomTime),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  group('updateDiver', () {
    test('persists scalar field changes', () async {
      await insertDiverRow('d1', name: 'Old Name');

      final updated = Diver(
        id: 'd1',
        name: 'New Name',
        email: 'new@example.com',
        phone: '555-1234',
        medicalNotes: 'Checked ok',
        bloodType: 'O+',
        allergies: 'Peanuts',
        medications: 'Ibuprofen',
        notes: 'Loves warm water',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      await repository.updateDiver(updated);

      final read = await repository.getDiverById('d1');
      expect(read, isNotNull);
      expect(read!.name, equals('New Name'));
      expect(read.email, equals('new@example.com'));
      expect(read.phone, equals('555-1234'));
      expect(read.medicalNotes, equals('Checked ok'));
      expect(read.bloodType, equals('O+'));
      expect(read.allergies, equals('Peanuts'));
      expect(read.medications, equals('Ibuprofen'));
      expect(read.notes, equals('Loves warm water'));
      expect(read.isDefault, isTrue);
    });

    test('persists emergency contacts, insurance, dates', () async {
      await insertDiverRow('d2');

      final medDate = DateTime(2025, 3, 15);
      final insDate = DateTime(2026, 1, 1);
      final updated = Diver(
        id: 'd2',
        name: 'With Details',
        emergencyContact: const EmergencyContact(
          name: 'Contact A',
          phone: '911',
          relation: 'spouse',
        ),
        emergencyContact2: const EmergencyContact(
          name: 'Contact B',
          phone: '112',
          relation: 'sibling',
        ),
        medicalClearanceExpiryDate: medDate,
        insurance: DiverInsurance(
          provider: 'DAN',
          policyNumber: 'P-123',
          expiryDate: insDate,
        ),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      await repository.updateDiver(updated);

      final read = await repository.getDiverById('d2');
      expect(read!.emergencyContact.name, equals('Contact A'));
      expect(read.emergencyContact.phone, equals('911'));
      expect(read.emergencyContact2.name, equals('Contact B'));
      expect(
        read.medicalClearanceExpiryDate?.millisecondsSinceEpoch,
        equals(medDate.millisecondsSinceEpoch),
      );
      expect(read.insurance.provider, equals('DAN'));
      expect(read.insurance.policyNumber, equals('P-123'));
      expect(
        read.insurance.expiryDate?.millisecondsSinceEpoch,
        equals(insDate.millisecondsSinceEpoch),
      );
    });
  });

  group('setDefaultDiver', () {
    test('clears previous default and sets new one', () async {
      await insertDiverRow('d1', name: 'One', isDefault: true);
      await insertDiverRow('d2', name: 'Two', isDefault: false);
      await insertDiverRow('d3', name: 'Three', isDefault: false);

      await repository.setDefaultDiver('d2');

      final all = await repository.getAllDivers();
      final byId = {for (final d in all) d.id: d};
      expect(byId['d1']!.isDefault, isFalse);
      expect(byId['d2']!.isDefault, isTrue);
      expect(byId['d3']!.isDefault, isFalse);
    });

    test('setting current default keeps it as default', () async {
      await insertDiverRow('d1', isDefault: true);

      await repository.setDefaultDiver('d1');

      final all = await repository.getAllDivers();
      expect(all.single.isDefault, isTrue);
    });
  });

  group('getDiveCountForDiver', () {
    test('returns 0 when diver has no dives', () async {
      await insertDiverRow('d1');
      expect(await repository.getDiveCountForDiver('d1'), equals(0));
    });

    test('returns count of dives for this diver only', () async {
      await insertDiverRow('d1');
      await insertDiverRow('d2');
      await insertDiveRow('dive-1', diverId: 'd1');
      await insertDiveRow('dive-2', diverId: 'd1');
      await insertDiveRow('dive-3', diverId: 'd1');
      await insertDiveRow('dive-4', diverId: 'd2');

      expect(await repository.getDiveCountForDiver('d1'), equals(3));
      expect(await repository.getDiveCountForDiver('d2'), equals(1));
    });
  });

  group('getTotalBottomTimeForDiver', () {
    test('returns 0 when diver has no dives', () async {
      await insertDiverRow('d1');
      expect(await repository.getTotalBottomTimeForDiver('d1'), equals(0));
    });

    test('sums bottom_time for this diver only', () async {
      await insertDiverRow('d1');
      await insertDiverRow('d2');
      await insertDiveRow('dive-1', diverId: 'd1', bottomTime: 1800);
      await insertDiveRow('dive-2', diverId: 'd1', bottomTime: 2400);
      await insertDiveRow('dive-3', diverId: 'd2', bottomTime: 3000);

      expect(await repository.getTotalBottomTimeForDiver('d1'), equals(4200));
      expect(await repository.getTotalBottomTimeForDiver('d2'), equals(3000));
    });
  });

  group('active diver id in settings', () {
    test('round-trips a diverId through setActive/getActive', () async {
      expect(await repository.getActiveDiverIdFromSettings(), isNull);

      await repository.setActiveDiverIdInSettings('active-1');
      expect(
        await repository.getActiveDiverIdFromSettings(),
        equals('active-1'),
      );
    });

    test('setActiveDiverIdInSettings(null) clears the stored id', () async {
      await repository.setActiveDiverIdInSettings('active-1');
      expect(
        await repository.getActiveDiverIdFromSettings(),
        equals('active-1'),
      );

      await repository.setActiveDiverIdInSettings(null);
      expect(await repository.getActiveDiverIdFromSettings(), isNull);
    });

    test('setActiveDiverIdInSettings overwrites a previous value', () async {
      await repository.setActiveDiverIdInSettings('one');
      await repository.setActiveDiverIdInSettings('two');
      expect(await repository.getActiveDiverIdFromSettings(), equals('two'));
    });
  });

  group('_mapRowToDiver populates optional date fields', () {
    test(
      'medicalClearanceExpiryDate and insurance expiry survive round-trip',
      () async {
        final medDate = DateTime(2025, 12, 25);
        final insDate = DateTime(2027, 6, 6);

        final d = Diver(
          id: '',
          name: 'Has Dates',
          medicalClearanceExpiryDate: medDate,
          insurance: DiverInsurance(
            provider: 'PADI',
            policyNumber: 'X1',
            expiryDate: insDate,
          ),
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );
        final created = await repository.createDiver(d);

        final read = await repository.getDiverById(created.id);
        expect(read, isNotNull);
        expect(
          read!.medicalClearanceExpiryDate?.millisecondsSinceEpoch,
          equals(medDate.millisecondsSinceEpoch),
        );
        expect(
          read.insurance.expiryDate?.millisecondsSinceEpoch,
          equals(insDate.millisecondsSinceEpoch),
        );
      },
    );
  });

  group('DeleteDiverResult.hasReassignments', () {
    test('false when both counts are zero', () {
      const r = DeleteDiverResult(
        reassignedTripsCount: 0,
        reassignedSitesCount: 0,
      );
      expect(r.hasReassignments, isFalse);
    });

    test('true when trips count > 0', () {
      const r = DeleteDiverResult(
        reassignedTripsCount: 1,
        reassignedSitesCount: 0,
      );
      expect(r.hasReassignments, isTrue);
    });

    test('true when sites count > 0', () {
      const r = DeleteDiverResult(
        reassignedTripsCount: 0,
        reassignedSitesCount: 5,
      );
      expect(r.hasReassignments, isTrue);
    });

    test('carries target id and name when populated', () {
      const r = DeleteDiverResult(
        reassignedTripsCount: 2,
        reassignedSitesCount: 3,
        reassignedToDiverId: 'd-other',
        reassignedToDiverName: 'Other Diver',
      );
      expect(r.hasReassignments, isTrue);
      expect(r.reassignedToDiverId, equals('d-other'));
      expect(r.reassignedToDiverName, equals('Other Diver'));
    });
  });
}
