import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  Future<Diver> seedCurrentDiver() async {
    final diverRepo = DiverRepository();
    final diver = await diverRepo.createDiver(
      Diver(
        id: '',
        name: 'Test Diver',
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    return diver;
  }

  test(
    'allBuddyCertificationsProvider maps buddy ids to their certs',
    () async {
      final diver = await seedCurrentDiver();
      final now = DateTime.now();

      final buddyRepo = BuddyRepository();
      final certRepo = CertificationRepository();

      final buddy = await buddyRepo.createBuddy(
        Buddy(
          id: '',
          name: 'Alice',
          diverId: diver.id,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await certRepo.createCertification(
        Certification(
          id: '',
          buddyId: buddy.id,
          name: 'Instructor',
          agency: CertificationAgency.padi,
          level: CertificationLevel.instructor,
          cardNumber: '12345',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      final map = await container.read(allBuddyCertificationsProvider.future);
      expect(map[buddy.id], hasLength(1));
      expect(map[buddy.id]!.single.level, CertificationLevel.instructor);
    },
  );
}
