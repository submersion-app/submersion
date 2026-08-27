import 'package:fit_tool/fit_tool.dart';

import 'package:submersion/features/dive_import/data/services/fit/fit_constants.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_message_access.dart';

/// A gas switch from a FIT `event` message (event 57 = gas_switched).
class FitGasSwitchEvent {
  const FitGasSwitchEvent({required this.timestampMs, required this.gasIndex});

  /// Unix milliseconds of the switch.
  final int timestampMs;

  /// The `dive_gas` message index of the gas switched to.
  final int gasIndex;
}

/// Extracts gas switches from FIT `event` messages, sorted by timestamp.
///
/// Reads raw field values instead of fit_tool's typed getters: the
/// `EventMessage.event` getter throws on enum values missing from its
/// outdated FIT profile, and gas_switched (57) is one of them.
class FitGasSwitchExtractor {
  const FitGasSwitchExtractor._();

  static List<FitGasSwitchEvent> extract(List<Message> messages) {
    final switches = <FitGasSwitchEvent>[];
    for (final message in messages.whereType<EventMessage>()) {
      final event = FitMessageAccess.rawNum(message, FitConstants.evEvent);
      if (event == null || event.toInt() != FitConstants.gasSwitchedEvent) {
        continue;
      }
      final timestamp = FitMessageAccess.rawNum(
        message,
        FitConstants.evTimestamp,
      );
      final gasIndex = FitMessageAccess.rawNum(message, FitConstants.evData);
      if (timestamp == null || gasIndex == null) continue;
      switches.add(
        FitGasSwitchEvent(
          timestampMs: timestamp.toInt(),
          gasIndex: gasIndex.toInt(),
        ),
      );
    }
    switches.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return switches;
  }
}
