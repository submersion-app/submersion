# Display-only media color correction

Status: approved, 2026-10-19. Issue #3520. Release: v1.8.3.

## Why

Underwater photos and videos come out too blue. Water absorbs red light first,
and the deeper the shot the less red survives, so a diver scrolling their dive
photos in Submersion sees a blue (or, in lakes, quarries and temperate seas,
green) cast over everything. Divers fix this today in a separate app
(Lightroom, Dive+, ScubAI) and then have two copies of every photo.

Submersion already knows something those apps do not: the depth each photo
and video was taken at, matched from the dive profile. This feature uses that
to show natural colour inside the app, automatically or by hand, without ever
changing a file.

## Goals

1. An automatic correction that warms underwater photos and videos, informed
   by the depth each was taken at.
2. Hand adjustment of any photo or video: strength of the automatic fix,
   warmth, tint, brightness, contrast, saturation, and "pick white".
3. A hand adjustment is remembered per photo or video and syncs to the diver's
   other devices.
4. The correction shows everywhere a photo or video appears: grids,
   thumbnails, map markers, dive and site media strips, the full-screen viewer,
   and video while it plays.
5. A video's automatic correction changes as the clip plays, following the
   colour of the water and the depth through the clip.
6. One photo's hand adjustment can be applied to every other photo and video
   from the same dive in one step.
7. Sharing a photo from the app sends it with the correction applied.

## Non-goals

- Dehaze, shadows, highlights, local contrast, or any other per-region tool.
  These cannot run at draw time on every thumbnail and every video frame.
- A cache of pre-rendered corrected previews. Considered and rejected by the
  user: correction is computed at draw time only.
- Sharing a corrected video. Shared videos go out as the original file. Re-
  encoding with the adjustments is follow-up #3521.
- Cropping, rotation, filters or any other photo editing.

## Anti-goals (would be a failure even if it works)

- **Any write to a photo or video, or to a cached copy of one.** Not the
  original, not the OS or app thumbnails, not the video posters, not the
  media store's uploaded thumbnails or renditions. Correction lives only in
  how the app draws a photo. The only bytes this feature ever produces are
  (a) the small numbers it saves per photo and (b) the temporary file the
  share sheet already writes, which now carries the corrected pixels.
- Warming a surface shot (boat, beach, surface interval) so it looks orange.
- Turning photos purple by over-boosting red.
- Existing divers seeing their photos change on upgrade. The automatic fix is
  off by default.
- A grid that stutters or a viewer that lags because of the correction.

## Decisions made with the user

### The automatic fix

- **Off by default** for every diver, new and existing. Switched on in
  Settings > Photos & Media as "Automatic colour correction". Saved per diver,
  so it syncs with the diver's other settings.
- **Surface shots are skipped.** A surface shot is one the photo matcher
  placed before the descent or after the ascent (the dive-window slack in
  `media_dive_window.dart` / `dive_photo_matcher.dart`), or one whose matched
  depth is under about 1 m. *(The 1 m threshold is a design call, not the
  user's.)*
- **Only photos and videos linked to a dive are considered** (the user's
  choice). Site attachments (maps, entry signs, parking), equipment paperwork,
  documents and library-only items never get the automatic fix, though they
  can still be adjusted by hand.
- **A dive photo with no depth** (the dive has no profile) gets the automatic
  fix only if its own colours look underwater: a strong blue or green cast with
  very little red. Otherwise it is left alone. *(Design call.)*
- **Method** *(design call; details left to the builder within these limits)*:
  analyse each photo's colours once, from a small decode of its thumbnail.
  Rebuild the missing red from the green channel (green survives water best),
  then balance the channels toward neutral grey, with a cap so the result can
  never go purple. Depth bounds how far it may go: a 25 m shot may be warmed
  much more than a 5 m one. The output must be expressible as a single 4x5
  colour matrix (see Rendering), because that is what gets drawn.
- **Video:** sample several frames spread through the clip (around 6 to 8),
  discard ones that are nearly black or blown out, and compute a correction
  per sample. During playback the correction blends smoothly between samples.
  The dive profile's depth at each moment of the clip refines it between
  samples. Thumbnails and grids for a video use the clip's average. A video's
  `takenAt` is treated as the start of recording, as the photo matcher already
  does. *(Design call.)*
- **Windows and Linux** have no in-app video playback today (only the Android,
  AVFoundation and web `video_player` implementations are installed). There,
  videos still get multi-frame sampling (the user's choice), used for the
  clip-average correction on their thumbnails and posters. Per-moment
  correction during playback applies only where videos play. Adding desktop
  playback is not part of this feature.

### Hand adjustment

- Controls: **Auto** (per photo on/off), **Pick white**, **Strength** (how much
  of the automatic fix), **Warmth** (blue to red/yellow), **Tint** (green to
  magenta), and under a "More" fold **Brightness**, **Contrast**,
  **Saturation**. Plus **Reset**.
- The panel's **Auto** switch overrides the Settings switch for that one photo,
  in either direction. *(Design call.)*
- Hand adjustments work on every photo and video, including surface shots and
  anything the automatic fix skipped, whether the automatic fix is on or off.
- **Remembered per photo or video, and synced.** Stored as a small value on
  the media row, so it travels with the row through the existing media sync.
  *(Placement on the row is a design call; see Builder's calls.)*
- **On a video,** the sliders shift the whole clip while the automatic part
  still varies through it. Pick white is offered only on a paused frame and
  shifts the whole clip by the same amount. *(Design call.)*

### The viewer panel (layout A, chosen from mockups)

Mockup: [assets/2026-10-19-media-color-correction-mockup.html](assets/2026-10-19-media-color-correction-mockup.html).

- A new "Adjust colour" action in the viewer toolbar
  (`media_viewer_toolbar.dart`), in the photo and video viewers.
- It opens a panel under the photo on phones, docked to the right on desktop
  widths. The viewer stays usable: swiping to the next photo still works with
  the panel open, and the panel then edits that photo.
- The photo updates live while a slider moves.
- Press and hold the photo to see the original.
- A small label on the photo says what is applied, for example "18 m · auto"
  or "adjusted". *(Design call.)*
- **Apply to this dive:** copies the current photo's slider nudges (Strength,
  Warmth, Tint, Brightness, Contrast, Saturation) and its Auto switch to every
  other photo and video on the same dive. Each keeps its own automatic fix
  from its own depth, with the nudges added on top (the user's choice).
  - Targets that already have hand adjustments have their sliders and Auto
    switch **replaced** (the user's choice).
  - A target's own picked white point is **kept**, and the source's is not
    copied, because a white point only holds for the photo it was picked on.
  - A **confirmation** names how many photos and videos will change before
    anything is written, and an **Undo** is offered afterwards that restores
    every target's previous adjustment (the user's choice). This implies the
    stored model keeps the white point separate from the slider values.
- **The site media viewer** (`site_media_viewer_page.dart`) has its own toolbar
  and its own share path (`_shareCurrentItem` calls `writeShareTempFile`
  directly). It gets the same panel and corrected photo sharing, so "everywhere"
  holds for dive photos opened from a site. *(Design call.)*

### Sharing

- Sharing a **photo** (single or multi-select, from any viewer including the
  site viewer) sends the corrected pixels. The
  share helper (`media_share_helper.dart`) already resolves full-resolution
  bytes and writes a share temp file; the correction is applied to the decoded
  image before that temp file is written. The temp copy keeps the photo's
  date, location and camera metadata. *(Metadata keeping is a design call.)*
- Sharing a **video** sends the original file, unchanged.
- A photo with no correction in effect is shared exactly as today (original
  bytes, no re-encode).

## Delivery

One PR with everything in this design, for v1.8.3 (the user's choice, over
splitting photos and video into two PRs).

## Constraints

- **Rendering is a colour matrix at draw time.** Every correction (automatic,
  hand, or both combined) reduces to one 4x5 matrix applied with
  `ColorFiltered` / `ColorFilter.matrix` around the existing image and video
  widgets. Per-pixel linear maps only, which is why warmth, tint, brightness,
  contrast, saturation, strength and white point are in and dehaze is out.
- **One render path.** `MediaItemView` (`lib/features/media/presentation/widgets/media_item_view.dart`)
  is what grids, strips and viewers use to draw a photo; the correction is
  applied there and in the viewer's video player, so every surface picks it up
  without per-screen work.
- **Video frame sampling needs a new native call on every platform.** Today
  each platform makes its single poster with the OS thumbnailer (QuickLook on
  macOS, the Windows shell's `IShellItemImageFactory`, `ffmpegthumbnailer` on
  Linux, photo_manager on iOS/Android) and none can choose the moment. A
  "frame at time T" call is needed for macOS and iOS (AVFoundation
  `AVAssetImageGenerator`), Android (`MediaMetadataRetriever`), Windows (Media
  Foundation source reader) and Linux (`ffmpegthumbnailer -t`). It only reads
  the video.
- **Analysis results are device-local and may be recomputed.** The numbers the
  automatic fix derives from a photo's pixels are not synced (each device can
  derive them). They may be kept in memory or in a device-local table, but
  never in or beside the media files.
- Units: depth shown in the label follows the active diver's unit settings.
- All new strings go through l10n.

## Builder's calls

- Exact automatic algorithm and its constants, within the limits above (green-
  anchored red rebuild, grey-world balance, purple cap, depth-bounded
  strength, single matrix output).
- Slider ranges and default positions; how strength scales the automatic
  matrix.
- How hand adjustments are stored on the media row (one JSON text column vs
  several numeric columns), the schema rung, and sync serializer wiring,
  following the repo's `lib/core/database/tables/` and `migrations/` layout.
- Where analysis results are cached (memory only vs a device-local table) and
  how concurrency is bounded so grids stay smooth.
- Videos with no local file (store-only, or not yet downloaded): fall back to
  the poster plus profile depth.
- How the panel looks within layout A, matching the existing viewer styling.

## Follow-ups

- #3521: share corrected videos by re-encoding the clip with
  the per-moment adjustments.

## Out of scope reminders

- No change to "write dive data to photo" (it writes metadata, not colour).
- PDF logbooks embed no dive photos, so they are unaffected.
