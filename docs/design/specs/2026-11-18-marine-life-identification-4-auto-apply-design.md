# Marine life identification, piece 4: find species on a dive, auto-apply and review

Issue: #4727. Parent program: #4668.

Program overview, with the decisions that apply to every piece:
[2026-11-17-marine-life-identification-program-design.md](2026-11-17-marine-life-identification-program-design.md).
The photos piece
([piece 1](2026-11-17-marine-life-identification-1-photos-design.md)) and
the video piece
([piece 2](2026-11-17-marine-life-identification-2-video-design.md)) built
everything this piece stands on. Read the overview first; this document does
not repeat its reasoning.

Decisions are marked **(decided)** when the maintainer made them and
**(proposed)** when they are the designer's call, open to correction.

This piece is one pull request **(proposed)**, as pieces 1 and 2 were.

## Why

Today a suggestion becomes a species tag only when the diver taps it, and
the app only looks at a photo or video when the diver opens it in the
viewer. A diver back from a trip with a few hundred photos and clips linked
to their dives is not going to open each one. The program promised three
things for this piece: a setting that tags confident matches with no tap,
a "not yet validated" state on the tags the app applied, and a place to
work through what the app applied.

Recon for this design found two facts that shaped it:

- Analysis runs only on media opened in the viewer. Auto-apply on its own
  would only save one tap on a chip the diver is already looking at.
- The published pack (both detectors, centre crop) has confident bars of
  **never**. Only Megalodon alone, centre crop, has one (0.95, with a usable
  place). A setting keyed on the confident bar applies nothing with today's
  pack.

So the piece is built around the situation the maintainer chose: **a trip's
worth of media, where the diver asks the app to look at a whole dive**
**(decided)**. The review place is useful from day one, because it gathers
the suggestions from media the diver never opened; auto-apply starts working
the day a pack earns a confident bar, with no app release.

## What the diver gets

1. **Find species in photos**, an action on a dive. The app analyses every
   photo and video linked to the dive, one at a time, with progress and a
   way to cancel.
2. **Species to review**, a page listing, for a dive or the whole log, the
   species the app tagged on its own and the species it only suggests, each
   with its crop. The diver confirms, removes or adds from there and saves
   once.
3. **A setting** that tags confident matches with no tap. Those tags are
   marked as not yet confirmed until the diver confirms them, on every
   device the log syncs to.
4. **A second setting** choosing when such a tag logs its sighting on the
   dive: when the diver confirms it (the default), or straight away.

## Goals

- Look at a whole dive's media on the diver's request, with no need to open
  each item.
- Gather everything the app found on a dive (or across the log) in one place
  where the diver can settle it quickly, at the level of a species on a dive.
- Let confident matches enter the log with no tap, always distinguishable
  from the diver's own entries, on every device.
- Keep counts, firsts and statistics, which read sightings, free of the
  app's unconfirmed guesses unless the diver chooses otherwise.
- Every app write and every review save is one History entry the diver can
  revert.

## Non-goals

- Analysing media nobody asked for. Nothing runs on import or in the
  background **(decided)**.
- A run for a trip, a site, or the whole log. One dive at a time
  **(proposed)**; a trip run can follow.
- People, and the general Guided Media Tagging queue of media to work
  through. The review page covers species only.
- A new or lower bar for applying. Auto-apply uses the pack's confident bar
  and nothing lower **(decided)**.
- Syncing identifications, crops or embeddings. Unchanged from piece 1.
- Analysis, Find species and auto-apply on Android, Windows, Linux and the
  web. Those follow `marineLifeIdEnabled`, which is on for iPhone, iPad and
  Mac only. The mark on a tag, Confirm, Remove and the review page are not
  limited this way (see "Every device").

## Anti-goals

- A tag the app applied that looks like the diver's own anywhere it is
  marked: on this device, on another device, or after an older app version
  has synced it.
- A wrong guess left behind as a sighting, or as a species in the diver's
  list, after the diver rejected the tag.
- A run that keeps a copy of the diver's videos or photos. Only crops are
  kept, as before.
- A long run that silently drains the battery or overheats the device.

## Decisions taken in the design conversation

| Question | Decision |
| --- | --- |
| What situation the setting serves | A trip's worth of media; the diver starts the analysis for a dive **(decided)** |
| Automatic on import? | No; the diver starts it **(decided)** |
| Which suggestions are applied | Only those passing the pack's confident bar; no separate lower bar **(decided)** |
| While the pack's bar is never | The setting is shown disabled, with a line explaining why **(decided)** |
| Sightings for applied tags | Logged only once the diver confirms, by default; an option logs them straight away **(decided)** |
| Rejecting a tag whose sighting was logged straight away | Removes the sighting too, under three guards (below) **(decided)** |
| Where the review place is | One page, opened from the dive's Marine life card and from a log-wide banner on the Species page **(decided)** |
| What the review page lists | One row per species per dive: the app's unconfirmed tags, then suggestions **(decided)** |
| Find species on a locked dive | Allowed **(decided)** |
| Undo | The review page holds changes until its own Save; each automatic apply is one History entry **(decided)** |
| Sync | The new tag columns sync; the compatibility floor rises to this schema version **(decided)** |
| Media not on this device | The run fetches everything, videos included **(decided)** |
| Build approach | Build on `MediaIdentificationService` (approach A below) **(decided)** |
| Where the mark, Confirm, Remove and the review page work | Everywhere tags show, on every platform, whether or not the feature runs there **(decided)** |
| A species tagged on some of a dive's media and only suggested on others | One row under "Tagged by the app"; Confirm covers all of it, Remove dismisses all of it **(decided)** |
| A video fish the app tagged, not yet confirmed | Outlined pill (the app's confident name) until confirmed, then filled **(decided)** |
| A species the app created for a tag the diver rejects | Removed with the tag, under guards like the sighting's **(decided)** |

## Approaches

Three ways of building it were weighed.

**A. Build on the existing identification service (chosen).** The run feeds
the dive's media into the queue the viewer already uses, behind anything
the viewer asks for. Skipping, renaming and reconciling stay where they
are, the engine runs one item at a time and the models load once.
Auto-apply is a small pure rule beside the reconcile rules, run after each
item is stored or found to need nothing. The two marks are columns on the
tag table. The review page is one page with a scope. Cost: it changes the
service that live naming (#4715, merged) and naming levels (#4723, open)
also change, so merges need care.

**B. A separate pipeline for the run.** A worker of its own that loads the
models and walks the dive's media start to finish. Easier to read alone,
but two users of one engine would load the models twice or contend for
them, on phones where memory was the measured risk, and the skip, rename
and reconcile rules would be duplicated.

**C. A side table for the marks** instead of columns on the tag. It leaves
`media_species` untouched, but a new synced table needs its own sync
registration, tombstones and ordering against the tag, and a mark that is
lost or arrives late silently turns the app's guess into the diver's entry.
Rejected.

## What the diver sees

### Every device

**(decided)** A tag the app applied syncs to every device the log reaches:
Android, Windows, Linux, the web, iPhones and iPads under the 8 GB floor,
and Macs that never downloaded a model. On all of them:

- the tag carries its "not yet confirmed" look wherever this piece marks
  it (the viewer's chip row and species sheet, the video labels);
- Confirm and Remove work, with the sighting and species guards;
- the dive's Marine life card shows "N species to review", and the Species
  page shows its banner, whenever unconfirmed tags exist;
- Species to review opens and lists the unconfirmed tags, with each media
  item's thumbnail where the device holds no crop.

Only these need the feature (`marineLifeIdEnabled`) and an installed pack:
Find species, analysis in the viewer, suggestions, and the two settings.
Where the feature is off, the review page has no Suggested section.

So the tag work lives in the shared media code, not behind the species_id
feature gate: the columns, confirming and removing with the guards
(`SpeciesTaggingService` in `lib/features/media/data/services/`), the
chip and sheet looks (`lib/features/media/presentation/widgets/`), and the
review page's route, which is not in `webUnavailableRoutePrefixes`. The
page may live in `lib/features/species_id/presentation/` as long as
nothing on its tag path reads `marineLifeIdEnabled` or the pack
**(proposed)**.

### Settings

The **Marine life identification** page gains two rows under "Identify fish
when I open a photo or video" **(proposed wording)**:

```
  Identify fish when I open a photo or video     ( on )

  Tag confident matches automatically            ( off )
    The app adds a species tag when it is sure of a match.
    You confirm each one in Species to review.

  Log sightings for these tags
    (•) When I confirm the tag
    ( ) Straight away
```

- **Tag confident matches automatically** is off by default **(proposed;
  the program said so)**.
- While the installed pack's confident bar is never, both with and without
  a place, the switch is shown off and disabled, with this line in place of
  its description: "The installed model isn't yet sure enough of any species
  to tag on its own. Suggestions still appear for you to add."
  **(decided: shown disabled; proposed: wording)**. A pack with a bar only
  for photos with a place (Megalodon alone today) enables the switch, and
  the description adds "Only for photos and videos with a location."
  **(proposed)**.
- With no pack installed, the two rows are hidden, as the page's other
  model-dependent rows are **(proposed)**.
- **Log sightings for these tags** is enabled only while the switch above
  is on. Default "When I confirm the tag" **(decided)**.
- Both are per-device preferences in `SettingsKeys`, like the identify
  toggle **(proposed)**. Analysis and applying happen on a device, and a
  diver may want auto-apply on a Mac and not on a phone.
- The identify toggle keeps its meaning: whether opening media in the
  viewer analyses it. It does not stop a Find species run, which the diver
  asked for explicitly **(proposed)**.

### The dive page: the Marine life card

Today the card is hidden when the dive has no sightings. It now also shows
when the dive has an unconfirmed tag on its media (every device), or when
the feature is on, a pack is installed and the dive has at least one linked
photo or video **(proposed)**. With no sightings it shows only the lines
below.

```
Marine life                                         3 species
  ( Queen Parrotfish )  ( Blue Tang )  ( Rock Beauty )
  ─────────────────────────────────────────────────────
  [ Find species in photos ]
  5 species to review                                       >
```

- **Find species in photos** starts a run for this dive. It shows only
  where the feature is on and a pack is installed. It shows on the locked
  page **(decided)** and not while the page is unlocked, where the card is
  in its edit state **(proposed)**.
- While a run is going, the button becomes a line with progress and a
  Cancel: "Finding species: 12 of 49" **(proposed)**.
- When the dive's media has all been analysed with the installed pack and
  nothing is left to review, the button reads "All photos checked"
  disabled, so the diver knows a run would do nothing **(proposed)**.
- **N species to review** shows when the dive has any unconfirmed app tag
  or any suggestion. It opens Species to review for this dive. Shown on the
  locked page only **(proposed)**.

### Starting a run

- If any of the dive's media has no readable file on this device, the
  start asks first: "17 photos and 3 videos aren't on this device. Finding
  species will download them." with **Download and find** and **Cancel**
  **(decided: fetch everything; proposed: ask first, wording)**. The count
  checks each item on the device, not the network: a file it names that
  does not open, or a photo library item whose original the library holds
  only in iCloud (asked of the library, through photo_manager's
  `isLocallyAvailable`) **(decided 2026-11-19: count library items
  exactly, after review found the approximate count let a run download
  iCloud-only originals unannounced)**.
- With nothing to download, the run starts at once.

### During a run

- Items are taken one at a time, photos before videos, each in the dive's
  media order **(proposed: photos first, so the quick results arrive
  first)**.
- An item already analysed with the installed pack is not analysed again,
  but auto-apply is still considered for it (see "Applying").
- A photo or video the diver opens in the viewer during the run goes first;
  the run then carries on.
- The run keeps going while the diver uses the rest of the app. One run at
  a time: starting Find species on another dive while one runs queues it
  after the current one **(proposed)**.
- When the app goes to the background the run pauses after the item (or
  video chunk) in progress, and resumes when the app comes back
  **(proposed; iOS does not allow this work in the background anyway)**.
- When the device is too hot (the engine's existing `tooHot` refusal), the
  run pauses and the card says "Paused: device too warm" with Resume
  **(proposed)**.
- Cancel stops after the item in progress. Everything analysed so far is
  kept. Starting again picks up where it stopped, since analysed items are
  skipped.
- When the app is closed mid-run, nothing restarts on its own; Find
  species again resumes in the same way.

### When a run ends

A snackbar, and the card's line, summarise it **(proposed wording)**:

- "Checked 46 photos and 3 videos. Tagged 2 species; 5 to review."
- When some items could not be read (gone, unreachable, failed to
  download): "... 4 could not be opened."

### Species to review

One page, two scopes **(decided)**:

- **This dive**, opened from the dive's Marine life card. Title "Species to
  review" with the dive's number and site as a subtitle.
- **The whole log**, opened from a banner at the top of the Species page:
  "12 species to review" with an arrow. The page groups rows by dive, newest
  dive first, then a **Site photos** group for media with a site and no
  dive, then **Other photos** for media with neither **(proposed)**. The
  banner is hidden when the count is zero.

Rows, one per species per dive (or group) **(decided)**:

```
Species to review                     Cancel        Save
Dive 42, Punta Sur

  Tagged by the app, not yet confirmed
  [crop] Queen Parrotfish    96%   on 3 photos   [ Confirm ] [ Remove ]
  [crop] Rock Beauty         97%   on 1 video    [ Confirm ] [ Remove ]
                                                 [ Confirm all ]
  Suggested
  [crop] Blue Tang           71%   on 2 photos   [ Add ]     [ x ]
  [crop] Sergeant Major      66%   on 1 photo    [ Add ]     [ x ]
```

- **The crop** is the best crop this device holds for that species on that
  dive. Where this device has none (the tag arrived by sync, or crops were
  cleared), the row shows the photo's or video's thumbnail instead
  **(decided)**. The score is shown only when there is an identification
  on this device.
- **A species both tagged and suggested** on the same dive (the app was
  confident on some media and less sure on others, the common case) is one
  row, under "Tagged by the app", reading "on 5 photos (2 tagged, 3
  suggested)" **(decided)**. It counts as one species to review.
- **Confirm** marks every unconfirmed tag of that species on the dive's
  media as confirmed, and adds the species, as a confirmed tag, to every
  media item in the row where it was only suggested **(decided)**. With
  "When I confirm the tag", it also logs the dive's sighting of the
  species, finding an existing one or creating one, exactly as tagging by
  hand does.
- **Remove** removes every unconfirmed tag of that species on the dive's
  media and dismisses the row's suggestions **(decided)**. The
  identifications behind the tags become rejected by the existing
  reconcile rule, so the species is not suggested or applied again on that
  media. A sighting logged straight away, or a species the app created,
  goes with it under the guards in "Sightings and species".
- **Confirm all** confirms every unconfirmed row in the section.
- **Add** tags every media item whose suggestion is that species, as the
  species sheet's Add does today, but as a confirmed tag: the diver chose
  it **(proposed)**. On a dive photo this logs the sighting, as today.
- **x** dismisses the suggestion on every media item it covers.
- **Tapping a row** expands it to one line per photo or video, each with
  its own crop (or thumbnail) and its own Confirm/Remove (a tagged item) or
  Add/x (a suggested one), so one wrong photo can be removed and the rest
  confirmed **(decided)**. The row's buttons then apply to the lines not
  yet settled.
- **Tapping a crop or thumbnail** opens that photo or video in the viewer.
  With unsaved changes on the page, the page asks to save or discard first
  **(proposed)**.
- A row a decision has settled moves out of its section in place, with a
  short line ("Confirmed", "Removed", "Added", "Dismissed") until Save, so
  the diver sees what Save will do **(proposed)**.

Saving **(decided)**:

- Every action on the page is held until **Save**. **Cancel** discards
  them. Leaving with unsaved changes asks first, with the shared discard
  dialog. No unlock is needed: the page is a deliberate mode with its own
  Save, like bulk edit.
- Save writes everything as one History entry.

What it reads:

- Unconfirmed tags: `media_species` rows marked unconfirmed, for the media
  in scope.
- Suggestions: the same rule as the viewer's chip row today
  (`groupSuggestions`): suggestable, undecided identifications whose top
  species is not already tagged on that media item, with the naming level
  in force (#4723) applied where that has merged.
- Media in scope: for a dive, the dive's media; for the log, every media
  item with an unconfirmed tag or a suggestion.

### The viewer

The viewer must not show an app-applied tag as the diver's own
**(follows from the anti-goal; proposed look)**:

- In the chip row, an unconfirmed tag chip is drawn like a tagged chip with
  a dashed outline and a small "unconfirmed" glyph, after the confirmed
  tags and before the suggestions.
- In the species sheet, the "Tagged on this photo" section lists
  unconfirmed tags first, each with **Confirm** beside the existing
  remove control. Confirm and remove there go through the photo's sitting,
  like every other change in the sheet.
- On a locked photo the chip shows and does nothing, as suggested chips
  do today.
- These looks show on every device (see "Every device").

### Video labels

**(decided)** A fish the app tagged and the diver has not confirmed keeps
the **outlined** pill, which piece 2 defines as the app's confident name,
playing and paused. It turns **filled** ("the diver tagged it") once the
tag is confirmed.

This is a change to the label rule in
`lib/features/species_id/domain/services/track_labels.dart`, not to the
playback layer: an accepted track whose tag on the video is unconfirmed
gets `TrackLabelKind.confident` instead of `accepted`. The label layer
needs the video's unconfirmed species alongside the tags it already reads,
including the in-memory reconcile it runs while a sitting holds tags. Live
naming (#4715) shipped this file; the change is small and is coordinated
through the program's lead session.

Elsewhere tags are read without a mark: the media library's species
filter and tile markers, the species page's photos, global search, the
query language and agent access treat an unconfirmed tag as a tag
**(proposed)**. Sightings, which drive counts, firsts and statistics, are
where the default keeps the app's guesses out.

## Applying

### The rule

A pure function beside `reconcileDecisions` in
`lib/features/species_id/domain/services/identification_rules.dart`
**(proposed name: `identificationsToApply`)**. Given a media item's
identifications and its current tags, it returns the species to tag, each
with the identifications it covers:

- Only **undecided** identifications. Accepted and rejected ones are never
  reconsidered, so a species the diver removed is never applied again on
  that item.
- Only identifications whose stored `confident` flag is true. The flag is
  written when a crop or track is named (`namingFlags`, video piece
  section 3). Naming levels (#4723) move only the suggest bars, so they do
  not change what is applied.
- **Depends on #4726 (closes #4725).** `namingFlags` on main compares
  against `confidentScore` alone, for photos and tracks alike. That PR
  makes it use `confidentScoreNoLocation` when candidates were not limited
  by place. Without it a pack with a bar only for located media (Megalodon
  alone) would apply on photos with no place. This piece merges after it,
  or carries the same fix if it has not landed. Stored rows need no
  re-flagging: no published pack has had a reachable confident bar, so no
  stored row is confident today.
- On a video, only tracks: the same nameable-track restriction the video
  reconcile uses.
- **On a video, only once its scan is complete (proposed, the designer's
  call).** A video scan stores after every chunk, a scan from the viewer
  often covers only what the diver watched, and live naming renames a
  fish when it gets a clearly better view. Applying after the first chunk
  would fix an early, worse name in the log. So a video is applied to only
  when its whole length has been scanned. A run always scans its videos to
  the end; a video watched in part in the viewer is applied when its scan
  completes, on a later visit or by a run.
- Grouped by the top candidate's species, skipping any species already
  tagged on the item (matched by `candidateMatches`).

### When it runs

**(proposed)** After any of these, for the item concerned, when the setting
is on and the feature is enabled:

1. An analysis or a renaming of the item is stored (viewer or run).
2. A run reaches an item that needs no analysis. This is what applies
   media analysed before the setting was turned on, or renamed by a newer
   pack that earned a confident bar.
3. The viewer opens an item that needs no analysis (the same case, from
   the viewer).

It writes nothing when the rule returns nothing.

### How it writes

- Each species is resolved to a species row by `SuggestionAcceptor`, as
  Add does today. When that creates a new species of the diver's own (the
  candidate is not in the catalogue and no species has its scientific
  name), the tag records that it created it.
- The tag is written through `SpeciesTaggingService`, with the tag marked
  unconfirmed. With "When I confirm the tag", it links to the dive's
  existing sighting of that species when there is one and otherwise
  carries no sighting. With "Straight away", it finds or creates the
  sighting as a hand tag does, and records on the tag whether it created
  it.
- The existing reconcile then accepts the identifications, as it does for
  any tag change, so the chip row and suggestions update.
- An item whose sitting is open in the viewer (unified editing, unlocked)
  is not applied to while the sitting lasts; it is considered again the
  next time it is opened or reached by a run **(proposed; the builder
  checks how a sitting's Save treats a tag written underneath it)**.

### History

- Applying from the viewer is one automatic History entry per item,
  labelled "Marine life identification" **(decided)**.
- A run's applying is **one** History entry for the whole run
  **(decided)**. `ChangeLogScope.automatic` labels everything written
  inside its zone, including a save the diver makes meanwhile, so the run
  must not hold a scope open for minutes. The builder chooses how: for
  example, collecting the run's tag writes and writing them in one short
  scope when the run ends or is cancelled, or adding a way to file short
  writes under one operation id. Reverting that entry removes the run's
  tags and any sightings it created with them.
- A new label in `ChangeLogLabels` (`marine_life_id`), shown translated on
  the History page, in all 11 languages.
- The review page's Save is one manual History entry with its own label
  (`species_review`) **(proposed)**.

## Sightings and species

### Sightings

**(decided)**

- **When I confirm the tag (default).** An unconfirmed tag carries no
  sighting of its own. If the dive already has a sighting of that species,
  the tag links to it, which adds nothing to the log. On confirm, the
  sighting is found or created exactly as a hand tag does, and the tag is
  linked to it.
- **Straight away.** The tag finds or creates the dive's sighting at once.
  If it created it, the tag records that.
- **Rejecting** (Remove on the review page, or removing the tag in the
  viewer's sheet) an unconfirmed tag that created its sighting also removes
  that sighting, only when all three hold:
  1. the tag created it (not one the diver had already logged, which the
     tag merely linked to);
  2. no other tag on the dive's media still points at it, confirmed or not;
  3. the diver has not changed it: count, abundance and notes are still
     what the app wrote (count 1, abundance null, notes empty).
  Otherwise the sighting stays, as today.
- Once a tag is confirmed it is the diver's own; removing it later follows
  today's rule and never removes a sighting **(proposed)**. Confirming
  therefore clears the "created its sighting" mark.
- A tag on media with no dive (site photos) never has a sighting, as
  today.

### Species the app created

**(decided)** The pack names thousands of species the built-in catalogue
lacks, so auto-apply will often create a species of the diver's own (a
synced row) to tag with. Rejecting an unconfirmed tag that created its
species also removes that species, after any sighting it takes with it,
only when all three hold:

1. the tag created it (`SuggestionAcceptor` made it for this tag, rather
   than finding the catalogue species or an existing one with the same
   scientific name);
2. nothing else uses it: no other tag on any media, no sighting, no site
   species entry, and no other row that references a species. The builder
   lists every foreign key to `species` and checks each;
3. the diver has not changed it: its names, category and description are
   still what the app wrote.

Otherwise the species stays. Confirming clears the "created its species"
mark, and a confirmed tag's species is the diver's own from then on. A
History revert of the applying entry removes the species with the tag, as
any revert of an insert does.

## Storage

### Main database, schema version 378

Main is at 377. If another piece takes 378 first, this one takes the next
number when it merges main.

Three columns on **`media_species`**, all nullable, in
`lib/core/database/tables/media_tables.dart` **(proposed names)**:

| Column | Meaning |
| --- | --- |
| `unconfirmed` | 1 while the app applied the tag and the diver has not confirmed it; null otherwise |
| `created_sighting` | 1 when the app's tag created its sighting (Straight away); null otherwise. Cleared on confirm |
| `created_species` | 1 when the app created the tag's species for it; null otherwise. Cleared on confirm |

- **Null means the diver's own tag.** Every tag that exists today is one,
  so no backfill is needed, and a peer that omits the columns can only
  ever make a tag look like the diver's, never the reverse. The dangerous
  failure is losing the mark; the compatibility floor below guards it.
- The row is no longer write-once: confirming updates it. Update the
  table's doc comment, which says it is write-once.
- Integer column names avoid the endings the demo date-shift guard treats
  as dates.
- Register per `docs/developer/database.md`: the migration rung in
  `lib/core/database/migrations/`, column backstops (not in
  `before_open.dart`), and the generated SQL column notes
  (`dart run tool/generate_sql_column_notes.dart`).

No change to the identification tables or the local cache.

### Sync

**(decided: the columns sync and the floor rises; proposed: the
mechanics)**

- `media_species` is in `clockGuardedEntities`: exported by its own `hlc`,
  merged as a blind upsert that skips a remote copy strictly older than
  local. Confirming, and any other update to the row, stamps its clock
  through the sync repository's pending mark, so the change reaches peers
  and wins over older copies. Removing a tag deletes the row as today, with
  a tombstone carrying the delete's clock.
- One device confirms while another removes: the later action wins, by the
  row's clock against the tombstone's.
- The export already serialises whole rows (`toJson`), so the new columns
  travel with the tag. Check that the merge writes them, including an
  explicit null (confirming clears both).
- **Compatibility floor.** `AppDatabase.minimumCompatibleSchemaVersion`
  rises to 378, with a comment in the style of the abundance raise
  (#4337): a peer below 378 stores an app-applied tag as a plain tag; once
  it updates, the columns are null there, and its next full publish sends
  them as explicit nulls, which the merge applies as real values, silently
  confirming the app's tags on every device. Peers below 378 are held until
  they update; their own payloads still decode, a missing column being
  null.
- Identifications, crops and embeddings still do not sync. On another
  device the review page shows unconfirmed tags with the media thumbnail
  and no score, and no suggestions unless that device analysed the media.
- A sighting created straight away, or a species the app created, later
  removed under the guards is an ordinary delete, synced as today.
- Guards are checked on the device where the diver rejects the tag,
  against what that device holds. A peer that later brings a new
  reference (another device tagged the same species meanwhile) revives
  nothing: the delete and the new row meet in the merge as any delete and
  edit do today **(proposed; the builder confirms the species delete path
  behaves as the sighting one does)**.

## The run

### Where it lives

**(proposed)** A `DiveSpeciesRun` controller in
`lib/features/species_id/data/services/`, owned by a provider that lives
for the app session, so that leaving the dive page does not stop it.

- It lists the dive's media (`mediaForDiveProvider` or the repository
  behind it), keeps photos and videos, and orders them as above.
- It asks `MediaIdentificationService` for each item in turn through a new
  run lane: a request that is not tied to a screen, waits behind every
  viewer request, and is never dropped by `cancelPending` from the viewer.
- It passes each item's location the way the viewer does
  (`_photoLocation` in `media_viewer_actions.dart`: the item's own
  position, else the dive's site, else the dive's entry position). Move
  that helper somewhere both can call.
- It reports progress (items done of items total, with a video counting
  by its own scan progress) and the final summary.
- It stops between items or chunks on cancel, backgrounding and heat, as
  above.

### Reaching media not on this device

**(decided: fetch everything)**

- **Photos:** resolved as the viewer resolves them today (`_imageOf`: a
  readable local file, else `mediaBytesProvider`, which can fetch from the
  photo library or the media store).
- **Videos:** a run has no player, and `videoFileReaderProvider` today
  answers only for the playback the on-screen player holds, by design ("a
  scan downloads nothing"). The run needs its own resolver that gets a
  file the way playing the video would (`resolvedFilePathProvider`), with
  the bookmark access the scan already uses. Leave the viewer's resolver as
  it is: opening a video in the viewer still downloads nothing for a scan.
- Whatever the resolver downloads lands where playing the media would put
  it and follows that cache's existing rules; the run keeps no copy of its
  own **(proposed)**. Only crops are kept, as before.
- An item that cannot be resolved is counted as "could not be opened" and
  is tried again by the next run.

This is the one place this piece touches the media layer. It does not
touch the video playback layer that live naming owns: a run's video scan
has no playhead, and the live naming scan order already scans from the
start when no playhead is reported.

### The service

- A new lane in `MediaIdentificationService`'s queue for run requests,
  served only when no viewer request is waiting.
- The service's enable gate today is `marineLifeIdEnabled &&
  identifyFishOnOpen`. Split it so a run request is served whenever the
  feature is enabled and a pack is installed, whatever the identify
  toggle says.
- After storing an analysis or renaming, or finding an item needs nothing,
  the service calls the applier (above) for that item.

## Edge cases

- **The setting is on but the pack's bar is never.** Nothing is applied.
  The setting row says why. The run and review still work for
  suggestions.
- **The pack is updated to one with a confident bar.** Media named by the
  old pack is renamed the next time it is opened or reached by a run, gets
  its `confident` flags, and is applied then.
- **The pack is removed.** No analysis; stored identifications keep their
  flags. Auto-apply still considers stored rows the next time an item is
  opened or reached by a run, since its rule reads only stored flags
  **(proposed)**.
- **The diver tags the same species by hand on a photo the app already
  tagged.** The tag already exists; the species picker shows it as tagged.
  The sheet's Confirm is the way to make it the diver's own.
- **The diver removes a tag in the viewer that was unconfirmed.** Same as
  Remove on the review page: identifications rejected, sighting and
  species removed under their guards.
- **A photo moves to another dive, or loses its dive.** Its unconfirmed
  tags move with it. A sighting created straight away stays on the old
  dive, as a hand tag's would.
- **A sighting created straight away, then the diver edits its count.**
  Guard 3 fails; rejecting the tag keeps the sighting.
- **The app created a species, and the diver later tags it by hand on
  another photo.** Guard 2 fails; rejecting the app's tag keeps the
  species.
- **A device without the feature receives an app-applied tag.** It shows
  the unconfirmed look, lists it on the review page with the media
  thumbnail, and can confirm or remove it, guards included. It offers no
  Find species and no suggestions.
- **A video watched halfway in the viewer, with the setting on.** Its
  confident tracks are not applied until its scan has covered the whole
  video; the suggestions show meanwhile.
- **Two photos on the dive tagged with the same species straight away.**
  The first creates the sighting, the second links to it. Removing the
  first while the second still points at it keeps the sighting (guard 2).
  The second records that it did not create it.
- **A dive is deleted while its run is going.** The run stops; the items'
  identifications are cleaned up by piece 1's existing cleanup.
- **Another logbook is opened mid-run.** The service already drops
  results for the logbook it started in; the run stops.
- **The demo logbook.** Its own database; nothing crosses.
- **An older app version syncing.** Held by the raised floor until it
  updates.

## Out of scope

- Runs for a trip, a site or the whole log.
- Analysing on import or in the background.
- Android, Windows and Linux engines (piece 3).
- Changing the bars, the naming levels or the pack.
- Marking unconfirmed tags in the media library, search, the query
  language or agent access.
- User documentation beyond the developer page.

## Testing

**(proposed)**

- Pure rules: `identificationsToApply` (undecided only, confident only,
  tracks only on video, complete scans only on video, grouped by species,
  skips tagged); the sighting
  guards and the species guards, each guard failing alone; the track label
  rule giving an unconfirmed accepted track the outlined kind.
- Every device: the chip, sheet, card, banner and review page work with
  `marineLifeIdEnabled` false and no pack, showing thumbnails and no
  Suggested section.
- Mixed rows: a species tagged on some media and suggested on others is
  one row; Confirm tags the suggested media; Remove dismisses them.
- Repository and migration: the rung, the backstops, the new columns
  written and read, confirm clearing both.
- Sync: export and merge of the new columns, including an explicit null;
  a confirm on one device reaching another; the later of confirm and
  remove winning; the floor value.
- Service: the run lane waits behind viewer requests and is not dropped by
  `cancelPending`; the split enable gate; the applier called after store,
  rename and "needs nothing".
- Run controller: order, skip of analysed items, cancel, pause and resume,
  summary counts, an unreadable item counted.
- History: one entry per viewer apply, one per run, a diver save during a
  run not filed under the run.
- Widgets: settings rows (hidden, disabled with the never line, enabled
  with the place-only note), the dive card's states, the review page
  (sections, expand, Save and Cancel, leave check, thumbnail fallback),
  the Species page banner, the viewer's unconfirmed chip and the sheet's
  Confirm.
- Hand check on a Mac and the iOS Simulator with a real pack and a dive of
  real media, including media not on the device. No automated test runs
  the real models.

## Left to the builder

- Column and class names marked proposed.
- How the run files its tag writes under one History entry without
  labelling the diver's own saves.
- How the run resolves a video file without a player, within the rule
  that the viewer's own resolver stays as it is.
- How a sitting's Save treats a tag written underneath it, and therefore
  whether skipping items with an open sitting is needed.
- The "not on this device" count before a run (since decided: library
  items are asked of the library).
- Exact copy, in all 11 languages.
- The full list of foreign keys to `species` for the species guard.
