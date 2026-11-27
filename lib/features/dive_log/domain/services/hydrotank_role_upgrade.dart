import 'package:submersion/core/constants/enums.dart';

/// Whether a stored cylinder takes the Avelo Hydrotank role (issue #4657)
/// that a fresh read of its dive gives it, on re-parse and on resync from
/// the original file (issue #4665).
///
/// Before the Hydrotank role every Avelo import stored its Hydrotank as back
/// gas, and nothing tells that default from a diver's choice, so a stored
/// back gas with no recorded role source is upgraded. Any other stored role
/// is the diver's and stays; a role read off the transmitter name has its
/// own rule. A diver who sets the Hydrotank back to back gas sees it turned
/// again by the next re-parse or resync, a limit the design accepts: in
/// Avelo mode the T1 cylinder is the Hydrotank.
bool upgradesToHydrotank({
  required String? storedRole,
  required String? storedRoleSource,
  required String? parsedRole,
}) =>
    storedRoleSource == null &&
    storedRole == TankRole.backGas.name &&
    parsedRole == TankRole.hydrotank.name;
