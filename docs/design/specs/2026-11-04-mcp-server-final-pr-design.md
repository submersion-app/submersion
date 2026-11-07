# MCP server final PR: every remaining write, and the gate comes off

Issue #4071, release v1.8.4. Spec: `docs/design/specs/2026-11-01-mcp-server-design.md`.
Builds on the write core of PRs 4, 5a to 5d (5d is #4202).

## Intent

Eric decided on 2026-11-04 that everything left of #4071 lands in one final
PR: the approved 5e gear design, writes for every other entity a diver edits,
a reasoned exemption for every repository write that is not a diver's edit,
the removal of the debug-mode gate, and the docs. When it merges, an agent can
change anything a diver can change in the app, and nothing else, and the
feature ships.

## Rules every writer keeps (unchanged from 5a to 5d)

- Write through the repository call the app's own page uses, so its rules and
  side effects hold; enforce in the writer what the page enforces before it
  calls the repository.
- The preview lists exactly what the apply writes: derived fields
  (`SideEffects.fields`), rows of other records (`touched`,
  `createTouched`, `DeleteReach.touched`), rows a create adds
  (`alsoCreates`), and values a form prefills (`createDefaults`).
- Rules read the set as it stands (`SetSoFar`); a change the stored state
  cannot judge is refused with "in a set of its own".
- Refuse what the page would not offer, with the page's wording where it has
  one. Never throw at apply for a case the preview could see.
- Units are stored metric; documents say which unit each key holds.
- Dates: calendar days as local midnight, true moments as UTC, wall-clock
  times as the app stores each one (the maps note which).

## What gets a writer

Grouped as the PR's commits run. "Read" means the read entity already exists.

### Gear (the approved 5e design)
- `equipment_observations` (child of an item): ok or issue, tags from the
  item type's list, dive link, note, `observed_at`; lists incidents it
  unlinks; refreshes condition findings after the apply.
- `cylinder_fills` (child of a tank): O2 and He as a possible mix, sanity
  ranges for pressure and temperature, metric; a tank with no passport id
  gets one minted and listed.
- `passport_id` on tank items: lower-case UUID, refused while another
  in-service item holds it; lists the fills it relinks.
- `transmitters` (keys of a transmitter item): serial or computer and
  channel, setup fields applied to every key of the item, unique per diver;
  no silent takeover; opt-in `apply_to_existing_dives` counted by the app's
  own preview and revertible through the change log.

### Trips (read for all)
- `trips`: name required, dates 1950 to 2100 with end not before start,
  planning numbers, parent trip rules as the repository applies them; only
  the owner changes `is_shared`; delete as the owner; liveaboard details kept
  only for a liveaboard; no implicit dive assignment.
- Relations on `trips`: `dive_ids` (through `assignDivesToTrip`, which
  stretches the dates and lists it) and `equipment_ids` (pack and unpack).
- `liveaboard_details` (child of a trip): vessel name required, vessel type
  from the four, capacity positive.
- `itinerary_days` (child): day type by trip type, planned dives 0 to 12,
  rest forces 0; generate missing days only, no duplicate dates.
- `trip_cylinders` and `trip_cylinder_events` (children): the board's add,
  edit, reorder and delete; fills and adjustments with the fill sheet's mix
  and pressure rules; gas values as fractions on the wire, percent in the
  store; a fill on an own cylinder copies to its passport, listed.
- `trip_checklists`, `trip_checklist_sections`, `trip_checklist_items`:
  create, rename, reorder, move, toggle done, delete; apply a template
  (idempotent, listed) and replace with one; save as a template.

### People
- `divers`: create (name required, email shaped), update (the profile pages'
  fields and limits, written whole), weight entries create and delete; the
  default diver through `setDefaultDiver` only. Deleting or merging a diver
  is not an agent write (Eric, 2026-11-04): a delete wipes everything the
  profile owns with no undo, and the app's typed-name confirmation stays the
  only way.
- `certifications`, `currency_rules`, `currency_prefs`, `currency_events`:
  the edit page's and dialogs' rules; a built-in rule edited becomes a
  custom copy, as the page does.
- `courses` and `course_requirements`: name required, completion not before
  start, requirement kinds and target counts; relations `certification_ids`
  on courses and `dive_ids` on a requirement.
- Dive relations the dive writer lacks today: buddies with roles
  (`setBuddiesForDive` semantics) and the trip link.
- Site relation the site writer lacks: `site_types`; sharing of trips and
  sites (`setSharing`) and per-profile hides.

### Planning and library
- `checklist_templates`, `pre_dive_templates` (built-ins read-only, cell
  linearity needs its source item), `pre_dive_sessions` (start from a
  template, item states, complete, abort, link to a dive; locked once done).
- `dive_plans` and `dive_plan_series`: save, rename, duplicate, link to a
  dive (one plan per dive), delete; no gas or deco validation, as the app.
- `rules` (saving never runs them), `saved_queries` (parsed and validated as
  the query field does), `connection_maps`.

### Places, safety, media and the rest
- `site_features` (child of a site), `incidents`, `emergency_chambers`
  (create and delete; built-ins are hidden in Settings, not deleted).
- `dive_computers`: favourite and the auto-download opt-out (rename and
  delete go through the gear item, as now).
- Safety finding dismissals, as a field on a finding (needs a read entity).
- `gps_tracks` (trim, split, delete with the geometry cache evicted) and
  `nav_tracks` (rename, site, equipment, correction, primary, link, unlink,
  delete).
- `documents` (metadata only; page bytes never) and `smart_albums`.
- `media` (Eric, 2026-11-04: every edit the app offers, delete included):
  time pin, move to another dive, people tags, species tags, colour
  adjustment, site attachment details; delete through the media deletion
  coordinator with the cloud delete held while the change can be reverted. No create by URL (the
  app would fetch it), no caption or favourite (the app never edits them).

### Merges (Eric, 2026-11-04: yes, like tags)
- `sites`, `buddies` and `dive_computers` merge as tags do: a delete naming
  `merge_into`, previewed with every link it moves and what it changes on the
  survivor, revertible through the change log, through `mergeSites`,
  `mergeBuddies` and `mergeComputers`. The rules each merge UI applies hold
  (a site merge keeps at most one other profile's site, as its survivor).

## What is exempt, with the reason in the coverage guard

- Diver delete and diver merge: a profile wipe and a repair, left to the app.
- Inner steps of another write: every `clear*Links`, `restore*`, `undo*`,
  `relink*`, `repoint*`, `deleteByTripId`, `deleteFor*`, cascade and merge
  helper, each naming its caller.
- Imports, device downloads and derived data: profile and pressure series,
  derived metrics, imported metadata, fill-if-empty, source clocks, tide
  records, trip day weather, safety reviews, rule runs and the plan mission
  store.
- Bulk shortcuts of a covered single write (bulk tags, tanks, weights,
  deletes), named against the write they repeat.
- Settings and UI state: view configs and column presets, CSV import presets.
- Security, never agent-writable: network credentials, media feed
  subscriptions (their URLs carry tokens and make the app fetch), watched
  folders (file paths), and every media cache, upload stamp and scan state.

## Read side fixes this PR also makes

- The `media` document stops listing `file_path`, `local_path` and
  `thumbnail_path`, which the spec says an agent never sees.
- Read entities the new writers need: safety findings; the transmitter and
  trip keys the maps found missing (`scale_factor` on nav tracks,
  `source_item_id` on pre-dive items, credited dives on a requirement).

## Shipping

- `agentAccessAvailableProvider` drops its debug clause (Eric, 2026-11-04):
  desktop only, on for everyone who turns it on.
- The release note and the user docs move out of debug mode with it.
- The coverage baseline ends empty: every repository write is covered or
  exempt with a reason.

## Out of scope, filed separately

- App bugs the maps found: `removeDiveFromTrip` does not stage the dive for
  sync; every liveaboard save clears the embark and disembark coordinates;
  `createRecord` and an older record (#4201).

## Execution

One branch stacked on #4202, one commit per family in the order above, each
with its tests; the plan in `docs/design/plans/`. Inline, as 5c and 5d were,
with a whole-branch review at the end, two review rounds and one Copilot
review. Expect the branch to be the largest the project has merged.
