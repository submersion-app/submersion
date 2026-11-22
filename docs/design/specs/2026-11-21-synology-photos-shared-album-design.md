# Synology Photos shared album as a manifest subscription

Prototype design. Not yet tied to an issue.

## Goal

A diver keeps dive photos on a Synology NAS and tags them in Synology Photos.
A *condition album* (an album defined by a filter such as "tag = diving")
collects every tagged photo wherever it lives on the NAS, so moving files
between folders does not drop them from the album. Synology Photos can share
such an album through a password-protected link.

Submersion should subscribe to that link the way it subscribes to a manifest
feed: new tagged photos appear on the matching dive by themselves, on every
device, without copying the originals anywhere.

## Why a manifest subscription and not a connector

The manifest subscription pipeline already does almost everything needed:

- `SubscriptionPoller` polls on a schedule, keys every row on a stable
  `entryKey`, inserts only entries with a confident dive match, patches
  changed entries and flags vanished ones as orphaned.
- `NetworkFetchPipeline` inserts the rows; `HttpUrlMediaResolver` serves them;
  `NetworkCredentialsService` keeps per-host secrets in the keychain.

What is missing is a way to read a Synology share instead of a JSON/Atom/CSV
document, and a way to authenticate image requests with a session cookie
instead of a static `Authorization` header. A `serviceConnector` would need a
new account kind, a picker tab and its own resolver; the subscription route
reuses all of that machinery.

## The Synology share API (observed, unofficial)

Observed against DSM 7 with Synology Photos 1.9.1-10928. The API behind share
links is not documented by Synology, so every call below is an observation, not
a contract.

API versions the NAS advertised through `SYNO.API.Info` (no login needed), and
the ones the prototype calls:

| API | Advertised | Used |
|---|---|---|
| `SYNO.Core.Sharing.Login` | 1 | 1 |
| `SYNO.Foto.Browse.Item` | 1-7 | 1 |
| `SYNO.Foto.Browse.Album` | 1-5 | 1 |
| `SYNO.Foto.Thumbnail` | 1-2 | 2 |
| `SYNO.Foto.Download` | 1-2 | 2 |

If a later Synology Photos release breaks the integration, compare its
`SYNO.API.Info` answer against this table first.

All calls go to `https://<host>:<port>/mo/sharing/webapi/entry.cgi`.
`<code>` is the share code from the link `https://<host>:<port>/mo/sharing/<code>`.

| Purpose | Request | Notes |
|---|---|---|
| Log in | POST `api=SYNO.Core.Sharing.Login&method=login&version=1&sharing_id=<code>&password=<pw>` | Returns `{"data":{"sharing_sid":"..."}}`. Plain form fields over HTTPS are accepted; the web client's own RSA wrapping is optional. No prior page visit is needed. Wrong password: error 101. |
| List items | POST `api=SYNO.Foto.Browse.Item&method=list&version=1&offset=<n>&limit=<n>&passphrase=<code>&additional=["thumbnail","resolution","video_meta"]` with `Cookie: sharing_sid=<sid>` and `X-SYNO-SHARING: <code>` | Both the cookie and the header are required. Items carry `id`, `filename`, `filesize`, `time`, `type` (`photo`, `video`, others), `additional.resolution`, `additional.thumbnail.cache_key`. |
| Thumbnail | GET `api=SYNO.Foto.Thumbnail&method=get&version=2&id=<id>&cache_key=<key>&type=unit&size=<sm|m|xl>&_sharing_id=<code>` with the cookie | `sm` 320 px, `m` 320 px short edge, `xl` 1280 px short edge. `cache_key` is required. |
| Original | GET `api=SYNO.Foto.Download&method=download&version=2&force_download=true&item_id=[<id>]&passphrase=<code>&download_type=source&_sharing_id=<code>` with the cookie | Only when the share allows downloads (`privacy_type: public-download`); a view-only share answers error 804. Honors `Range` (206). |

Behaviour that shapes the design:

- **Errors arrive as HTTP 200 with a JSON body** (`{"success":false,"error":{"code":N}}`),
  also for image requests. 119 means "no valid session".
- **A new login invalidates the previous session** for the same share. A client
  must therefore not log in on a timer; it logs in only when it has no session
  or the server has rejected the one it has.
- **`time` is the capture time as local wall clock stored as if UTC**, the
  same convention as `MediaItem.takenAt`. It matches EXIF `DateTimeOriginal` of
  the original byte for byte, so no EXIF read is needed.
- **No GPS** is returned in the listing.
- One listing call with a large `limit` returns hundreds of items; the client
  still pages to stay bounded.

## Design

### 1. Recognising a share link: `SynologyShareLink`

Pure value object (`lib/features/media/data/synology/synology_share_link.dart`):

- `tryParseShareLink(Uri)`: accepts `https://host[:port]/mo/sharing/<code>`
  (and the same path under a `/photo` prefix, which DSM uses behind some
  reverse proxies). Returns the origin and the code, or null.
- `tryParseApiUri(Uri)`: recognises the entry.cgi URLs this feature builds and
  recovers the share from their `_sharing_id` parameter.
- Builders for the list, thumbnail and download URLs.
- `thumbnailFor(Uri original, size)`: derives the thumbnail URL from a stored
  original URL. The stored URL carries `id` and `cache_key` as extra query
  parameters (Synology ignores unknown parameters), so a row needs only its one
  `url` column.

Only `https` links are accepted: the password and session would otherwise
travel in clear text.

### 2. Sessions: `SynologyShareSessions`

`lib/features/media/data/synology/synology_share_sessions.dart`, one instance
per app (Riverpod singleton), keyed by origin + share code:

- `sessionFor(link, password)`: returns the cached `sharing_sid`, or logs in.
  Concurrent callers share one in-flight login, so a grid of thumbnails never
  fires a burst of logins (each of which would kill the previous session).
- `invalidate(link, staleSid)`: drops the session only if it is still the one
  that failed, so a caller holding an old sid cannot throw away a fresh one.
- `headersFor(link, password)`: `Cookie` + `X-SYNO-SHARING`.
- A cheap validation (`list` with `limit=1`) runs at most once per two minutes
  before handing out headers for images. Image requests cannot see Synology's
  JSON error (the image widget only sees "not an image"), so this is how a
  session lost to another device's login is noticed.

Login errors are mapped to a typed `SynologyShareException` with a kind
(`wrongPassword`, `downloadNotAllowed`, `noSession`, `unexpected`).

### 3. Reading the album: `SynologyAlbumSource`

`lib/features/media/data/synology/synology_album_source.dart`:

- Reads the album's `sharing_info.privacy_type` first
  (`SYNO.Foto.Browse.Album get`). A view-only share (`public-view`) cannot
  serve originals (error 804), so its entries point at the `xl` thumbnail
  instead of the original download.
- Pages through `SYNO.Foto.Browse.Item list` (1000 per page). **Any failing
  page fails the whole fetch.** A partial list would read to the poller as
  "these entries vanished" and flag them orphaned on every device.
- Maps each `photo` item to a `ManifestEntry`:
  `url` = original download URL (with `id` and `cache_key` as extra
  parameters), `takenAt` = `time` as wall-clock UTC, `width`/`height` from
  `resolution`, `mediaType` = `photo`, `metadataComplete` = true.
- **`entryKey` = capture time + file size** (`t<time>-s<filesize>`), not the
  Synology item id. The id survives a move inside Synology Photos, but a move
  through File Station or SMB can be re-indexed as delete + new item with a
  new id; the poller would then orphan the old row (with the diver's notes
  and links) and insert a duplicate. Time and size survive moves and renames.
  When two items collide on that key, the id is appended to the later ones so
  keys stay unique per subscription (the unique index would otherwise reject
  the insert). The poller's patch step updates `url` when the id or
  `cache_key` changes, so a moved photo keeps its row.
- Videos and other types (`live`) are skipped in this prototype (see Open
  points).
- On error 119 it invalidates the session and retries once.
- Returns the same `ManifestFetchOutcome` the feed parsers produce, so the
  poller and the manifest panel need no Synology branch. A missing or wrong
  password maps to `ManifestFetchFailure(statusCode: 401)`.

`ManifestFetchService.fetch` delegates to it when the URL is a share link.
No new `ManifestFormat` value: a Synology subscription is recognised by its
URL, and the stored format stays `json`. That keeps the synced enum and its
labels untouched in the prototype.

### 4. Skipping metadata extraction

`NetworkFetchPipeline` skips the per-entry network round-trip only when an
entry carries `takenAt`, size **and GPS**. Synology returns no GPS, so a first
import of several hundred entries would download every original (gigabytes
with videos). `ManifestEntry` gains `metadataComplete`: the publisher states it
has said everything it knows, and the pipeline skips extraction for it.

### 5. Credentials and headers

`NetworkCredentialsService` gains the auth type `synologyShare` (password
only). Synology gives every share link its own password, so it is stored per
share, under `synologyShareKey(link)` = `<host>:<port>/mo/sharing/<code>`,
not per host: with one slot per host, saving a second album's password
locked the first one out. The key is also the row's name in the saved hosts
list, one row per album. A share password saved per host (the first
prototype) is still read as a fallback; the share's own password wins.

`headersFor(uri)`:

- A share URI (link or API URL) with a password for its share: the session
  headers from `SynologyShareSessions`.
- A share URI with no password saved: a login with an empty password, which
  is how a share without a password opens (observed: an open share accepts
  it, a protected one answers error 1001). `SynologyAlbumSource` does the
  same, and only when that is refused reports the share as needing its
  password. `SynologyShareSessions` remembers a refused password for its
  validation interval, so the thumbnails of a protected share without a
  saved password do not each send a login.
- Otherwise the host's secret as before: basic / bearer headers unchanged, a
  host-wide share password yields nothing for non-share URLs.

Secrets are cached per key as before; the session itself is not cached
there, because it changes.

### 6. Serving images

`HttpUrlMediaResolver` gains an optional `headersFor` lookup and returns
`NetworkData` with those headers. Today it returns no headers at all, so the
main image view never sends credentials; passing them is a fix for basic/bearer
hosts as well. For a Synology URL, `resolveThumbnail` returns the `m`
thumbnail instead of the original, so grids load about 50 KB per tile instead
of several MB.

`verify` keeps its one-byte range request; Synology answers 206 for a live
item. For an item that no longer exists Synology answers **200 with a JSON
error** (804), which the generic check would read as "available". A JSON
response to a Synology media URL therefore counts as a transient error: it
never confirms the item, and it never flags it missing either (the poller's
diff is what orphans rows whose entry left the album).

### 7. UI

The URL tab's manifest mode is the entry point; nothing new in navigation.

- Paste the share link, tap Fetch.
- Without a saved password the fetch fails as unauthorized. For a share link
  the panel then shows a password field and a "Save password and fetch"
  button, which saves the `synologyShare` credential for the share and fetches
  again.
- From there: preview, Subscribe, Import. A share link skips the per-row
  import review: it links every photo with a confident dive match (the same
  rule the poller applies) and leaves the rest for later polls. The review
  page asks for one suggestion per row and rebuilds as each arrives; with
  several hundred rows that froze the app for minutes in the prototype test,
  and nobody wants to tick hundreds of rows by hand.
- Automatic polling: the `SubscriptionPollerScheduler` existed but nothing
  started it, so subscriptions were polled only by Poll now. The app root
  now starts it after the first frame: one cycle 30 seconds after launch,
  then a cadence of a quarter of the shortest interval, at most an hour,
  each cycle polling only the subscriptions that are due. It runs while the
  app runs; there is no background fetch when it is closed. The edit dialog
  sets the interval, and moving it moves the next poll with it. Widget tests
  get a scheduler that polls nothing (`getBaseOverrides`).
- Poll now on a share's subscription (Settings, network sources) that fails
  for want of a password, none saved or the saved one refused
  (`synologyNeedsPassword`), opens a password dialog, saves the password for
  the share and polls again; a refused one asks again until cancelled. A
  lost password is fixed where the subscription is, not by pasting the link
  again.
- Review rows and the network thumbnail widget paint Synology's `sm`
  rendition instead of downloading originals.
- `ManifestEntry.filename` carries the original file name: shown in review
  lists and stored in `media.original_filename` (the poller fills it in for
  rows that have none), never as the user-facing caption.

Strings follow the panel's existing hard-coded English with `TODO(media):
l10n` markers; localisation comes with the real feature.

### 8. Importing the same feed twice

Each subscription keys its rows on its own id, so a second subscription to
the same feed used to import every entry again, and deleting a subscription
(which keeps its rows on purpose) and subscribing again showed every photo
twice. The prototype test hit exactly this. It applies to every manifest
format, not only Synology:

- Import looks for a subscription that already reads the URL
  (`ManifestSubscriptionRepository.findByManifestUrl`, compared through
  `canonicalManifestUrl`, which reduces a share link to origin and code). If
  there is one, the import writes under it: entries it already holds are
  skipped, Subscribe switches an inactive one on, and Undo never deletes it.
- New entries are first matched by media URL against manifest rows whose
  subscription is gone (`planManifestAdoption`). Those rows are taken over
  (`subscription_id` and `entry_key` rewritten, missing mark cleared) instead
  of imported again, keeping their dive links, notes and edits. Import and
  the poller both do this.
- Rows of a live subscription are never taken over. Known gap: when the
  media rows sync to a device before their subscription row, they look
  detached there for a moment, and a local subscription to the same URL
  could take them over.

### 9. When the share changes its format

The API is unofficial, so a DSM or Synology Photos update can change it. A
poll that reads a changed list as a smaller album would mark every photo it
cannot read missing, on every device. So:

- `synologyFormatProblem` fails the fetch ("Album format not recognised")
  when the list's items carry no type this client knows, or when fewer than
  half of its photos parse. A few unreadable photos are skipped with a
  warning that lists the item's field names (never values), which is what a
  developer needs to see what was renamed.
- For every feed, the poller refuses a successful fetch with no entries
  while the subscription still holds rows it has not marked missing:
  recorded as a failure, nothing marked. The price is that an album emptied
  on purpose is not mirrored; its rows stay until deleted.
- Every failed poll is logged with the subscription id (never the URL,
  which carries the share code), and skipped entries with their count and
  the first three warnings.
- The user sees it: Poll now reports the recorded error instead of
  "Polled", and the media library shows a banner while an active
  subscription's last poll failed, with a button to the network sources.

### 10. Passwords on another device, setup and data health

Subscriptions and their rows sync; share passwords never do (keychain
only), and the saved hosts table is excluded from sync. A device that gets a
protected album by sync, or by restoring a backup elsewhere, has to enter
its password once. That device is told so in the places that already report
unfinished setup:

- **Set up this device:** `PendingSetupService` lists a
  `subscriptionPassword` item for every active share subscription whose last
  poll on this device wanted a password (none saved, or refused). Only the
  poll can tell, because an open share needs none; the launch poll gives the
  answer shortly after a new device starts. The item's action runs the same
  password flow as Poll now (`resolveSharePassword`): ask, save for the share,
  poll again. Dismissable per device like the other items; the list
  recomputes when a poll records its outcome.
- **Data health:** `evaluateMediaHealth` counts active subscriptions as the
  feature being in use, and reports `mediaSubscriptionNeedsPassword` or
  `mediaSubscriptionFailing` (attention) for the first such subscription,
  so Settings > Data and the Network sources rows carry the mark. Every
  failing subscription is reported, not only missing passwords, so a
  changed feed format does not go unnoticed. Subscriptions are named by
  display name or host, never by URL.
- **Saved hosts:** a row whose secret this device's keychain lacks (a
  restored backup) is marked "Password missing on this device".
- **Check now on a photo:** a share URL this device holds no session for
  verifies as `unauthenticated` without a request, instead of the
  transient error Synology's JSON answer would give. The photo info then
  says "Password missing or not accepted", opens the password dialog for
  the photo's subscription, polls it and checks once more. Only a refused
  password counts as no session: `NetworkCredentialsService.headersFor`
  rethrows an unreachable share, so a check while offline stays transient
  and never asks for a password.

### 11. Videos and live photos

Observed: the list (with `additional` `video_meta` and `video_convert`)
gives a video's length, codecs and the conversions Synology made; `high` is
a 720p H.264 MP4. `SYNO.Foto.Streaming` (method `streaming`, version 2,
`id`, `quality`, `passphrase`, `_sharing_id`) serves a conversion as
`video/mp4` and honours Range; `quality=orig_h264` serves the original
size. The thumbnail API gives a video's poster frame. Every one of them
needs the session cookie: a session id in the query is refused (error 101).

- **Import:** videos become `video` entries with their length. The row
  points at the `high` stream (`SynologyShareLink.streamUri`), about a fifth
  of the original's size, or at the original when there is no conversion
  (a view-only share streams in any case). Live photos become photos
  pointing at their xl rendition, the still frame; the original bundles the
  still with a motion clip no viewer here shows.
- **Poster:** `thumbnailFor` derives it from the stream URL like from an
  original, so the grid shows the video's frame.
- **Playing:** the app could not play a network video at all before.
  A player sends no headers, so `NetworkVideoCache` downloads the video
  with the source's headers into `CacheLocation.networkVideos` and the
  viewer plays the file (`resolvedFilePathProvider`). One download per URL,
  a file once here is reused, JSON or HTML answers are refused, and the
  least recently used files go once the directory passes 2 GB. Not
  Synology specific: any `networkUrl` or `manifestEntry` video plays this
  way.
- **Original:** a video playing a conversion shows "Play original" in the
  viewer; it switches this session's playback to the original
  (`SynologyShareLink.originalFor`), downloaded the same way.

## Security

- The share code alone does not open a password-protected share; the password
  lives only in the device keychain and never syncs.
- The share link (in `media_subscriptions.manifestUrl`) and the item URLs (in
  `media.url`) do sync. Another device sees the subscription and, once the
  diver enters the password there, its photos.
- HTTPS only. A self-signed NAS certificate is out of scope for the prototype;
  DSM's Let's Encrypt certificate works.
- Sessions are never logged; URLs carry the share code but no session.

## Open points (for the real feature)

1. **Videos.** Done in the prototype (section 11). Open: playing while the
   download runs instead of after it, and a setting for the cache size.
2. **Two devices, one share.** If a login really ends every other session of
   the share (observed from one client; not yet confirmed across clients),
   phone and desktop knock each other out. The validation step limits the
   damage to a two-minute gap; a real fix might need one share per device.
3. **Several shares on one host.** Resolved: passwords are stored per share
   (section 5). Open: whether the host-wide fallback is still worth keeping
   once nobody has a prototype-era password saved.
4. **Format identity.** A dedicated `ManifestFormat.synologyPhotos` with its
   label and l10n, instead of URL detection.
5. **Unofficial API.** Any DSM update may change it; the client must fail
   visibly (subscription error) rather than silently.
6. **Self-signed certificates** via the existing pinning used by WebDAV.
7. **Logs.** `ManifestFetchService` logs the manifest URL on failure, which for
   a share link includes the share code. Acceptable for a password-protected
   share; the session id is never logged.

## Cross-examination (resolved)

| Question | Finding | Change |
|---|---|---|
| Is the Synology item id a stable key? | Only for moves inside Synology Photos; a re-index can mint a new id. | `entryKey` from capture time + size, id appended on collision. |
| What if a page of the listing fails? | A partial list would orphan the missing rows on every device. | Any page error fails the whole fetch. |
| Does `verify` detect a deleted item? | Synology answers 200 + JSON 804, read as "available". | JSON responses for Synology URLs count as transient errors. |
| What if the share is view-only? | Originals answer 804; every full-size view would fail. | Read `privacy_type`; point entries at `xl` when downloads are off. |
| Are there types besides photo and video? | Yes, `live`. | Imported as their still frame (section 11). |
| Do extra query parameters break the API? | No; download and thumbnail ignore unknown parameters (checked). | Store `id` and `cache_key` on the original URL. |
| Can a burst of thumbnails trigger many logins? | Yes, and each login ends the previous session. | One in-flight login per share; invalidate only the failing sid. |
| Does the first import download every original? | Yes, without GPS the pipeline extracts each entry. | `ManifestEntry.metadataComplete` skips extraction. |

## Prototype test in the app (Windows hot build, real share)

Run against a password-protected album of several hundred items
(photos, videos, live photos) and a copy of a real logbook of about a thousand
dives, in an isolated database.

| # | Scenario | Result |
|---|---|---|
| 1 | Paste the share link, Fetch, no password saved | Password form appears |
| 2 | Wrong password | Form again, with "The share did not accept the password" |
| 3 | Right password | Preview lists exactly the album's photos (videos and live photos were skipped at this stage; see section 11); capture times correct |
| 4 | Subscribe and Import | Photos with a confident match linked to their dives within about 40 s; app stays responsive; spot check: a photo 29 min before entry lands on that dive |
| 5 | Media library | Synology photos paint with thumbnails from the NAS |
| 6 | Full-screen view | Original loads; depth, temperature and profile overlay derived from the dive |
| 7 | Poll now | No duplicates, no orphans, file names filled in, poll time recorded |
| 8 | Scan all network media | Every imported item reported reachable |
| 9 | Another client logs in to the share, then new images are shown after the validation interval | Session renewed, images load |
| 10 | Another client logs in, then Poll now at once | Album source renews the session itself; poll succeeds |

Found and fixed during the test: import froze on the per-row review (now
skipped for shares), review rows showed `entry.cgi` and no thumbnails (now
file name and `sm` rendition), the network scan counted Synology's JSON error
as reachable (now inconclusive), and a wrong password gave no feedback.

Seen, not changed (existing behaviour): the subscription card shows the
format chip "JSON" for a share and only refreshes "last polled" after the page
is reopened; the first import does not count as a poll.

## Testing

TDD, unit tests with `MockClient` (no network):

- `SynologyShareLink`: parsing, rejecting non-HTTPS and foreign paths,
  builders, thumbnail derivation.
- `SynologyShareSessions`: single in-flight login, invalidate only the stale
  sid, wrong password, validation throttle.
- `SynologyAlbumSource`: paging, mapping of photos, videos and live photos,
  119 retry, 401 mapping, error envelopes, format change detection.
- `NetworkVideoCache` and `motion_photo`: download, reuse, refusal of error
  pages, eviction, motion photo probe and clip extraction.
- `NetworkCredentialsService`: save/decode of `synologyShare`, headers only for
  share URIs.
- `NetworkFetchPipeline`: `metadataComplete` skips extraction.
- `HttpUrlMediaResolver`: headers passed through, Synology thumbnail URL.
- `ManifestFetchService`: delegation for share links only.

Manual: a Windows hot build against a real share, then the phone.
