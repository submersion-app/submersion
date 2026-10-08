# Perdix-Style Dive Computer Overlay on Media Playback (#168)

Status: approved design, pre-implementation
Issue: https://github.com/submersion-app/submersion/issues/168
Date: 2026-07-16

## Summary

A draggable, translucent overlay styled after a Shearwater Perdix dive computer
face, shown over videos (live, synced to playback) and photos (static, at the
capture instant) in `PhotoViewerPage`. It displays the dive computer readings
for the exact moment on screen, derived from the dive profile via the existing
media enrichment anchor.

## Decisions Made During Brainstorming

| Decision | Choice |
| --- | --- |
| Display behavior | Adaptive like a real Perdix: NDL normally; STOP + TTS when in deco |
| Unsyncable media | Overlay (and its toggle) hidden entirely — no dashes, no guesses |
| Scope | Videos and photos (static face for photos) |
| Visual fidelity | Translucent HUD: Perdix screen layout on a semi-transparent black panel, no device case, no Shearwater branding (trademark) |
| Data density | Data-rich: three rows — Depth/NDL/Time, Max/Temp/Gas, Tank/CNS/ppO2 — rows collapse when data is absent |
| Architecture | Self-contained overlay widget; video-position bridge stays inside the widget (no Riverpod provider at frame rate) |

## Time Synchronization

- Anchor: `MediaEnrichment.elapsedSeconds` — seconds into the dive at the media
  item's capture start (already computed by `EnrichmentService`, wall-clock
  normalized, reflecting any user clock-offset correction applied at
  enrichment time).
- Video: `diveTimeSeconds = enrichment.elapsedSeconds + videoPosition`
  where `videoPosition` comes from the existing `VideoPlayerController`
  (listener pattern already used by the scrub bar in
  `photo_viewer_page.dart`). Resolved at `floor(diveTimeSeconds)` — integer
  seconds, matching a real Perdix's ~1 Hz refresh and `resolveSample()`'s
  integer-timestamp API.
- Photo: static `diveTimeSeconds = enrichment.elapsedSeconds`.
- Clamping: values clamp to the first/last profile sample when the mapped time
  falls outside the profile (pre-entry or post-surfacing footage). The face
  never blanks mid-playback.

## Availability Gate

The overlay and its toggle button exist only when ALL hold for the current
media item:

1. `enrichment != null`
2. `enrichment.matchConfidence != MatchConfidence.noProfile`
3. The dive profile has at least one sample.

## Components

All new UI code under `lib/features/media/presentation/widgets/perdix_overlay/`.

### `PerdixFaceData` (view-model)

Immutable class: `depth`, `runningMaxDepth`, `ndlSeconds`, `ceilingMeters`,
`ttsSeconds`, `diveTimeSeconds`, `temperature`, `gasLabel`, `tankPressureBar`,
`cnsPercent`, `ppO2`, `inDeco`. All fields nullable except `depth` and
`diveTimeSeconds`. Metric internally; formatting happens in the widget.

### `resolvePerdixFace(...)` (pure function)

Inputs: profile samples, `ProfileAnalysis?`, tanks + gas switches, tank
pressure series, prefix-max depth array, `diveTimeSeconds`.
Wraps `resolveSample()` from `instrument_tiles.dart:197` (same
profile/analysis index-alignment caveat applies: pass the profile the analysis
was computed over) and adds:

- `runningMaxDepth` from a prefix-max array computed once per profile load
  (authentic Perdix MAX = max so far in the dive, not the logged dive max).
- `gasLabel` in Perdix `O2/He` notation (e.g. `21/00`, `18/45`) resolved from
  the tank/gas-switch timeline at the timestamp.
- `inDeco` = sample `ceiling > 0` or `decoType == 2`.

### `PerdixFace` (presentational widget)

- Semi-transparent black rounded panel (`rgba(0,0,0,0.55)`), monospace type,
  small cyan labels, large white values.
- Row 1: DEPTH | NDL | TIME. Row 2: MAX | TEMP | GAS. Row 3: TANK | CNS | PPO2.
- Deco mode: NDL cell becomes STOP showing the ceiling rounded UP to the next
  3 m / 10 ft stop increment; MAX cell becomes TTS.
- Color coding (real-device conventions): NDL green > 5 min, yellow <= 5 min,
  red at 0; ppO2 yellow >= 1.4 bar, red >= 1.6 bar; STOP/ceiling shown in red
  when in deco.
- Cells with no data are omitted; a fully empty row collapses. Recreational
  air dives without AI show a clean two-row face.
- Fixed design width ~300 dp, scaled down proportionally on narrow panes.
- All values formatted through the existing unit-settings services (depth
  m/ft, temp C/F, pressure bar/psi). Labels are localized ARB strings (all 10
  non-English locales per project policy).

### `DraggablePerdixOverlay` (interaction wrapper)

- Copies the fraction-based `Align` + `onPanUpdate` pattern from
  `DraggableReadoutCard` (`draggable_readout_card.dart`), fractions clamped to
  [0,1], NaN-sanitized.
- For video: rebuilds the face via `AnimatedBuilder` on the
  `VideoPlayerController` — only the overlay subtree repaints per frame.
- Consumes taps on the face (drag detector), so video tap-to-play/pause works
  everywhere outside it.

### Viewer integration

- Mounted in the `PhotoViewerPage` stack alongside the existing controls
  overlay, for both `_VideoItem` pages and photo pages, behind the
  availability gate.
- Toggle: a dive-computer icon button in the viewer's top overlay bar; hidden
  when the gate fails. One shared setting for photos and videos.
- Coexists with the existing photo metadata bar and mini profile overlay;
  the user can drag it clear.

### Settings

Three new persisted settings, mirroring `fullscreenReadoutCardX/Y`:
`perdixOverlayEnabled` (bool, default false), `perdixOverlayX`,
`perdixOverlayY` (double fractions).

## Data Sources in the Viewer

Profile, `ProfileAnalysis`, tanks/gas switches, and tank pressures come from
the same providers `ProfileInstrumentBar` and the fullscreen profile page
already use (`diveProvider`/`diveProfileProvider`, analysis provider, tank
pressure provider), watched by the overlay's parent — not per frame.

## Error Handling

- Gate failures render nothing (no error states shown to the user).
- Resolver returns a `PerdixFaceData` with nulls for anything unavailable;
  the widget renders what exists.
- NaN/absurd persisted positions are sanitized exactly as
  `DraggableReadoutCard._sanitize` does.

## Testing (TDD)

- Unit — `resolvePerdixFace`: interpolation/nearest-sample resolution, prefix
  running-max behavior, deco trigger + stop-increment rounding (metric and
  imperial), gas label across a gas switch, tank pressure lookup, start/end
  clamping, all-optional-null dives.
- Widget — `PerdixFace`: row collapse (3-row vs 2-row), deco cell swap, NDL
  and ppO2 color thresholds, metric vs imperial formatting via settings mocks.
- Widget — integration: toggle hidden when gate fails, drag persists
  fractions, static photo mode vs listener-driven video mode.
- Manual smoke on macOS with a real enriched dive video before PR.

## Out of Scope

- Burning the overlay into exported video files.
- A moving playback marker on the mini profile overlay (future; would lift the
  video->dive-time bridge into a provider).
- Per-slot user-configurable metrics (real-Perdix-style layout config).
- Shearwater branding/logo on the face.
