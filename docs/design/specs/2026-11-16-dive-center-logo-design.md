# Dive center logo (#4460)

## Intent

A dive center can carry a logo the way a buddy carries a profile photo, so a
diver recognizes their usual shops at a glance wherever a specific center is
drawn: the list, the map, and the screens that reference it. Requested in
issue #4460.

## Goals

- Pick, replace and remove a logo from the dive center edit page.
- Store it on the center's row and sync it to the diver's other devices.
- Show it in place of the store icon everywhere a specific center is drawn.

## Non-goals

- Fetching logos automatically (from the import API, a website or a search).
- Keeping wide or transparent logos whole. The logo is a square crop, as for
  buddies; a very wide logo is cropped to a square.
- Changing the generic "dive center" icons that do not belong to one center
  (navigation, search labels, import search results, field constants).

## Anti-goals

- A logo that exists on one device only. Storage is bytes on the row, never a
  path or a media-library link.
- Unbounded bytes. Every logo goes through the existing 512 px encoder.
- Logos decoded at full size in long lists or on a dense map.

## Approaches

1. **`logo` BLOB column on `dive_centers` (chosen).** Mirrors `buddies.photo`:
   one nullable column, synced as base64 through the serializer's existing
   BLOB handling, drawn through `ProfileAvatar`'s size-bounded decode.
2. **Separate `dive_center_logos` child table.** Keeps bytes off list queries,
   but buddy lists already carry their photo on the row without trouble, and a
   child table needs the parent-gated child sync plumbing. Rejected.
3. **Link to a media-library item.** Media items are links to files on one
   device, so the logo would be missing elsewhere. Rejected.

## Design (as decided)

- **Picking.** The edit page gets the buddy edit page's tappable 50-radius
  avatar with a camera badge, running the shared `pickProfilePhoto` flow
  (camera, library, remove; square crop; encode). No contacts source.
- **Storage.** A 512x512 square JPEG (`ImageEncodeSpec.avatar`) in a new
  nullable `logo` BLOB column on `dive_centers`, added by a new schema rung.
  Existing rows read null; nothing is backfilled.
- **Transparency.** A transparent PNG never turns black: package:image's
  JPEG encoder already blends alpha onto white, so the shared encoder needs
  no change and buddy and diver photos behave as before. A codec test pins
  it. (The design chat proposed adding the fill; building found it was
  already there.)
- **Sync.** Dive center rows are exported, fetched and applied with the BLOB
  serializer (base64), in every arm where buddies already use it, and the
  base-export table entry is marked as carrying a BLOB.
- **No logo.** The store icon stays exactly as today, not initials.
- **Shape** (decided during the build). A logo takes the shape the store
  icon has in each place today: a rounded square on the standard list tile
  and the detail header, a circle on map markers, the map card and the
  picker. A center with no logo looks exactly as now.
- **Compact and dense list rows** (decided during the build) have no icon
  today. They gain a small logo before the name only when the center has
  one; without a logo the row is unchanged.
- **Surfaces** (logo replaces the store icon):
  - dive center list, all three tile styles
  - dive center detail header and the master-detail summary pane
  - map markers (logo inside the rating-coloured ring; cluster bubbles
    unchanged) and the map's bottom card
  - dive center picker in the dive editor
  - the dive center row on a dive's detail page

## Left to the builder

- The widget's name and shape (a `DiveCenterAvatar` wrapping `ProfileAvatar`
  with an icon fallback is the expected shape).
- Exact marker and tile sizes, keeping each surface's current footprint.
- Any other place that copies or serializes a dive center (import, export,
  agent access) carries the logo through or leaves it out deliberately.
