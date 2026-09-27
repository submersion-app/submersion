import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart';

const _profile = ModProfileLimits(
  workingPpO2: 1.4,
  decoPpO2: 1.6,
  flushPpO2: 1.6,
  setpointBar: 1.3,
);

void main() {
  group('resolveModLimits', () {
    test('no overrides follow the profile and are not marked', () {
      final r = resolveModLimits(ModLimitOverrides.none, _profile);
      expect(r.workingPpO2, 1.4);
      expect(r.decoPpO2, 1.6);
      expect(r.flushPpO2, 1.6);
      expect(r.setpointBar, 1.3);
      expect(r.workingOverridden, isFalse);
      expect(r.decoOverridden, isFalse);
      expect(r.flushOverridden, isFalse);
      expect(r.setpointOverridden, isFalse);
    });

    test('an override is marked only while it differs from the profile', () {
      const overrides = ModLimitOverrides(workingPpO2: 1.3, flushPpO2: 1.1);
      final differs = resolveModLimits(overrides, _profile);
      expect(differs.workingPpO2, 1.3);
      expect(differs.workingOverridden, isTrue);
      expect(differs.flushOverridden, isTrue);

      // The profile later moves onto the override: no longer "differs".
      final caughtUp = resolveModLimits(
        overrides,
        const ModProfileLimits(
          workingPpO2: 1.3,
          decoPpO2: 1.6,
          flushPpO2: 1.1,
          setpointBar: 1.3,
        ),
      );
      expect(caughtUp.workingOverridden, isFalse);
      expect(caughtUp.flushOverridden, isFalse);
    });

    test('deco is never computed below working', () {
      // A profile change can leave an old deco override under the working
      // limit; the deco MOD must still not be shallower than the working MOD.
      final r = resolveModLimits(
        const ModLimitOverrides(decoPpO2: 1.3),
        _profile,
      );
      expect(r.workingPpO2, 1.4);
      expect(r.decoPpO2, 1.4);
    });
  });

  group('ModLimitOverrides', () {
    test('an override equal to the profile is stored as none', () {
      final o = ModLimitOverrides.none.withLimits(
        workingPpO2: 1.4,
        decoPpO2: 1.5,
        profile: _profile,
      );
      expect(o.workingPpO2, isNull);
      expect(o.decoPpO2, 1.5);
    });

    test('round-trips through JSON and snaps to the slider grids', () {
      const o = ModLimitOverrides(
        workingPpO2: 1.3,
        decoPpO2: 1.5,
        flushPpO2: 1.1,
        setpointBar: 1.2,
      );
      expect(ModLimitOverrides.fromJson(o.toJson()), o);
      final snapped = ModLimitOverrides.fromJson({
        'workingPpO2': 1.33,
        'flushPpO2': 1.45,
        'setpointBar': 1.26,
        'decoPpO2': 9.9,
      });
      expect(snapped.workingPpO2, 1.35);
      expect(snapped.flushPpO2, 1.5);
      expect(snapped.setpointBar, 1.3);
      expect(snapped.decoPpO2, isNull);
    });
  });
}
