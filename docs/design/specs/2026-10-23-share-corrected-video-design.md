# Share colour-corrected videos

Issue: #3521 (follow-up to #3520)
Status: approved 2026-10-23

## Intent

Display-only colour correction (#3520) lets a diver tune how a dive video
looks in Submersion, and the automatic fix follows depth through the clip.
Sharing a photo already sends the corrected pixels; sharing a video sends the
original file, so a buddy who was on the dive receives the blue clip, not the
one the diver saw. The diver would have to recreate the correction in another
app.

This feature makes a shared video look the way it looked in the viewer.

## Goals

- A shared video with a colour correction in effect is a re-encoded copy
  carrying that correction, moment by moment, exactly as the viewer draws it
  while it plays.
- The copy keeps the original's resolution, frame rate, codec family, bit
  depth, HDR and roughly its quality, its audio, and its recording date and
  location, so it sorts into the recipient's library beside their own shots
  from the dive.
- The diver sees progress and can cancel a long encode.
- When the correction cannot be applied, the diver is told so and offered the
  original instead. Never a silent fallback.

## Non-goals

- Changing the original file or any cached copy (OS thumbnails, app
  thumbnails, posters, media store uploads). As in #3520, nothing is written
  back.
- An "export corrected video" action outside Share (save to library, save to
  file). Share is the only entry point.
- Trimming, resizing for messaging apps, or choosing an output quality.
- Changing photo sharing, or sharing documents.
- In-app playback on Windows or Linux.
- Linux. Share cannot send files on Linux at all today (share_plus throws
  `UnimplementedError` for any share with files), so a corrected copy would
  have nowhere to go. Linux Share behaves exactly as it does now and no Linux
  encode is built; issue #3606 covers Linux sharing and the Linux encode.

## Anti-goals

- The shared clip looking different from the viewer (different warmth, a
  colour jump where playback was smooth, washed-out or crushed tones). That
  would be worse than sending the original.
- Sharing the uncorrected original without saying so after the diver asked
  for a corrected share.
- Holding the whole video in memory to correct it.

## Behaviour

### Which videos are re-encoded

A video is re-encoded when the matrix the viewer would draw it with is not
identity at some moment of the clip. The rule is the one #3520 already uses
(`effectiveAdjustment`, `diverAutoFor`, `needsAutoStats`,
`composeCorrection`): the diver's own sliders, the diver's automatic fix on a
dive video, or both. Any other video is shared as the original, exactly as
today (resolved bytes, written to the share temp file).

The unsaved slider draft counts, as it does for photos
(`colorAdjustmentDraftNotifierProvider`), so a diver who shares straight from
the adjust panel sends what is on screen.

### What the copy carries

The colour at each moment is what `VideoColorFilter` draws at that playback
position:

```
composeCorrection(
  adjustment: adjustment,
  auto: track.paramsAt(seconds, depthAt: depthAt),
)
```

where `track` is `videoColorTrackProvider` for the clip (seven sampled
frames) and `depthAt` is `videoDepthAtProvider` (the dive profile). When the
automatic fix is wanted but no track can be built (the frames cannot be
read), the viewer falls back to the poster's colour; the share does the same,
giving one constant matrix for the whole clip. When the automatic fix is not
wanted, the matrix is the sliders alone, constant through the clip.

### Colour timeline (decided: the Dart side computes, native interpolates)

Native code never sees adjustments, auto params, depth or profiles. The Dart
side samples the composed 4x5 matrix through the clip into a colour timeline,
a list of `(seconds, ColorMatrix)` keys, and native code applies, to each
decoded frame at presentation time `t`, the linear interpolation of the two
keys around `t` (the first key before it, the last after it). A constant
correction is a timeline of one key.

The step between keys is the builder's call; it must be fine enough that the
interpolated matrix stays within one 0-255 level per channel of what
`VideoColorFilter` computes at any moment (a key every 0.5 s is the starting
guess; the depth bounding is not linear in time, which is why keys are dense
rather than one per sampled frame).

### How the matrix is applied to SDR video (constraint)

`ColorFilter.matrix` applies the matrix to the stored, gamma-encoded sRGB
values on a 0-255 scale; offsets (column 5) are on that scale; alpha is
ignored for video. `ColorMatrix.applyToPixel` is the reference. Each engine
must apply it the same way, to encoded values, not in a linear-light working
space, and clamp to the valid range. Core Image and Media3 both default to
linear working colour spaces, so this has to be set explicitly on each. A
test (below) compares encoded output against `applyToPixel`.

### HDR and 10-bit video (decided: keep HDR)

An HDR source (HLG, PQ/HDR10, HDR10+, Dolby Vision) stays HDR in the copy,
and a 10-bit source stays 10-bit.

Every correction is defined on SDR values: the sliders' matrices, and the
automatic fix, which is measured from frames the engine has already
tone-mapped to SDR JPEGs. *My call* on how that carries into HDR, chosen so
that everything inside the SDR range comes out exactly as on an SDR video
and highlights above it carry on smoothly instead of clipping:

1. Decode to linear light in BT.709/sRGB primaries, scaled so SDR reference
   white is 1.0 (PQ: 203 cd/m2, per ITU-R BT.2408; HLG: the BT.2408
   reference level). Values may exceed 1.0, and may go negative for BT.2020
   colours outside BT.709.
2. Encode with the sRGB transfer function extended beyond 0..1 (mirrored
   for negatives): the "extended sRGB" space.
3. Apply the matrix there, offsets divided by 255. No clamp at 1.0.
4. Decode back to linear and re-encode to the source's primaries and
   transfer function (BT.2020 with PQ or HLG), clamped to its legal range.

For values in 0..1 this is exactly the SDR maths above. Core Image's
extended sRGB working space is this space; on Android and Windows the
conversion is written as a shader or per-pixel step.

Metadata kept: colour primaries, transfer function and matrix tags, and
HDR10 static mastering metadata (mastering display and content light
levels) when present. Dynamic metadata cannot be carried through a pixel
change and is dropped: an HDR10+ clip comes out as HDR10, and a Dolby Vision
clip comes out as its base layer (iPhone's Dolby Vision is profile 8.4, whose
base layer is HLG, so it comes out as HLG). A device that cannot decode or
encode HDR (Android needs HDR editing support; Windows needs a 10-bit HEVC
encoder) gives the failure dialog, never a silent SDR copy.

### Output file

- Codec (decided: match the source): an HEVC source gives an HEVC copy
  (Main 10 when the source is 10-bit or HDR) and an H.264 source an H.264
  copy. *My call:* any other source codec (ProRes, AV1, VP9, Motion JPEG)
  gives HEVC, Main 10 when 10-bit or HDR. Modern phones and messaging apps
  play HEVC, and matching the source keeps footage like GoPro 5.3K, 8K and
  4K at 120 fps within what the device's encoder accepts. If the device
  still cannot encode it at full size, that is the failure dialog; it is
  never shrunk or changed to another codec silently (Media3's encoder
  fallback, which lowers resolution, is turned off).
- MP4 container (*my call*), HEVC tagged `hvc1` so Apple devices play it.
- Same pixel dimensions, orientation and frame rate as the source.
- Video bitrate sized from the source (the probe's overall bitrate) so
  quality is close to the original. The exact rule, including a floor and a
  ceiling, is the builder's call.
- Audio: every audio track's content kept. Copy it unchanged where the
  engine and container allow; otherwise AAC at the source's sample rate and
  channel count. A clip with no audio has none.
- Metadata: the recording date and the location (QuickTime/MP4 creation
  date and ISO 6709 location) are carried over whenever the source has them.
- Name: the item's share filename with an `.mp4` extension, in the same
  per-item folder the photo share uses (`<temp>/share/<item id>/`), so two
  shared items never collide. Cleanup is whatever already cleans that folder.

### Library rows and the poster fallback

A video shared from the library comes without its profile match. As the
photo share already does (`needsStoredMatch`, `enrichmentFor`), the share
reads the stored match first, so the depth lookup and surface check match
the viewer. When the automatic fix falls back to the poster's colour and no
tile has analysed it yet, the share works out the poster's statistics
itself rather than treating the auto part as empty (*my call*).

### Reading the source

The source is a file path, never bytes: `resolvedFilePathProvider` for the
item (gallery asset, local file, or the media store's cached original), and
on iOS and macOS a row linked through a security-scoped bookmark is opened
through `videoFileAccessProvider`, with access held for the encode only. If
no file can be reached, that is a failure (below), not a reason to load
bytes.

### While it encodes

When a share includes at least one video to re-encode, the spinner is
replaced by a small modal dialog:

- Title "Preparing video", a determinate progress bar with a percentage, and
  a Cancel button.
- Several videos to re-encode: "Preparing video 2 of 3", the bar showing the
  current video's progress.
- Photos and unchanged videos in the same share are prepared as today, before
  or between the encodes, under the same dialog.
- A share with no video to re-encode keeps today's spinner.

Cancel stops the native encode, deletes any partial and finished temp copies
of this share, closes the dialog, and opens no share sheet and no error.

### When the correction cannot be applied

Any failure to produce the corrected copy (no engine; no reachable file; a codec the engine cannot decode; an encoder
error; the frames for the colour track failing is NOT one of these, since the
poster fallback covers it) shows a dialog:

- Title: "Couldn't apply the colour correction"
- Body: one video: "This video can still be shared without it." Several
  failed: "N videos can still be shared without it."
- Buttons: "Share original" and "Cancel".

Share original opens the share sheet with the originals for the failed
videos and the corrected copies and photos already prepared. Cancel opens no
share sheet and deletes the temp copies.

*My call:* in a multi-item share, the remaining items are still prepared
after one fails, and the dialog appears once at the end rather than
interrupting after each failure.

### iOS sent to the background mid-encode

iOS stops video encoding soon after an app leaves the screen, and a long
clip takes longer than the extra time iOS grants. *My call:* the encode asks
for that extra time; if it is interrupted anyway, the share stops, temp
copies are deleted, and a message says preparing the video stopped when
Submersion went into the background and to share again to start over. It is
not the "Couldn't apply the colour correction" dialog, which would describe
the wrong cause. The same applies to Android if the system stops the encode.

### Where Share lives

All three share paths get the behaviour: the dive media viewer
(`media_viewer_page.dart`), the site media viewer
(`site_media_viewer_page.dart`, which has its own copy of the flow) and the
library's multi-select share (`media_share_helper.dart`). Folding the site
viewer onto the shared helper is the builder's call.

## The engine change

`submersion_transcoder` gains a colour-corrected encode on iOS, macOS,
Android and Windows (not Linux, see Non-goals), beside the existing `transcode` used by media store uploads. Its
Dart signature is the builder's call, but it takes a source file, an output
file, the colour timeline (as plain lists of seconds and 20-value matrices,
since the package never sees app types), a quality target, a progress
callback, and a way to cancel. It keeps `transcode`'s contract: write to
`<output>.tmp`, rename only on success, never leave a `.tmp`, throw
`TranscodeException` on failure. Cancel is new for the package; a cancelled
encode leaves no file and reports as cancelled, distinct from a failure.

The probe grows what the encode needs: video codec, bit depth, colour
primaries, transfer function, HDR static metadata, rotation and frame rate.

Per platform, the hook the builder is expected to use (each is the builder's
to change if it proves wrong):

- **iOS and macOS (AVFoundation):** the existing `AVAssetReader` to
  `AVAssetWriter` path, with each decoded pixel buffer (10-bit for HDR) run
  through `CIColorMatrix` in a Core Image context whose working colour space
  is extended sRGB, rendered into a buffer carrying the source's colour
  attachments, and the writer given the asset's metadata and the source's
  colour properties.
- **Android (Media3 Transformer):** for SDR, a time-varying `RgbMatrix`
  effect with the SDR working colour space set so the matrix sees encoded
  values; for HDR, `HDR_MODE_KEEP_HDR` with a custom GL effect doing the
  extended sRGB conversion. Encoder fallback off. Media3 is 1.4.1 today;
  upgrading it is allowed if a needed option is newer.
- **Windows (Media Foundation):** the WinRT `MediaTranscoder` used today
  cannot take a custom per-frame effect in an unpackaged app, so this encode
  is a Source Reader to Sink Writer loop (RGB32 for SDR, a 10-bit format for
  HDR), with the matrix applied to each frame between them.

## Testing

TDD on the Dart side; native code is checked against real clips.

- The colour timeline: for a track, a depth lookup and an adjustment, every
  key equals what `VideoColorFilter` computes at that time, and the
  interpolated matrix at points between keys stays within the tolerance
  above. Constant cases give one key; identity gives "share the original".
- The share flow, with a fake engine: progress shown and updated; "2 of 3";
  Cancel stops the engine and opens no sheet; a failure shows the dialog;
  Share original shares originals for failed items plus the prepared files;
  a share with nothing to re-encode keeps today's path and spinner.
- The channel engine: arguments sent, progress routed by id, cancel sent,
  cancellation and failure mapped to their Dart outcomes.
- Native colour accuracy: encode a short test clip of flat colour patches
  with a known timeline on each platform the session can run (macOS, iOS
  simulator, Android emulator), extract frames at known times, and compare
  against `applyToPixel` within a small tolerance allowing for H.264 loss.
  Also check audio is present and date and location survive.
- HDR: an HLG clip and a PQ clip with known patches, one patch inside the
  SDR range and one above it. Check the copy keeps its primaries, transfer
  and bit depth, the in-range patch matches the SDR maths after conversion,
  and the highlight patch is not clipped.
- Codec matching: an H.264 source gives H.264, an HEVC source HEVC.
- Windows is covered by its unit tests and CI build; whatever cannot be run
  here is listed in the PR.

## Left to the builder

- The engine API's exact shape and the colour timeline's step.
- The bitrate rule and audio copy versus re-encode per platform.
- Per-platform implementation details within the constraints above.
- Whether the site viewer's share flow moves onto the shared helper.
- Wording of the new strings beyond the titles and buttons above (new ARB
  keys, in every locale the app ships).
