# Cloud HTTP Request Deadlines: Design

**Status:** approved 2026-08-25
**Issue:** #1279
**Branch:** `worktree-1279-cloud-http-timeouts`
**Supersedes nothing.** Generalises the deadlines `S3ApiClient` gained in
#1175/#942 to the other two cloud transports.

## Problem

`S3ApiClient` is the only cloud transport in the app with request deadlines.
The Dropbox and Google Drive clients both fall back to a bare `http.Client()`,
which on Dart IO means `HttpClient.connectionTimeout == null` and no response
or idle deadline at all. A socket that connects and then wedges, or one that
never connects, waits on the OS default.

Found while investigating #1270 (media uploads stuck on desktop). Not the root
cause of that issue, but the underlying gap is real and worth closing on its
own.

## Findings

Every claim below was verified against `origin/main` at 716d2c597fc.

**F1. The S3 client gets this right and documents why.**
`s3_api_client.dart:93` wraps `IOClient(HttpClient()..connectionTimeout =
defaultConnectTimeout)`. `:117`, `:121`, `:132` and `:140` define
`defaultConnectTimeout` (15s), `defaultResponseTimeout` (30s),
`defaultUploadTimeout` (10m) and `defaultIdleTimeout` (30s), each with its own
rationale traced back to #942, and `:729` applies the response/upload split on
the send path.

**F2. Dropbox has none.** `dropbox_api_client.dart:64` is
`_http = httpClient ?? http.Client()`. `grep -n "timeout"` over the file
returns nothing.

**F3. Dropbox's auth manager has none either, and it is on the same critical
path.** `dropbox_auth_manager.dart:25` is the same fallback. This matters more
than it looks: `dropbox_api_client.dart:307` awaits `_getAccessToken()`
*inside* the send loop, before every request. A wedged token refresh stalls
every Dropbox request behind it exactly like a wedged request would, so fixing
only the API client would leave the hole open.

**F4. Google Drive has none, on either auth path.**
`google_drive_media_object_store.dart:17` takes an injected `http.Client`.
Both construction sites (`media_store_service.dart:60`,
`google_drive_account_adapter.dart:51`) get it from
`google_drive_storage_provider.dart:108`'s `mediaHttpClient()`, which returns
the authenticator's `authClient`. That is a `googleapis_auth` refreshing
client over a plain `http.Client()` in both implementations
(`desktop_oauth_authenticator.dart:60`, `google_sign_in_authenticator.dart:113`).
`grep -n "timeout" lib/core/services/media_store/*.dart` returns nothing.

**F5. The same client backs Drive *sync*, not just media.**
`google_drive_storage_provider.dart:130` builds `drive.DriveApi(client)` from
the same `authClient`. One wrapper at the authenticator therefore covers sync,
media transfers, and the store marker read below.

**F6. The store marker read runs before every queue entry, on the same
transport.** `media_store_providers.dart:311` calls
`StoreMarkerStore(store: store).read()` (one GET of `smv1/store.json`,
`store_marker.dart:46`) from the worker's preflight, and
`media_store_worker.dart:78` re-runs that preflight per entry, not once per
drain.

**F7. There is no containment for a wedged request on `main` today.**
`media_store_worker.dart:66-111` is a sequential `while (true)` loop guarded
by a `_running` single-flight flag, and `await _pipeline.process(entry)` has
no per-entry deadline. A request that never returns therefore blocks the loop
forever *and* leaves `_running` true, so every later `drain()` call returns
immediately. #1279's text refers to a per-entry drain budget from #1270 as
already containing the blast radius; #1270 is still open and that budget is
not on `main`, so the freeze is currently unbounded.

**F8. googleapis never declares a body length.**
`_discoveryapis_commons-1.0.7/lib/src/request_impl.dart:11-32`: `RequestImpl`
extends `http.BaseRequest`, supplies the body from a `Stream<List<int>>` in
`finalize()`, and never assigns `contentLength`. It is null for every call the
Drive API makes, upload or not. Any deadline rule keyed purely on declared
body size would put every Drive upload on the short response deadline.

## Design

One shared decorator, installed at four seams. No transport re-implements the
policy.

### Part 1: `TimeoutHttpClient`

New file `lib/core/services/cloud_storage/http_timeouts.dart`.

`TimeoutHttpClient` is an `http.BaseClient` decorator over any inner client.
`send` applies a deadline to `_inner.send(request)` (status and headers) and a
second, independent idle deadline to the response body stream, then rebuilds
the `StreamedResponse` around the wrapped stream. `close()` forwards to the
inner client.

`TimeoutHttpClient.overSockets()` additionally owns its transport:
`IOClient(HttpClient()..connectionTimeout = ...)`. The two halves are
complementary and both are needed. The `send` deadlines bound a socket that
connects and then stalls; `connectionTimeout` bounds one that never connects.

The four constants are deliberately F1's constants, with F1's reasoning:

| Deadline | Value | Bounds |
| --- | --- | --- |
| connect | 15s | TCP connect to an unreachable endpoint |
| response | 30s | status + headers on a request with no meaningful body |
| upload | 10m | the same, on a request whose body must be written first |
| idle | 30s | longest gap the response body may go without a byte |

The idle deadline is a gap, not a total budget: a legitimate 8 MiB download
over a weak link takes minutes and must not be killed, while a connection that
has stopped delivering is dead regardless of how little it had left to send.

### Part 2: which deadline a request gets

`Client.send` does not complete until the request body has been written, so
for a PUT the "wait for a response" window contains the whole upload. That is
why the upload deadline exists at all, and why it cannot simply be applied to
everything: a wedged Dropbox RPC would then take ten minutes to fail.

The classifier is size first, method second:

1. A declared `contentLength` above `uploadBodyThresholdBytes` (64 KiB) is an
   upload. Below it, the request is a control-plane call whose body is written
   in one go, so the response deadline is the right one. A Dropbox RPC carries
   a few dozen bytes of JSON; the smallest thing the app actually uploads is
   an 8 MiB chunk, so 64 KiB separates them with room to spare.
2. When `contentLength` is null the method decides: `GET`, `HEAD` and `DELETE`
   get the response deadline, anything else gets the upload deadline.

Step 2 exists entirely because of F8. Without it every Drive upload would be
cut off at 30s and healthy transfers would start failing.

### Part 3: the four installation seams

**Dropbox API client.** `httpClient ?? TimeoutHttpClient.overSockets()`. No
change to `_send`: its existing `on Exception` wrapper already maps the
resulting `TimeoutException` to `CloudStorageException('Could not reach
Dropbox')`, and `DropboxMediaObjectStore` already classifies that message as
transient. This one seam covers Dropbox sync and Dropbox media.

**Dropbox auth manager.** The same fallback, for F3.

**Desktop OAuth authenticator.** The default `baseClientFactory` becomes a
timed client. The wrapper goes *underneath* `gauth.autoRefreshingClient`
(`desktop_oauth_authenticator.dart:139`), so it covers every Drive call the
refreshing client makes, its own token refreshes, the consent-flow token
exchange, and revocation.

**google_sign_in authenticator.** The opposite: the plugin builds the
authorized client over a socket layer the app never sees, so the wrapper goes
on the *outside* of `authorization.authClient(scopes:)`. The field's type
relaxes from `gapis_auth.AuthClient?` to `http.Client?`, which is what the
`GoogleDriveAuthenticator.authClient` contract already exposes and all
downstream consumers already use.

By F4 and F5 those two authenticator seams are sufficient for Google Drive:
`GoogleDriveMediaObjectStore` needs no change, because its transport is the
authenticator's client at both construction sites. Wrapping it again inside
the store would stack a second idle deadline on the same stream for no gain.

### Part 4: testability

Each transport that builds its own default exposes a `@visibleForTesting`
`transport` getter, so a test can assert the fact the issue is actually about
("this client did not fall back to a bare `http.Client()`") rather than
asserting it indirectly through a stall. `TimeoutHttpClient` carries the
`connectTimeout` it configured as a field, null when the inner client came
from the caller, so the same assertion covers the connect half.

## Out of scope

**`S3ApiClient` is not routed through the wrapper.** It applies the same four
deadlines inline, interleaved with its SigV4 retry loop, which classifies
`TimeoutException` as a retryable transport fault and replays the request
(possibly against a server-corrected region). Unpicking that is a change to a
well-covered path with no behaviour to gain. The duplication is one `.timeout`
pair, and this design deliberately adopts its constants rather than inventing
new ones.

**Other bare `http.Client()` users stay as they are:** weather, tides, reef,
bathymetry, the GitHub updater, and the Lightroom client. None sit on the sync
or media transfer paths, so none can wedge a queue. The wrapper is now
available to them.

**Retry policy is unchanged.** A deadline that fires surfaces through each
client's existing error mapping. Nothing here adds attempts, backoff, or a new
`UnavailableKind`; per the media fetch-budget work, a new unavailability kind
must never reach an orphan path, so introducing one was avoided outright.

## Product decisions (do not relitigate)

- **Ten minutes, not one, for uploads.** Killing a transfer that was making
  progress is the failure mode that left large first syncs failing nine times
  in ten (#942). The deadline exists to bound a genuinely wedged socket, not
  to enforce throughput.
- **A 64 KiB threshold, not "any body".** Chosen so control-plane POSTs fail
  fast while real chunks get the long clock. It is a classifier, not a limit:
  nothing rejects a body for its size.
- **Deadlines live in the transport, not in each call site.** Every call site
  that would otherwise need its own `.timeout` is a place a future call site
  can forget one. That is exactly how #1279 happened.
