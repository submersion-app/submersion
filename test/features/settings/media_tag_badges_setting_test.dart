import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Preferences whose writes finish only when the test says so, recording the
/// order they were started in.
class _GatedPrefs implements SharedPreferences {
  final started = <bool>[];
  final gates = <Completer<bool>>[];

  @override
  bool? getBool(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) {
    started.add(value);
    final gate = Completer<bool>();
    gates.add(gate);
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The device-local switch for the library's tag markers (issue #4218).
void main() {
  test('defaults to on when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = MediaTagBadgesNotifier(
      await SharedPreferences.getInstance(),
    );
    expect(notifier.state, isTrue);
  });

  test('starts from the stored choice', () async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.mediaTagBadges: false,
    });
    final notifier = MediaTagBadgesNotifier(
      await SharedPreferences.getInstance(),
    );
    expect(notifier.state, isFalse);
  });

  test('persists a change under its own key only', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = MediaTagBadgesNotifier(prefs);

    await notifier.setEnabled(false);

    expect(notifier.state, isFalse);
    expect(prefs.getBool(SettingsKeys.mediaTagBadges), isFalse);
    expect(prefs.getBool(SettingsKeys.mediaProvenanceBadges), isNull);
  });

  test('the unstored fallback changes state without storage', () async {
    final notifier = MediaTagBadgesNotifier.unstored(true);
    await notifier.setEnabled(false);
    expect(notifier.state, isFalse);
  });

  test('a quick second toggle waits for the first write to land', () async {
    // On Windows and Linux a write replaces the whole preferences file, so
    // two in flight could land in either order and keep the older choice.
    final prefs = _GatedPrefs();
    final notifier = MediaTagBadgesNotifier(prefs);

    final first = notifier.setEnabled(false);
    final second = notifier.setEnabled(true);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, isTrue);
    expect(prefs.started, [false]);

    prefs.gates.first.complete(true);
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(prefs.started, [false, true]);

    prefs.gates.last.complete(true);
    await second;
  });

  test('a failed write does not hold up the next one', () async {
    final prefs = _GatedPrefs();
    final notifier = MediaTagBadgesNotifier(prefs);

    final first = notifier.setEnabled(false);
    final second = notifier.setEnabled(true);
    await Future<void>.delayed(Duration.zero);
    prefs.gates.first.completeError(StateError('disk full'));
    await expectLater(first, throwsStateError);
    await Future<void>.delayed(Duration.zero);

    expect(prefs.started, [false, true]);
    prefs.gates.last.complete(true);
    await second;
  });
}
