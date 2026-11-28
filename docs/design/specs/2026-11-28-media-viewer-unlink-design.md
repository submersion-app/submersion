# Unlink from the media viewer

Date: 2026-11-28. Release: v1.8.7. Status: approved in chat.

## Intent

A diver often spots a photo or video that does not belong while looking at
it full screen. Today the only way to unlink it is to close the viewer, find
it again in a grid (the dive or site Media card, the library, the Gear tab),
select it and unlink it there. The viewer should offer Unlink itself, once the
item is unlocked for editing (issue #4527's lock).

## Goals

- An Unlink action in the unlocked viewer's editing bar.
- It does exactly what the Unlink of the screen the viewer was opened from
  does, so the two can never disagree.
- Like every other change in the unlocked viewer, it is held until Save and
  undone by Cancel.

## Non-goals

- Documents (PDFs and other files) open in `DocumentViewerPage` and the
  attachment details page, not the media viewer; they get nothing here.
- No Unlink while locked, and none in the read-only browser build.
- No new meaning of "unlink": the existing `MediaUnlinkService` paths are
  reused as they are.

## Anti-goals

- Deleting or changing a user's original file. Unlink never touches it
  (product rule: never delete originals).
- An unlink that happens before Save, or that survives Cancel.
- A dive-scoped Unlink that destroys a photo a site or gear item still uses.

## Approaches considered

- **A. Hold the unlink in the photo's own sitting (chosen).** Each place
  that opens the viewer says what Unlink means there. Unlink, once
  confirmed, is held in the photo's sitting; Save runs the existing unlink
  inside the photo save's transaction. Works everywhere the viewer opens.
- **B. Hand the unlink to the page underneath** (the dive's, site's or gear
  item's sitting, as their Media cards do). Only works when that page exists
  and is unlocked: the library, map, trip, species and buddy viewers would
  get no Unlink. Rejected.
- **Immediate unlink** (confirm, then unlink at once, ending the sitting) was
  offered and declined: it would be the one action in the unlocked viewer
  that skips Save.

## Decisions

### What Unlink unlinks from

The viewer takes an unlink scope from whoever opens it:

| Opened from | Scope | Service call |
| --- | --- | --- |
| Dive Media card, profile photo markers, dashboard panel (`PhotoViewerPage`) | dive | `unlinkFromDive` |
| Trip gallery, species photos, dive sightings, species review, marine life crop strip, buddy photos | dive | `unlinkFromDive` |
| Site "dive photos" strip (`SiteViewerScope.divePhotos`) | dive | `unlinkFromDive` |
| Site media section | site | `unlinkFromSite` |
| Gear photos section, check-in photos, observations card, Media screen Gear tab | gear | `unlinkFromEquipment` |
| Media library grid and media map | everything | `unlinkFromLibrary` semantics (delete every link) |

The dive, site and gear scopes keep their existing carve-outs: a row another
attachment still needs keeps its row with only that one link cleared.

Unlink is offered only when the item has the link in question: the dive
scope needs a dive link, the site scope a site link, the gear scope a gear
link. The everything scope always offers it.

### The action

- In the unlocked editing bar, icon `link_off`, labelled for its scope:
  "Unlink from dive", "Unlink from site", "Unlink from gear", or "Unlink"
  in the library and map.
- Ranked after the existing editing actions, so on a phone it may sit in the
  overflow menu without displacing anything already shown.
- Photos and videos alike.

### Confirming

Tapping it shows the same confirmation the matching grid shows (title, body
and, when a caption or favorite would be lost, the metadata note), for one
item. Cancel in the dialog does nothing.

### Held state

Once confirmed:

- A strip over the item reads "Will be unlinked from this dive when you
  save" (site, gear item, or "your library" for the everything scope), with
  an Undo button that drops the held unlink and nothing else.
- The item is dimmed.
- The other editing actions (species, people, tags, time, adjust colour) go
  quiet while the unlink is held. Changes made before Unlink stay held and
  are written with it.
- Save is enabled; the sitting counts as changed.
- Paging stays locked, as for any unlocked photo.

### Save

- One `PhotoEditSaveService.save` call: the photo's held changes, then the
  unlink, in the same transaction and change log operation, so it is one
  History entry, labelled with an unlink card id. A failure writes nothing.
- The unlink runs through the scope's `MediaUnlinkService` path with the
  remote blob delete held for the commit (as `SittingMediaWriters` does with
  `holdRemoteDelete: true`), and the delete queue drained after commit.
- The everything scope also clears a gear cover naming the item, as the
  library's Unlink does.
- After a successful save the viewer moves to the next item, or the previous
  one if this was the last, and closes if it was the only one.
- A save that fails says so (the existing save-failed snackbar), and the
  unlink stays held.

### Cancel and leaving

Cancel, Escape, closing the viewer, or stepping away go through the existing
"discard changes?" check; a held unlink is a change, and discarding it keeps
the item.

### Edge cases

- Item deleted on another device while the unlink is held: the viewer's
  existing gone handling ends the sitting and says so.
- Item moved to another dive meanwhile (dive scope): the existing
  `PhotoMovedError` refusal applies.
- Viewer opened over an unlocked dive page: the photo's own Save does the
  unlink; the dive page's sitting sees the row gone through its existing
  handling.
- A dive-scoped item that loses its dive link elsewhere while held: Save is
  refused by the moved check, and nothing is written.

## Left to the builder

- How the scope is passed (a parameter on `MediaViewerPage` and the wrapper
  pages, defaulting to no Unlink), and whether the held unlink is an
  `EditField` on `PhotoRecord` or a held write.
- Exact l10n keys and wording beyond what is fixed above; reuse the grids'
  confirmation strings.
- Widget and service tests per the repo's TDD rule, covering each scope, the
  carve-outs, Undo, Cancel, and the step after Save.
