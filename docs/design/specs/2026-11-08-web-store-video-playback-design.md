# Playing media store videos in the web app

Issue #4162. Follow-up from #4121 (the web app, PR #4142).

## Why

In a browser, a video that lives in the media store shows only its
thumbnail. `MemoryMediaStoreFetches` serves an original or rendition only
for photos, because a page has no file to hand the video player, and
`_VideoItem` in `media_viewer_page.dart` plays only from a file path
(`resolvedFilePathProvider`). A diver who opens the web app sees their dive
videos as stills with a "video file not found" message.

The player on the web (`video_player_web`) sets a URL as the `src` of an
HTML `<video>` element. That element fetches the file itself, and the page
cannot add headers to its requests, so the URL alone has to authorise the
read. S3 and Dropbox can produce such a URL. Google Drive (bearer token in
the `Authorization` header only; tokens in the query string stopped working
in 2020) and WebDAV (Basic auth in a header; Chrome refuses
`user:pass@host` URLs for media) cannot, so they stream through a service
worker that adds the header.

## Goals

- A video in the media store plays in the web app from every store the web
  app supports: S3 and S3-compatible, Dropbox, Google Drive and WebDAV.
- Playback streams: it starts within a couple of seconds, seeking works,
  and the page never holds the video's bytes in memory. There is no size
  cap.
- The viewer's existing loading spinner and error screen are reused; the
  installed apps' file-path playback is unchanged.

## Browsers and hosts

- Chromium, Firefox and Safari are equal targets, as decision 12 of the web
  app spec (`docs/design/specs/2026-11-02-web-app-design.md`) already says.
  Every store's playback, including through the stream worker, must work
  in all three. Because WebKit is the browser most likely to refuse ranged
  media through a service worker, the build starts with a throwaway spike
  that plays a ranged video through a minimal worker in Chromium, Firefox
  and WebKit. If any of them cannot, the build stops and the maintainer
  decides before the worker is written.
- Sub-path hosting (`--base-href /repo/`, documented in
  `web_hosting/HOSTING.md`) is supported. The worker file sits at the
  bundle root, its scope is the base href, and every `media-stream/<ticket>`
  URL is built from the base href, not from the domain root (my call).

## Non-goals

- Documents (PDFs) in the browser. They keep their thumbnail.
- iCloud Drive and Git, which the web app does not support.
- Offline playback, caching video bytes, or downloading a video to disk
  from the browser.
- Any change to how the installed apps resolve or cache videos.

## Anti-goals

- No public share links, and no change to any file's sharing or permissions
  on the user's store.
- No video bytes in `MediaBytesMemory`: a video must never push photos out
  of the page's image memory.
- No credentials at rest in the browser for this feature (no IndexedDB or
  Cache Storage copies of tokens or passwords).

## The decided behaviour

### Per store

| Store | What the player gets | Lifetime |
| --- | --- | --- |
| S3 and S3-compatible | A SigV4 presigned GET URL for the object, signed locally | 6 hours (my call) |
| Dropbox | A temporary link from `/2/files/get_temporary_link` | 4 hours (fixed by Dropbox) |
| Google Drive | A same-site `media-stream/<ticket>` URL (under the base href). The stream worker relays each request to the page, which reads that byte range through its Drive store adapter | Ticket lives while the viewer page holds it |
| WebDAV | A same-site `media-stream/<ticket>` URL, relayed the same way through the page's WebDAV store adapter | Same |

The `<video>` element loads S3 and Dropbox links cross-origin without CORS
(a media element in no-cors mode), and the site's
`Cross-Origin-Embedder-Policy: credentialless` admits them without a CORP
header. Stream worker URLs are same-origin.

### Which version plays

The original first, as in the installed apps. If the player fails to
initialise it (a format this browser cannot decode, such as HEVC `.mov` in
Firefox) and the row has a rendition (`remoteCompressedUploadedAt`), the
viewer tries the rendition. "Failed to load video" shows only when neither
plays. A row with only a rendition plays the rendition.

### Stale links

A link can stop working while the viewer is open: an S3 or Dropbox link
expires, or a relayed read fails. When the player reports an error after it had
initialised, the viewer resolves a fresh source once, builds a new
controller, seeks to the last position and restores the play or pause
state, with nothing shown to the user. A second failure in a row shows the
normal error screen (my call: one silent retry per failure, so a broken
store cannot loop).

### Without a stream worker

When the browser offers no service worker (Firefox private windows, some
locked-down browsers) or registration fails, Drive and WebDAV videos keep
their thumbnail with a line saying that playing them needs a normal
(non-private) browser window. S3 and Dropbox videos still play. There is no
download-into-memory fallback.

### Store setup

The WebDAV CORS templates in `lib/core/platform/web/cors_rule_templates.dart`
(nginx and Apache) add `Range` to `Access-Control-Allow-Headers`, and the
hosting guide says existing WebDAV
users update their header block once. Drive needs nothing new. S3 and
Dropbox need nothing new (no-cors media loads).

### Video extras

The colour correction track, "Pick white" on a video and people tags read
frames through the transcode engine (`transcodeEngineProvider`) and a file
path. In a browser there is no engine and no path. The builder checks each
extra against a streamed video and hides any control that cannot work in a
browser, rather than leaving it to fail silently. People tags drawn from
the controller's position are expected to keep working.

## Structure (decided)

1. **A playback source for videos.** Alongside `resolvedFilePathProvider`,
   the viewer resolves a video's playback source: a file path (installed
   apps, unchanged) or a URL (browser). `_VideoItem` builds
   `VideoPlayerController.file` or `VideoPlayerController.networkUrl` from
   it. The browser path asks the media store runtime's resolver; it never
   downloads bytes.
2. **A store capability for streaming.** Store adapters that can stream a
   key either give a direct URL plus its expiry (S3, Dropbox) or read one
   byte range of it (Drive, WebDAV), which the relay serves. Each is a
   separate optional interface, not a new member on `MediaObjectStore`,
   so installed-app adapters and test fakes are untouched. iCloud does not
   implement it.
3. **S3 presigning** lives in `SigV4Signer` (query-string auth:
   `X-Amz-Algorithm`, `X-Amz-Credential`, `X-Amz-Date`, `X-Amz-Expires`,
   `X-Amz-SignedHeaders=host`, `UNSIGNED-PAYLOAD`, `X-Amz-Signature`) and uses the same
   addressing, key prefix and effective region as `S3ApiClient`'s signed
   requests, so path-style endpoints (MinIO) and region correction behave
   the same.
4. **The stream worker** is a service worker at the bundle root (scoped to
   the base href), registered
   at app start in browser builds only. It answers only
   `GET <base>media-stream/<ticket>` and lets every other request go to the
   network untouched. It holds no state and no credentials: for each
   request it posts the ticket and the `Range` header to the page that made
   the request (over a `MessageChannel`), and builds the response from the
   page's answer. The page keeps the tickets (store, key, content type,
   total size), reads at most one chunk of the requested range through the
   store adapter it already has (sign-in, token renewal and retries
   included), and answers `206` with `Content-Range`, `Content-Length`,
   `Content-Type` and `Accept-Ranges`. An unknown ticket answers `404` and
   a failed read `502`, which the viewer's stale-link path handles. Tickets
   are released when the video page is released. The worker calls
   `clients.claim()` on activation so the first visit is controlled without
   a reload. (Changed from an earlier draft in which the worker held each
   upstream URL and its credentials; the maintainer chose the relay on
   2026-11-08 so no credentials leave the page.)
5. **The bundle.** The worker file is added to `check_web_bundle.py`'s
   required list (it must not be named `flutter_service_worker.js`, which
   the build deletes), and the hosting configs serve it with
   `Cache-Control: no-cache`.
6. **Docs.** The `MemoryMediaStoreFetches` class comment, the web app
   spec's capability table (`docs/design/specs/2026-11-02-web-app-design.md`,
   the `mediaStore` row) and the hosting guide are updated to say videos
   play.

## Testing

- `SigV4Signer` presigning against AWS's published presigned URL example,
  plus path-style addressing.
- Dropbox temporary link request and response mapping, and link reuse
  until near expiry.
- Drive and WebDAV ranged reads, and the relay's range parsing, chunking,
  `416`, `404` and `502` answers, as VM unit tests.
- Viewer widget tests with the fake video player: URL source chosen in a
  browser, original-to-rendition fallback, one silent stale retry restoring
  position, the second failure showing the error, and the no-worker message
  for Drive and WebDAV.
- A Playwright test in Chromium, Firefox and WebKit (run in the web smoke
  job) plays a video through the real stream worker with a page-side
  responder, at the site root and under a sub-path base, and plays a MinIO
  presigned URL under the site's isolation headers.
- Real Dropbox, Google Drive and WebDAV stores are checked by the
  maintainer, as in #4142.

## Left to the builder

- Names of the new types, providers and files.
- Whether the worker is plain JavaScript or Dart compiled with
  `dart compile js` like `drift_worker.dart`.
- How Dropbox link reuse is cached, and the exact refresh margin.
- The page-to-worker message format.
- The exact wording of the no-worker message (an ARB string, translated as
  the project does).
