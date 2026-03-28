import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('CertificationRepository error handling', () {
    late CertificationRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = CertificationRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final cert = Certification(
        id: 'c1',
        name: 'Open Water',
        agency: CertificationAgency.padi,
        createdAt: now,
        updatedAt: now,
      );

      // getAllCertifications - rethrows
      await expectLater(repository.getAllCertifications(), throwsA(anything));

      // getCertificationById - rethrows
      await expectLater(
        repository.getCertificationById('c1'),
        throwsA(anything),
      );

      // createCertification - rethrows
      await expectLater(
        repository.createCertification(cert),
        throwsA(anything),
      );

      // updateCertification - rethrows
      await expectLater(
        repository.updateCertification(cert),
        throwsA(anything),
      );

      // deleteCertification - rethrows
      await expectLater(
        repository.deleteCertification('c1'),
        throwsA(anything),
      );
    });
  });
}
