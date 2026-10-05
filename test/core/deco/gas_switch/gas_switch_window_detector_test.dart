import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';

import 'gas_switch_test_profiles.dart';

void main() {
  final dive = sampleProfile(standardDecoDive);
  final air = gasOf(0.21);
  final ean50 = gasOf(0.5);
  final o2 = gasOf(1.0);

  SwitchWindowDetection detect(
    List<ProfileGasSegment> segments, {
    SampledProfile? profile,
  }) {
    final p = profile ?? dive;
    return detectSwitchWindows(
      depths: p.depths,
      timestamps: p.timestamps,
      gasSegments: segments,
      gases: [air, ean50, o2],
      maxPpO2: 1.6,
    );
  }

  test('activeSegmentAt mirrors the engine lookup', () {
    final segments = [seg(0, 0.21), seg(100, 0.5)];
    expect(segmentFO2(activeSegmentAt(segments, 0)), closeTo(0.21, 1e-9));
    expect(segmentFO2(activeSegmentAt(segments, 99)), closeTo(0.21, 1e-9));
    expect(segmentFO2(activeSegmentAt(segments, 100)), closeTo(0.5, 1e-9));
    expect(segmentFO2(activeSegmentAt(segments, -5)), closeTo(0.21, 1e-9));
  });

  test('air segment matches an air cylinder (0.7902 vs 0.79)', () {
    const recordedAir = ProfileGasSegment(startTimestamp: 0, fN2: 0.7902);
    expect(sameMix(segmentFO2(recordedAir), 0, air.fO2, air.fHe), isTrue);
    expect(sameMix(0.32, 0, 0.36, 0), isFalse);
  });

  test('on-time switches produce windows that end at the switch', () {
    final result = detect([seg(0, 0.21), seg(1690, 0.5), seg(2540, 1.0)]);
    // EAN50 and O2; air (MOD 66 m) is never exceeded.
    expect(result.assessedGasCount, 2);
    expect(result.windows, hasLength(2));
    final first = result.windows.first;
    expect(first.gas, same(ean50));
    expect(dive.timestamps[first.startIndex], 1630);
    expect(dive.timestamps[first.switchIndex!], 1690);
    expect(first.endIndex, first.switchIndex);
    final second = result.windows.last;
    expect(second.gas, same(o2));
    expect(dive.timestamps[second.startIndex], 2510);
    expect(dive.timestamps[second.switchIndex!], 2540);
  });

  test('a gas never switched to is a window with no switch', () {
    final result = detect([seg(0, 0.21)]);
    final ean = result.windows.firstWhere((w) => identical(w.gas, ean50));
    expect(ean.switchIndex, isNull);
    // Ends where O2 becomes the ideal gas.
    expect(dive.timestamps[ean.endIndex], 2510);
    final oxygen = result.windows.firstWhere((w) => identical(w.gas, o2));
    expect(oxygen.switchIndex, isNull);
    expect(oxygen.endIndex, dive.timestamps.length - 1);
  });

  test('skipping EAN50 straight to O2 leaves EAN50 without a switch', () {
    final result = detect([seg(0, 0.21), seg(2540, 1.0)]);
    final ean = result.windows.firstWhere((w) => identical(w.gas, ean50));
    expect(ean.switchIndex, isNull);
    final oxygen = result.windows.firstWhere((w) => identical(w.gas, o2));
    expect(dive.timestamps[oxygen.switchIndex!], 2540);
  });

  test('a mid-dive excursion above the MOD opens no early window', () {
    final profile = sampleProfile([
      (0, 0),
      (120, 40),
      (600, 40),
      (720, 15),
      (1020, 15),
      (1140, 40),
      ...standardDecoDive.skip(2),
    ]);
    final result = detect([
      seg(0, 0.21),
      seg(1690, 0.5),
      seg(2540, 1.0),
    ], profile: profile);
    expect(result.windows, isNotEmpty);
    for (final window in result.windows) {
      expect(profile.timestamps[window.startIndex], greaterThanOrEqualTo(1630));
    }
  });

  test('a gas the dive never took below its MOD is not assessed', () {
    final result = detect(
      [seg(0, 0.21)],
      profile: sampleProfile([
        (0, 0),
        (60, 20),
        (5400, 20),
        (5460, 6),
        (6060, 6),
        (6080, 3),
        (6680, 3),
        (6700, 0),
      ]),
    );
    // EAN50 (MOD 22 m) never had depth > 23 m. O2 (MOD 6 m) did.
    expect(result.windows.where((w) => identical(w.gas, ean50)), isEmpty);
  });

  test('a gas whose MOD the final ascent never reaches is not assessed', () {
    // A recording that ends at 22.5 m: below EAN50's 23 m hysteresis line,
    // but never at or above its 22 m MOD, and nowhere near O2's 6 m.
    final result = detect([
      seg(0, 0.21),
    ], profile: sampleProfile([(0, 0), (120, 40), (1500, 40), (1610, 22.5)]));
    expect(result.assessedGasCount, 0);
    expect(result.windows, isEmpty);
  });

  test('a switch to a richer gas ends the open window there', () {
    // Back gas until O2 at the 9 m stop (t = 2400), never EAN50. The EAN50
    // window ends at the O2 switch, not at O2's 6 m MOD further up.
    final result = detect([seg(0, 0.21), seg(2400, 1.0)]);
    final ean = result.windows.firstWhere((w) => identical(w.gas, ean50));
    expect(ean.switchIndex, isNull);
    expect(dive.timestamps[ean.endIndex], 2400);
    expect(result.windows.where((w) => identical(w.gas, o2)), isEmpty);
  });

  test('air breaks after an on-time O2 switch open no window', () {
    final result = detect([
      seg(0, 0.21),
      seg(1690, 0.5),
      seg(2540, 1.0),
      seg(2780, 0.21),
      seg(3080, 1.0),
    ]);
    // Only the two on-time switches.
    expect(result.windows, hasLength(2));
    expect(result.windows.every((w) => w.switchIndex == w.endIndex), isTrue);
  });

  /// The standard dive with real-world noise at the 6 m stop: readings
  /// alternate 5.9 m and 6.2 m, either side of O2's 6.0 m MOD.
  SampledProfile noisySixMetreStop() {
    final depths = [...dive.depths];
    for (var i = 0; i < dive.timestamps.length; i++) {
      final t = dive.timestamps[i];
      if (t >= 2510 && t <= 3110) depths[i] = i.isEven ? 5.9 : 6.2;
    }
    return (timestamps: dive.timestamps, depths: depths);
  }

  test('depth noise at the stop keeps one late O2 window', () {
    final profile = noisySixMetreStop();
    final result = detect([
      seg(0, 0.21),
      seg(1690, 0.5),
      seg(2800, 1.0),
    ], profile: profile);
    final oxygen = result.windows.where((w) => identical(w.gas, o2)).toList();
    expect(oxygen, hasLength(1));
    expect(profile.timestamps[oxygen.single.switchIndex!], 2800);
    expect(oxygen.single.endIndex, oxygen.single.switchIndex);
  });

  test('depth noise keeps one window per gas when EAN50 is skipped', () {
    final result = detect([seg(0, 0.21)], profile: noisySixMetreStop());
    expect(result.windows.where((w) => identical(w.gas, ean50)), hasLength(1));
    expect(result.windows.where((w) => identical(w.gas, o2)), hasLength(1));
  });

  test('identical-mix switches (sidemount) open no window', () {
    final result = detectSwitchWindows(
      depths: dive.depths,
      timestamps: dive.timestamps,
      gasSegments: [seg(0, 0.32), seg(900, 0.32), seg(1690, 0.5)],
      gases: [gasOf(0.32), ean50],
      maxPpO2: 1.6,
    );
    expect(result.windows, hasLength(1));
    expect(result.windows.single.gas, same(ean50));
  });

  test('a switch to a gas outside the plan opens no window of its own', () {
    final result = detectSwitchWindows(
      depths: dive.depths,
      timestamps: dive.timestamps,
      gasSegments: [seg(0, 0.21), seg(1200, 0.32), seg(1690, 0.5)],
      gases: [air, ean50],
      maxPpO2: 1.6,
    );
    expect(result.windows, hasLength(1));
    expect(result.windows.single.gas, same(ean50));
  });
}
