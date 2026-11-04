import 'package:submersion/core/constants/enums.dart' show DiveMode;

/// Whether a dive has gas switches to edit, as the dive editor shows them:
/// with one cylinder there is nothing to switch to, a gauge dive logs no
/// gas, and a planned dive's switches belong to the plan.
bool gasSwitchesEditable({
  required int tankCount,
  required DiveMode mode,
  required bool isPlanned,
}) => tankCount >= 2 && mode != DiveMode.gauge && !isPlanned;
