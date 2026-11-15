# Site catalogue: fill gaps in existing sites (slice 4)

Date: 2026-11-14
Status: approved 2026-11-14
Program: `2026-11-13-site-catalogue-program.md`
Issue: #4514

## Intent

Slices 1 and 2 made a newly adopted site arrive complete: a diver who picks
a built-in site gets its position, depth, type, entry and description, and
the site keeps a link to its catalogue record. A site the diver already had
gets none of that. It was typed by hand, imported from another logbook, or
adopted before slice 1 stored a link, and it stays as bare as the day it
was made, even when the catalogue holds the same place in full.

This slice gives existing sites the same benefit. The app pairs the diver's
sites with catalogue records, shows the pairs in a list the diver reviews,
and on their say-so links each site and fills the fields the site has
empty. It never changes a value the diver holds.

**What today's data can give.** Measured on the shipped catalogue (20,931
records): of the 3,931 dive site records, 1,733 carry anything beyond a
name and a place (depth on 680, a site type on 1,171, entry on 370, a
description on 427, no difficulty at all). The 17,000 wreck and reef
records are richer: 15,329 carry a depth or a description. So today a pair
mostly gives a link, a position for a site that has none, and sometimes a
depth and a type. Slice 3 adds researched details to dive site records, and
this slice is what delivers them to sites the diver already has. The
lasting case is therefore "a record my site is linked to has gained
details", not only the one-off catch-up.

Terms. A **pair** is one of the diver's sites with the one catalogue record
the app believes is the same place. An **offer** is what a pair would
change: the link, if the site has none, and the record's values for fields
the site has empty. A site is **linked** when `dive_sites.catalogue_id` is
set.

## What was decided

Chosen by the maintainer on 2026-11-14.

- **Which pairs are listed.** Three kinds:
  1. Same name and within 150 m: listed ticked.
  2. Same name, and the diver's site has no position: listed un-ticked; the
     record's position is part of the offer.
  3. Within 150 m under a different name (the diver's "Thistlegorm", the
     catalogue's "SS Thistlegorm"): listed un-ticked.
  Loosely similar names further away are not paired.
- **Nothing is written silently.** Links and details are written only when
  the diver applies the list. There is no background linking pass, not even
  for sites that are an exact twin of a record.
- **Three ways in.** An entry in the Sites page's overflow menu; a
  dismissible notice on the Sites page when pairs are waiting; a line on a
  paired site's own page.
- **Only empty fields are offered.** Where the site holds a value, the
  record's value is never offered, however different.
- **Granularity.** One tick per site in the list. Opening a row shows the
  site beside the record with a tick per field.
- **Un-ticked rows stay.** Applying acts on ticked rows only. A row leaves
  the list only when it is applied or the diver answers it ("Not the same
  site", "No thanks").
- **An answer is stored with the site and synced,** in one new column that
  follows the path slice 1 built for the link.
- **The merge gap from slice 1 is closed here.** Merging two adopted sites
  kept one link, so the other record was offered again. The new column also
  records the records a site stands for besides its link.
- **Build approach A:** pairing and filling are two small rules of their
  own, read through the catalogue's existing interface (see "Approaches").
- **Shared library sites take part,** when this profile may edit them. A
  library site never enters the personal sync, so its link and its answers
  travel per profile, the way its private notes and rating do (section 6).
- **"Not the same site" does not change the 150 m hide rule.** The record
  stays hidden from the picker's nearby section and the map while the
  diver's unlinked site lies within 150 m, and is reached by its name.

## Goals

1. A diver's sites are paired with catalogue records by the three rules
   above.
2. A review list shows every pair and what applying it would add.
3. Applying a pair links the site and fills only fields that are empty at
   the moment of writing.
4. A site adopted before slice 1 gets its link through the same list.
5. A linked site whose record gains details in a later catalogue is offered
   those details.
6. "Not the same site" and "No thanks" are remembered with the site and
   reach the diver's other devices.
7. A record that a merge folded into another site is no longer offered.
8. The diver can reach the list from the Sites menu, from a notice, and
   from a paired site's page.

## Non-goals

- AI-researched records, their "not verified" mark and its rules (slice 3).
  This slice only fixes one rule for them in advance: a pair with a
  researched record is never ticked for the diver.
- Catalogue site pages and browsing (slice 5).
- Offering a record's value where the site already holds one.
- Pairing by similar names (a new name comparison), or beyond 150 m.
- Removing the boilerplate the old adoption wrote ("Imported from Bundled
  dive site database" in notes, a "Features:" line in the description).
- Copying filled values on to dives already logged at the site.
- Carrying the link or the answers in shared site library documents:
  they are each profile's own (section 6).
- Pairing a library site this profile may not edit, or turning an offer
  into a suggestion to the library's owners.

## Anti-goals

- A value the diver typed, replaced or removed.
- A catalogue position attached to a site without the diver ticking it.
- A notice that keeps coming back after the diver has dealt with it.
- An offer the diver declined, offered again on the same device or another.
- The Sites page waiting on the catalogue to open.

## Constraints

- **Main database.** Schema version 364 when this was written; the
  column shipped as version 369, after main took 365 to 368. Tables in
  `lib/core/database/tables/`, rungs in `lib/core/database/migrations/`;
  nothing is added to `database.dart`. The new column takes the next
  version; renumber at merge time if main has moved. `before_open.dart` is
  at the 800-line guard, so the backstop goes in
  `before_open_child_columns.dart`, where the link's is.
- **File size.** `site_repository_impl.dart` is 2,053 lines and
  `site_list_content.dart` 1,838. New repository code goes in a file of
  its own. The repository has no part files today (`site_links.dart` and
  `site_children.dart` are separate classes), and the apply write needs
  its private members, so the builder picks between the file's first
  `part` and a separate class given what it needs. The notice is a widget
  of its own with a one-line insertion.
- **Units.** Depths and distances shown follow the active diver's unit
  settings.
- **Localisation.** Every new string goes in all 11 ARB files.
- **Guards.** `test/architecture/` and `test/shared/` scan all of `lib/`.
  Known ones that bite here: no buttons or chips in `ListTile.trailing`;
  every new synced column needs a label in the conflict field catalogue; an
  indeterminate spinner hangs consumer tests that `pumpAndSettle`.
- **Sync.** A personal site's row syncs whole, last writer wins. A child
  change must not re-stamp its parent (#1769), but a fill writes site
  columns, so it stamps the site once. A shared library site's row never
  enters the personal sync (`_exportDiveSites` leaves it out, #2567): its
  shared fields travel in the library's documents, and a profile's private
  notes and rating in the synced `library_site_notes` table, copied back
  onto the row by `applyLibrarySiteNotes`.
- **TDD**, platform-agnostic paths, `dart format .`.
- The PR description says `Part of #4514`, and carries before and after
  screenshots.

## Measured facts (2026-11-14)

- Sites adopted before slice 1 were created with the record's exact name
  and position and the note "Imported from Bundled dive site database". In
  the maintainer's local database (21 sites): 11 carry that note, 10 sit on
  the catalogue's exact position under the same name, 1 more lies within
  150 m of a record under a different name, and every site has a position.
- 19,424 of the 20,931 record names are unique worldwide and 20,095 are
  unique within their country.
- 3,697 records have another record within 150 m (672 of them dive site
  records). Position alone often lands on a neighbour; a name tells them
  apart.

## Approaches considered

| | A. Own pairing and fill rules | B. Stretch the GPS matcher | C. Adopt, then merge |
|---|---|---|---|
| How | Two pure rules (which record pairs with a site; what a record would add), fed by the catalogue's `near`, `byId` and one new exact-name read. A review page modelled on the GPS match review page. One column patch writes fields and link together. | Treat each site as a dive position and run `SiteMatchingService`. | Adopt the record as a new site, then run the site merge with its field chooser. |
| For | Each rule is testable alone; the fill rule has the shape `mergeLocationDetails` already has; no existing flow changes behaviour. | Reuses a tested ranker. | Reuses the most screens. |
| Against | New code, though small. | That matcher ignores names, takes its distances from the diver's GPS sensitivity setting, offers the diver's own sites as candidates and creates sites when applied. Most of it would be switched off. | Creates and deletes a site per pair (sync tombstones, change log noise, "after create" rules firing), and the merge chooser lets a record's value replace the diver's. |

**Chosen: A**, by the maintainer.

## Design

### 1. Pairing

A pure function in the dive sites domain decides the pair for one site,
given the candidate records. A service gathers the candidates through the
`SiteCatalogue` interface and runs it over the active diver's sites.

**Which sites take part.** The active diver's sites, less any site of a
shared library this profile may not edit (the rule "Fill in location
details" uses, `LibraryEditStamper.mayEdit`). A library site the profile
may edit takes part like any other; section 6 says how its link and
answers are kept.

**Names are equal** when they match after the picker's folding
(`normalize` in `lib/core/text/fuzzy_match.dart`: case and diacritics),
with punctuation and repeated spaces ignored. "Salt-Pier" equals "salt
pier"; "Thistlegorm" does not equal "SS Thistlegorm".

**Records that are never candidates for a site:**

- a record claimed by any of the diver's sites: its link, or one it stands
  for (section 5);
- a record the site has answered "Not the same site" to;
- a record without a position.

**The rules, in order, for one site:**

1. **Linked.** The site has a link. Its record is its pair, and it appears
   only if the offer (section 2) is not empty. A link to a record the
   catalogue no longer holds gives nothing.
2. **Sure.** The site has a position, and a candidate within 150 m has an
   equal name. Listed ticked.
3. **Nearby.** The site has a position, no candidate within 150 m has an
   equal name, and at least one candidate lies within 150 m. Listed
   un-ticked.
4. **Named.** The site has no position, and exactly one candidate has an
   equal name. When the site has a country (its code, or its country text
   read through `countryCodeFor`), only candidates in that country count;
   otherwise the whole catalogue does. Listed un-ticked. Two or more
   candidates: no pair.

**Choosing among several candidates** (rules 2 and 3): a dive site record
before a register record, then the nearer. This is the preference GPS
matching already applies.

**One record, two sites.** A record is paired with one site per run. Sure
claims are settled first, then nearby, then named; within a kind the
nearer site wins. A site that loses its candidate takes its next one under
the same rules, or none.

**150 m** is the distance the picker and the map already use to hide a
record behind one of the diver's unlinked sites
(`offerableCatalogueSites`). It is one shared constant.

**Never ticked for the diver,** whatever the kind: a pair whose offer
includes a position (so a linked site that has lost or never had its
position is listed un-ticked), and a pair whose record has
`trust == researched` (slice 3).

The interface gains one read: every record whose name is equal to a given
name, optionally within one country. `search` cannot stand in for it: it
matches substrings and stops at 50.

### 2. What a pair offers

A second pure function takes a site, its site type ids and a record, and
returns the offer: the fields below whose condition holds. It has the
shape of `mergeLocationDetails`.

| Field shown | Offered when the site's | Written |
|---|---|---|
| Position | coordinates are missing | `lat`, `lon` |
| Depth | minimum and maximum depth are both missing | `min_depth_m`, `max_depth_m`, whichever the record has |
| Country | country is blank | country and its code, together |
| Region | region is blank | `region` |
| Town | city is blank | `locality` |
| Island | island is blank | `island` |
| Body of water | body of water is blank | the record's, named in the diver's place-name language as adoption does |
| Water type | water type is unset | `water_type` |
| Site types | site has no types | `types` |
| Entry | site has no entry methods | `entry` |
| Difficulty | difficulty is unset | `difficulty` |
| Hazards | hazards is blank | `hazards` |
| Description | description is blank | `description` |

Rules:

- A field the record does not carry is not in the offer.
- **Never offered or written:** name, notes, rating, access notes, parking,
  mooring number, exit methods, and a position when the site has one.
- **Depth is one field.** A site with a maximum and no minimum is not given
  the record's minimum: the two ranges may not belong together.
- **Place fields follow the place.** Position, country, region, town,
  island and body of water are offered only when the site is at the
  record's place: it has no position, or lies within 150 m of the record.
  A linked site the diver has since moved elsewhere is not given the
  record's place names.
- A field the diver declined for this record (section 5) is left out.
- The link is part of every offer for an unlinked site. A pair whose offer
  holds no field is still listed when the site is unlinked: the link is
  what it adds. A linked site with an empty offer is not listed.
- Altitude is not offered. When a position is written, the altitude is
  then filled best-effort from the elevation service after the write
  commits, as GPS matching does.

### 3. The review list

A page at `/sites/catalogue-review`, modelled on the GPS match review page
(`site_match_review_page.dart` and its notifier): it loads the pairs, seeds
the ticks, and applies what is ticked.

```
Built-in details for your sites                  Apply (11)

SAME SITE (11)
[x] Salt Pier
    Adds: link, depth 5-15 m, reef, shore entry        >
[x] Hilma Hooker
    Adds: link, wreck, description                     >

CHECK THESE (3)
[ ] Thistlegorm       40 m from "SS Thistlegorm"
    Adds: link, depth 16-32 m, description             >
[ ] Blue Hole         no position. "Blue Hole", Egypt
    Adds: link, position, country, region              >
```

- **Sections.** "Same site" holds the pairs listed ticked: linked and
  sure pairs. "Check these" holds every pair listed un-ticked: nearby and
  named pairs, any pair whose offer includes a position, and any pair with
  a researched record. An empty section is not shown.
- **A row** shows the site's name; for a nearby pair, the distance and the
  record's name; for a named pair, that the site has no position and the
  record's name and place; then one line listing what it adds. The tick and
  the control that opens the comparison must satisfy the
  `ListTile.trailing` guard.
- **Apply** acts on every ticked row and stays on the page. A message says
  how many sites were linked and how many had details filled. Rows that
  were applied leave; the rest stay.
- **Leaving** the page writes nothing and asks nothing: un-ticked rows are
  still there next time.
- **Nothing to offer:** the page says the diver's sites already carry
  everything the built-in catalogue has for them.
- **Catalogue not loaded yet** (first launch after an update): the page
  shows the empty state and re-reads when the import finishes, as other
  catalogue screens do. No indeterminate spinner.

**The comparison** opens from a row and from a site's page (section 7).

```
Thistlegorm                  SS Thistlegorm (UKHO)
[x] Depth        (empty)     16-32 m
[x] Site type    (empty)     Wreck
[ ] Description  (empty)     Cargo ship, lost 1941
    Name         Thistlegorm          yours stays
    Position     27.8138, 33.9200     yours stays, 40 m apart

[Not the same site]                    [Fill in 2]
```

- One row per offered field with a tick, all ticked to start. Below them,
  the name and, when both have one, the two positions and the distance
  between them, marked as staying the diver's.
- The record's source credit is shown, as the site page shows it for a
  linked site.
- For a named pair the record's position, country and region are shown in
  full, since the position is the thing being trusted.
- **The primary action** applies this pair now: the link and the ticked
  fields. Fields left un-ticked are remembered as declined (section 5).
  With every field un-ticked it links the site and fills nothing.
- **"Not the same site"** (unlinked pair) records the answer and removes
  the row. **"No thanks"** (linked pair) declines every offered field and
  removes the row.
- Opened from the list, ticks changed in the comparison and then closed
  without acting are kept for that row until the page is left: the row's
  tick in the list then applies exactly those fields.

### 4. Applying

One repository write per pair, in the mould of `applyLocationDetails`:

- In one transaction it reads the site row, and writes only the chosen
  columns that are **still empty in that row**, the link if the row still
  has none, the site types if the site still has none, and the answers.
  A value typed between loading the list and applying it is never
  overwritten.
- If the record has meanwhile been claimed by another of the diver's sites,
  the pair is skipped and counted as such.
- The site is stamped and marked for sync once. A library site records
  which fields changed, as `applyLocationDetails` does.
- A list Apply runs inside one `ChangeLogScope.bulk`, so the change log
  shows one bulk edit.
- A failure on one pair is logged and counted; the others still apply. The
  message says how many could not be applied.
- No "after create" logbook rules run: no site is created.
- `updateSite` keeps ignoring the link. Besides this write, a link is set
  on an existing site only by a UDDF import that carries one and by a
  merge whose survivor had none.
- A library site's fill goes the same way; section 6 adds what is kept
  for the profile.

### 5. What is remembered: `dive_sites.catalogue_answers`

A new nullable text column on the site, carried on the `DiveSite` entity
as a small value object with `copyWith`. It holds, as JSON:

| Key | Meaning | Written by |
|---|---|---|
| `also` | Record ids this site stands for besides its link | A merge |
| `not` | Record ids the diver said are not this site | "Not the same site" |
| `declined` | For a record id, the names of offered fields the diver turned down | "No thanks", or a field left un-ticked when a pair is applied |

- The column is null when all three are empty. Text that cannot be read is
  treated as empty and never fails a site read. Keys this build does not
  know are kept when the value is rewritten.
- A declined field stays declined for that record, also when a later
  catalogue changes the record's value for it. Linking the site to a
  different record starts afresh.
- **Claimed records.** `linkedCatalogueIds` returns each site's link and
  its `also` ids. Every reader of that function therefore hides a record a
  merge folded away: the picker's by-area and search sections, the map
  overlay, the import page's "already imported" mark, and GPS matching's
  candidate list. `getSiteByCatalogueId`, which adoption asks before
  creating a site, also answers with a site that stands for the record.
- **Merge.** The survivor keeps its link (or takes the first merged site's,
  as today). Every other link and `also` id among the merged sites joins
  the survivor's `also`. The `not` lists are united, less anything the
  survivor now claims. `declined` is kept for the survivor's link only.
  Undo restores each site's column, through the snapshot entities that
  already restore the link.
- **Sync, backup, export.** The column takes the link's path: a schema
  step with the `beforeOpen` backstop, the row mapper, a label in the
  conflict field catalogue, the sync overlay rule that a peer on an older
  build cannot strip it, a UDDF element beside `catalogueid` with a
  round-trip test. It travels in the database backup. CSV does not carry
  it, and neither do shared site library documents.
- **How the link reaches other devices.** For a personal site, unchanged
  from slice 1: it is an ordinary site column, so a site linked on one
  device arrives linked on the others and its pair disappears from their
  lists. This slice adds only the write that sets it. A library site is
  section 6.

### 6. Shared library sites

A library site's row is outside the personal sync, and the library's
documents are shared by every member. The link and the answers are one
profile's view of the site, so they travel the way that profile's private
notes and rating already do.

- `library_site_notes` gains two nullable columns, `catalogue_id` and
  `catalogue_answers`, in the same schema step as the site's column.
- Wherever this slice writes a library site's link or answers (applying a
  pair, an answer, a merge), it writes them on the site's row on this
  device and also keeps them in the acting profile's `library_site_notes`
  row, creating the row if the profile has none. Personal sync carries
  that row.
- `applyLibrarySiteNotes` copies them onto the row on the profile's other
  devices, as it copies notes and rating. A notes record that holds no
  link or answers never clears the row's. The other way round, a record
  that holds a link or answers and neither notes nor a rating supplies the
  row's notes only where no other record does: a second profile linking a
  site does not blank the notes of the first.
- The fields a fill writes on a library site are shared fields. They are
  stamped for the library as `applyLocationDetails` stamps them and reach
  every member through its documents. Another member whose own site view
  is unlinked still sees a pair for it, now offering the link alone.
- **Claimed records** count a library site's link and `also` ids too. A
  library row has no diver, so `getSiteByCatalogueId` and the pairing
  service must look at the library sites the diver can see as well as
  their own.
- A library pull, a detach into a personal copy and a library restore
  must leave the row's two columns as they leave its notes; the builder
  checks each path.

### 7. Ways in

- **Sites overflow menu.** A new entry beside "Fill in location details",
  in each of the three places that menu is built (`site_list_page.dart`
  and twice in `site_list_content.dart`). It opens the review page.
- **Notice.** One line above the site list when pairs are waiting, with
  the count, a "Review" action that opens the page, and a dismiss control.
  Dismissing remembers, on this device only, the pairs waiting at that
  moment, each as its site, its record and the fields on offer, replacing
  what was remembered before. The notice returns when a pair is waiting
  that is not among them: a new pair, or one whose offer has grown (a
  linked site whose record gained details). It is never shown while a
  site search or filter is active.
- **Site page.** A paired site's header shows one line, beside the
  catalogue credit line: that the built-in catalogue has details for the
  site, or for an unlinked pair that it may hold this site, with a
  "Review" action that opens the comparison for that pair.

All three read one provider that holds the current pairs. It recomputes
when the diver's sites change, when a catalogue import lands
(`siteCatalogueRevisionProvider`) and when the active diver changes. The
Sites page and the site page never wait for it: the notice and the line
appear when it is ready.

### 8. Documentation

- `docs/user/dive-sites.md` gains a section on the review list: what is
  paired, that only empty fields are filled, and what the two answers do.
- The program overview's slice table points at this document.

## Calls the designer made

The maintainer decided the items under "What was decided". Everything else
is the designer's call. The ones most worth checking:

- A named pair needs exactly one candidate, narrowed by the site's country
  when it has one (section 1).
- A dive site record beats a register record, then the nearer wins
  (section 1).
- A record already claimed by one of the diver's sites is never offered to
  another (section 1).
- Linked sites with new details are listed under "Same site", ticked
  (sections 1 and 3).
- Depth is offered only when the site has neither depth (section 2).
- Place fields are offered only at the record's place (section 2).
- The comparison is text only, with no map (section 3).
- Apply stays on the page; leaving never asks (section 3).
- A field left un-ticked in an applied pair is remembered as declined, and
  a declined field stays declined when the record's value later changes
  (sections 3 and 5).
- The notice's dismissal is kept on the device, not synced (section 7).
- The old adoption's boilerplate is left alone, and a description holding
  only a "Features:" line counts as filled (non-goals).
- Filled values are not copied to dives already logged at the site.
- A researched record's pair is never ticked, and neither is any pair
  that would write a position (section 1).
- The notice's memory holds each waiting pair with its offered fields, so
  a grown offer brings the notice back (section 7).
- A library site this profile may not edit is left out, not offered as a
  suggestion to the library's owners (section 1).
- A member of a library sees a link-only pair for a site another member
  already filled (section 6).

## Known gaps after the build

- A site under a different name from its record is paired only when it has
  a position within 150 m. "Thistlegorm" with no position is not paired
  with "SS Thistlegorm".
- A hand-dropped pin more than 150 m from the record is not paired, even
  under the same name.
- Two devices that each answer a different offer for one site before they
  sync: the later write of the column wins, and the other answer is asked
  once more.
- Country names from the catalogue are English, as for an adopted site
  (slice 1's known gap).
- A site adopted before slice 1 keeps its "Imported from" note, and a
  "Features:" line keeps its description from being offered.
- A site with a maximum depth and no minimum is not offered the record's
  minimum.
- After "Not the same site", the record is still hidden from the picker's
  nearby section and the map while the diver's unlinked site lies within
  150 m of it (decided: the hide rule is unchanged). It is found by name.
- On a device with two profiles in one library, a library site's row
  shows the link and answers of whichever profile's record is newest, as
  it does for notes and rating.
- On such a device, a profile that has notes of its own for a library
  site and then links it becomes the newest record, and the row shows
  that profile's notes from then on, as after any edit of theirs. A
  record carries one timestamp for all it holds; telling a catalogue
  write from a notes write would need a second one.

## Rulings made during the build (2026-11-14)

Calls the builder made where the design was silent or the code said
otherwise. Each is the builder's, not the maintainer's.

- **A site with a blank name** (or one of punctuation only) can pair by
  position, as a nearby pair, and never by name.
- **A site whose equal-named record went to a nearer site** gets no pair
  at all in that run. It is not handed a neighbour under another name.
- **A site whose own record another of the diver's sites already has**
  (the diver holds one place twice) gets no pair either, for the same
  reason.
- **A site already linked to a record is filled even when an older site
  holds the same link** (two devices adopted the record before they
  synced). Only a site about to be linked can be beaten to a record.
- **GPS matching still offers a record a merged site stands for** when
  that site is out of range of the dive; choosing it links the dive to
  the site. It is left out only when the site itself is in range.
- **A profile's new record for a library site starts empty** when another
  profile already has one: the row then shows that profile's private
  notes, which are not copied.
- **A search for pairs that a newer one has replaced stops** at its next
  catalogue read, so a burst of site writes costs one full search.
- **The copy-back for library sites never clears.** It takes the newest
  record that holds a link, and separately the newest that holds answers.
  A cleared value cannot be told from one never set, so undoing a merge of
  library sites on one device leaves the merged claims on the profile's
  other device until its next answer there.
- **Apply is a button in a bottom bar,** as on the GPS match review page,
  not an app bar action as sketched. Tapping a row opens its comparison;
  only the checkbox toggles the tick.
- **The "Adds" line** shows short values as themselves (a depth range,
  place names, type and entry names) and names long ones (position,
  hazards, description) by their label.
- **The comparison** shows each field's two values side by side under the
  field's name ("Your site" and "Built-in record"), since three columns do
  not fit a phone.
- **The apply write is its own repository class**
  (`SiteCatalogueFillRepository`), outside the 2,053-line site repository.
- **Record text is trimmed** when written.
- **29 new strings,** fewer than planned: position, depth, site types and
  entry reuse the site editor's labels.

### Added by the second review (2026-11-14)

A second review of the whole branch, at a higher effort, reported 18
findings. All are fixed. The calls it led to:

- **A site with no position needs exactly one namesake among all the
  records of its name,** counted before any is ruled out as taken. When
  that one already belongs to another of the diver's sites, the site gets
  no pair: it is most likely a second copy of that site, and is not handed
  a different place that shares the name.
- **Names are compared with accents removed in either spelling,** as one
  character or as a letter followed by a combining mark.
- **The exact-name read answers every name in one statement**
  (`SiteCatalogue.namedMany`, replacing `named`). The name key is worked
  out inside the query by a registered SQL function,
  `catalogue_name_key`, so it runs on the database's worker and uses the
  same rule as the pairing.
- **A library site the profile has hidden does not claim its record.**
- **A library site's row and the profile's record are written in one
  transaction.** A link only this device knew would never reach the
  profile's other devices.
- **Applying does not wait for altitude lookups.** They run after it
  answers, one after another, and a failure is logged.
- **Applying one site is an ordinary edit in the change log,** not a bulk
  edit of one.
- **The review list remembers the details un-ticked for a row,** not the
  ones chosen. A detail the record gains afterwards is offered like any
  other and is never turned down without having been shown.
- **A row's "Adds" line names only the details still ticked.** A linked
  site with none left ticked reads "No thanks", which is what applying it
  does.
- **After any write the list takes no other until the pairs have been
  found again.** Until then it still shows rows the write dealt with.
- **A write that outlives the page still finishes its follow-up.** The
  pairs are found again and the site list is refreshed through the
  provider container, not through the page's own state.
- **Each tick is named after its site for a screen reader.**
- **An altitude lookup's answer is written only when the site still has
  no altitude.** The lookup can be out for seconds, and a value the diver
  entered meanwhile stays.
- **A pair whose record has gone or changed since it was shown is not
  applied.** Each record is read again before its write; an import that
  replaced the catalogue while a comparison was open leaves the pair
  counted as not applied, and the next search offers what the catalogue
  holds now.
- **A merge carries over keys of the answers that this build cannot
  read,** from every merged site. The survivor's value stands where two
  hold the same key, then the first merged site's.

## Left to the builder

- File, class and provider names; the route's exact path; the JSON
  spelling of the column beyond the three keys.
- How candidates are read efficiently for a few hundred sites (one read
  per site, or a batched one), and how the exact-name read is indexed.
- How `getSiteByCatalogueId` finds a site by an `also` id.
- How the tick and the comparison control sit in a row within the guards.
- The strings, their keys, and the wording of the notice and the line.
- Where the notice's dismissal is stored on the device.
- The change log label for a list Apply.
- Whether a row's "Adds" line abbreviates when it is long.

## Acceptance

The scenarios use a fixture catalogue.

1. **Catch-up.** A diver has "Salt Pier" at a record's exact position with
   no link, made before slice 1. The Sites page shows the notice. The list
   shows the site under "Same site", ticked. Apply links it and fills its
   empty depth and types; its notes, with the old "Imported from" text,
   are unchanged. The site's page now shows the source credit.
2. **No position.** "Blue Hole" with country Egypt and no coordinates is
   listed under "Check these", un-ticked. Ticking it and applying gives the
   site the record's position, and its altitude is then looked up. With two
   "Blue Hole" records in Egypt the site is not listed.
3. **Different name.** "Thistlegorm", 40 m from "SS Thistlegorm", is listed
   under "Check these" with the distance. Its name is unchanged after
   applying.
4. **Never overwritten.** A paired site with a depth of 30 m and a record
   with 28 m: depth is not in the offer and is unchanged after applying. A
   depth typed after the list loaded and before Apply is kept.
5. **Per field.** In the comparison the diver un-ticks the description and
   applies. The site is linked, has the depth, has no description, and the
   description is not offered for that site again.
6. **Not the same site.** The answer removes the row. The pair is not
   listed again, also after an app restart, and the record is still
   offered in the picker's search.
7. **Un-ticked rows stay.** After Apply with one row un-ticked, that row is
   still listed, and the notice counts it until it is dismissed.
8. **Notice.** Dismissed, it stays away across restarts and returns when a
   new pair appears.
9. **New details.** A linked site whose record gains a depth in a new
   catalogue file is listed under "Same site" after the import.
10. **Site page.** A paired site's page shows the line; "Review" opens the
    comparison; after applying, the line is gone.
11. **Sync.** On a second device the applied site arrives linked and
    filled, and "Not the same site" given on the first device keeps the
    pair off the second device's list.
12. **Merge.** Two sites linked to two records are merged. The record of
    the merged-away site is not offered in the picker or on the map.
    Undoing the merge brings both sites back with their own links.
13. **Shared library.** A library site this profile may not edit is never
    listed. One it may edit is listed; applying fills the shared fields
    for every member, and on the profile's second device the site arrives
    linked, with its "Not the same site" answers, through personal sync.
    A later edit of the site's private notes does not clear the link.
14. **Linked, no position.** A linked site with no coordinates is listed
    under "Check these", un-ticked, offering the record's position.

## Testing

Tests first. At least:

- The pairing rule: each of the four kinds; name equality (case,
  diacritics, punctuation); 150 m either side; dive site before register;
  nearer wins; claimed and answered records excluded; one record contested
  by two sites; a named pair with one, two and no candidates, with and
  without a country; a researched record un-ticked.
- The offer rule: every field's condition; the depth unit; place fields
  only at the record's place; declined fields left out; a link-only offer
  for an unlinked site; an empty offer for a linked one.
- The exact-name read over a real local cache database.
- The apply write over a real database: only chosen columns; still-empty
  re-check inside the transaction; the link set once; types added only to
  a site with none; a claimed record skipped; sync marked once; a library
  site's changed fields recorded; a failure on one pair does not stop the
  rest.
- The column: migration, mapper round trip with unknown keys and with
  unreadable text, sync round trip and the older-peer overlay, merge and
  undo, UDDF round trip.
- `linkedCatalogueIds` with `also` ids, and through it the picker, the map
  filter, the import page mark, GPS matching and adoption.
- The review page: sections, seeded ticks, Apply applies ticked rows only
  and stays, the message, the empty state, catalogue not ready.
- The comparison: per-field ticks, "Not the same site", "No thanks",
  link-only apply.
- The notice: shown, hidden under a search, dismissed, returning on a new
  pair and on a grown offer, not returning for the same pairs. The site
  page line for a linked and an unlinked pair.
- Library sites: the two columns on `library_site_notes` (migration,
  sync round trip, older-peer overlay); apply and answers keep them for
  the profile; `applyLibrarySiteNotes` copies them and a record without
  them clears nothing; the claimed check sees a library site's link; a
  pull, a detach and a restore keep them.
- A pair whose offer includes a position is un-ticked, linked or not.
- `test/architecture/` and `test/shared/` after adding files.
