/// Feature flags for gating in-progress or externally-blocked features out of
/// the user-facing UI without deleting their implementation.
///
/// These flags intentionally gate UI surfaces only. The backing services,
/// providers, repositories, auth flows, and database code remain fully intact
/// and functional so a feature can be restored by flipping a single flag.
///
/// Flags here are plain mutable top-level variables (not `const`) so that
/// widget tests can toggle them; they are evaluated at runtime, and production
/// code only ever reads them. [marineLifeIdEnabled] is the exception: its
/// default depends on the platform, so it is a getter with a test override.
library;

import 'package:flutter/foundation.dart';

/// Whether the Adobe Lightroom integration is surfaced in the UI.
///
/// The Lightroom integration is code-complete but pending review/approval by
/// Adobe. Until that review resolves, every Lightroom entry point is hidden so
/// we do not advertise a connection users cannot actually complete (and to
/// avoid giving false hope should Adobe reject the integration outright).
///
/// This flag hides UI ONLY. All Lightroom services, providers, auth managers,
/// and stored-account handling under `lib/core/services/lightroom/`,
/// `lib/features/media/.../lightroom_*`, etc. are left untouched and keep
/// working. Any account already connected on a device continues to sync.
///
/// It is a mutable top-level variable rather than a `const` so that widget
/// tests can toggle it to exercise both the hidden and enabled UI wiring;
/// production code only ever reads it. Tests that set it must reset it (e.g.
/// via `addTearDown`) so the value does not leak between tests.
///
/// To re-enable once Adobe approves: set the default below to `true`. That
/// single change restores the media-sources entry point, the settings page +
/// route, and the per-dive / per-trip / photo-viewer scan and "Open in
/// Lightroom" actions. If Adobe permanently rejects the integration, the
/// Lightroom code and this flag can be deleted together in a follow-up cleanup.
///
/// Before it is turned on, the dive page's Lightroom suggestions row
/// (`lightroom_suggestions_row.dart`) must hold Accept and Dismiss in the
/// dive's Media card and hide them while the dive is locked: today they write
/// at once (issue #4527, the media library design note, "Left for later").
bool lightroomUiEnabled = false;

/// Whether marine life identification is surfaced in the UI (issue #4668):
/// the settings page, analysing photos as they are opened, and suggested
/// species in the photo viewer.
///
/// On wherever an engine runs and hidden on the web. Core ML runs on
/// iPhone, iPad and Mac; the ONNX engine on Android, Windows and Linux
/// (piece 3,
/// docs/design/specs/2026-11-19-marine-life-identification-3-other-platforms-design.md),
/// unless a build passes `--dart-define=MARINE_LIFE_ID_ONNX=false`.
/// It asks [visionEngineRuns], as the engines do, on every read, so the UI
/// never offers it on a platform with no engine. See
/// docs/design/specs/2026-11-18-marine-life-release-gate-design.md.
///
/// A build passing `--dart-define=MARINE_LIFE_ID=false` turns it off
/// everywhere. Like [lightroomUiEnabled] it hides UI only. Tests may set it;
/// a test that does must call [resetMarineLifeIdEnabled] in `tearDown` or
/// `addTearDown`, which puts the platform default back, and
/// `applyGlobalTestDefaults` resets it before every test file.
bool get marineLifeIdEnabled =>
    _marineLifeIdOverride ??
    (_marineLifeIdDefine && visionEngineRuns(defaultTargetPlatform));

/// Overrides the platform default, for tests.
@visibleForTesting
set marineLifeIdEnabled(bool value) => _marineLifeIdOverride = value;

/// Drops a test's override, so [marineLifeIdEnabled] follows the platform,
/// and [marineLifeLabelsShown] with it.
@visibleForTesting
void resetMarineLifeIdEnabled() {
  _marineLifeIdOverride = null;
  _marineLifeLabelsOverride = null;
}

/// Whether marine life results are shown (issue #4876): the labels over
/// photos and videos, their modes, the species to review, the suggestions
/// on a photo, and accepting, dismissing and naming from the frame. Unlike
/// [marineLifeIdEnabled] it does not need an engine here: results analysed
/// on another device sync, so a phone that can never run the models, the
/// browser app included, still shows them. Analysing (and everything that
/// offers it) stays behind [marineLifeIdEnabled].
///
/// Off only in a build passing `--dart-define=MARINE_LIFE_ID=false`. A test
/// that turns [marineLifeIdEnabled] on or off turns this with it, unless it
/// sets this too; [resetMarineLifeIdEnabled] drops both.
bool get marineLifeLabelsShown =>
    _marineLifeLabelsOverride ?? _marineLifeIdOverride ?? _marineLifeIdDefine;

/// Overrides [marineLifeLabelsShown], for tests.
@visibleForTesting
set marineLifeLabelsShown(bool value) => _marineLifeLabelsOverride = value;

bool? _marineLifeLabelsOverride;

/// Whether labels show over videos on [platform] (issue #4876): wherever
/// the viewer plays one, which is everywhere but Linux. Scanning a video
/// is narrower ([visionVideoRuns]): a browser plays videos but scans none.
bool videoLabelsShown(TargetPlatform platform, {bool web = kIsWeb}) =>
    web || platform != TargetPlatform.linux;

const _marineLifeIdDefine = bool.fromEnvironment(
  'MARINE_LIFE_ID',
  defaultValue: true,
);
bool? _marineLifeIdOverride;

/// Whether an on-device vision engine runs on [platform]: Core ML on iPhone,
/// iPad and Mac ([coreMlRuns]), and the ONNX engine on Android, Windows and
/// Linux unless [onnx] (the `MARINE_LIFE_ID_ONNX` define) is off; never in a
/// browser, where Safari on a Mac still reports macOS.
/// [marineLifeIdEnabled] and the engines all ask this, so the UI and the
/// engine cannot disagree about where it runs.
bool visionEngineRuns(
  TargetPlatform platform, {
  bool web = kIsWeb,
  bool onnx = marineLifeOnnxPlatforms,
}) =>
    coreMlRuns(platform, web: web) ||
    (!web &&
        onnx &&
        (platform == TargetPlatform.android ||
            platform == TargetPlatform.windows ||
            platform == TargetPlatform.linux));

/// Whether the Core ML engine runs on [platform]: iPhone, iPad and Mac, never
/// in a browser.
bool coreMlRuns(TargetPlatform platform, {bool web = kIsWeb}) =>
    !web &&
    (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS);

/// Whether videos are scanned on [platform]: everywhere an engine can run
/// but Linux, where the app has no video player, and the web.
bool visionVideoRuns(TargetPlatform platform, {bool web = kIsWeb}) =>
    !web &&
    (platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.android ||
        platform == TargetPlatform.windows);

/// Turns the ONNX engine's platforms (Android, Windows, Linux) on. On since
/// the pack carries ONNX models (published 2026-11-22) and the Android floor
/// was settled: kept at 6.5 GiB, so 8 GB phones, after the Pixel 6a run
/// failed. A build passing `--dart-define=MARINE_LIFE_ID_ONNX=false` turns
/// them off. Only the exact
/// word `false` does: any other value (`0`, `False`, `off`) leaves them on.
/// It gates the engine and every screen that offers it, not packaging: the
/// build hook ships ONNX Runtime in every Android, Windows and Linux build,
/// so CI runs the real runtime and the turn-on build is the one tested.
const bool marineLifeOnnxPlatforms = bool.fromEnvironment(
  'MARINE_LIFE_ID_ONNX',
  defaultValue: true,
);

/// Lifts the ONNX engine's memory floor, for the build that measures a 6 GB
/// phone only. No released build sets it.
const bool marineLifeIgnoreFloor = bool.fromEnvironment(
  'MARINE_LIFE_ID_IGNORE_FLOOR',
);
