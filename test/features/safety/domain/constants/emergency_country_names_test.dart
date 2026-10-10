import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/data/services/emergency_data_service.dart';
import 'package:submersion/features/safety/domain/constants/emergency_country_names.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(EmergencyDataService.resetCacheForTesting);

  test('every country in the bundled emergency data has a name', () async {
    final numbers = await EmergencyDataService.loadNumbers();
    final chambers = await EmergencyDataService.loadBundledChambers();
    final codes = {
      ...numbers.emsByCountry.keys,
      for (final region in numbers.regions) ...region.countries,
      for (final chamber in chambers) chamber.country,
    };

    final unnamed = codes.where((c) => !emergencyCountryNames.containsKey(c));
    expect(unnamed, isEmpty, reason: 'Add these codes to the name table.');
  });

  test('display name pairs the name with its code', () {
    expect(emergencyRegionDisplayName('DE'), 'Germany (DE)');
  });

  test('an unknown code is shown as itself', () {
    expect(emergencyRegionDisplayName('AQ'), 'AQ');
  });
}
