# Tag people in photos and videos

Date: 2026-10-28
Issue: #1745
Release: v1.8.4
Builds on: main at ec1610a298b, schema v320. Follows the species tags on
media (`media_species`, #1638) and the media tags design
(`2026-10-23-media-and-document-tags-design.md`, #1970), whose seams this
feature reuses.
Mockup: [assets/2026-10-28-buddy-photo-tags-mockup.html](assets/2026-10-28-buddy-photo-tags-mockup.html)

## Problem

A diver can tag the fish in a photo but not the people. There is no way to
record "me and my buddy are in this shot", and no way to start from a buddy,
or from yourself, and find the photos and videos they appear in. The request
came from a user (#1745) who pointed at species tagging as the model.

## Intent

Record who appears in each photo and video, and make that useful in both
directions: while going through a dive's media, and starting from a person.
The maintainer wants both directions equally. "Me" matters as much as
buddies: the motivating case is a selfie, and the payoff is being able to
pull up every photo and video of yourself.

## Goals

- Tag one or more buddies, and the diver themself ("Me"), on any photo or
  video.
- On a photo, mark where the person is (a face tag: a box on the image).
- On a video, mark a person at a moment: a box on a paused frame plus the
  time. A person can be tagged at several moments in one video.
- Tag a person without a spot ("they're in this"), on photos and videos,
  for when no face is visible.
- See who is tagged while viewing, and jump from a tag to the person.
- From a buddy, see every photo and video they are tagged in.
- Filter the media library by person, Me included, so "Photos of me" can be
  kept as a smart album.
- When a tagged buddy is not logged on the photo's dive, offer to add them.

## Non-goals

- Automatic face finding or recognition. Masks, regulators and hoods defeat
  face detectors, everyone wears similar gear, and no detector runs on
  desktop. The maintainer agreed the app cannot ask reliably.
- Boxes that follow a person through a video (tracking).
- Tagging people who are not buddies (free-text names). "New buddy" in the
  picker covers the case.

## Anti-goals

- A wrong automatic guess the diver has to correct. The app may rank the
  picker; it never guesses who a face is.
- Tagging that changes the dive's buddy list without asking. Tags and dive
  buddies stay independent facts: adding a tag never adds a dive buddy on its
  own, and removing a tag never removes one.
- Copying photos into app storage. Media stays links only; tags are rows
  about a media item, nothing more.

## Decisions (the maintainer's)

1. Build issue #1745 rather than a new issue.
2. Both directions: tag from the media, and browse from the person.
3. Tagging yourself is in scope, for selfies, to find photos and videos of
   you.
4. Photos get face tags: a box marking where the person is.
5. Videos get face tags as moments: a box on a paused frame plus its time.
   The tag's chip shows the time and jumps the video there.
6. The diver taps the spot; the app does not find faces. The picker lists Me
   first, then the buddies logged on this dive, then everyone else,
   searchable.
7. The viewer flow in the mockup (screens 1 to 3) is approved as shown.
8. Tagging a buddy who is not on the dive offers to log them as a buddy on
   that dive.
9. Media visible to several diver profiles (media with no dive) shows each
   profile only its own tags: tags of its own buddies (`buddies.diver_id`)
   and its own Me. Another profile's tags are invisible, in the chips, the
   boxes, tag mode, the buddy page and the library filter. Ownership comes
   from the buddy's `diver_id` or the row's `diver_id`; no owner column is
   added.
10. A buddy linked to another local profile (`buddies.linked_diver_id`) is not
    that profile's Me. Tagging buddy Bob does not put the photo in linked
    profile B's "Photos of me". Me tags and buddy tags stay separate, so the
    queries never join through the link.

## Behaviour

### Viewing (mockup screen 1)

- The media viewer shows a row of people chips beside the species chips:
  "Me" first, then buddies by name. A video moment tag reads
  "Alex · 0:42".
- Face boxes are drawn over the photo with the person's name. They follow
  the viewer's existing controls visibility: tapping the photo to clear the
  screen hides the boxes with the toolbar and the bottom metadata.
- Tapping a buddy chip opens that buddy's page. Tapping "Me" opens the media
  library filtered to Me (there is no "me" page that lists media today).
- Tapping a video moment chip pauses the video at that time and shows its box.
  The scrub bar shows a small mark at each tagged moment.

### Tagging (mockup screen 2)

- A people button in the viewer toolbar turns tag mode on. A hint reads "Tap a
  person to tag them" and carries a "Tag without a spot" link.
- In tag mode, a tap drops a box centred on the tap. The diver can drag its
  corners to fit, then the picker opens.
- Picker order: Me; "On this dive" (the dive's logged buddies); "Everyone
  else"; a search field over all buddies; "New buddy" (name only).
- For media not attached to a dive, the "On this dive" group is absent.
- On a video, tag mode pauses playback and the tag records the paused time.
- Tapping an existing box in tag mode lets the diver change the person, move
  or resize the box, or remove the tag.
- "Tag without a spot" opens the same picker and saves a tag with no box and
  no time.
- A person can be tagged more than once on a video (different moments). On a
  photo, the builder decides whether a second tag of the same person replaces
  the first or is refused; a person appears once in a still.

### The offer to add a buddy to the dive

- After the diver picks a buddy who is not in the dive's buddy list, a
  dismissable prompt asks "Add Alex to this dive's buddies?" with an Add
  action. Ignoring it keeps the tag and leaves the dive untouched.
- Add logs them with the default "buddy" role, editable later on the dive.
- No offer for Me, and none for media not attached to a dive.
- "New buddy" creates the buddy from the name, tags them, then makes the same
  offer.

### From a person

- **Buddy page:** a Photos section near "Shared dives" shows thumbnails of
  every photo and video the buddy is tagged in, newest first, opening into the
  viewer. Hidden when there are none. Mirrors the species page's photos
  section.
- **Media library filter:** a People option beside species and tags. Picking
  one or more people (Me included) shows media tagged with any of them.
  Active filter chips and smart albums carry it like the other filters.

### Housekeeping

- Deleting a buddy removes their tags, synced as deletions so they do not
  return from another device.
- Merging buddies moves the duplicate's tags to the survivor, inside the
  merge's existing undo snapshot, and repoints smart albums that filtered on
  the duplicate (as `smart_album_tag_repoint.dart` does for tag merges).
- Deleting a diver removes that diver's Me tags (`diver_delete_steps.dart`).
- Deleting a media item removes its tags; restoring it (undo) restores them
  (`media_row_restore.dart`).
- Tags sync across the diver's devices like species tags.
- "Me" belongs to the diver profile active when tagging. Each profile's Me
  tags are its own; another profile does not see them as "Me".

## Data model

A new synced table, `media_people` (my call on the name), one row per tag:

| Column | Notes |
| --- | --- |
| `id` | text primary key |
| `media_id` | FK to `media`, cascade |
| `buddy_id` | FK to `buddies`, cascade, nullable |
| `diver_id` | FK to `divers`, cascade, nullable; set for a Me tag |
| `bbox_x`, `bbox_y`, `bbox_width`, `bbox_height` | nullable reals, normalised 0 to 1 against the displayed image (null for a tag without a spot) |
| `video_position_ms` | nullable int; set only for a video moment tag |
| `created_at`, `updated_at` | ints |
| `hlc` | nullable text, the sync clock |

Exactly one of `buddy_id` and `diver_id` is set. Box columns are all set or all
null. These are my calls on shape; the builder may adjust names but keeps one
table for photos and videos, so "who is in this media" is one query.

Unlike `media_species`, rows are edited after creation (move, resize, change
person), so the row carries `updated_at` and resolves conflicts by its clock.

The schema rung goes in `lib/core/database/migrations/` and the table in
`lib/core/database/tables/`, never in `database.dart` (the split from #2502).
A fresh install and an upgrade from v320 both create the table; no existing
data changes.

## Sync

Register `media_people` through the same checklist the media tags junction
used in #3605 (payload field, JSON, changeset tables, fetch, single and bulk
apply, record ids, table map, tombstones, merge order after `media`,
`buddies` and `divers`, parent refs, conflict references, hlc targets). The
`sync_repository`, `sync_data_serializer`, `sync_service`, the before-open
table backstop and the sync migration helper are the touch points that PR
changed and this one will too. The architecture guard tests under
`test/architecture/` fail when a synced table misses a registration; they
are the checklist's safety net.

## Where the code goes (guidance, not a mandate)

- Repository: a `MediaPeopleRepository` in `lib/features/media/data/
  repositories/`, alongside `media_species_repository.dart`.
- Providers for a media item's people and a person's media, in
  `lib/features/media/presentation/providers/`.
- Viewer: a people chips row beside `MediaSpeciesChipsRow`, a face box
  overlay, tag mode, and a toolbar action in `media_viewer_toolbar.dart`.
  `media_viewer_page.dart` is large; new UI goes in new widget files.
- Picker: a bottom sheet in `lib/features/media/presentation/widgets/`,
  reading the dive's buddies through the existing buddy providers.
- Buddy page: a section widget beside `BuddySharedDivesSection`.
- Library filter: a people field on `MediaLibraryFilter`, its JSON, the
  filter sheet, the active filter chips and the library query.
- Every user-visible string goes through the ARB files, in every locale the
  app ships.

## Constraints

- Works the same on macOS, Windows, Linux, iOS and Android, except that
  video moment tags cannot be placed where the video cannot play (see My
  calls). No new native dependency.
- Paths built with `p.join`; tests restore any global state they replace.
- Files stay under 800 lines; the viewer page is already large.
- TDD: tests first for the repository, sync registration, filter, merge,
  delete and restore paths, and widget tests for tag mode, the picker order
  and the offer.

## Left to the builder

- The exact box drawing and resize handles, and the default box size on a
  tap.
- How the photo case treats a second tag of the same person.
- Icons and exact wording, within the mockup's intent.
- Whether the buddy page section shows a count.
- Index choices for the new table.

## My calls (not discussed with the maintainer)

- The table name and shape above, including one table for photos and
  videos.
- "Tag without a spot" lives as a link on the tag-mode hint.
- "New buddy" in the picker creates a buddy from a name only.
- Tapping the Me chip opens the library filtered to Me.
- People tags are not written to UDDF export in this change: UDDF has no
  field for them, and species tags on media are not exported either.
- No bulk people tagging from the library's multi-select bar in this
  change.
- "Me" in a saved filter means the profile viewing it, not a fixed profile.
  Smart albums have no owner and are shared by every profile on the device,
  so the filter JSON stores a "me" flag rather than a diver id. "Photos of
  me" then shows each profile its own photos, and a diver merge or delete
  needs no album repoint.
- A video the app cannot play (any video on Linux, where `video_player` has
  no implementation; a connector video that only shows its poster; a video
  whose file is missing) allows only "Tag without a spot". Its existing
  moment chips still show their time; tapping one does not seek. This is the
  one platform difference: on Linux, video moment tags made elsewhere are
  shown but cannot be placed.
