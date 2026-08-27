import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_gas_extractor.dart';

void main() {
  test('extracts enabled gas mixes sorted by message index', () {
    final g0 = DiveGasMessage()
      ..messageIndex = 0
      ..oxygenContent = 30
      ..heliumContent = 0
      ..status = DiveGasStatus.enabled;
    final g1 = DiveGasMessage()
      ..messageIndex = 1
      ..oxygenContent = 50
      ..heliumContent = 0
      ..status = DiveGasStatus.enabled;

    final gases = FitGasExtractor.extract([g1, g0]);

    expect(gases, hasLength(2));
    expect(gases[0].index, 0);
    expect(gases[0].o2Percent, 30);
    expect(gases[1].o2Percent, 50);
  });

  test('excludes disabled gases', () {
    final enabled = DiveGasMessage()
      ..messageIndex = 0
      ..oxygenContent = 21
      ..status = DiveGasStatus.enabled;
    final disabled = DiveGasMessage()
      ..messageIndex = 1
      ..oxygenContent = 100
      ..status = DiveGasStatus.disabled;

    final gases = FitGasExtractor.extract([enabled, disabled]);

    expect(gases, hasLength(1));
    expect(gases.single.o2Percent, 21);
  });
}
