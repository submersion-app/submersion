/// Feature flags for gating in-progress or externally-blocked features out of
/// the user-facing UI without deleting their implementation.
///
/// These flags intentionally gate UI surfaces only. The backing services,
/// providers, repositories, auth flows, and database code remain fully intact
/// and functional so a feature can be restored by flipping a single flag.
///
/// Flags here are plain mutable top-level variables (not `const`) so that
/// widget tests can toggle them; they are evaluated at runtime, and production
/// code only ever reads them.
library;

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
