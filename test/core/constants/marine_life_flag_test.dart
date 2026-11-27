import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/feature_flags.dart';

import '../../helpers/global_test_defaults.dart';

/// Marine life identification is on wherever an engine runs (iPhone, iPad
/// and Mac with Core ML; Android, Windows and Linux with the ONNX engine) and
/// hidden elsewhere, per
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

  test('on for Android, Windows and Linux by default', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(marineLifeIdEnabled, isTrue, reason: '$platform');
    }
  });

  test('off where no engine runs', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    expect(marineLifeIdEnabled, isFalse);
  });

  test('follows the platform on every read', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(marineLifeIdEnabled, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    expect(marineLifeIdEnabled, isFalse);
  });

  test('the engine runs on iOS and macOS, never in a browser', () {
    expect(visionEngineRuns(TargetPlatform.iOS, web: false), isTrue);
    expect(visionEngineRuns(TargetPlatform.macOS, web: false), isTrue);
    // Safari on a Mac reports macOS; the web build has no engine.
    expect(visionEngineRuns(TargetPlatform.macOS, web: true), isFalse);
    expect(visionEngineRuns(TargetPlatform.iOS, web: true), isFalse);
  });

  test('the engine runs on Android, Windows and Linux by default', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        visionEngineRuns(platform, web: false),
        isTrue,
        reason: '$platform',
      );
      expect(
        visionEngineRuns(platform, web: true),
        isFalse,
        reason: '$platform',
      );
    }
  });

  test('the harness defaults drop a leftover override', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    marineLifeIdEnabled = false;
    applyGlobalTestDefaults();
    expect(marineLifeIdEnabled, isTrue);
  });

  test('a build can turn the ONNX platforms off', () {
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

  test('the ONNX platforms are on and the floor kept by default', () {
    expect(marineLifeOnnxPlatforms, isTrue);
    expect(marineLifeIgnoreFloor, isFalse);
  });

  test('a test override wins until reset', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    marineLifeIdEnabled = false;
    expect(marineLifeIdEnabled, isFalse);
    resetMarineLifeIdEnabled();
    expect(marineLifeIdEnabled, isTrue);
  });

  group('labels shown (issue #4876)', () {
    tearDown(resetMarineLifeIdEnabled);

    test('follow the feature, not the engine, unless set', () {
      marineLifeIdEnabled = false;
      expect(marineLifeLabelsShown, isFalse);
      marineLifeLabelsShown = true;
      expect(marineLifeLabelsShown, isTrue);
      expect(marineLifeIdEnabled, isFalse);
      resetMarineLifeIdEnabled();
      marineLifeIdEnabled = true;
      expect(marineLifeLabelsShown, isTrue);
    });

    test('video labels show wherever the viewer plays videos', () {
      expect(videoLabelsShown(TargetPlatform.android, web: false), isTrue);
      expect(videoLabelsShown(TargetPlatform.windows, web: false), isTrue);
      expect(videoLabelsShown(TargetPlatform.linux, web: false), isFalse);
      expect(videoLabelsShown(TargetPlatform.linux, web: true), isTrue);
    });
  });
}
