# Memory for large photos and videos

Issue #4699. On an iPhone 17 Pro Max the app's own media set its memory
ceiling: with one 50 MP photo open in the viewer and no identification model
loaded it sat at 1,700 MiB, against 785 MiB with a video open, and its
overall peak, 2,708 MiB, fell in the minutes when about 20 photos and videos
were added to a dive. iOS gave it a limit of 3,376 MiB
([the phone memory findings](2026-11-17-marine-life-phone-memory.md)).

This note records where that memory goes in the code, what was changed, and
what was measured before and after.

## How it was measured

No phone runs were made for this work. The figures come from a Mac (M5 Pro,
macOS 27.2), in two standalone programs that use no app code, no database
and no network, sampled every 50 ms for the physical footprint, the figure
iOS compares with its limit:

- A Flutter release build (Impeller, as on iOS) that decodes the photo the
  way a given code path does: `MemoryImage` or `FileImage`, wrapped in the
  same `ResizeImage` the path builds, drawn in one to eight pages at once.
  Settings for the iPhone 17 Pro Max: a 440 x 956 point screen at 3x.
- A Dart command-line program (AOT) for the paths that never draw: staging
  an upload and package:image's resize.

Media: the same 8192 x 6144 JPEG (5.9 MB) and 27 s 4K HEVC clip (425 MB) as
the phone run, plus the photo rotated to 6144 x 8192 for the portrait case.

"Held" is the footprint 1.5 s after the last decode, above the program's
own baseline; "peak" is the highest sample after the baseline. Each figure is
the range over two runs.

## Before and after

| Path | Before | After |
| --- | --- | --- |
| Files tab, 8 review cards of the 50 MP photo | +2,523 to +2,534 peak, +2,138 to +2,149 held | +248 to +253 peak, +67 to +69 held |
| Files tab, 4 cards | +1,271 to +1,353 peak, +1,078 to +1,088 held | +244 peak, +39 to +61 held |
| Media store upload, staging the 425 MB clip | +947 to +963 peak | +1 peak |
| Compressed upload of the 50 MP photo (2048 px) | +563 to +570 peak | +130 to +158 peak |
| Viewer, the photo rotated to portrait | +242 to +257 held (5736 x 7648) | +141 to +144 held (4302 x 5736) |
| Viewer, the photo as taken (landscape) | +146 held (5736 x 4302) | unchanged, by choice |

MiB throughout. What each change does:

- **Files tab review cards** drew each picked photo at 48 px with no decode
  bound, so every card decoded the whole original. They now decode at twice
  the square's pixel width.
- **Photo-library originals** were read into memory. On iOS and macOS
  photo_manager reads an original by exporting it to a file and reading that
  back, so the resolver now hands over the file: an upload copies it file to
  file, and a viewer page decodes from the path instead of holding a copy of
  the original. Android still reads bytes, which cross the platform channel
  there rather than coming from a file.
- **The site media viewer** drew a video page as a photo, which resolved the
  original: a photo-library video was read whole into memory and handed to
  the image decoder, which cannot read it ("Invalid image data"). It now
  shows the video's poster at screen size. The staging figure above is the
  same read.
- **Compressed uploads** of local photos decoded the original with
  package:image. They now use the engine's codecs, which scale as they decode,
  as thumbnails already did. A JPEG's EXIF (capture time, location) is copied
  into the rendition less its orientation, as package:image's re-encode kept
  it, and a format package:image cannot read (HEIC) still uploads untouched,
  since its metadata could not be carried over.
- **The viewer** bounded its decode by width only, so a portrait photo was
  decoded at nearly its full size. It now fits the decode inside a square of
  the same bound, which gives portrait photos the detail landscape ones
  already had.

## Kept as they were

Decided with the maintainer on 2026-11-18:

- **Zoom detail.** The viewer still decodes at the screen's long side x 3 x 2
  (5736 px on that phone), which keeps a 50 MP photo sharp to about 4x zoom.
  Two times the photo's on-screen size would hold about +45 MiB instead of
  +146 MiB, but goes soft past 2x zoom.
- **Neighbour pages.** The viewer still decodes the page either side at the
  full bound, so a run of 50 MP photos holds three of them: +446 MiB, against
  about +190 MiB with the neighbours at on-screen size.

## Still open

- **The phone's photo figure.** The viewer's own decode of that photo holds
  about 150 MiB, and neither of the two changes that touch it applies to a
  landscape JPEG. The rest of the 1,700 MiB against 785 MiB was not traced:
  the run had marine life identification on, which reads the original again
  (`mediaBytesProvider`, kept for 30 s), sends it over the platform channel
  and decodes it natively. A phone run with the identification switched off,
  or with Instruments attached, would settle it.
- **When the 2,708 MiB peak happened.** The readout reports the highest
  footprint since launch, read at the next identification stage, so the peak
  may have come from the second model load rather than from the media being
  added. If those media came through the Files tab, the review cards alone
  account for it.
- **Network-served originals** in the viewer keep the width-only bound:
  cached_network_image takes both dimensions as exact bounds, and the viewer
  shares its cache entry.
