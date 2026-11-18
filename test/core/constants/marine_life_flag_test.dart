import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/feature_flags.dart';

import '../../helpers/global_test_defaults.dart';

/// Marine life identification is on wherever an engine runs (iPhone, iPad
/// and Mac) and hidden elsewhere, per
/// docs/design/specs/2026-11-18-marine-life-release-gate-design.md. These run
/// without `--dart-define=MARINE_LIFE_ID`, so they see the default.
void main() {
  setUp(resetMarineLifeIdEnabled);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    resetMarineLifeIdEnabled();
  });

  test('on for iOS and macOS by default', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(marineLifeIdEnabled, isTrue, reason: '$platform');
    }
  });

  test('off for Android, Windows and Linux by default', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(marineLifeIdEnabled, isFalse, reason: '$platform');
    }
  });

  test('follows the platform on every read', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(marineLifeIdEnabled, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(marineLifeIdEnabled, isFalse);
  });

  test('the engine runs on iOS and macOS, never in a browser', () {
    expect(visionEngineRuns(TargetPlatform.iOS, web: false), isTrue);
    expect(visionEngineRuns(TargetPlatform.macOS, web: false), isTrue);
    // Safari on a Mac reports macOS; the web build has no engine.
    expect(visionEngineRuns(TargetPlatform.macOS, web: true), isFalse);
    expect(visionEngineRuns(TargetPlatform.iOS, web: true), isFalse);
    expect(visionEngineRuns(TargetPlatform.android, web: false), isFalse);
  });

  test('the harness defaults drop a leftover override', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    marineLifeIdEnabled = false;
    applyGlobalTestDefaults();
    expect(marineLifeIdEnabled, isTrue);
  });

  test('a test override wins until reset', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    marineLifeIdEnabled = false;
    expect(marineLifeIdEnabled, isFalse);
    resetMarineLifeIdEnabled();
    expect(marineLifeIdEnabled, isTrue);
  });
}
