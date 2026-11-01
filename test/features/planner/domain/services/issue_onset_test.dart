import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/services/issue_onset.dart';

void main() {
  group('runtimeReaching', () {
    const steps = [
      RuntimeIncrement(startRuntime: 0, durationSeconds: 600, amount: 10),
      RuntimeIncrement(startRuntime: 600, durationSeconds: 600, amount: 20),
    ];

    test('interpolates inside the increment that crosses the threshold', () {
      // 10 after the first step, 20 more over the next 600 s: 25 is reached
      // three quarters of the way through it.
      expect(runtimeReaching(steps, threshold: 25), 1050);
    });

    test('a threshold met exactly at a step boundary lands on it', () {
      expect(runtimeReaching(steps, threshold: 10), 600);
    });

    test('a start already at the threshold reports the dive start', () {
      expect(runtimeReaching(steps, threshold: 40, start: 45), 0);
    });

    test('carried exposure moves the crossing earlier', () {
      // 15 + 10 = 25 after the first step; 5 of the next 20 takes 150 s.
      expect(runtimeReaching(steps, threshold: 30, start: 15), 750);
    });

    test('a threshold never reached reports null', () {
      expect(runtimeReaching(steps, threshold: 31), isNull);
    });

    test('an instant increment crosses at its own runtime', () {
      const lump = [
        RuntimeIncrement(startRuntime: 0, durationSeconds: 300, amount: 5),
        RuntimeIncrement(startRuntime: 300, durationSeconds: 0, amount: 50),
      ];
      expect(runtimeReaching(lump, threshold: 20), 300);
    });

    test('reads increments in dive order, however they were charged', () {
      // Problem-solving gas is charged after every authored leg, though it
      // falls where the bottom ends: ahead of the ascent listed before it.
      const charged = [
        RuntimeIncrement(startRuntime: 0, durationSeconds: 300, amount: 10),
        RuntimeIncrement(startRuntime: 300, durationSeconds: 300, amount: 10),
        RuntimeIncrement(startRuntime: 300, durationSeconds: 0, amount: 50),
      ];
      expect(runtimeReaching(charged, threshold: 15), 300);
    });
  });

  group('legOnsetRuntime', () {
    test('a descent crosses where the depth meets the limit', () {
      // 0 to 40 m over 400 s: 30 m is reached at 300 s into the leg.
      final at = legOnsetRuntime(
        startRuntime: 100,
        durationSeconds: 400,
        startDepth: 0,
        endDepth: 40,
        exceeds: (depth) => depth > 30,
      );
      expect(at, closeTo(400, 1));
    });

    test('an ascent that is over the limit from the start onsets at once', () {
      final at = legOnsetRuntime(
        startRuntime: 100,
        durationSeconds: 400,
        startDepth: 40,
        endDepth: 0,
        exceeds: (depth) => depth > 30,
      );
      expect(at, 100);
    });

    test('a shallow-side limit crosses on the way up', () {
      // Hypoxic shallower than 10 m: on a 40 to 0 m ascent over 400 s that
      // is 300 s in.
      final at = legOnsetRuntime(
        startRuntime: 0,
        durationSeconds: 400,
        startDepth: 40,
        endDepth: 0,
        exceeds: (depth) => depth < 10,
      );
      expect(at, closeTo(300, 1));
    });

    test('a level leg onsets at its start', () {
      final at = legOnsetRuntime(
        startRuntime: 240,
        durationSeconds: 600,
        startDepth: 30,
        endDepth: 30,
        exceeds: (_) => true,
      );
      expect(at, 240);
    });
  });
}
