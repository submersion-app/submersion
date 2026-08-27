import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('AppSettings defaults ascentGasSet to allCarried', () {
    const settings = AppSettings();
    expect(settings.ascentGasSet, AscentGasSet.allCarried);
  });

  test('copyWith overrides ascentGasSet and preserves it otherwise', () {
    const settings = AppSettings();
    final updated = settings.copyWith(ascentGasSet: AscentGasSet.decoStageOnly);
    expect(updated.ascentGasSet, AscentGasSet.decoStageOnly);
    expect(
      updated.copyWith(gfLow: 40).ascentGasSet,
      AscentGasSet.decoStageOnly,
    );
  });
}
