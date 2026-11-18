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
bool lightroomUiEnabled = false;

/// Whether marine life identification is surfaced in the UI (issue #4668):
/// the settings page, analysing photos as they are opened, and suggested
/// species in the photo viewer.
///
/// On wherever an engine runs (iPhone, iPad and Mac) and hidden on the web,
/// Android, Windows and Linux, which have no engine yet. It asks
/// [visionEngineRuns], as `ChannelVisionEngine` does, on every read, so the UI
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

/// Drops a test's override, so [marineLifeIdEnabled] follows the platform.
@visibleForTesting
void resetMarineLifeIdEnabled() => _marineLifeIdOverride = null;

const _marineLifeIdDefine = bool.fromEnvironment(
  'MARINE_LIFE_ID',
  defaultValue: true,
);
bool? _marineLifeIdOverride;

/// Whether the on-device vision engine (Core ML) runs on [platform]: iPhone,
/// iPad and Mac, and never in a browser, where Safari on a Mac still reports
/// macOS. [marineLifeIdEnabled] and `ChannelVisionEngine` both ask this, so
/// the UI and the engine cannot disagree about where it runs.
bool visionEngineRuns(TargetPlatform platform, {bool web = kIsWeb}) =>
    !web &&
    (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS);
