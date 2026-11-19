import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/marine_life/presentation/pages/species_edit_routes.dart';

/// The old species edit address opens the page unlocked once phase 3's
/// switch is on, and keeps the form until then (issue #4527).
void main() {
  test('the edit address opens the page unlocked with the switch on', () {
    expect(
      speciesEditLocation('manta', unlockEditing: true),
      '/species/manta?mode=edit',
    );
  });

  test('with the switch off the edit address keeps the form', () {
    expect(speciesEditLocation('manta', unlockEditing: false), isNull);
  });
}
