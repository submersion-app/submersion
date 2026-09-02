import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/marine_life/data/services/builtin_species_seed_version_store.dart';

void main() {
  test('reads 0 when nothing was applied, then round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsBuiltInSpeciesSeedVersionStore(
      await SharedPreferences.getInstance(),
    );

    expect(await store.appliedVersion(), 0);
    await store.markApplied(2);
    expect(await store.appliedVersion(), 2);
    await store.clear();
    expect(await store.appliedVersion(), 0);
  });

  test('a malformed stored value reads as 0', () async {
    SharedPreferences.setMockInitialValues({
      PrefsBuiltInSpeciesSeedVersionStore.key: 'two',
    });
    final store = PrefsBuiltInSpeciesSeedVersionStore(
      await SharedPreferences.getInstance(),
    );

    expect(await store.appliedVersion(), 0);
  });
}
