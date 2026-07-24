# Local-file video thumbnails (desktop) — design

## Problem

Videos linked via **Add photo or video → Files** (local-file source) render a
movie-icon placeholder in the media grid, while videos linked from Apple Photos
(the gallery source) show a real poster frame. The difference is mechanical:
`photo_manager` asks the OS for a poster for gallery assets, but the local-file
path has no equivalent, so `LocalFileResolver.resolveThumbnail` returns the raw
video `FileData`, which `MediaItemView` cannot decode and falls back to the
placeholder.

Goal: local-file videos on **desktop** show an OS-generated poster frame that
looks identical to a gallery video tile (poster + videocam badge).

## Scope

- **In scope:** macOS, Windows, Linux local-file video posters in the dive
  media grid.
- **Out of scope:** iOS and Android (keep the placeholder). Local-file video on
  iOS is a separate known gap — only a security-scoped bookmark is stored, no
  usable path — and mobile video import is rare for this workflow.
- **Explicitly NOT a bonus:** the media-store upload pipeline
  (`ThumbnailGenerator`) calls the same `resolveThumbnail`, so it is tempting to
  assume local-video posters start flowing to uploads for free. They do not.
  `ThumbnailGenerator._resizeToJpeg` decodes generic `BytesData` by the row's
  `originalFilename` (`thumbnail_generator.dart`), so a `.mp4`-named row still
  decodes to null — exactly as the prior raw-video `FileData` path did. That is
  **no regression**, and the requirement here is only that this design does not
  make the upload path worse. Actually feeding poster bytes into upload
  thumbnails needs `_resizeToJpeg` to recognise poster bytes as an image
  regardless of the video filename, and is a deliberate follow-up.

## Mechanism: native OS thumbnailers

Mirror the gallery approach — ask the OS — rather than bundling a cross-platform
decoder (ffmpeg_kit / media_kit), which would add a large native binary with
size and LGPL/GPL considerations (and ffmpeg_kit is retired).

A new method `generateVideoThumbnail` is added to the existing
`com.submersion.app/local_media` `MethodChannel` (native handlers already exist:
`LocalMediaHandler.swift` on macOS, and the Windows/Linux runners).

- **macOS** — `QLThumbnailGenerator` (QuickLook; the engine Finder and Photos
  use). The app is sandboxed, so the Dart side passes the **security-scoped
  bookmark blob** (as `readBookmarkBytes` does); the handler resolves it, starts
  security-scoped access, generates the thumbnail, releases access. Returns
  encoded image bytes (JPEG).
- **Windows** — `IShellItemImageFactory::GetImage` (the Explorer thumbnail
  cache). Non-sandboxed; takes the plain `localPath`. Returns encoded image
  bytes (PNG/JPEG).
- **Linux** — shell out to `ffmpegthumbnailer` (preferred) or a gstreamer
  pipeline **if present on `PATH`**; otherwise return null. Linux has no
  universal thumbnail API, so this degrades to the icon rather than adding a
  hard runtime dependency.

Every native path returns `null` on any error. Nothing throws to the UI.

## Architecture & data flow

```
DiveMediaSection grid tile
  └─ MediaItemView.resolveThumbnail(item, target)
       └─ LocalFileResolver.resolveThumbnail
            ├─ image  → FileData(file)                       (unchanged)
            └─ video  → VideoThumbnailService.posterFor(item, maxDim)
                          ├─ disk-cache hit → BytesData(jpeg)
                          ├─ miss → local_media channel
                          │           .generateVideoThumbnail(...)
                          │         → write cache → BytesData(jpeg)
                          └─ null (unsupported/failed) → resolve() → FileData(video)
                                                          → MediaItemView placeholder
```

`MediaItemView` already renders `BytesData` via `Image.memory`, and
`DiveMediaSection` already stacks the videocam badge over the thumbnail — so a
returned poster looks exactly like a gallery video tile with no render-layer
changes. The existing `FileData() when item.isVideo → _VideoThumbnailPlaceholder`
branch remains as the fallback.

### Why `BytesData`, not a cached `FileData(poster)`

`MediaItemView` guards `FileData() when item.isVideo → placeholder` to stop raw
video bytes reaching `Image.file`. A cached-poster *file* returned as `FileData`
would wrongly trip that guard. Returning `BytesData` keeps "this is a renderable
image" unambiguous at the type level, so the render switch needs no
special-casing. Posters are ~tens of KB, so reading bytes is cheap.

## Components

### `VideoThumbnailService` (pure-Dart, unit-tested)

Responsibility: given a local-file video `MediaItem` and a max dimension, return
poster bytes or null, with a disk cache. Depends on `LocalMediaPlatform` (the
channel), `LocalBookmarkStorage` (macOS bookmark blob), and a cache directory.

- **Cache key:** a hash of `localPath + file mtime + file size + maxDimension`.
  Replacing or re-exporting a file changes its mtime and therefore the key, so a
  stale poster is never served.
- **Cache location:** `Application Support/Submersion/video_thumbnails/<key>.img`.
  The extension is deliberately format-agnostic: the cache stores whatever
  encoded bytes the platform returned (JPEG from macOS QuickLook, PNG from the
  Windows shell and ffmpegthumbnailer). Nothing decodes by filename —
  `Image.memory` sniffs the container — so a `.jpg` name would misdescribe most
  entries.
- **Flow:**
  1. Return null immediately if the item has no `localPath`.
  2. Compute the key from the file's stat. A failed stat is **not** fatal: it
     falls back to a coarser key (path + dimension) and generation still
     proceeds, because on sandboxed macOS the path may be unreadable to Dart
     while the native side can still resolve it through the bookmark.
  3. Cache hit → return the cached bytes. If the cache directory cannot be
     resolved at all, caching is skipped and generation still proceeds.
  4. Miss → resolve the platform argument (macOS: bookmark blob via
     `LocalBookmarkStorage.read(item.bookmarkRef)`; Windows/Linux: `localPath`),
     call `generateVideoThumbnail`, and on non-null bytes write the cache and
     return them.
  4. Channel returns null → return null (resolver falls through to the raw-video
     `FileData`, i.e. the placeholder).
- **Eviction:** none initially. Posters are small and bounded by the local-video
  count; a size cap is a noted follow-up (YAGNI).

### `LocalMediaPlatform.generateVideoThumbnail`

Thin channel wrapper: `Future<Uint8List?> generateVideoThumbnail({String? path,
Uint8List? bookmarkBlob, required int maxDimension})`. Returns null when the
channel yields null or throws (unsupported platform / missing tool / decode
failure).

### `LocalFileResolver.resolveThumbnail`

For `item.isVideo`, delegate to `VideoThumbnailService.posterFor`; on non-null
return `BytesData(poster)`, otherwise fall through to `resolve(item)` (current
behavior). For non-video items, unchanged (`resolve(item)`).

### Native handlers

New `generateVideoThumbnail` case on the `local_media` channel in each desktop
runner (macOS/Windows/Linux) implementing the mechanism above.

## Timing

Lazy, on-demand at tile render — not at import. A folder of ~160 GoPro clips
generates posters only for the ~12 visible tiles; the rest are produced on
scroll and then cached. Eager-at-import would churn on multi-hundred-MB files
nobody is viewing.

## Error handling

- Native failure / unsupported platform / missing Linux tool → channel returns
  null → placeholder. Never an exception to the UI.
- Item with no `localPath` → null → placeholder.
- A local file Dart cannot stat is **not** treated as failure: the key degrades
  and generation is still attempted (native may reach it via the macOS
  bookmark). Only a null from the channel yields the placeholder, at which
  point the resolver's existing volume-offline / not-found handling in
  `resolve()` applies to the fallback.
- Cache directory unresolvable (e.g. `getApplicationSupportDirectory()` throws)
  → caching is skipped, generation still proceeds. The service never lets that
  escape into grid rendering.
- Corrupt cache read → treat as a miss and regenerate.

## Testing

- `VideoThumbnailService`: cache hit, cache miss (calls channel, writes cache),
  key derivation (mtime/size/dimension changes bust the key), null passthrough
  when the channel returns null, null when the item has no `localPath`, and
  generation still succeeding when the cache directory cannot be resolved —
  all against a fake `LocalMediaPlatform`.
- `LocalFileResolver.resolveThumbnail`: video → `BytesData` when the service
  returns bytes; video → `FileData` fallback when it returns null; image →
  `FileData` unchanged.
- Native handlers: manual desktop smoke tests per platform (consistent with the
  rest of the native surface, which `flutter_test` cannot drive).

## Non-goals / follow-ups

- Feeding poster bytes into the media-store upload thumbnail. Needs
  `ThumbnailGenerator._resizeToJpeg` to recognise poster bytes as an image
  rather than decoding by the row's `.mp4` `originalFilename`. See the scope
  note above: today that path yields null, unchanged from before this design.
- Poster cache size cap / eviction.
- iOS/Android local-file video posters.
- Regenerating posters when a file is edited in place without an mtime change
  (not expected for imported media).
