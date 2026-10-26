# Guided reconnect for a mismatched media store (issue #2303)

Status: design, 2026-10-25. The maintainer skipped the design questions, so
every decision below is the builder's call, written down so it can be
checked in review.

## 1. Why

When the photo copies' folder no longer carries the marker this device
attached to (the store was wiped and set up again, or the folder was
repointed), the preflight suspends the transfer queue and remembers the
mismatch. Today the only way out is hidden: choose the same account again
from Photos and videos > Change, which silently adopts whatever the folder
holds now. Nothing tells the diver what that does to their existing copies,
and the "Reconnect" action on the setup card only opens the page.

The issue was written when `media` rows carried no store id, which made a
silent adopt unsafe. Issue #3482 has since added `media.remote_store_id`, and
with it most of the safety the issue asked for already exists:

- `MediaStoreService.attachToAccountRow` claims this device's unclaimed stamps
  for the store it is leaving before it attaches to the new one.
- `stampsInStore` drops stamps made in another store, so the upload pipeline
  sees those rows as not uploaded to the new store.
- The pipeline HEADs every key before uploading, so an object the new store
  already holds is stamped without being sent again, and a missing one is
  uploaded.

So "adopt, then verify what the store really has" is: attach, then queue
every eligible row (the existing backfill), then drain. This feature is
mostly a guided, honest front door onto machinery that is already correct.

## 2. Goals

- One tap from every place the mismatch is shown opens a guided choice.
- The choice offered fits what the folder holds now, and each option says
  plainly what happens to the existing copies before the diver commits.
- Committing does the whole job: attach, re-check every photo, resume the
  queue. No second trip to Advanced.

## 3. Non-goals

- Changing how the preflight detects a mismatch.
- Fixing other devices' unclaimed stamps. Each device claims its own when it
  reconnects, which is the only place that knows which store they were made
  in.
- Deleting anything, in either store.

## 4. Anti-goals

- **Never overwrite another store's marker.** Writing a fresh identity over
  a marker another device attached to strands every device on it: the
  #1356 identity split, done on purpose. So "rebuild" is offered only when
  the folder holds no marker at all (see 5.2).
- **Never run the Verify sweep as part of a reconnect.** It deletes objects
  the logbook does not reference, and a folder the logbook has no record of
  may hold another logbook's photos. Verify stays a deliberate action in
  Advanced.

## 5. Behaviour

### 5.1 Entry points

The same sheet, "Reconnect photo copies", opens from:

1. the setup card's mismatch item: its Reconnect action opens the sheet in
   place of navigating to Photos and videos;
2. the Uploads (Transfers) page's paused notice, when its hold is a marker
   mismatch, as an action under the notice text;
3. the Photos and videos status line, when it reads "Uploads paused" for a
   mismatch, as an action under the line.

### 5.2 What the sheet offers

On opening, the sheet reads the marker again (a spinner says it is checking
the account). What it finds decides the choices:

| Found | Choices |
| --- | --- |
| The attached marker again | Nothing to choose: the flag is cleared, uploads resume, the sheet says so. |
| Another store's marker, one the library knows (a synced `media_stores` row) | **Use the copies there now** (adopt), **Stop keeping copies on this device** (detach) |
| Another store's marker the library has no record of | The same two, with adopt's text warning that it is only right if the folder belongs to this logbook |
| No marker | **Start the copies again there** (rebuild), detach |
| Could not read | The error, **Try again**, detach |

Consequence lines (shown under each choice before it is tapped):

- Adopt, known store: another of your devices set these copies up; photos
  already there stay, and anything missing uploads again from this device.
- Adopt, unknown store: this logbook has no record of these copies; choose
  this only if the account is meant for this logbook.
- Rebuild: the record of the copies is gone from the account; a new set
  starts there, photos still there are kept, and everything this device has
  uploads again.
- Detach: this device stops keeping copies, and nothing in the account is
  deleted.

When photos and videos are kept only in the cloud (`countHeldOnlyInStore` of
the attached store is above zero), the sheet adds one line: those items
open again only if the account still holds them.

The choices commit on tap. All of them can be undone (another reconnect,
or setting the copies up again), and each one's consequence is already on
screen.

### 5.3 What each choice does

- **Adopt** and **rebuild** are the same call: `attachToAccountRow` with
  the attached account row and its store. `ensure()` decides whether it
  adopts (a marker is there) or mints (none is). Then the backfill queues
  every eligible row and the worker drains. If another device minted a marker
  between the check and the tap, the rebuild becomes an adopt, which is the
  safe outcome. The snackbar names what actually happened.
- **Detach** is today's `MediaStoreService.disconnect()`.
- An attachment with no account (a legacy, pre-accounts S3 attachment), or
  whose account row is gone, cannot be re-attached through an account row.
  There the sheet offers **Choose the account again** (opens Photos and
  videos) in place of adopt or rebuild, plus detach. The page opens from the
  context that opened the sheet, so the desktop settings pane shows it in
  the pane; opened from Photos and videos itself, the choice just closes
  the sheet, leaving the diver on the page where the account is chosen.
- Every entry point reuses the existing "Reconnect" action label. The two
  existing mismatch strings that said "choose the account again" now point
  at reconnecting instead.

## 6. Structure (builder's calls)

- `lib/features/media_store/domain/media_store_reconnect_situation.dart`: the
  sealed situation the check returns.
- `lib/features/media_store/data/media_store_reconnect.dart`: `inspect()`,
  `reconnect()` (adopt or rebuild) and `detach()`, built on
  `MediaStoreAttachState`, `MediaStoreService`, `MediaBackfillService`,
  `MediaStoresRepository`, `MediaRepository` and an injected store lookup,
  so it is testable without providers.
- A provider beside the other media store providers.
- `lib/features/media_store/presentation/widgets/media_store_reconnect_sheet.dart`:
  the sheet and a `showMediaStoreReconnectSheet` helper the three entry
  points call.
- `MediaStorePreflight`'s doc comment is updated: it still never adopts on
  its own, and now names the sheet as the way out.

## 7. Testing

- Service: each situation from `inspect()` (match, known other, unknown
  other, none, unreadable, no account); adopt claims the old stamps, attaches
  to the new id, announces it and queues the backfill; rebuild mints; a
  rebuild racing a new marker adopts; detach clears the attachment.
- Sheet: each situation renders its choices and consequence lines, and each
  choice calls the service.
- Entry points: the card item, the paused notice and the status line open
  the sheet only for a mismatch.
