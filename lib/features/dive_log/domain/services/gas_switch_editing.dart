import 'package:submersion/core/constants/enums.dart' show DiveMode;

/// Whether a dive has gas switches to edit, as the dive editor shows them:
/// with one breathing cylinder there is nothing to switch to, a gauge dive
/// logs no gas, and a planned dive's switches belong to the plan. A suit
/// inflation bottle is not breathed, so [breathingTankCount] leaves it out
/// (issue #4243).
bool gasSwitchesEditable({
  required int breathingTankCount,
  required DiveMode mode,
  required bool isPlanned,
}) => breathingTankCount >= 2 && mode != DiveMode.gauge && !isPlanned;
