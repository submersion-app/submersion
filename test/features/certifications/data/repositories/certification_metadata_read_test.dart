import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';

import '../../../../helpers/test_database.dart';

/// Metadata reads leave the scanned cards behind (issue #3848): they are the
/// reads a screen that draws no card uses, and a certification read this way
/// must not cost its card when it is saved back.
void main() {
  late AppDatabase db;
  late CertificationRepository repo;

  setUp(() async {
    db = await setUpStatementLoggingTestDatabase();
    repo = CertificationRepository();
    await withoutStatementLog(() async {
      await db.customStatement(
        'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
        "VALUES ('d1', 'Ana', 1, 0, 0), ('d2', 'Bo', 0, 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
        "VALUES ('b1', 'd1', 'Sam', 0, 0)",
      );
    });
  });
  tearDown(tearDownTestDatabase);

  Certification cert({
    required String id,
    String? diverId = 'd1',
    String? buddyId,
    String name = 'Open Water',
    DateTime? issueDate,
    Uint8List? front,
    Uint8List? back,
  }) => Certification(
    id: id,
    diverId: buddyId == null ? diverId : null,
    buddyId: buddyId,
    name: name,
    agency: 'padi',
    level: 'openWater',
    additionalCredentials: const [
      CertificationCredential(agency: 'cmas', level: 'cmas1StarDiver'),
    ],
    cardNumber: 'N-$id',
    issueDate: issueDate,
    expiryDate: DateTime(2030),
    instructorName: 'Ines',
    instructorNumber: '7',
    notes: 'kept',
    photoFront: front,
    photoBack: back,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> seed(List<Certification> certs) => withoutStatementLog(() async {
    for (final c in certs) {
      await repo.createCertification(c);
    }
  });

  Future<List<String>> statementsDuring(Future<void> Function() body) async {
    final logged = <String>[];
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    return [
      for (final line in logged)
        if (line.startsWith('Drift: Sent')) line,
    ];
  }

  void expectNoCardBlobs(List<String> statements) {
    expect(statements, isNotEmpty);
    for (final statement in statements) {
      expect(statement, isNot(contains('document_pages')));
      expect(statement, isNot(contains('photo_front')));
      expect(statement, isNot(contains('SELECT *')));
    }
  }

  group('getCertificationMetadata', () {
    test('matches getAllCertifications field for field and in order', () async {
      await seed([
        cert(id: 'old', name: 'Rescue', issueDate: DateTime(2020)),
        cert(id: 'new', name: 'Nitrox', issueDate: DateTime(2024)),
        cert(id: 'undated', name: 'Deep'),
      ]);

      final full = await withoutStatementLog(repo.getAllCertifications);
      final metadata = await withoutStatementLog(repo.getCertificationMetadata);

      expect([for (final c in metadata) c.id], ['new', 'old', 'undated']);
      expect(metadata.map((c) => c.copyWith(cardImagesLoaded: true)), full);
    });

    test('keeps to the diver it is asked for', () async {
      await seed([cert(id: 'mine'), cert(id: 'theirs', diverId: 'd2')]);

      final metadata = await withoutStatementLog(
        () => repo.getCertificationMetadata(diverId: 'd2'),
      );

      expect([for (final c in metadata) c.id], ['theirs']);
    });

    test('leaves the card images behind', () async {
      await seed([
        cert(
          id: 'c1',
          front: Uint8List.fromList([1]),
          back: Uint8List.fromList([2]),
        ),
      ]);

      late List<Certification> metadata;
      final statements = await statementsDuring(() async {
        metadata = await repo.getCertificationMetadata();
      });

      expectNoCardBlobs(statements);
      expect(metadata.single.photoFront, isNull);
      expect(metadata.single.photoBack, isNull);
      expect(metadata.single.cardImagesLoaded, isFalse);
    });
  });

  test('a full read says its card images are loaded', () async {
    await seed([cert(id: 'c1')]);

    final full = await withoutStatementLog(repo.getAllCertifications);
    final byId = await withoutStatementLog(
      () => repo.getCertificationById('c1'),
    );

    expect(full.single.cardImagesLoaded, isTrue);
    expect(byId!.cardImagesLoaded, isTrue);
  });

  test('saving a metadata certification keeps its card', () async {
    final front = Uint8List.fromList([1]);
    final back = Uint8List.fromList([2]);
    await seed([cert(id: 'c1', front: front, back: back)]);

    await withoutStatementLog(() async {
      final metadata = (await repo.getCertificationMetadata()).single;
      await repo.updateCertification(metadata.copyWith(name: 'Renamed'));
    });

    final read = (await withoutStatementLog(
      () => repo.getCertificationById('c1'),
    ))!;
    expect(read.name, 'Renamed');
    expect(read.photoFront, front);
    expect(read.photoBack, back);
    final images = await withoutStatementLog(
      () => DocumentRepository().cardImagesFor(['c1']),
    );
    expect(images['c1']?.front, front);
  });

  test('searchCertifications leaves the card images behind', () async {
    await seed([
      cert(id: 'c1', front: Uint8List.fromList([1])),
    ]);

    late List<Certification> found;
    final statements = await statementsDuring(() async {
      found = await repo.searchCertifications('open');
    });

    expectNoCardBlobs(statements);
    expect(found.single.id, 'c1');
    expect(found.single.cardImagesLoaded, isFalse);
  });

  test('getCertificationsForBuddies leaves the card images behind', () async {
    await seed([
      cert(id: 'c1', buddyId: 'b1', front: Uint8List.fromList([1])),
    ]);

    late Map<String, List<Certification>> found;
    final statements = await statementsDuring(() async {
      found = await repo.getCertificationsForBuddies(['b1', 'nobody']);
    });

    expectNoCardBlobs(statements);
    expect(found.keys, ['b1']);
    expect(found['b1']!.single.cardNumber, 'N-c1');
    expect(found['b1']!.single.cardImagesLoaded, isFalse);
  });

  test('getCertificationMetadataByBuddy leaves the card images behind and '
      'lists the newest first', () async {
    await seed([
      cert(
        id: 'old',
        buddyId: 'b1',
        name: 'Rescue',
        issueDate: DateTime(2020),
        front: Uint8List.fromList([1]),
      ),
      cert(id: 'new', buddyId: 'b1', name: 'Nitrox', issueDate: DateTime(2024)),
      cert(id: 'mine'),
    ]);

    late List<Certification> found;
    final statements = await statementsDuring(() async {
      found = await repo.getCertificationMetadataByBuddy('b1');
    });

    expectNoCardBlobs(statements);
    expect([for (final c in found) c.id], ['new', 'old']);
    final full = await withoutStatementLog(
      () => repo.getCertificationsByBuddy('b1'),
    );
    expect(full.map((c) => c.id), found.map((c) => c.id));
    expect(full.last.photoFront, [1]);
  });
}
