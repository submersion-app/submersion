# Video volume and mute control (default muted)

## Why

Most scuba video carries nothing worth hearing: water, bubbles and breathing.
Today every clip in the media viewer plays at full volume and there is no way
to turn it down inside the app. Sound should be the exception a diver opts
into for the rare clip worth hearing (a surface briefing, someone talking on
the boat), not the default.

## Goals

- Every video opens muted.
- A mute button on the video controls, and the **M** key, toggle sound.
- Where there is a mouse, hovering the button slides out a volume slider.
- Unmuting (and the chosen level) lasts until the viewer closes: swiping to
  the next video keeps it, and the next time any viewer opens it starts muted
  again.

## Non-goals and anti-goals

- No Settings switch for the default. Muted is what is wanted; a setting is
  clutter.
- No persistence across viewer sessions or app restarts. One deliberate unmute
  must never flip the default for the next dive's bubble noise.
- No volume slider on touch screens: the device's hardware buttons set the
  level there, and a second slider would fight them.
- Anti-goal: any moment of sound at full volume while muted, including when a
  streamed video's expired link is reopened mid-play (#4162).

## Approaches considered

1. **A sound object owned by the viewer page (chosen).** `MediaViewerPage`
   creates it on open and disposes it on close, which is exactly the "resets
   when the viewer closes" rule. Every player already reaches the page through
   `_onVideoControllerChanged`, including a reopened stream's replacement, so
   the page applies the sound there; the opener is given it too, so a reopened
   stream that resumes playing is muted before `play()`.
2. **An app-wide auto-disposing Riverpod provider.** Less wiring, but the reset
   rides on Riverpod's listener timing: two stacked viewers would share state,
   and a gap in listeners during a swipe could reset it.
3. **Per-player volume handed over on swipe.** No shared state, but the handover
   sits on the most delicate seam of the swipe and reopen code.

## Design

- **`ViewerAudio`** (a `ChangeNotifier` in `lib/features/media/presentation/`):
  `muted` (starts true), `level` (0.0 to 1.0, starts 1.0), `effectiveVolume`
  (0 when muted, else level), `toggleMute()`, `setLevel(x)`, and
  `applyTo(VideoPlayerController)`.
  - Setting the level above 0 while muted unmutes; setting it to 0 shows as
    muted.
  - Unmuting with a level of 0 restores the last level above 0 (1.0 if none).
- **Viewer page** owns one `ViewerAudio`, applies it to each controller it
  registers, and re-applies to every live controller when it changes.
- **Opening a player** (`_VideoItem` and `VideoPlaybackOpener`) sets the
  volume before the player can play, including a reopen that resumes playing.
- **`VideoControlsBar`** gains a speaker button after the total time, in both
  placements (fullscreen bottom edge and the bottom panel's top row). Icon:
  `volume_off` when muted or at 0, `volume_down` below half, `volume_up`
  otherwise. Hovering the button, or giving it keyboard focus, shows a short
  slider beside it; it stays while the pointer is on the button or the slider,
  while focus is inside the control, and through a drag that strays off it
  until release. The bar holds the auto-hiding controls up for all three
  (hover, focus, drag). The button is no taller than the bar (40 px), whose
  height the fullscreen fish labels keep clear.
- **Background audio** (added after review): players open with
  `VideoPlayerOptions(mixWithOthers: true)`, so opening a muted video on iOS
  or Android no longer pauses the diver's music or podcast. Chosen knowing
  that an unmuted video then plays over that audio instead of pausing it.
- **M key** on the video page toggles mute, also in people tag mode (muting
  does not move the frame).
- **Accessibility:** the button is a button labelled "Mute video" or "Unmute
  video"; the slider is a slider labelled "Video volume" on its own node,
  stepping by each platform's native slider step (10% on Apple platforms, 5%
  on Android, Windows and Linux), as Flutter's Slider does.
- New strings go through the ARB files in `lib/l10n/arb/`.

## Left to the builder

- Exact slider width and animation (keep the scrub bar usable on a narrow
  desktop window).
- Test seams: unit tests for `ViewerAudio`, widget tests for the button,
  icon and hover slider, and viewer tests for muted-on-open, carry-over across
  a swipe, reset on reopen of the viewer, and a reopened stream staying muted.
