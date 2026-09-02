import 'package:submersion/features/marine_life/data/services/builtin_species_seed_version_store.dart';

class InMemorySeedVersionStore implements BuiltInSpeciesSeedVersionStore {
  InMemorySeedVersionStore([this.version]);

  int? version;
  int clearCalls = 0;

  @override
  Future<int> appliedVersion() async => version ?? 0;

  @override
  Future<void> markApplied(int applied) async => version = applied;

  @override
  Future<void> clear() async {
    clearCalls++;
    version = null;
  }
}
