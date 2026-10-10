import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/services/dive_participant_names.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';

/// Regression tests for issue #3039: the home tab's Recent dives showed no
/// Buddy, while the same dive on the Dives tab did. The Dives tab reads
/// `getAllDives`, which loads the `dive_buddies` junction; the home card
/// hydrated each dive through `getDiveById`, which does not.
void main() {
  late DiveRepository dives;
  late BuddyRepository buddies;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    dives = DiveRepository();
    buddies = BuddyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Buddy> person(String name) {
    final now = DateTime(2026, 1, 1);
    return buddies.createBuddy(
      Buddy(id: '', name: name, createdAt: now, updatedAt: now),
    );
  }

  test('recent dives carry the buddies recorded on each dive', () async {
    await dives.createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final ana = await person('Ana Reyes');
    await buddies.addBuddyToDive('d1', ana.id, DiveRole.buddyId);

    final container = makeContainer();
    final recent = await container.read(recentDivesProvider.future);

    expect(recent.single.resolvedBuddyNames, 'Ana Reyes');
  });

  test('renaming a buddy refreshes the card without a dive write', () async {
    await dives.createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final ana = await person('Ana Reyes');
    await buddies.addBuddyToDive('d1', ana.id, DiveRole.buddyId);

    final container = makeContainer();
    final onScreen = container.listen(recentDivesProvider, (_, _) {});
    addTearDown(onScreen.close);
    final initial = await container.read(recentDivesProvider.future);
    expect(initial.single.resolvedBuddyNames, 'Ana Reyes');

    // A rename writes only `buddies`, and a sync pull of a buddy link only
    // `dive_buddies` (#1769); neither restamps the dive, so the card must
    // also listen to the buddy link tables.
    await buddies.updateBuddy(ana.copyWith(name: 'Ana Ortiz'));

    String? names;
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final recent = await container.read(recentDivesProvider.future);
      names = recent.single.resolvedBuddyNames;
      if (names == 'Ana Ortiz') break;
    }
    expect(names, 'Ana Ortiz');
  });
}
