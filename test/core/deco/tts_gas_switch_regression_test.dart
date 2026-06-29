// test/core/deco/tts_gas_switch_regression_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

void main() {
  // Synthetic deco profile: descend to 40 m, 25 min bottom on air, switch to
  // EAN50 at 21 m on the way up, sampled every 60 s to the surface.
  ({List<double> depths, List<int> timestamps, List<ProfileGasSegment> gas})
  buildProfile() {
    final depths = <double>[];
    final timestamps = <int>[];
    var t = 0;
    void add(double d) {
      depths.add(d);
      timestamps.add(t);
      t += 60;
    }

    for (var d = 0.0; d <= 40.0; d += 8) {
      add(d);
    }
    for (var i = 0; i < 25; i++) {
      add(40);
    }
    for (var d = 40.0; d >= 0.0; d -= 3) {
      add(d);
    }

    // Recorded switch to EAN50 (fN2 0.50) at the sample nearest 21 m on ascent.
    final switchIndex = depths.lastIndexWhere((d) => (d - 21).abs() < 1.6);
    final gas = <ProfileGasSegment>[
      const ProfileGasSegment(startTimestamp: 0, fN2: airN2Fraction),
      ProfileGasSegment(startTimestamp: timestamps[switchIndex], fN2: 0.50),
    ];
    return (depths: depths, timestamps: timestamps, gas: gas);
  }

  test(
    'gas-aware TTS is monotone non-increasing across the recorded switch',
    () {
      final p = buildProfile();
      final algo = BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.80);
      algo.reset();
      final plan = OptimalOcAscentGas(
        gases: const [
          AvailableGas(
            fN2: airN2Fraction,
            fHe: 0.0,
            maxPpO2Mod: double.infinity,
          ),
          AvailableGas(fN2: 0.50, fHe: 0.0, maxPpO2Mod: 22.0),
        ],
        maxPpO2: 1.6,
      );
      final statuses = algo.processProfileWithGasSegments(
        depths: p.depths,
        timestamps: p.timestamps,
        gasSegments: p.gas,
        ascentGasPlan: plan,
      );

      // No upward step in TTS at the recorded switch: from the bottom phase
      // through the ascent the TTS must never jump UP at the switch sample.
      final tts = statuses.map((s) => s.ttsSeconds).toList();
      final switchIndex = p.depths.lastIndexWhere((d) => (d - 21).abs() < 1.6);
      expect(
        tts[switchIndex] <= tts[switchIndex - 1] + 1,
        isTrue,
        reason: 'TTS stepped up at the recorded gas switch',
      );
    },
  );

  test(
    'null ascentGasPlan reproduces the single-gas-per-sample legacy path',
    () {
      final p = buildProfile();
      final a = BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.80)..reset();
      final legacy = a.processProfileWithGasSegments(
        depths: p.depths,
        timestamps: p.timestamps,
        gasSegments: p.gas,
      );
      final b = BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.80)..reset();
      final explicitNull = b.processProfileWithGasSegments(
        depths: p.depths,
        timestamps: p.timestamps,
        gasSegments: p.gas,
        ascentGasPlan: null,
      );
      expect(
        explicitNull.map((s) => s.ttsSeconds),
        legacy.map((s) => s.ttsSeconds),
      );
    },
  );
}
