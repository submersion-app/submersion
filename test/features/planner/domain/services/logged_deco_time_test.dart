import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/services/logged_deco_time.dart';

/// Builds a profile at 10 s steps from (seconds, depth) corner points.
List<DiveProfilePoint> _profile(
  List<(int, double)> corners, {
  int Function(int timestamp, double depth)? tts,
}) {
  final points = <DiveProfilePoint>[];
  for (var i = 0; i < corners.length - 1; i++) {
    final (t0, d0) = corners[i];
    final (t1, d1) = corners[i + 1];
    for (var t = t0; t < t1; t += 10) {
      final f = (t - t0) / (t1 - t0);
      final depth = d0 + (d1 - d0) * f;
      points.add(
        DiveProfilePoint(timestamp: t, depth: depth, tts: tts?.call(t, depth)),
      );
    }
  }
  final (tl, dl) = corners.last;
  points.add(
    DiveProfilePoint(timestamp: tl, depth: dl, tts: tts?.call(tl, dl)),
  );
  return points;
}

void main() {
  // 40 m for 20 min, then ascent. Working cut is 20 m (half of 40).
  final corners = <(int, double)>[
    (0, 0),
    (120, 40),
    (1320, 40),
    (1560, 6),
    (2160, 6),
    (2220, 3),
    (3120, 3),
    (3180, 0),
  ];

  test('uses the computer TTS at the last working-depth sample', () {
    final profile = _profile(
      corners,
      tts: (t, depth) => depth >= 20 ? 30 * 60 : 0,
    );
    expect(loggedTtsSeconds(profile: profile), 30 * 60);
  });

  test('falls back to the highest computer TTS on the working portion', () {
    final profile = _profile(
      corners,
      tts: (t, depth) {
        if (depth >= 39) return 28 * 60;
        return 0;
      },
    );
    expect(loggedTtsSeconds(profile: profile), 28 * 60);
  });

  test('falls back to a calculated curve at the working cut', () {
    final profile = _profile(corners);
    final curve = [for (final p in profile) p.depth >= 20 ? 25 * 60 : 60];
    expect(loggedTtsSeconds(profile: profile, ttsCurve: curve), 25 * 60);
  });

  test('falls back to the remaining clock time to the surface', () {
    final profile = _profile(corners);
    final tts = loggedTtsSeconds(profile: profile);
    expect(tts, isNotNull);
    final lastWorking = profile.lastWhere((p) => p.depth >= 20);
    expect(tts, 3180 - lastWorking.timestamp);
  });

  test('empty or zero-depth profiles yield null', () {
    expect(loggedTtsSeconds(profile: const []), isNull);
    expect(
      loggedTtsSeconds(
        profile: const [DiveProfilePoint(timestamp: 0, depth: 0)],
      ),
      isNull,
    );
  });
}
