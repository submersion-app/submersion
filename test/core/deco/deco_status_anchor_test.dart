import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

/// 45 m for 25 min on air, ascend at 9 m/min to 21 m, hold 6 min, ascend to
/// 6 m, hold 10 min, surface. 10 s samples. Deep enough to set a deep GF-low
/// anchor that later off-gassing would otherwise re-derive shallower.
({List<double> depths, List<int> timestamps}) _profile() {
  final depths = <double>[];
  final timestamps = <int>[];
  var t = 0;
  void add(double d) {
    depths.add(d);
    timestamps.add(t);
    t += 10;
  }

  for (var i = 0; i <= 15; i++) {
    add(45.0 * i / 15); // 150 s descent
  }
  for (var i = 0; i < 150; i++) {
    add(45.0);
  }
  for (var i = 1; i <= 16; i++) {
    add(45.0 - 24.0 * i / 16); // 160 s to 21 m
  }
  for (var i = 0; i < 36; i++) {
    add(21.0);
  }
  for (var i = 1; i <= 10; i++) {
    add(21.0 - 15.0 * i / 10); // 100 s to 6 m
  }
  for (var i = 0; i < 60; i++) {
    add(6.0);
  }
  for (var i = 1; i <= 4; i++) {
    add(6.0 - 6.0 * i / 4);
  }
  return (depths: depths, timestamps: timestamps);
}

void main() {
  group('DecoStatus.gfLowCeilingAnchor', () {
    test('every status from a profile walk carries the running anchor', () {
      final p = _profile();
      final statuses = BuhlmannAlgorithm(
        gfLow: 0.30,
        gfHigh: 0.80,
      ).processProfile(depths: p.depths, timestamps: p.timestamps);
      expect(statuses.every((s) => s.gfLowCeilingAnchor != null), isTrue);
      // Running max: never decreases along the dive.
      for (var i = 1; i < statuses.length; i++) {
        expect(
          statuses[i].gfLowCeilingAnchor!,
          greaterThanOrEqualTo(statuses[i - 1].gfLowCeilingAnchor! - 1e-9),
        );
      }
      expect(statuses.last.gfLowCeilingAnchor!, greaterThan(0));
    });

    test('restoring from a mid-profile status continues the run exactly', () {
      final p = _profile();
      final full = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.80);
      final statuses = full.processProfile(
        depths: p.depths,
        timestamps: p.timestamps,
      );
      // Branch during the 21 m hold (after the deep anchor was set and some
      // off-gassing has happened).
      const split = 15 + 150 + 16 + 20;
      final tailDepths = p.depths.sublist(split);
      final tailTimes = p.timestamps.sublist(split);
      final seg = [
        ProfileGasSegment(startTimestamp: tailTimes.first, fN2: airN2Fraction),
      ];

      final exact = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.80)
        ..restoreState(
          statuses[split].compartments,
          gfLowCeilingAnchor: statuses[split].gfLowCeilingAnchor!,
        );
      final tail = exact.processProfileWithGasSegments(
        depths: tailDepths,
        timestamps: tailTimes,
        gasSegments: seg,
      );
      for (var k = 0; k < tail.length; k++) {
        expect(
          tail[k].ceilingMeters,
          closeTo(statuses[split + k].ceilingMeters, 1e-9),
          reason: 'sample $k',
        );
        expect(
          tail[k].ttsSeconds,
          statuses[split + k].ttsSeconds,
          reason: 'tts sample $k',
        );
      }

      // Control: setCompartments re-derives the anchor from the off-gassed
      // state and diverges somewhere in the tail.
      final rederived = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.80)
        ..setCompartments(statuses[split].compartments);
      final control = rederived.processProfileWithGasSegments(
        depths: tailDepths,
        timestamps: tailTimes,
        gasSegments: seg,
      );
      final diverges = List.generate(
        control.length,
        (k) => (control[k].ceilingMeters - statuses[split + k].ceilingMeters)
            .abs(),
      ).any((d) => d > 0.01);
      expect(diverges, isTrue);
    });
  });
}
