import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/screen_awake.dart';

/// Issue #1194: the sync maintenance dialog tells the user to keep the app
/// open, and their phone then locks itself and suspends the work behind it.
void main() {
  late List<bool> toggles;

  setUp(() {
    toggles = [];
    ScreenAwake.debugToggle = ({required bool enable}) async {
      toggles.add(enable);
    };
  });

  tearDown(ScreenAwake.debugReset);

  test('holds the screen for exactly as long as the body runs', () async {
    final gate = Completer<void>();
    final done = ScreenAwake.hold(() async {
      expect(toggles, [true], reason: 'taken before the body gets going');
      await gate.future;
      return 'result';
    });

    expect(toggles, [true]);
    gate.complete();
    expect(await done, 'result');
    expect(toggles, [true, false]);
  });

  test('releases when the body throws', () async {
    await expectLater(
      ScreenAwake.hold(() async => throw StateError('provider offline')),
      throwsStateError,
    );

    expect(toggles, [
      true,
      false,
    ], reason: 'a failed wipe must not leave the screen pinned on');
    expect(ScreenAwake.debugHolders, 0);
  });

  test('an inner hold cannot release the outer one', () async {
    await ScreenAwake.hold(() async {
      await ScreenAwake.hold(() async {});
      expect(toggles, [
        true,
      ], reason: 'the outer hold is still running its own work');
    });

    expect(toggles, [true, false]);
  });

  group('acquire', () {
    test('takes the lock and releases it on the returned handle', () {
      final held = ScreenAwake.acquire();
      expect(toggles, [true]);

      held.release();
      expect(toggles, [true, false]);
      expect(ScreenAwake.debugHolders, 0);
    });

    test('release is idempotent', () {
      final held = ScreenAwake.acquire();
      held.release();
      held.release();
      held.release();

      expect(toggles, [
        true,
        false,
      ], reason: 'an owner may release on several end paths');
      expect(ScreenAwake.debugHolders, 0);
    });

    test('is counted against a concurrent hold', () async {
      final held = ScreenAwake.acquire();
      final gate = Completer<void>();
      final running = ScreenAwake.hold(() => gate.future);

      held.release();
      expect(toggles, [true], reason: 'the hold is still running');

      gate.complete();
      await running;
      expect(toggles, [true, false]);
    });

    test('debugReset releases an acquire a test leaked', () {
      ScreenAwake.acquire();
      expect(toggles, [true]);

      ScreenAwake.debugReset();

      expect(toggles, [true, false]);
      expect(ScreenAwake.debugHolders, 0);
    });
  });

  test('debugReset releases a hold a test leaked', () {
    // A test that fails mid-hold never reaches its own release. Clearing the
    // count without releasing would pin the screen on for the rest of the run.
    unawaited(ScreenAwake.hold(() => Completer<void>().future));
    expect(toggles, [true]);

    ScreenAwake.debugReset();

    expect(toggles, [true, false]);
    expect(ScreenAwake.debugHolders, 0);
  });

  test('a plugin that fails does not disturb the work', () async {
    ScreenAwake.debugToggle = ({required bool enable}) async {
      throw MissingPluginException('no wakelock here');
    };

    expect(await ScreenAwake.hold(() async => 42), 42);
    expect(ScreenAwake.debugHolders, 0);
  });

  test('a plugin that never answers does not stall the work', () async {
    // The lock is cosmetic; the maintenance operation behind it is not.
    ScreenAwake.debugToggle = ({required bool enable}) =>
        Completer<void>().future;

    expect(await ScreenAwake.hold(() async => 42), 42);
  });
}
