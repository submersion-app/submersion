import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_record_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/wait_until.dart';

/// Issue #4496: a buddy's certification chip on the list is derived from the
/// `certifications` table at read time. Saving the buddy edit form writes the
/// `buddies` row first (the lists reload, still reading the old cert) and the
/// certifications after, so a provider that follows only the `buddies` tick
/// keeps showing the old level until something else reloads it. Each case
/// here writes ONLY certifications rows and expects the provider to follow.
void main() {
  late SharedPreferences prefs;
  late BuddyRepository buddyRepo;
  late CertificationRepository certRepo;
  late String buddyId;
  late String diverId;

  final twoStar = CertificationLevel.cmas2StarDiver.name;
  final threeStar = CertificationLevel.cmas3StarDiver.name;

  Certification cmasCert(String level) => Certification(
    id: '',
    buddyId: buddyId,
    name: level,
    agency: CertificationAgency.cmas.name,
    level: level,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    buddyRepo = BuddyRepository();
    certRepo = CertificationRepository();

    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    diverId = diver.id;
    await prefs.setString(currentDiverIdKey, diver.id);
    final buddy = await buddyRepo.createBuddy(
      Buddy(
        id: '',
        name: 'Joachim',
        diverId: diver.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    buddyId = buddy.id;
    await certRepo.createCertification(cmasCert(twoStar));
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Upgrades the buddy's only cert from 2 star to 3 star the way the buddy
  /// edit form commits it: a certifications-only write, no `buddies` tick.
  Future<void> upgradeCert() async {
    final current = await certRepo.getCertificationsByBuddy(buddyId);
    await certRepo.replaceBuddyCertifications(buddyId, [
      current.single.copyWith(name: threeStar, level: threeStar),
    ]);
  }

  /// Keeps [provider] alive, checks it starts on 2 star, upgrades the cert and
  /// waits for [levelOf] to read 3 star.
  Future<void> expectFollowsCertChange<T>(
    ProviderListenable<AsyncValue<T>> provider,
    Future<T> Function(ProviderContainer) read,
    String? Function(T) levelOf,
  ) async {
    final container = makeContainer();
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    expect(levelOf(await read(container)), twoStar);
    await upgradeCert();
    await waitUntil(() async => levelOf(await read(container)) == threeStar);
  }

  String? levelIn(List<Buddy> buddies) =>
      buddies.firstWhere((b) => b.id == buddyId).certificationLevel;

  String? levelInCounted(List<BuddyWithDiveCount> buddies) =>
      buddies.firstWhere((b) => b.buddy.id == buddyId).buddy.certificationLevel;

  group('buddy providers follow a certifications-only write (#4496)', () {
    test('allBuddiesProvider', () async {
      await expectFollowsCertChange(
        allBuddiesProvider,
        (c) => c.read(allBuddiesProvider.future),
        levelIn,
      );
    });

    test('allBuddiesWithDiveCountProvider', () async {
      await expectFollowsCertChange(
        allBuddiesWithDiveCountProvider,
        (c) => c.read(allBuddiesWithDiveCountProvider.future),
        levelInCounted,
      );
    });

    test('buddySearchWithDiveCountProvider', () async {
      await expectFollowsCertChange(
        buddySearchWithDiveCountProvider('joa'),
        (c) => c.read(buddySearchWithDiveCountProvider('joa').future),
        levelInCounted,
      );
    });

    test('buddySearchProvider', () async {
      await expectFollowsCertChange(
        buddySearchProvider('joa'),
        (c) => c.read(buddySearchProvider('joa').future),
        levelIn,
      );
    });

    test('buddyByIdProvider', () async {
      await expectFollowsCertChange(
        buddyByIdProvider(buddyId),
        (c) => c.read(buddyByIdProvider(buddyId).future),
        (b) => b?.certificationLevel,
      );
    });

    test('globalSearchBuddiesProvider', () async {
      await expectFollowsCertChange(
        globalSearchBuddiesProvider(buddyId),
        (c) => c.read(globalSearchBuddiesProvider(buddyId).future),
        levelInCounted,
      );
    });

    test('BuddyListNotifier', () async {
      await expectFollowsCertChange(buddyListNotifierProvider, (c) async {
        await waitUntil(() async => c.read(buddyListNotifierProvider).hasValue);
        return c.read(buddyListNotifierProvider).requireValue;
      }, levelIn);
    });
  });

  group('watchHydratedBuddiesChanges (#4496)', () {
    // A custom agency or level ranks and titles the primary cert, so a write
    // to either must reach the buddy readers like a certifications write.
    test('ticks on a custom agency and a custom level write', () async {
      final customRepo = CustomCertificationRepository();

      var tick = buddyRepo.watchHydratedBuddiesChanges().first;
      final agency = await customRepo.createAgency(
        diverId: diverId,
        name: 'Club',
        isShared: false,
      );
      await tick.timeout(const Duration(seconds: 10));

      tick = buddyRepo.watchHydratedBuddiesChanges().first;
      await customRepo.createLevel(
        diverId: diverId,
        agencyId: agency.id,
        name: 'Club Diver',
        isProgression: true,
        isShared: false,
      );
      await tick.timeout(const Duration(seconds: 10));
    });
  });
}
