import 'package:fit_tool/fit_tool.dart';

/// A gas mix from a FIT `dive_gas` message.
class FitGas {
  const FitGas({
    required this.index,
    required this.o2Percent,
    required this.hePercent,
    required this.enabled,
  });

  final int index;
  final double o2Percent;
  final double hePercent;
  final bool enabled;
}

/// Extracts the enabled gas mixes from FIT `dive_gas` (msg 259) messages,
/// sorted by message index (index 0 is the primary/bottom gas).
class FitGasExtractor {
  const FitGasExtractor._();

  static List<FitGas> extract(List<Message> messages) {
    final gases =
        messages
            .whereType<DiveGasMessage>()
            .map(
              (m) => FitGas(
                index: m.messageIndex ?? 0,
                o2Percent: (m.oxygenContent ?? 21).toDouble(),
                hePercent: (m.heliumContent ?? 0).toDouble(),
                enabled: m.status == DiveGasStatus.enabled,
              ),
            )
            .where((g) => g.enabled)
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    return gases;
  }
}
