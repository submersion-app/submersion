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

  test('the ONNX platforms run only with the define', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        visionEngineRuns(platform, web: false, onnx: false),
        isFalse,
        reason: '$platform',
      );
      expect(
        visionEngineRuns(platform, web: false, onnx: true),
        isTrue,
        reason: '$platform',
      );
    }
    expect(
      visionEngineRuns(TargetPlatform.android, web: true, onnx: true),
      isFalse,
    );
    expect(
      visionEngineRuns(TargetPlatform.fuchsia, web: false, onnx: true),
      isFalse,
    );
  });

  test('Core ML runs on Apple platforms only', () {
    expect(coreMlRuns(TargetPlatform.macOS, web: false), isTrue);
    expect(coreMlRuns(TargetPlatform.iOS, web: false), isTrue);
    expect(coreMlRuns(TargetPlatform.android, web: false), isFalse);
    expect(coreMlRuns(TargetPlatform.macOS, web: true), isFalse);
  });

  test('video runs everywhere but Linux and the web', () {
    expect(visionVideoRuns(TargetPlatform.linux, web: false), isFalse);
    expect(visionVideoRuns(TargetPlatform.windows, web: false), isTrue);
    expect(visionVideoRuns(TargetPlatform.android, web: false), isTrue);
    expect(visionVideoRuns(TargetPlatform.iOS, web: false), isTrue);
    expect(visionVideoRuns(TargetPlatform.macOS, web: false), isTrue);
    expect(visionVideoRuns(TargetPlatform.android, web: true), isFalse);
  });

  test('the platform defines are off by default', () {
    expect(marineLifeOnnxPlatforms, isFalse);
    expect(marineLifeIgnoreFloor, isFalse);
  });

  test('a test override wins until reset', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    marineLifeIdEnabled = false;
    expect(marineLifeIdEnabled, isFalse);
    resetMarineLifeIdEnabled();
    expect(marineLifeIdEnabled, isTrue);
  });
}
