import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_browse_prefs_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

Future<ProviderContainer> _container(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('default is none and grid', () async {
    final container = await _container({});

    expect(container.read(speciesGroupByProvider), SpeciesGroupBy.none);
    expect(container.read(speciesBrowseGridProvider), isTrue);
  });

  test('persists and reads back', () async {
    final container = await _container({});
    await container
        .read(speciesGroupByProvider.notifier)
        .set(SpeciesGroupBy.trip);
    await container.read(speciesBrowseGridProvider.notifier).set(false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kSpeciesGroupByKey), 'trip');
    expect(prefs.getBool(kSpeciesBrowseGridKey), isFalse);
    final fresh = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(fresh.dispose);
    expect(fresh.read(speciesGroupByProvider), SpeciesGroupBy.trip);
    expect(fresh.read(speciesBrowseGridProvider), isFalse);
  });

  test('an unknown stored value reads as the default', () async {
    final container = await _container({kSpeciesGroupByKey: 'byMoonPhase'});

    expect(container.read(speciesGroupByProvider), SpeciesGroupBy.none);
  });
}
