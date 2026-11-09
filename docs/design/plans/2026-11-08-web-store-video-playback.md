# Web Store Video Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Videos in the media store play in the web app from S3, Dropbox, Google Drive and WebDAV, streamed, in Chromium, Firefox and Safari.

**Architecture:** S3 and Dropbox hand the browser player a direct URL (a SigV4 presigned URL, a Dropbox temporary link). Drive and WebDAV play from a same-origin `media-stream/<ticket>` URL that a stateless service worker relays to the page, which reads the byte range through the store adapter it already has. The viewer resolves a playback plan (file path on installed apps, ordered stream candidates in a browser) and opens it through a small opener that handles rendition fallback and one silent stale-link retry.

**Tech Stack:** Flutter (Dart 3, Riverpod 3, `video_player` / `video_player_web`), `package:web` and `dart:js_interop`, plain JavaScript service worker, Python Playwright 1.52 for the three-browser test.

**Spec:** `docs/design/specs/2026-11-08-web-store-video-playback-design.md`

## Global Constraints

- S3 presigned URL lifetime: 6 hours. Dropbox temporary link lifetime: 4 hours (Dropbox's own), reused until 10 minutes before expiry.
- Relay chunk: at most 2 MiB (`2 * 1024 * 1024`) per relayed answer.
- Worker file: `web/media_stream_worker.js`, never `flutter_service_worker.js`. It never caches and never answers anything but `GET <scope>media-stream/<ticket>`.
- Stream URLs are built from the base href (`document.baseURI`), never from `/`.
- No video bytes in `MediaBytesMemory`; no credentials in the worker, IndexedDB or Cache Storage.
- Version order: original, then rendition. One silent stale retry per failure, a second failure in a row shows the error.
- Without a usable worker: Drive and WebDAV videos show the new "needs a normal browser window" message; S3 and Dropbox still play.
- New user-facing strings go in all 23 ARB files (feature-grouped: insert beside `media_photoViewer_videoFileNotFound`).
- No file over 800 lines: `media_viewer_page.dart` is already 2040, so new viewer logic goes in new files and the page only calls it.
- Paths with `p.join`, no em-dashes anywhere, `dart format .` before each commit.

## Review Focus

1. **A browser that requests `bytes=0-1` first, or sends no `Range` at all (Safari).** Expected: a valid `206` for the clamped range; with no header, treat as `bytes=0-`. Pinned in Task 5 (`handles a request with no Range header`, `clamps bytes=0-1`).
2. **A range starting at or past the end (seek to the very end).** Expected: `416` with `Content-Range: bytes */<total>`, never a store read. Pinned in Task 5.
3. **A server that ignores `Range` and returns `200` with the whole body (some WebDAV servers).** Expected: the adapter slices to the requested range. Pinned in Task 4 (`slices a 200 answer to the requested range`).
4. **Two tabs, or a page reload, while a worker is active.** Expected: each request is answered by the page that made it (`event.clientId`), and an unknown ticket gets `404`, not a hang. Pinned in Task 1 (`unknown ticket answers 404`) and the worker's 30 second reply timeout (`504`).
5. **A video with only a rendition, or an original the browser cannot decode.** Expected: the rendition plays; "Failed to load video" only when both fail. Pinned in Task 8.

---

### Task 1: Stream worker and three-browser harness (the spike gate)

This task is the spec's spike. If any of Chromium, Firefox or WebKit cannot play the fixture through the worker, STOP and bring the result to the maintainer before Task 2.

**Files:**
- Create: `web/media_stream_worker.js`
- Create: `scripts/web/fixtures/media_stream/index.html`, `scripts/web/fixtures/media_stream/sample.mp4`
- Create: `scripts/web/media_stream_worker_test.py`
- Modify: `.github/workflows/ci.yaml` (web-smoke job: install `chromium` too, run the new test with the smoke)

**Interfaces:**
- Produces (worker to page message, posted to the requesting client with a `MessageChannel` port in the transfer list):
  `{type: 'media-stream-request', ticket: string, range: string | null}`
- Consumes (page to worker reply on that port):
  `{status: number, headers: {[name: string]: string}, body: ArrayBuffer | null}`
- Worker behaviour: `install` calls `skipWaiting()`, `activate` calls `clients.claim()`; `fetch` calls `respondWith` only for `GET` same-origin URLs whose path starts with `new URL(registration.scope).pathname + 'media-stream/'`. No client for `event.clientId` gives `503`; no reply in 30 s gives `504`.

- [ ] **Step 1: Make the fixture.** `ffmpeg -f lavfi -i testsrc=size=160x120:rate=10 -t 4 -c:v libx264 -pix_fmt yuv420p -movflags +faststart scripts/web/fixtures/media_stream/sample.mp4` (keep it under 100 KB). `index.html` registers `media_stream_worker.js` (relative URL, scope `./`), waits for `navigator.serviceWorker.controller`, answers `media-stream-request` messages by fetching `sample.mp4` with the same `Range` from the server, clamped to 16 KiB per answer so playback needs many ranged requests, and answers `404` for any ticket but `t1`. It exposes `window.playTicket(t)` that sets `<video src="media-stream/<t>">` and resolves once `currentTime > 1`.

- [ ] **Step 2: Write the failing tests** in `media_stream_worker_test.py`, parametrized over `chromium`, `firefox`, `webkit`, serving a temp dir that holds the fixture plus a copy of `web/media_stream_worker.js` with the hosting headers (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: credentialless`):
  - `test_plays_through_relay[<browser>]`: `playTicket('t1')` resolves; then seeking to 3.0 s resolves `seeked`.
  - `test_plays_under_sub_path[<browser>]`: the same with the files under `/sub/` and `<base href="/sub/">`.
  - `test_unknown_ticket_answers_404[<browser>]`: `fetch('media-stream/nope')` from the page has status 404.
  - `test_other_requests_pass_through[<browser>]`: `fetch('sample.mp4')` returns the file byte for byte.
  - `test_presigned_minio_url_plays[<browser>]`: when `MINIO_ENDPOINT` is set, upload `sample.mp4` with boto3, play `generate_presigned_url('get_object', ExpiresIn=600)` in the page; skipped locally without MinIO, and CI's no-skip check stays scoped to `smoke.xml` only if this file writes its own report (give it `--junitxml="$RUNNER_TEMP/stream.xml"` and assert zero skips there too since CI has MinIO).

- [ ] **Step 3: Run to see them fail.** `python -m pytest scripts/web/media_stream_worker_test.py -v` in a venv with `scripts/web/requirements-smoke.txt`. Expected: FAIL, worker file missing.

- [ ] **Step 4: Write `web/media_stream_worker.js`** to the interface above.

- [ ] **Step 5: Run again.** Expected: PASS in all three browsers (MinIO case skipped locally). Any browser failing: stop, report to the maintainer.

- [ ] **Step 6: Wire CI.** In the web-smoke job add `chromium` to `playwright install --with-deps`, run the new test after the smoke under `xvfb-run -a` with its own junit file, and fail on zero tests or any skip.

- [ ] **Step 7: Commit** `feat(media): add the media stream relay worker`.

### Task 2: Streaming store interfaces and S3 presigning

**Files:**
- Create: `lib/core/services/media_store/media_streaming.dart`
- Modify: `lib/core/services/cloud_storage/s3/sigv4_signer.dart`, `lib/core/services/cloud_storage/s3/s3_api_client.dart`, `lib/core/services/media_store/s3_media_object_store.dart`
- Test: `test/core/services/cloud_storage/s3/sigv4_signer_test.dart`, `test/core/services/cloud_storage/s3/s3_api_client_test.dart`, `test/core/services/media_store/s3_media_object_store_test.dart`

**Interfaces:**
- Produces in `media_streaming.dart`:
  - `class DirectLink { const DirectLink({required Uri url, required DateTime expiresAt}); }`
  - `abstract interface class DirectLinkStore { Future<DirectLink> directLink(String key); }`
  - `abstract interface class RangeReadStore { Future<Uint8List> readRange(String key, {required int start, required int endInclusive}); }` (the store's `head(key)` gives the total)
  - `const Duration kS3PresignLifetime = Duration(hours: 6);`
- Produces: `static Uri SigV4Signer.presign({required String method, required String scheme, required String host, required String canonicalUri, required String accessKeyId, required String secretAccessKey, required String region, required DateTime requestTime, required Duration expiresIn, String service = 's3'})`
- Produces: `Uri S3ApiClient.presignGet(String key, {required Duration expiresIn})`, using `_target(key)`, `_region` and `_now`.
- `S3MediaObjectStore implements MediaObjectStore, DirectLinkStore`; `directLink(key)` presigns `_wire(key)` for `kS3PresignLifetime`, `expiresAt` = client clock + lifetime.

- [ ] **Step 1: Failing tests.**
  - `presign matches the AWS published example`: host `examplebucket.s3.amazonaws.com`, path `/test.txt`, region `us-east-1`, `2013-05-24T00:00:00Z`, 86400 s, key `AKIAIOSFODNN7EXAMPLE` / secret `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`; expect `X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404`. Recompute the value independently in Python before trusting it.
  - `presignGet uses path-style addressing and the effective region`: a MinIO-style config (`http://localhost:9000`, path style) gives `http://localhost:9000/<bucket>/<key>?X-Amz-...` with `X-Amz-Expires=21600` and the credential scope's region; a region correction (existing test helper) moves the scope to the corrected region.
  - `directLink presigns the prefixed key for six hours`.
- [ ] **Step 2: Run, expect FAIL** (`flutter test test/core/services/cloud_storage/s3/ test/core/services/media_store/s3_media_object_store_test.dart`).
- [ ] **Step 3: Implement.** Query params `X-Amz-Algorithm=AWS4-HMAC-SHA256`, `X-Amz-Credential`, `X-Amz-Date`, `X-Amz-Expires`, `X-Amz-SignedHeaders=host`; canonical request with header `host` only and payload `UNSIGNED-PAYLOAD`; reuse `canonicalRequest`, `stringToSign`, `deriveSigningKey`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): presign S3 video links`.

### Task 3: Dropbox temporary links

**Files:**
- Modify: `lib/core/services/cloud_storage/dropbox/dropbox_api_client.dart`, `lib/core/services/media_store/dropbox_media_object_store.dart`
- Test: their existing test files under `test/core/services/`

**Interfaces:**
- Produces: `Future<String> DropboxApiClient.getTemporaryLink(String path)` (RPC `/2/files/get_temporary_link`, body `{"path": path}`, returns `link`; not-found maps like `download`).
- `DropboxMediaObjectStore implements MediaObjectStore, DirectLinkStore`, with constructor parameter `DateTime Function()? now`. `directLink(key)` returns a cached link while `now()` is before `expiresAt - 10 minutes`, else fetches a new one with `expiresAt = now() + 4 hours`.

- [ ] **Step 1: Failing tests:** `getTemporaryLink posts the path and returns the link`; `directLink reuses a link until ten minutes before expiry` (second call at +3h49m hits the cache, at +3h51m fetches again; count requests on the mock client).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): give Dropbox videos temporary links`.

### Task 4: Ranged reads for Google Drive and WebDAV

**Files:**
- Modify: `lib/core/services/media_store/google_drive_media_object_store.dart`, `lib/core/services/media_store/webdav_media_object_store.dart`
- Test: their existing test files

**Interfaces:**
- Consumes: `RangeReadStore` (Task 2).
- Both stores `implements RangeReadStore`. `readRange(key, start:, endInclusive:)` sends `GET` with `Range: bytes=<start>-<endInclusive>`; a `206` body is returned as is; a `200` body is sliced to `[start, endInclusive]` (clamped to its length); not found throws `MediaStoreException(kind: notFound)`. Drive caches key to file id per store instance so a chunk does not re-query the folder; on a `404` it drops the cached id and looks it up once more.

- [ ] **Step 1: Failing tests** for each store: `sends the Range header and returns the 206 body`, `slices a 200 answer to the requested range`, `missing key throws notFound`; Drive also `looks the file id up once across reads`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** (Drive through its existing `_send` with the auth retry; WebDAV through `_client.request('GET', _client.uriFor(_path(key)), headers: {...})` inside `_guard`).
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): read Drive and WebDAV videos a range at a time`.

### Task 5: The page-side relay

**Files:**
- Create: `lib/features/media/data/streaming/media_stream_relay.dart`
- Test: `test/features/media/data/streaming/media_stream_relay_test.dart`

**Interfaces:**
- Consumes: `RangeReadStore`, `MediaObjectStore.head`, `StoreKeys.contentTypeFor`.
- Produces:
  - `class RelayAnswer { final int status; final Map<String, String> headers; final Uint8List? body; }`
  - `class MediaStreamRelay { MediaStreamRelay({required Uri base, int chunkBytes = kRelayChunkBytes, String Function()? newTicket}); Uri register({required MediaObjectStore store, required String key, required String extension}); void release(Uri url); Future<RelayAnswer> answer(String ticket, String? range); }`
  - `const int kRelayChunkBytes = 2 * 1024 * 1024;`
- `register` requires `store is RangeReadStore` (ArgumentError otherwise) and returns `base.resolve('media-stream/<ticket>')`; tickets are 32 hex chars from `Random.secure()`. The total comes from `store.head(key)` on the first answer and is kept on the ticket.

- [ ] **Step 1: Failing tests:**
  - `answers bytes=0- with the first chunk` (status 206, `Content-Range: bytes 0-<chunk-1>/<total>`, `Content-Length`, `Content-Type: video/mp4` for `mp4`, `Accept-Ranges: bytes`).
  - `clamps bytes=0-1` to two bytes.
  - `handles a request with no Range header` as `bytes=0-`.
  - `clamps the end to the total` for a range past the last byte.
  - `answers 416 at or past the end` with `Content-Range: bytes */<total>` and no store read.
  - `answers 404 for an unknown or released ticket`.
  - `answers 502 when the store read throws`.
  - `heads the store once per ticket`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): answer relayed stream requests from the store`.

### Task 6: Registering the worker in browser builds

**Files:**
- Create: `lib/features/media/data/streaming/media_stream_worker_host.dart` (conditional export), `..._io.dart`, `..._web.dart`
- Create: `lib/features/media/presentation/providers/media_stream_providers.dart`
- Modify: `lib/core/bootstrap/app_bootstrap_web.dart` (start registration, not awaited), `scripts/check_web_bundle.py` (`REQUIRED` gains `media_stream_worker.js`) and its test, `web_hosting/_headers`, `web_hosting/nginx.conf`, `web_hosting/Caddyfile` (`no-cache` for the worker)
- Test: `test/features/media/presentation/providers/media_stream_providers_test.dart`, `scripts/check_web_bundle_test.py`

**Interfaces:**
- Produces: `Future<MediaStreamWorkerHost?> startMediaStreamWorker()`; memoized; null on io, when `navigator.serviceWorker` is absent, or when registration or `ready` fails (logged). `abstract interface class MediaStreamWorkerHost { Uri get base; void serve(Future<RelayAnswer> Function(String ticket, String? range) answer); }` The web host listens for `media-stream-request` messages and posts the `RelayAnswer` on the port, transferring the body's buffer.
- Produces: `final mediaStreamRelayProvider = FutureProvider<MediaStreamRelay?>` that builds a relay on the host's base and calls `host.serve(relay.answer)`; null when there is no host.
- Seam rule: the web file is the only one importing `package:web`; run `test/architecture/` (web_compile_seams_test, host_platform_single_source_test).

- [ ] **Step 1: Failing tests:** provider is null with a null host override; with a fake host it serves a relay whose `base` is the host's. Bundle check test: a bundle without `media_stream_worker.js` fails.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Inject the host through a provider (`mediaStreamWorkerHostProvider`, default `FutureProvider` calling `startMediaStreamWorker()`) so tests override it.
- [ ] **Step 4: Run, expect PASS,** plus `flutter test test/architecture/` and `python3.14 -m pytest scripts/check_web_bundle_test.py`.
- [ ] **Step 5: Commit** `feat(media): register the stream worker in the web app`.

### Task 7: The video playback plan

**Files:**
- Create: `lib/features/media/data/streaming/video_playback_plan.dart`
- Create: `lib/features/media/presentation/providers/video_playback_providers.dart`
- Test: `test/features/media/data/streaming/video_playback_plan_test.dart`, `test/features/media/presentation/providers/video_playback_providers_test.dart`

**Interfaces:**
- Produces:
  - `sealed class VideoPlayback`; `FilePlayback(String path)`; `StreamPlayback(List<StreamCandidate> candidates)`; `NoPlayback(NoPlaybackReason reason)` with `enum NoPlaybackReason { notFound, needsNormalWindow }`.
  - `class StreamCandidate { final ServedTier tier; final Future<Uri> Function() open; final void Function(Uri url) close; }` where `open` gives a fresh URL on every call (a new presign, a cached-or-new Dropbox link, or a new relay ticket) and `close` releases a relay ticket (no-op for direct links).
  - `VideoPlayback planStoreVideo(MediaItem item, {required MediaObjectStore store, required MediaStreamRelay? relay})`: candidates for the original (when `remoteUploadedAt != null`, key `StoreKeys.objectKey(hash, extension: StoreKeys.extensionFor(item.originalFilename))`) then the rendition (when `remoteCompressedUploadedAt != null`, key `StoreKeys.renditionKey(hash, ext: StoreKeys.renditionExtension(isVideo: true))`). `DirectLinkStore` gives direct candidates; `RangeReadStore` gives relay candidates or, with no relay, `NoPlayback(needsNormalWindow)`; no hash, no uploaded tier or another store type gives `NoPlayback(notFound)`.
  - `final videoPlaybackProvider = FutureProvider.autoDispose.family<VideoPlayback, MediaItem>`: in a browser, `planStoreVideo` with the runtime's store and `mediaStreamRelayProvider`; otherwise `resolvedFilePathProvider` mapped to `FilePlayback` or `NoPlayback(notFound)`.

- [ ] **Step 1: Failing tests:** original then rendition order; rendition only; S3 fake gives direct candidates whose `open` presigns afresh; WebDAV fake with relay gives relay URLs under the base and `close` releases the ticket; WebDAV fake without relay gives `needsNormalWindow`; no hash gives `notFound`; provider on a non-browser capability returns `FilePlayback` from an overridden `resolvedFilePathProvider`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): plan how a video plays on this device`.

### Task 8: The viewer plays streams

**Files:**
- Create: `lib/features/media/presentation/widgets/video_playback_opener.dart`
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (`_VideoItem` uses the plan and the opener; error keys gain `videoNeedsNormalWindow`), the 23 ARB files (`media_photoViewer_videoNeedsNormalWindow`), plus generated l10n
- Modify where the extras audit finds a control that cannot work in a browser (expected: the colour track and "Pick white" entry points, gated on `transcodeEngineProvider != null`)
- Test: `test/features/media/presentation/widgets/video_playback_opener_test.dart`, `test/features/media/presentation/pages/media_viewer_store_stream_test.dart` (a `_FakeVideoPlatform` like `media_viewer_video_test.dart`'s, with `restoreVideoPlayerPlatform` in `addTearDown`)

**Interfaces:**
- Consumes: `VideoPlayback`, `StreamCandidate`, `videoPlaybackProvider`.
- Produces: `class VideoPlaybackOpener { VideoPlaybackOpener(VideoPlayback playback, {VideoPlayerController Function(Uri url)? network, VideoPlayerController Function(String path)? file}); Future<VideoPlayerController> open(); Future<VideoPlayerController?> reopenAfterError(VideoPlayerController failed); void dispose(); }`
  - `open` tries candidates in order, disposing each that fails to initialise, and throws the last error when all fail.
  - `reopenAfterError` re-opens the same candidate once, seeks to the failed controller's last position and plays if it was playing; returns null (show the error) when the previous reopen has not yet been followed by the position moving past its resume point.
  - `dispose` closes every relay URL it opened.
- English copy: `"Playing this video needs a normal browser window. Private windows cannot stream from Google Drive or WebDAV."`

- [ ] **Step 1: Failing tests (opener):** `falls back to the rendition when the original fails to initialise`; `throws when every candidate fails`; `reopens once after an error at the same position and play state`; `a second error in a row returns null`; `dispose closes relay URLs`.
- [ ] **Step 2: Failing tests (viewer):** in a browser capability override, a `StreamPlayback` builds a network controller and plays; `NoPlayback(needsNormalWindow)` shows the new copy; `NoPlayback(notFound)` keeps "Video file not found"; the existing `media_viewer_video_test.dart` still passes unchanged.
- [ ] **Step 3: Run, expect FAIL.**
- [ ] **Step 4: Implement,** add the ARB key to all 23 locales (translated), run `flutter gen-l10n`.
- [ ] **Step 5: Extras audit:** with a browser capability and no transcode engine, confirm in a widget test which video controls appear; hide any that cannot work (`colour track`, `Pick white` on video), and pin that with a test.
- [ ] **Step 6: Run, expect PASS:** `flutter test test/features/media/` and `flutter analyze`.
- [ ] **Step 7: Commit** `feat(media): play store videos in the browser viewer`.

### Task 9: Store setup and docs

**Files:**
- Modify: `lib/core/platform/web/cors_rule_templates.dart` (WebDAV nginx and Apache `Access-Control-Allow-Headers` gain `Range`) and its test
- Modify: `lib/features/media/data/resolvers/memory_media_store_fetches.dart` (class comment: videos stream through the viewer's playback plan, not these fetches)
- Modify: `docs/design/specs/2026-11-02-web-app-design.md` (`mediaStore` capability row), `web_hosting/HOSTING.md` (videos play; WebDAV users add `Range`; the worker is served `no-cache`)

- [ ] **Step 1: Failing test:** the WebDAV templates contain `Range` in the allowed headers.
- [ ] **Step 2: Implement and run** the template test.
- [ ] **Step 3: Full checks:** `dart format .`, `flutter analyze`, `flutter test test/architecture/ test/core/services/ test/features/media/`, `python3.14 scripts/check_docs_links.py`, and a release web build with `scripts/build_web.sh` followed by `python3.14 scripts/check_web_bundle.py build/web`.
- [ ] **Step 4: Commit** `docs(media): videos play from the store in the web app`.
