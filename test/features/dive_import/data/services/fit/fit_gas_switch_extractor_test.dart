import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_constants.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_gas_switch_extractor.dart';

/// Builds an event message with raw field values, bypassing fit_tool's typed
/// setters (whose Event enum predates gas_switched = 57).
EventMessage _event({int? event, int? timestampMs, int? gasIndex}) {
  final message = EventMessage();
  if (event != null) {
    message.getField(FitConstants.evEvent)!.setValue(0, event, null);
  }
  if (timestampMs != null) {
    message.timestamp = timestampMs;
  }
  if (gasIndex != null) {
    message.getField(FitConstants.evData)!.setValue(0, gasIndex, null);
  }
  return message;
}

void main() {
  group('FitGasSwitchExtractor', () {
    test('extracts gas_switched events sorted by timestamp', () {
      final switches = FitGasSwitchExtractor.extract([
        _event(event: 57, timestampMs: 5000, gasIndex: 2),
        _event(event: 57, timestampMs: 1000, gasIndex: 0),
      ]);

      expect(switches, hasLength(2));
      expect(switches[0].timestampMs, 1000);
      expect(switches[0].gasIndex, 0);
      expect(switches[1].timestampMs, 5000);
      expect(switches[1].gasIndex, 2);
    });

    test('ignores non-gas-switch events', () {
      final switches = FitGasSwitchExtractor.extract([
        _event(event: 56, timestampMs: 1000, gasIndex: 3),
        _event(timestampMs: 1000, gasIndex: 3),
      ]);

      expect(switches, isEmpty);
    });

    test('skips gas_switched events missing timestamp or data', () {
      final switches = FitGasSwitchExtractor.extract([
        _event(event: 57, gasIndex: 1),
        _event(event: 57, timestampMs: 2000),
        _event(event: 57, timestampMs: 3000, gasIndex: 1),
      ]);

      expect(switches, hasLength(1));
      expect(switches.single.timestampMs, 3000);
    });
  });
}
