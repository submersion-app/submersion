import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';

/// The location service the site page's Location card reads (moved from
/// the deleted site edit form's tests, issue #4527, phase 2, plan 7).
void main() {
  test('locationServiceProvider defaults to the LocationService singleton', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(locationServiceProvider),
      same(LocationService.instance),
    );
  });
}
