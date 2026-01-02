import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late CertificationRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = CertificationRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Certification createTestCert({
    String id = '',
    String name = 'Open Water Diver',
    CertificationAgency agency = CertificationAgency.padi,
    CertificationLevel? level,
    String? cardNumber,
    DateTime? issueDate,
    DateTime? expiryDate,
    String? instructorName,
    String notes = '',
  }) {
    final now = DateTime.now();
    return Certification(
      id: id,
      name: name,
      agency: agency,
      level: level,
      cardNumber: cardNumber,
      issueDate: issueDate,
      expiryDate: expiryDate,
      instructorName: instructorName,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('CertificationRepository', () {
    group('createCertification', () {
      test('should create a new cert with generated ID when ID is empty',
          () async {
        final cert = createTestCert(name: 'Advanced Open Water');

        final createdCert = await repository.createCertification(cert);

        expect(createdCert.id, isNotEmpty);
        expect(createdCert.name, equals('Advanced Open Water'));
      });

      test('should create a cert with provided ID', () async {
        final cert = createTestCert(id: 'custom-cert-id', name: 'Rescue Diver');

        final createdCert = await repository.createCertification(cert);

        expect(createdCert.id, equals('custom-cert-id'));
      });

      test('should create a cert with all fields', () async {
        final issueDate = DateTime(2023, 6, 15);
        final expiryDate = DateTime(2025, 6, 15);
        final cert = createTestCert(
          name: 'Nitrox Diver',
          agency: CertificationAgency.ssi,
          level: CertificationLevel.nitrox,
          cardNumber: 'SSI-12345',
          issueDate: issueDate,
          expiryDate: expiryDate,
          instructorName: 'John Smith',
          notes: 'EAN32/EAN36 certified',
        );

        final createdCert = await repository.createCertification(cert);
        final fetchedCert =
            await repository.getCertificationById(createdCert.id);

        expect(fetchedCert, isNotNull);
        expect(fetchedCert!.name, equals('Nitrox Diver'));
        expect(fetchedCert.agency, equals(CertificationAgency.ssi));
        expect(fetchedCert.level, equals(CertificationLevel.nitrox));
        expect(fetchedCert.cardNumber, equals('SSI-12345'));
        expect(fetchedCert.issueDate?.year, equals(2023));
        expect(fetchedCert.issueDate?.month, equals(6));
        expect(fetchedCert.expiryDate?.year, equals(2025));
        expect(fetchedCert.instructorName, equals('John Smith'));
        expect(fetchedCert.notes, equals('EAN32/EAN36 certified'));
      });
    });

    group('getCertificationById', () {
      test('should return cert when found', () async {
        final cert = await repository.createCertification(
          createTestCert(name: 'Find Me Cert'),
        );

        final result = await repository.getCertificationById(cert.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Find Me Cert'));
      });

      test('should return null when cert not found', () async {
        final result = await repository.getCertificationById('non-existent-id');

        expect(result, isNull);
      });
    });

    group('getAllCertifications', () {
      test('should return empty list when no certs exist', () async {
        final result = await repository.getAllCertifications();

        expect(result, isEmpty);
      });

      test('should return all certs ordered by issue date (newest first)',
          () async {
        await repository.createCertification(
          createTestCert(
            name: 'Old Cert',
            issueDate: DateTime(2020, 1, 1),
          ),
        );
        await repository.createCertification(
          createTestCert(
            name: 'New Cert',
            issueDate: DateTime(2023, 6, 1),
          ),
        );
        await repository.createCertification(
          createTestCert(
            name: 'Middle Cert',
            issueDate: DateTime(2022, 3, 1),
          ),
        );

        final result = await repository.getAllCertifications();

        expect(result.length, equals(3));
        expect(result[0].name, equals('New Cert'));
        expect(result[1].name, equals('Middle Cert'));
        expect(result[2].name, equals('Old Cert'));
      });
    });

    group('updateCertification', () {
      test('should update cert fields', () async {
        final cert = await repository.createCertification(
          createTestCert(name: 'Original Cert'),
        );

        final updatedCert = cert.copyWith(
          name: 'Updated Cert',
          cardNumber: 'NEW-12345',
          notes: 'Updated notes',
        );

        await repository.updateCertification(updatedCert);
        final result = await repository.getCertificationById(cert.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Updated Cert'));
        expect(result.cardNumber, equals('NEW-12345'));
        expect(result.notes, equals('Updated notes'));
      });

      test('should update agency and level', () async {
        final cert = await repository.createCertification(
          createTestCert(
            name: 'Level Cert',
            agency: CertificationAgency.padi,
            level: CertificationLevel.openWater,
          ),
        );

        final updatedCert = cert.copyWith(
          agency: CertificationAgency.ssi,
          level: CertificationLevel.advancedOpenWater,
        );

        await repository.updateCertification(updatedCert);
        final result = await repository.getCertificationById(cert.id);

        expect(result!.agency, equals(CertificationAgency.ssi));
        expect(result.level, equals(CertificationLevel.advancedOpenWater));
      });
    });

    group('deleteCertification', () {
      test('should delete existing cert', () async {
        final cert = await repository.createCertification(
          createTestCert(name: 'To Delete'),
        );

        await repository.deleteCertification(cert.id);
        final result = await repository.getCertificationById(cert.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent cert', () async {
        await expectLater(
          repository.deleteCertification('non-existent-id'),
          completes,
        );
      });
    });

    group('searchCertifications', () {
      setUp(() async {
        await repository.createCertification(
          createTestCert(
            name: 'Open Water Diver',
            agency: CertificationAgency.padi,
            cardNumber: 'PADI-001',
          ),
        );
        await repository.createCertification(
          createTestCert(
            name: 'Advanced Nitrox',
            agency: CertificationAgency.ssi,
            cardNumber: 'SSI-002',
          ),
        );
        await repository.createCertification(
          createTestCert(
            name: 'Rescue Diver',
            agency: CertificationAgency.naui,
            cardNumber: 'NAUI-003',
          ),
        );
      });

      test('should find certs by name', () async {
        final results = await repository.searchCertifications('Nitrox');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Advanced Nitrox'));
      });

      test('should find certs by agency', () async {
        final results = await repository.searchCertifications('PADI');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Open Water Diver'));
      });

      test('should find certs by card number', () async {
        final results = await repository.searchCertifications('NAUI-003');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Rescue Diver'));
      });

      test('should return empty list for no matches', () async {
        final results = await repository.searchCertifications('NonExistent');

        expect(results, isEmpty);
      });

      test('should be case insensitive', () async {
        final results = await repository.searchCertifications('rescue');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Rescue Diver'));
      });
    });

    group('getCertificationsByAgency', () {
      setUp(() async {
        await repository.createCertification(
          createTestCert(
            name: 'PADI Cert 1',
            agency: CertificationAgency.padi,
          ),
        );
        await repository.createCertification(
          createTestCert(
            name: 'PADI Cert 2',
            agency: CertificationAgency.padi,
          ),
        );
        await repository.createCertification(
          createTestCert(
            name: 'SSI Cert',
            agency: CertificationAgency.ssi,
          ),
        );
      });

      test('should return certs for specified agency', () async {
        final results = await repository
            .getCertificationsByAgency(CertificationAgency.padi);

        expect(results.length, equals(2));
        expect(
          results.every((c) => c.agency == CertificationAgency.padi),
          isTrue,
        );
      });

      test('should return empty list when no certs for agency', () async {
        final results =
            await repository.getCertificationsByAgency(CertificationAgency.gue);

        expect(results, isEmpty);
      });
    });

    group('getExpiringCertifications', () {
      test('should return certs expiring within specified days', () async {
        final now = DateTime.now();

        // Cert expiring in 15 days
        await repository.createCertification(
          createTestCert(
            name: 'Expiring Soon',
            expiryDate: now.add(const Duration(days: 15)),
          ),
        );

        // Cert expiring in 60 days
        await repository.createCertification(
          createTestCert(
            name: 'Expiring Later',
            expiryDate: now.add(const Duration(days: 60)),
          ),
        );

        // Cert with no expiry
        await repository.createCertification(
          createTestCert(
            name: 'No Expiry',
            expiryDate: null,
          ),
        );

        final results = await repository.getExpiringCertifications(30);

        expect(results.length, equals(1));
        expect(results[0].name, equals('Expiring Soon'));
      });

      test('should not include already expired certs', () async {
        final now = DateTime.now();

        // Already expired
        await repository.createCertification(
          createTestCert(
            name: 'Already Expired',
            expiryDate: now.subtract(const Duration(days: 10)),
          ),
        );

        // Expiring in 15 days
        await repository.createCertification(
          createTestCert(
            name: 'Expiring Soon',
            expiryDate: now.add(const Duration(days: 15)),
          ),
        );

        final results = await repository.getExpiringCertifications(30);

        expect(results.length, equals(1));
        expect(results[0].name, equals('Expiring Soon'));
      });
    });

    group('getExpiredCertifications', () {
      test('should return only expired certs', () async {
        final now = DateTime.now();

        // Expired cert
        await repository.createCertification(
          createTestCert(
            name: 'Expired Cert',
            expiryDate: now.subtract(const Duration(days: 30)),
          ),
        );

        // Valid cert
        await repository.createCertification(
          createTestCert(
            name: 'Valid Cert',
            expiryDate: now.add(const Duration(days: 30)),
          ),
        );

        // No expiry cert
        await repository.createCertification(
          createTestCert(
            name: 'No Expiry Cert',
            expiryDate: null,
          ),
        );

        final results = await repository.getExpiredCertifications();

        expect(results.length, equals(1));
        expect(results[0].name, equals('Expired Cert'));
      });

      test('should return empty list when no expired certs', () async {
        await repository.createCertification(
          createTestCert(
            name: 'Valid Cert',
            expiryDate: DateTime.now().add(const Duration(days: 365)),
          ),
        );

        final results = await repository.getExpiredCertifications();

        expect(results, isEmpty);
      });
    });
  });
}
