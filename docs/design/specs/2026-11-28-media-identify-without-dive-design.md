# Identify species in media that is not on a dive

Issue: #5122. Release: v1.8.7.

## Intent

A diver testing species identification on GoPro footage wanted to run it from
the Media section without first logging a dive for the footage. The
maintainer also wants it on the spot: pointing a phone at an aquarium, or at a
photo on a screen.

Today the analysis itself does not need a dive (`IdentificationTrigger` runs
on any media row), but getting a file in does: the import keeps only files
placed on a dive or a site, and a launch sweep deletes any media row without
one. Files placed only on a site also get no location for identification,
because `mediaLocation()` never reads the row's own site, so they fall back to
the stricter no-location bar (`suggestScoreNoLocation` 0.79 against
`suggestScore` 0.64).

The maintainer decided on these parts, all in this one feature and one PR:

1. **Identify without keeping:** open files from disk, run identification,
   keep nothing unless the diver chooses to.
2. **Camera:** an in-app camera with live suggestions over the preview, and
   photo and video capture that goes into the same Identify viewer.
3. **Keep media with no place:** the library may hold media that belongs to no
   dive and no site, held back from devices that have not updated.
4. **Place on a site quickly:** put every unmatched file of an import on one
   site in a single step.
5. **The site counts as the location.**
6. **Tags follow media to a dive:** moving tagged media onto a dive relinks its
   tags to that dive's sightings.

## Decisions that reverse earlier ones

- The media attached-or-absent design
  (`docs/design/specs/2026-08-23-media-attached-or-absent-design.md`) made
  every row carry a dive or site link and retired `retain_in_library`. This
  feature brings the flag back for media the diver keeps with no place.
- The marine life identification program
  (`docs/design/specs/2026-11-17-marine-life-identification-program-design.md`)
  listed "no live camera or recording in the app" as a decided non-goal. This
  feature adds both, for identification.

## Goals

- From the Media section, a diver can pick photos or videos, or take them with
  the camera, and see species suggestions on them without anything being
  written to the logbook, the species catalogue, the sync stream, History or
  the media store upload queue.
- On phones and tablets, the camera shows suggestions over the live preview.
- From the Identify viewer, a diver can keep a file on a dive, on a site, or
  with no place. What they confirmed or rejected comes along.
- The import review can keep unmatched files with no place, or put them all on
  one site at once.
- Kept media with no place stays in the library: the launch sweep, the delete
  cascades and older app versions on other devices leave it alone.
- Identification uses a media row's own site as its location when the file has
  no GPS and no dive.
- Moving media onto a dive gives its tags that dive's sightings.

## Non-goals

- Reading GPS from GoPro telemetry (GPMF) or any new metadata source.
- A map pin as a place. A place is a dive or a site.
- Changing what "Remove from dive" does: media with no other link is still
  deleted, as today.
- A per-diver owner for media with no place. Like site-only media today, it is
  visible to every diver on the device.
- A camera on desktop or the web.
- Confident live names. Live naming shows suggestions only.

## Anti-goals

- A file the diver did not keep reaching the database, the species catalogue,
  sync, History, the media store upload queue, the photo library or the media
  library.
- A cut-down second species UI for the Identify viewer. It shows the same
  suggestion bar, boxes, crops and confirm and reject controls as the normal
  viewer.
- Kept media with no place silently disappearing: through the sweep, a
  cascade, or another device.
- The camera screen crashing the app. When memory runs short, live naming
  stops; the camera keeps working.

## Constraints found in the code

- `MediaOrphanBacklogSweep` deletes every row with no dive or site link older
  than 24 hours on each launch, through `MediaDeletionCoordinator`, with
  tombstones that sync. Its query is `MediaRepository.getSweepableOrphanIds`
  over `isLinkedToLogbook`. The cascades (`planMediaCascade` in
  `media_parent_cascade.dart`, and the dive and site partitions in
  `media_repository.dart`) delete any row whose links are all going.
- `media.retain_in_library` exists and is synced, with a conflict label.
  Nothing sets or reads it in any release.
- `MediaViewerPage` re-reads each item through `mediaByIdProvider(item.id)`.
  It cannot show an item that is not a row.
- `MediaIdentificationService` takes its storage as constructor arguments
  (`MediaIdentificationRepository`, `IdentificationEmbeddingRepository`,
  `IdentificationCropStore`, `onItemSettled`). The species overlays read
  providers built on those (`photoDetectionsProvider`,
  `mediaSuggestionsProvider`, `mediaTagChipsProvider`,
  `suggestionAcceptorProvider`, `identificationCropProvider`, species name
  lookups such as `allSpeciesProvider`). Riverpod is 3.4: a scoped override
  reaches only providers that declare it in `dependencies`.
- `SuggestionAcceptor.resolveWithOrigin` creates a catalogue species when the
  candidate is not in the catalogue, and the species picker can create one.
- `VisionEngine.analyze({path, bytes})` names the animals in one image;
  `VisionEngine.memory()` reports memory in use.
- Species tags (`MediaSpecies`) belong to the media row. A tag without a dive
  is valid: `tagPhoto` and `applyAppTag` skip the sighting when the media has
  no dive. `confirmTag` links the current dive's sighting only when the tag
  has none.
- `reassignMediaToDive` is the single path that moves media onto a dive,
  including the ordinary Move to dive and agent writes.
- Sync is a shared store each device writes its own log to. Media export goes
  by HLC watermark (`_exportMedia`, `_buildSyncData`, the base `emit` used for
  base publish, compaction and nearby full export). A row left out of one
  export is never picked up again unless it is stamped with a new HLC
  (precedent: `backfillMissingHlc`). The shared-library site filter (#2567) is
  the precedent for leaving rows out of every export path.
- Each device's manifest publishes `writerSchemaVersion`. It has no app
  version. Builds before v1.8.5 permanently drop a child row whose media row
  is missing; v1.8.5 and later hold it until the parent arrives (#4954).
- The camera permission is declared on iOS and Android. `gal` (save to the
  photo library) is a dependency. Media is linked, never stored by the app.
- Memory: identification holds about 2.4 GB of the 3.3 GB an iPhone app may
  use; on a Pixel 6a Android killed the app when the camera opened during
  identification (Android's floor is now 8 GB).

## Approaches considered

For "identify without keeping":

1. **Scratch analyser (chosen).** The Identify viewer runs a second
   `MediaIdentificationService` wired to in-memory stores, on temporary media
   items that point at the files. Closing discards everything. Keep inserts
   the media row and copies the results and decisions into the real stores.
   Nothing can leak, by construction.
2. **Temporary database row.** Rejected: every library query, count, sync
   export and History entry would have to skip it, and a crash leaves rows.
3. **Import, then offer Discard.** Rejected: it syncs and uploads files the
   diver may never keep.

For the entry point, an Identify button in the Media section header was chosen
over a mode inside Import.

For older devices, holding kept media back from the shared export was chosen
over a version gate on the feature or a release note warning.

For the camera, an in-app camera with live suggestions and capture was chosen
over the system camera alone, in this PR rather than a later one.

## Design

### 1. Identify viewer (scratch)

- **Entry.** An Identify button in the Media section header, beside Import,
  Transfers and Sources, shown while marine life identification is enabled.
  With no species pack installed it shows the existing download prompt.
  On phones and tablets it opens the camera screen (section 2), which has a
  button to pick files instead. On desktop it opens the file picker.
- **Picking.** The same sources Import offers on the platform, several files
  at once, photos and videos. *Builder's call: reuse the import's pickers and
  candidate building, so capture time and GPS come from the same readers.*
- **Items.** Each file becomes a temporary `MediaItem` whose id can never
  collide with a row (for example `scratch:<uuid>`), with its local path or
  platform asset id, type, capture time, size and GPS.
- **Viewer.** `MediaViewerPage` gains a scratch mode: it reads items from the
  list it was given instead of `mediaByIdProvider`, shows no dive, site or
  edit actions, and shows a banner, "Not in your library. Nothing is kept
  unless you keep it.", with a Keep button.
- **Analysis.** The page sits in a scope where the identification,
  embedding, crop and tag stores are in memory, new species are held in
  memory (below), and `onItemSettled` does not run the auto-applier against
  the database. The species overlays read the same providers through that
  scope. Crop images go in a temporary folder deleted when the viewer closes.
  Location is the file's own GPS, and none for camera captures.
- **Decisions.** Accepting, confirming and rejecting suggestions and hand
  tagging change the in-memory tags and identifications as they would change
  the real ones.
- **New species.** A species the catalogue lacks is held in memory while the
  viewer is open and shows by name everywhere the viewer shows names. It is
  created in the catalogue only when a file using it is kept, and is never
  created otherwise.
- **Keep.** A sheet with three choices: Put on a dive, Put on a site, Keep
  without a place.
  - The dive choice lists dives, the one the capture time matches first.
  - With more than one unkept file open, the sheet offers this file or all
    unkept files. *Builder's call on the control.*
  - A camera capture is first saved to the photo library with `gal` and kept
    as a link to that asset. Nothing else is saved there.
  - Keeping inserts the media row with the chosen link through the import's
    insert path, with `retain_in_library` set when there is no place. It then
    creates the held new species it uses, copies the run, identifications,
    embeddings and crops to the new id, and writes the tags: confirmed and
    hand tags through `tagPhoto`, unconfirmed app tags through `applyAppTag`
    with the diver's sighting timing. A kept item leaves scratch mode.
  - A file gone from disk fails with a message, and the rest go ahead.
- **Leaving.** Closing with unkept files the diver made a decision on asks
  "Leave without keeping?". Otherwise it closes without asking. Camera
  captures not kept are deleted from the temporary folder.

### 2. Camera (phones and tablets)

- **Screen.** A full-screen camera with a photo and video switch, a shutter,
  a thumbnail of this session's captures, a button to pick files instead, and
  a "Names on" switch. Captures open in the Identify viewer with the session's
  other captures.
- **Live suggestions.** While names are on, the screen takes a frame about
  every 250 ms (the video scan's sample rate), runs it through the same
  detect-then-name pipeline as a photo, and draws boxes with suggestion names
  over the preview. A new frame is skipped while the previous one is still
  being named. Boxes are matched frame to frame so a label does not jump
  between animals. No location is used, and a line on the screen says so.
- **Recording.** While recording, live suggestions keep running when the
  device can sustain both; the recorded clip is analysed in full afterwards
  in the Identify viewer.
- **Memory.** Before each frame, `VisionEngine.memory()` is checked against a
  margin below the app's limit. Under it, live naming pauses with a line
  saying why, and resumes when memory recovers. The camera never closes for
  it.
- **Package.** The `camera` plugin, for its preview and image stream on iOS
  and Android. *Builder's call how frames reach the engine (encoded bytes
  through `analyze`, or a frame entry point added to the engine).*
- **Measure before release:** frame rate, time to first label and memory on
  an iPhone and an 8 GB Android phone, written to
  `docs/design/findings/`, as the earlier species ID pieces did.

### 3. Keep media with no place

- **Import review.** Each row's menu gains "Keep without a place" beside
  Choose dive and Choose site. A bar above the unmatched rows offers "Put all
  on a site" and "Keep all without a place". The Files tab's Unmatched group
  gets the same two actions, and its commit persists rows given either.
- **Insert.** Kept with no dive and no site, and `retain_in_library` true.
- **Sweep.** `getSweepableOrphanIds` leaves rows with `retain_in_library`.
- **Cascades.** When the last dive or site link of a row with
  `retain_in_library` is deleted, the row stays, with no place.
- **Placing later.** Moving such a row onto a dive or a site leaves the flag.
- **Library.** These rows show in the existing Unlinked group of By dive and
  under the Attached to: Unlinked facet.

### 4. Holding kept media back from older devices

- **Older peer.** A device whose manifest's `writerSchemaVersion` is below the
  schema version this PR ships. This PR bumps the schema version for that
  reason (with whatever migration it needs, or a no-op rung).
- **Held.** While any older peer is in the library, a media row with
  `retain_in_library` and no dive or site is left out of every export path
  (incremental, base, compaction, nearby full and delta), and so are its
  children: `media_species`, `media_enrichment`, `media_tags`, `media_people`,
  and the identification runs, identifications and crops. Nearby sync decides
  per session from the peer's hello.
- **Remembered.** The device records each media id it held back, in a
  device-local table that does not sync.
- **Released.** When a held row becomes safe to send (no older peer remains,
  or it has gained a dive or site), the device stamps the row and its
  children with a new HLC so the next export carries them, then forgets the
  id. A cloud sync releases before it publishes. A nearby session with a
  peer that keeps such media releases before it compares watermarks, so a
  library that syncs only nearby sends them too.
- **Remote deletes.** While a row is held, a delete of the row or one of its
  children is applied only when the delete's clock names a device known to
  run this schema or later: its manifest in this pull, or its hello in a
  nearby session. That is a delete the diver made. A delete from an older
  device (its cascade or sweep), or from a device not known, is not applied.
- **Resumed bases.** An interrupted base export records whether it held
  media back. One that did not is made again when the publish must hold;
  one that did is resumed once nothing is held, and the release sends what
  it left out.

### 5. The site as location

`mediaLocation()` gains the media row's own site: its own GPS, then the dive's
site, then the dive's entry position, then the row's own site. Every caller
that builds a location for identification passes it. A changed location
already makes a stored result stale through its region cell
(`media_identification_readiness.dart`), so placing media on a site names it
again without new code.

### 6. Tags when media moves onto a dive

Inside `reassignMediaToDive`'s transaction, for each tag on the moved media:

- A confirmed or hand tag links to the new dive's sighting of that species,
  found or created (the rule `tagPhoto` follows).
- An unconfirmed app tag links to the new dive's sighting if the diver logged
  one; otherwise its sighting link is cleared, so confirming it later creates
  the sighting on the new dive.
- Sightings on the old dive stay, as untagging never removes a sighting.

This applies to every move onto a dive, not only media that had no place.

## Edge cases to cover

- 200 clips in the Identify viewer: the service's existing queue; memory as
  for browsing 200 library items.
- A large video in scratch mode: analysis streams from the file; the
  temporary folder holds only crops.
- A file already in the library opened in Identify: still a scratch item.
  *Builder's call whether Keep applies the import's duplicate check.*
- The pack removed, or identification turned off, while the viewer or camera
  is open: the overlays already handle it; the camera stops live naming.
- Camera permission denied: the screen says so and offers the file picker.
- A single-device library: no older peers, nothing is held.
- A library whose older device is retired: no longer a peer, held rows
  release.

## Left to the builder

- How the scratch providers are scoped (a nested `ProviderScope` with
  `dependencies`, or a child container), as long as no scratch read or write
  reaches the real database.
- In-memory implementations of the stores: subclasses, or interfaces pulled
  out of the current classes.
- The held-media table's shape and where the export filter sits, following
  the #2567 pattern.
- Test layout, following TDD: unit tests for the sweep, cascades, location,
  move, export filter and release rules; widget tests for the Identify button,
  scratch viewer banner and Keep sheet, the camera screen's states, and the
  import review actions.
