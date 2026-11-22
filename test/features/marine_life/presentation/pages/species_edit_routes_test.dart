import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/marine_life/presentation/pages/species_edit_routes.dart';

/// The old species edit address opens the page unlocked (issue #4527).
void main() {
  test('the edit address opens the page unlocked', () {
    expect(speciesEditLocation('manta'), '/species/manta?mode=edit');
  });
}
