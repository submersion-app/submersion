import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/data/services/emergency_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(EmergencyDataService.resetCacheForTesting);

  test('loads hotline regions and resolves by country', () async {
    final numbers = await EmergencyDataService.loadNumbers();
    expect(numbers.regions, isNotEmpty);

    expect(numbers.hotlineFor('AU').name, contains('DES Australia'));
    expect(numbers.hotlineFor('US').name, contains('DAN America'));
    expect(numbers.hotlineFor('DE').name, contains('DAN Europe'));
    // Unknown country falls back to the worldwide hotline.
    expect(numbers.hotlineFor('XX').countries, isEmpty);
    expect(numbers.hotlineFor(null).countries, isEmpty);
  });

  test('resolves EMS numbers with default fallback', () async {
    final numbers = await EmergencyDataService.loadNumbers();
    expect(numbers.emsFor('US'), '911');
    expect(numbers.emsFor('AU'), '000');
    expect(numbers.emsFor('FR'), '112');
    expect(numbers.emsFor(null), '112');
  });

  test('loads bundled chambers with verification dates', () async {
    final chambers = await EmergencyDataService.loadBundledChambers();
    expect(chambers, isNotEmpty);
    for (final chamber in chambers) {
      expect(chamber.isBuiltIn, isTrue);
      expect(chamber.phone, isNotEmpty);
      expect(chamber.lastVerified, isNotNull);
    }
    expect(chambers.any((c) => c.country == 'AU'), isTrue);
  });
}
