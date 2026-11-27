import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/hydrotank_role_upgrade.dart';

/// The one rule re-parse and resync share for giving an Avelo dive stored
/// before the Hydrotank role (issue #4657) its Hydrotank (issue #4665).
void main() {
  bool upgrades(String? stored, String? source, String? parsed) =>
      upgradesToHydrotank(
        storedRole: stored,
        storedRoleSource: source,
        parsedRole: parsed,
      );

  test('a stored back gas the parse tags as the Hydrotank is upgraded', () {
    expect(upgrades('backGas', null, 'hydrotank'), isTrue);
  });

  test('another stored role is the diver\'s and stays', () {
    expect(upgrades('pony', null, 'hydrotank'), isFalse);
  });

  test('a back gas read off the transmitter name is left to its own rule', () {
    expect(upgrades('backGas', 'transmitterName', 'hydrotank'), isFalse);
  });

  test('a parse without a Hydrotank upgrades nothing', () {
    expect(upgrades('backGas', null, 'backGas'), isFalse);
    expect(upgrades('backGas', null, null), isFalse);
  });

  test('a stored Hydrotank is not upgraded again', () {
    expect(upgrades('hydrotank', null, 'hydrotank'), isFalse);
  });
}
