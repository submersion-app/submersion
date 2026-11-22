import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/data/services/certification_edit_save_service.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart'
    as domain;
import 'package:submersion/features/certifications/presentation/editing/certification_edit_fields.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A certification page's sitting is written as one History entry, and
/// writes only what it changed (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late CertificationRepository certifications;
  late CertificationEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<domain.Certification> stored([String id = 'c1']) async =>
      (await certifications.getCertificationById(id))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<({domain.Certification before, domain.Certification after})?> save(
    EditSession<domain.Certification> session,
  ) => service.save(
    certificationId: session.stored.id,
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
  );

  Future<void> insertCert(String id, {int? issued}) => db
      .into(db.certifications)
      .insert(
        CertificationsCompanion(
          id: Value(id),
          diverId: const Value('d'),
          name: Value('Open Water $id'),
          agency: const Value('padi'),
          level: const Value('openWater'),
          cardNumber: const Value('123'),
          issueDate: Value(issued),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    certifications = CertificationRepository();
    service = CertificationEditSaveService(certifications);
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('d'),
            name: Value('D'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await db
        .into(db.courses)
        .insert(
          const CoursesCompanion(
            id: Value('k1'),
            diverId: Value('d'),
            name: Value('Open Water'),
            agency: Value('padi'),
            startDate: Value(0),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await db.customStatement(
      "INSERT INTO buddies (id, name, created_at, updated_at) "
      "VALUES ('b9', 'Sam', 0, 0)",
    );
    await insertCert('c1', issued: 2000);
    await insertCert('c2', issued: 1000);
    await CourseRepository().setCourseCertifications('k1', ['c1', 'c2']);
    // A card with a front image, written through the repository.
    await certifications.updateCertification(
      (await stored()).copyWith(photoFront: Uint8List.fromList([1, 2, 3])),
    );
    // What setup wrote is not a sitting.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('writes a card number change as one History entry', () async {
    final session = EditSession(await stored())
      ..set(certificationCardNumberField, '456');

    final result = await save(session);

    expect((await stored()).cardNumber, '456');
    expect(result!.before.cardNumber, '123');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:certifications:c1:details');
  });

  // One case per column the certification's update writes: a value changed
  // in storage during the sitting, on a field the diver did not touch,
  // survives the Save.
  final census =
      <String, ({String sql, bool Function(domain.Certification) kept})>{
        'name': (
          sql: "UPDATE certifications SET name = 'Renamed'",
          kept: (c) => c.name == 'Renamed',
        ),
        'agency': (
          sql: "UPDATE certifications SET agency = 'ssi'",
          kept: (c) => c.agency == 'ssi',
        ),
        'level': (
          sql: "UPDATE certifications SET level = 'advancedOpenWater'",
          kept: (c) => c.level == 'advancedOpenWater',
        ),
        'additional credentials': (
          sql:
              'UPDATE certifications SET additional_credentials = '
              '\'[{"agency":"cmas","level":"cmas1Star"}]\'',
          kept: (c) => c.additionalCredentials.single.agency == 'cmas',
        ),
        'issue date': (
          sql: 'UPDATE certifications SET issue_date = 5000',
          kept: (c) => c.issueDate?.millisecondsSinceEpoch == 5000,
        ),
        'expiry date': (
          sql: 'UPDATE certifications SET expiry_date = 9000',
          kept: (c) => c.expiryDate?.millisecondsSinceEpoch == 9000,
        ),
        'instructor name': (
          sql: "UPDATE certifications SET instructor_name = 'Sam'",
          kept: (c) => c.instructorName == 'Sam',
        ),
        'instructor number': (
          sql: "UPDATE certifications SET instructor_number = '77'",
          kept: (c) => c.instructorNumber == '77',
        ),
        'instructor id': (
          sql: "UPDATE certifications SET instructor_id = 'b9'",
          kept: (c) => c.instructorId == 'b9',
        ),
        'notes': (
          sql: "UPDATE certifications SET notes = 'Newer'",
          kept: (c) => c.notes == 'Newer',
        ),
        'card number': (
          sql: "UPDATE certifications SET card_number = '999'",
          kept: (c) => c.cardNumber == '999',
        ),
      };
  for (final MapEntry(key: column, value: change) in census.entries) {
    test('a $column changed underneath keeps its newer value', () async {
      // The sitting changes a field other than the one changed underneath.
      final EditField<domain.Certification, String> touched = column == 'notes'
          ? certificationTitleField
          : certificationNotesField;
      final session = EditSession(await stored())..set(touched, 'Edited');
      await db.customStatement('${change.sql} WHERE id = ?', ['c1']);

      await save(session);

      final after = await stored();
      expect(change.kept(after), isTrue, reason: column);
      expect(touched.read(after), 'Edited');
    });
  }

  test('a card image changed underneath keeps its newer value', () async {
    final session = EditSession(await stored())
      ..set(certificationNotesField, 'Edited');
    await certifications.updateCertification(
      (await stored()).copyWith(photoFront: Uint8List.fromList([7])),
    );

    await save(session);

    expect((await stored()).photoFront, [7]);
  });

  test('new card photos are written in the same entry', () async {
    final session = EditSession(await stored())
      ..set(certificationPhotoFrontField, Uint8List.fromList([9, 9]))
      ..set(certificationPhotoBackField, Uint8List.fromList([8]));

    await save(session);

    final after = await stored();
    expect(after.photoFront, [9, 9]);
    expect(after.photoBack, [8]);
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['label'], 'record_edit:certifications:c1:cardPhotos');
  });

  test('a removed card photo is removed', () async {
    final session = EditSession(await stored())
      ..set(certificationPhotoFrontField, null);

    await save(session);

    expect((await stored()).photoFront, isNull);
  });

  test('the course representative follows an earlier issue date', () async {
    Future<String?> representative() async => (await (db.select(
      db.courses,
    )..where((t) => t.id.equals('k1'))).getSingle()).certificationId;
    expect(await representative(), 'c2');
    final session = EditSession(await stored())
      ..set(certificationIssueDateField, DateTime(1960));

    await save(session);

    expect(await representative(), 'c1');
  });

  test('clearing the card number stores null', () async {
    final session = EditSession(await stored())
      ..set(certificationCardNumberField, '  ');

    await save(session);

    expect((await stored()).cardNumber, isNull);
  });

  test('unchanged returns null and writes nothing', () async {
    final result = await save(EditSession(await stored()));

    expect(result, isNull);
    expect(await operations(), isEmpty);
  });

  test('a certification that has gone throws', () async {
    final session = EditSession(await stored())
      ..set(certificationCardNumberField, '456');
    await db.customStatement("DELETE FROM certifications WHERE id = 'c1'");
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');

    await expectLater(save(session), throwsStateError);
    expect(await operations(), isEmpty);
  });

  /// A new certification's sitting (issue #4527, phase 3, plan 11).
  group('create', () {
    domain.Certification fresh({String id = 'n1'}) => domain.Certification(
      id: id,
      diverId: 'd',
      name: 'Ice Diver',
      agency: 'padi',
      photoFront: Uint8List.fromList([1, 2]),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test(
      'creates the certification with its id, as one History entry',
      () async {
        final created = await service.create(
          certification: fresh(),
          changedCardIds: const ['details'],
        );

        expect(created.id, 'n1');
        expect((await stored('n1')).name, 'Ice Diver');
        final ops = await operations();
        expect(ops, hasLength(1));
        expect(ops.single['source'], 'manual');
        expect(ops.single['label'], 'record_edit:certifications:n1:details');
      },
    );

    test('card photos are written with the row', () async {
      await service.create(
        certification: fresh(),
        changedCardIds: const ['cardPhotos'],
      );

      expect((await stored('n1')).photoFront, [1, 2]);
    });

    test('a held write that throws leaves nothing', () async {
      await expectLater(
        service.create(
          certification: fresh(),
          changedCardIds: const ['details'],
          alsoWrite: () async => throw StateError('refused'),
        ),
        throwsStateError,
      );

      expect(await certifications.getCertificationById('n1'), isNull);
      expect(await operations(), isEmpty);
    });

    test('an empty id or one already stored is refused', () async {
      await expectLater(
        service.create(
          certification: fresh(id: ''),
          changedCardIds: const [],
        ),
        throwsStateError,
      );
      await expectLater(
        service.create(
          certification: fresh(id: 'c1'),
          changedCardIds: const [],
        ),
        throwsStateError,
      );
      expect(await operations(), isEmpty);
    });
  });
}
