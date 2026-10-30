import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Planner Setup-accordion global defaults (issue #3552): each one has an
/// AppSettings field, a documented default matching the field's old
/// hardcoded DivePlan/DpvMission constructor default, and carries through
/// copyWith. Persistence is covered separately by
/// diver_settings_repository_planner_defaults_test.dart.
void main() {
  test('defaults match the old hardcoded per-plan constructor defaults', () {
    const settings = AppSettings();
    expect(settings.plannerDescentRate, 18.0);
    expect(settings.plannerAscentRate, 9.0);
    expect(settings.plannerIntermediateAscentRate, 6.0);
    expect(settings.plannerShallowAscentRate, 3.0);
    expect(settings.plannerFinalAscentRate, 1.0);
    expect(settings.plannerGasSwitchStopSeconds, 0);
    expect(settings.plannerSacBottom, 15.0);
    expect(settings.plannerSacDeco, 15.0);
    expect(settings.plannerSacStressedFactor, 2.5);
    expect(settings.plannerBuddyFactor, 2.0);
    expect(settings.plannerProblemSolvingMinutes, 2);
    expect(settings.plannerBestMixEndMeters, 30.0);
    expect(settings.plannerDeviationDepthDelta, 5.0);
    expect(settings.plannerDeviationTimeMinutes, 5);
    expect(settings.plannerBatteryReserveFraction, closeTo(1 / 3, 0.0001));
    expect(settings.plannerWalkSpeedMps, 0.8);
  });

  test('copyWith carries each field independently of the others', () {
    const settings = AppSettings();
    final changed = settings.copyWith(
      plannerDescentRate: 20.0,
      plannerSacBottom: 18.0,
    );
    expect(changed.plannerDescentRate, 20.0);
    expect(changed.plannerSacBottom, 18.0);
    // Unrelated planner defaults are untouched - guards against a copyWith
    // line accidentally wired to the wrong field.
    expect(changed.plannerAscentRate, settings.plannerAscentRate);
    expect(changed.plannerSacDeco, settings.plannerSacDeco);
  });

  test('sacDeco and sacBottom are independent globals', () {
    const settings = AppSettings();
    final changed = settings.copyWith(plannerSacBottom: 20.0);
    expect(
      changed.plannerSacDeco,
      settings.plannerSacDeco,
      reason:
          'changing the bottom SAC default must not move the deco SAC '
          'default - they were decided to be independent columns',
    );
  });
}
