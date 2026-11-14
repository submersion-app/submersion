import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// diverCertificationsLoaderProvider (#4458): a dive's PDF export carries its
/// owner's cards, whichever profile is active.
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

  Future<Diver> diver(String name) => DiverRepository().createDiver(
    Diver(
      id: '',
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  Future<void> certify(Diver diver, String name) =>
      CertificationRepository().createCertification(
        Certification(
          id: '',
          diverId: diver.id,
          name: name,
          agency: CertificationAgency.padi.name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

  test("loads the given diver's cards, not the active diver's", () async {
    final active = await diver('Active');
    final owner = await diver('Owner');
    await certify(active, 'Rescue Diver');
    await certify(owner, 'Open Water');
    await prefs.setString(currentDiverIdKey, active.id);

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final cards = await container.read(diverCertificationsLoaderProvider)(
      owner.id,
    );

    expect(cards.map((c) => c.name), ['Open Water']);
  });
}
