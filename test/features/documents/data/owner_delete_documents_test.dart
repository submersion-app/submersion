import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../helpers/test_database.dart';

/// Every owner's delete path takes its documents with it, tombstoned
/// (issue #2613). Without the explicit cleanup the schema's SET NULL would
/// silently turn them into personal documents and peers would keep them.
const _now = 1700000000000;

Future<int> _docCount(AppDatabase db) async =>
    (await db.customSelect('SELECT COUNT(*) AS n FROM documents').getSingle())
        .read<int>('n');

Future<int> _tombstones(AppDatabase db, String entity) async =>
    (await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = ?',
              variables: [Variable.withString(entity)],
            )
            .getSingle())
        .read<int>('n');

Future<void> _addDoc(DocumentOwnerKind kind, String ownerId) =>
    DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: DocumentOwner(kind, ownerId),
        type: DocumentType.other,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [
        DocumentPage(
          id: '',
          documentId: '',
          pageIndex: 0,
          fileName: 'a.txt',
          mimeType: 'text/plain',
          sizeBytes: 1,
          bytes: Uint8List.fromList([1]),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Ana',
            isDefault: const Value(true),
            createdAt: _now,
            updatedAt: _now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<void> expectGone() async {
    expect(await _docCount(db), 0);
    expect(await _tombstones(db, 'documents'), 1);
    expect(await _tombstones(db, 'documentPages'), 1);
  }

  Future<void> seedCert(String id, {String? buddyId}) => db
      .into(db.certifications)
      .insert(
        CertificationsCompanion.insert(
          id: id,
          diverId: Value(buddyId == null ? 'd1' : null),
          buddyId: Value(buddyId),
          name: 'Open Water',
          agency: 'padi',
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  Future<void> seedBuddy(String id) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          diverId: const Value('d1'),
          name: 'Bo',
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  test('deleting a certification deletes its documents', () async {
    await seedCert('c1');
    await _addDoc(DocumentOwnerKind.certification, 'c1');
    await CertificationRepository().deleteCertification('c1');
    await expectGone();
  });

  test('deleting a buddy deletes their documents', () async {
    await seedBuddy('b1');
    await _addDoc(DocumentOwnerKind.buddy, 'b1');
    await BuddyRepository().deleteBuddy('b1');
    await expectGone();
  });

  test('deleting a buddy deletes their certifications documents', () async {
    await seedBuddy('b1');
    await seedCert('c2', buddyId: 'b1');
    await _addDoc(DocumentOwnerKind.certification, 'c2');
    await BuddyRepository().deleteBuddy('b1');
    await expectGone();
  });

  test(
    'bulk deleting buddies deletes their certifications documents',
    () async {
      await seedBuddy('b1');
      await seedCert('c2', buddyId: 'b1');
      await _addDoc(DocumentOwnerKind.certification, 'c2');
      await BuddyRepository().bulkDeleteBuddies(['b1']);
      await expectGone();
    },
  );

  test('deleting a trip deletes its documents', () async {
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            diverId: const Value('d1'),
            name: 'Bonaire',
            startDate: _now,
            endDate: _now,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await _addDoc(DocumentOwnerKind.trip, 't1');
    expect(await TripRepository().deleteTrip('t1', actingDiverId: 'd1'), true);
    await expectGone();
  });

  test('a document refiled under a trip leaves with the trip', () async {
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            diverId: const Value('d1'),
            name: 'Bonaire',
            startDate: _now,
            endDate: _now,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    final repo = DocumentRepository();
    final personal = await repo.save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.other,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    await repo.save(
      personal.copyWith(
        owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
      ),
      const [],
    );
    expect(await TripRepository().deleteTrip('t1', actingDiverId: 'd1'), true);
    expect(await _docCount(db), 0);
  });

  test('deleting a site deletes its documents', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            diverId: const Value('d1'),
            name: 'Reef',
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await _addDoc(DocumentOwnerKind.site, 's1');
    await SiteRepository().deleteSite('s1', actingDiverId: 'd1');
    await expectGone();
  });

  test('deleting a dive deletes its documents', () async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'v1',
            diverId: const Value('d1'),
            diveDateTime: _now,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await _addDoc(DocumentOwnerKind.dive, 'v1');
    await DiveRepository().deleteDive('v1');
    await expectGone();
  });

  test('bulk deleting dives deletes their documents', () async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'v1',
            diverId: const Value('d1'),
            diveDateTime: _now,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await _addDoc(DocumentOwnerKind.dive, 'v1');
    await DiveRepository().bulkDeleteDives(['v1']);
    await expectGone();
  });

  test('deleting equipment deletes its documents', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'e1',
            diverId: const Value('d1'),
            name: 'Reg',
            type: 'regulator',
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await _addDoc(DocumentOwnerKind.equipment, 'e1');
    await EquipmentRepository().deleteEquipment('e1');
    await expectGone();
  });

  test('deleting a course deletes its documents', () async {
    await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            id: 'k1',
            diverId: 'd1',
            name: 'AOW',
            agency: 'padi',
            startDate: _now,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await _addDoc(DocumentOwnerKind.course, 'k1');
    await CourseRepository().deleteCourse('k1');
    await expectGone();
  });

  test('deleting a dive center deletes its documents', () async {
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'x1',
            diverId: const Value('d1'),
            name: 'Buddy Dive',
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await _addDoc(DocumentOwnerKind.diveCenter, 'x1');
    await DiveCenterRepository().deleteDiveCenter('x1');
    await expectGone();
  });

  test('deleting a diver deletes every document they filed', () async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd2',
            name: 'Ben',
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd2',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    await DiverRepository().deleteDiverWithReassignment('d2');
    expect(await _docCount(db), 0);
    expect(await _tombstones(db, 'documents'), 1);
  });

  test('deleting a diver cancels their documents\' reminders', () async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd2',
            name: 'Ben',
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    final doc = await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd2',
        owner: const DocumentOwner.personal(),
        type: DocumentType.permit,
        expiryDate: DateTime(2030),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    final cancelled = <String>[];
    await DiverRepository(
      documentRepository: DocumentRepository(
        cancelReminders: (id) async => cancelled.add(id),
      ),
    ).deleteDiverWithReassignment('d2');
    expect(cancelled, [doc.id]);
  });
}
