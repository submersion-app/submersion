# Video Volume and Mute Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Videos in the media viewer open muted, with a mute button (and the M key) on the controls and a hover volume slider where there is a mouse.

**Architecture:** A `ViewerAudio` change notifier holds the viewer's sound (muted, level). `MediaViewerPage` creates one per open viewer and disposes it on close, which is the "resets when the viewer closes" rule. Each `_VideoItem` listens to it and applies it to its own player; `VideoPlaybackOpener` applies it right after every `initialize()`, so a reopened stream is at the right volume before it resumes playing. `VideoControlsBar` shows a new `VideoVolumeControl` after the total time.

**Tech Stack:** Flutter, `video_player` (`VideoPlayerController.setVolume`), flutter_test.

**Spec:** `docs/design/specs/2026-11-20-video-volume-mute-design.md`

## Global Constraints

- Every video opens muted; no Settings switch; nothing persisted beyond the open viewer.
- No volume slider on touch screens: the slider shows only on hover or keyboard focus.
- Never a moment at full volume while muted, including a reopened stream (#4162).
- `media_viewer_page.dart` is 792 lines against the 800-line cap: add at most 5 lines there.
- New strings go in `lib/l10n/arb/app_en.arb` and every other locale ARB, then regenerate.
- Tests that swap `VideoPlayerPlatform.instance` restore it (`useBarPlatform()` does).

## Review Focus

- Muting while a video plays must silence it at once, not at the next play: the item applies on every notifier change (Task 3 test "toggling mute applies to the live player").
- A stream reopened mid-play after a muted start stays muted (Task 2 test "reopen applies the volume before play").
- Dragging the slider to 0 then pressing unmute must give sound, not stay silent (Task 1 test "unmute from level 0 restores the last level").
- Keyboard users must reach the slider: Tab from the button onto the slider keeps it shown (Task 4 test "focus inside the control keeps the slider").
- Swiping to the next video keeps an unmute; a new viewer starts muted (Task 3 viewer tests).

---

### Task 1: `ViewerAudio`

**Files:**
- Create: `lib/features/media/presentation/helpers/viewer_audio.dart`
- Test: `test/features/media/presentation/helpers/viewer_audio_test.dart`

**Interfaces:**
- Produces: `class ViewerAudio extends ChangeNotifier` with `bool get muted` (starts true), `double get level` (starts 1.0), `double get effectiveVolume` (0 when muted, else level), `void toggleMute()`, `void setLevel(double level)` (clamped 0..1), `Future<void> applyTo(VideoPlayerController controller)` (calls `setVolume(effectiveVolume)`).

- [ ] **Step 1: Write the failing tests**
  - `starts muted at full level`: `muted == true`, `level == 1.0`, `effectiveVolume == 0`.
  - `toggleMute unmutes to the level and notifies`: after toggle, `effectiveVolume == 1.0`, listener called once.
  - `setLevel above 0 while muted unmutes`: `setLevel(0.4)` gives `muted == false`, `effectiveVolume == 0.4`.
  - `setLevel 0 reads as muted`: `setLevel(0)` gives `muted == true`, `effectiveVolume == 0`.
  - `unmute from level 0 restores the last level`: `setLevel(0.6)`, `setLevel(0)`, `toggleMute()` gives `effectiveVolume == 0.6`; from a fresh object, `setLevel(0)` then `toggleMute()` gives `1.0`.
  - `muting keeps the level`: `setLevel(0.3)`, `toggleMute()` gives `muted == true`, `level == 0.3`.
  - `applyTo sets the player's volume`: with `useBarPlatform()` and `readyController()`, `applyTo(c)` gives `c.value.volume == 0`.
- [ ] **Step 2: Run** `flutter test test/features/media/presentation/helpers/viewer_audio_test.dart`; expect compile failure.
- [ ] **Step 3: Implement.** Keep `_lastAudible` (last level above 0, default 1.0); `setLevel(0)` sets `muted` true and leaves `_lastAudible`; `toggleMute()` to unmuted with level 0 sets level to `_lastAudible`. Notify only on change.
- [ ] **Step 4: Run** the test; expect PASS.
- [ ] **Step 5: Commit** `feat(media): viewer audio state for video volume and mute`.

### Task 2: Opener applies the volume

**Files:**
- Modify: `lib/features/media/presentation/widgets/video_playback_opener.dart`
- Test: `test/features/media/presentation/widgets/video_playback_opener_test.dart`

**Interfaces:**
- Consumes: none.
- Produces: `VideoPlaybackOpener(playback, {required release, network, file, double Function()? volume})`. When `volume` is set, every player it opens (`open()` file and stream paths, and `reopenAfterError`) gets `setVolume(volume())` right after `initialize()`, inside the same try that releases it on failure.

- [ ] **Step 1: Write the failing tests** (in the existing opener test file, using its fakes):
  - `opened player takes the volume`: opener with `volume: () => 0`; the controller from `open()` has `value.volume == 0` (file and stream).
  - `reopen applies the volume before play`: a watched streamed player that was playing fails; the replacement has `value.volume == 0` and the fake records `setVolume` before `play` for it.
- [ ] **Step 2: Run** the opener test file; expect the new tests to FAIL.
- [ ] **Step 3: Implement** the parameter and the two call sites (`open()` file case, `_openCandidate`).
- [ ] **Step 4: Run** the opener test file; expect PASS.
- [ ] **Step 5: Commit** `feat(media): open video players at the viewer's volume`.

### Task 3: Viewer owns the sound; video pages apply it; M key

**Files:**
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (field `final _audio = ViewerAudio();`, `_audio.dispose()` in `dispose`, pass `audio: _audio` to `_PhotoGallery`)
- Modify: `lib/features/media/presentation/pages/media_viewer_gallery.dart` (`final ViewerAudio audio;` passed to `_VideoItem`)
- Modify: `lib/features/media/presentation/pages/media_viewer_video_item.dart`
- Test: `test/features/media/presentation/pages/media_viewer_video_test.dart` (and `video_viewer_test_harness.dart`: record `setVolume` calls per player in `FakeVideoPlatform`)

**Interfaces:**
- Consumes: Task 1 `ViewerAudio`; Task 2 `volume:` parameter.
- Produces: `_VideoItem.audio` (required `ViewerAudio`).

`_VideoItem`: pass `volume: () => widget.audio.effectiveVolume` to the opener; listen to `widget.audio` (add in `initState`, swap in `didUpdateWidget`, remove in `dispose`) and on change call `audio.applyTo(_controller)` when there is one; in `_handleKeyEvent`, `LogicalKeyboardKey.keyM` key-down calls `widget.audio.toggleMute()` and returns handled (also in tag mode).

- [ ] **Step 1: Write the failing tests:**
  - `a video opens muted`: open the viewer on a video; the fake's last volume for the player is 0.
  - `M toggles mute on the live player`: press M; last volume 1.0; press again, 0.
  - `toggling mute applies to the live player while it plays`: tap to play, press M, last volume 1.0 without another play.
  - `an unmute carries to the next video`: two videos, press M on the first, swipe (or arrow key) to the second; its player's volume is 1.0.
  - `a new viewer opens muted again`: unmute, pop the viewer, push a new one on the same video; volume 0.
- [ ] **Step 2: Run** the viewer test file; expect FAIL.
- [ ] **Step 3: Implement** the page, gallery and item changes above.
- [ ] **Step 4: Run** the viewer test file and the opener test file; expect PASS. Check `wc -l media_viewer_page.dart` is at most 800.
- [ ] **Step 5: Commit** `feat(media): videos open muted and M toggles sound`.

### Task 4: Volume control on the bar

**Files:**
- Create: `lib/features/media/presentation/widgets/video_volume_control.dart`
- Modify: `lib/features/media/presentation/widgets/video_controls_bar.dart` (optional `ViewerAudio? audio`; when set, `VideoVolumeControl(audio: audio)` after the total time)
- Modify: `lib/features/media/presentation/pages/media_viewer_bottom_metadata.dart` and `media_viewer_video_item.dart` (pass `audio:` to both bars)
- Modify: `lib/l10n/arb/app_*.arb` (keys below), regenerate l10n
- Test: `test/features/media/presentation/widgets/video_volume_control_test.dart`

**Interfaces:**
- Consumes: Task 1 `ViewerAudio`.
- Produces: `class VideoVolumeControl extends StatefulWidget { const VideoVolumeControl({super.key, required ViewerAudio audio}); static const buttonKey = ValueKey('videoVolume.button'); static const sliderKey = ValueKey('videoVolume.slider'); }`
- Strings: `media_photoViewer_muteVideoLabel` "Mute video", `media_photoViewer_unmuteVideoLabel` "Unmute video", `media_photoViewer_videoVolumeLabel` "Video volume".

Layout: an `IconButton` (white, 20 px icon, tooltip and semantics label = mute or unmute string) with `Icons.volume_off` when `effectiveVolume == 0`, `Icons.volume_down` below 0.5, `Icons.volume_up` otherwise; beside it an `AnimatedSize` slider, 80 px wide, shown while the pointer is over the control (`MouseRegion`) or focus is inside it (`Focus(onFocusChange:)` around both, `canRequestFocus: false`, `skipTraversal: true`). `Slider` value `effectiveVolume`, `onChanged: audio.setLevel`, white active, 30% white inactive, wrapped in `Semantics(label: videoVolumeLabel)`.

- [ ] **Step 1: Write the failing tests:**
  - `shows the muted icon and unmutes on tap`: muted audio; `volume_off` icon; tap button; `audio.muted == false`, `volume_up` icon.
  - `icon follows the level`: `setLevel(0.3)` gives `volume_down`.
  - `no slider without hover or focus`: `find.byKey(sliderKey)` finds nothing.
  - `hover shows the slider and dragging sets the level`: mouse gesture `addPointer` + `moveTo` the button; slider found; drag it to its left quarter; `audio.level` about 0.25 and unmuted.
  - `focus inside the control keeps the slider`: focus the button via `Tab`, slider shown; `Tab` again onto the slider, slider still shown.
  - `semantics labels`: button labelled "Unmute video" while muted, "Mute video" after the tap.
  - In `video_controls_bar_test.dart`: `bar shows the volume control when given audio` and `bar shows none without audio`.
- [ ] **Step 2: Run** the two test files; expect FAIL.
- [ ] **Step 3: Implement** the widget, bar parameter, both call sites and strings.
- [ ] **Step 4: Run** `video_volume_control_test.dart`, `video_controls_bar_test.dart`, `media_viewer_video_test.dart`; expect PASS. `dart format .`, `flutter analyze`.
- [ ] **Step 5: Commit** `feat(media): mute button and hover volume slider on the video controls`.
