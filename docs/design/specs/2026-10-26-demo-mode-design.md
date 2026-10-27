# Demo mode: explore Submersion with a sample logbook

Status: approved design. Release: v1.8.4.

## Why

A new diver who installs Submersion meets an empty app. Every screen that
would show what the app can do (statistics, maps, gear service, certifications,
trips, the planner, profile analysis) is empty until they have entered or
imported a real logbook, which is a lot of work to do before they know whether
the app is worth it. Existing users have the same problem in miniature: a
feature they have never used shows them nothing.

Demo mode lets anyone open a complete, believable sample logbook, roam the
whole app, and leave again with their own data exactly as it was.

## Goals

- Every part of the app that holds data has something believable in it, so
  whatever an explorer is curious about shows what it can do. There is no
  guided tour and no curated path.
- Dive profiles and tank pressure curves look like real dives, because they are
  derived from real dives, not from easing curves and noise.
- Demo mode is offered to everyone: on the first-run welcome screen, and in
  Settings for people who already have a logbook.
- A user's real data is never opened, changed, copied, synced or backed up while
  demo mode is on, and comes back exactly as it was when they exit.
- Nothing in the sample logbook can be tied back to any real diver.

## Non-goals

- A guided tour, coach marks or a scripted walkthrough.
- Keeping anything made in demo mode. Edits work, and are discarded on exit.
- Moving sample dives into a real logbook.
- Shipping the sample logbook inside the app.

## Anti-goals (failure even if it works)

- Sample data reaching a user's cloud folder, backup, club shared library or
  another device, where it could overwrite or mix with real data.
- Any real diver's dive being recognisable in the sample logbook (their name,
  buddies, sites, dates, notes, serial numbers, or a profile that matches one of
  their dives one to one).
- Real source files, or the harvested shape library, committed to the
  repository or published. Only the finished, reshaped and checked demo
  logbook is ever published.
- A screen that is empty in demo mode.
- A crash, a dead battery or a killed app during demo mode leaving the real
  logbook damaged, swapped out, or with its sync and backup settings altered.

## What the user sees

### Entering

Two entry points:

1. **First run.** The welcome screen (`welcome_fork_step.dart`) gains a third
   choice next to "Start fresh" and "I have existing data": "Explore with sample
   data".
2. **Settings.** An "Explore with sample data" entry in Settings > Data, for
   people who already have a logbook. It explains in one or two sentences that
   their own logbook is set aside, untouched, and comes back when they exit.

Entering:

1. The app downloads the sample logbook and its photos (15 MB or less) with a
   progress indicator. It downloads every time demo mode is entered, because
   exiting removes everything. Offline or on failure, the user
   sees a plain message and stays where they were, with nothing changed.
2. The app prepares the demo database from the download (see Dates), switches
   to it, and restarts into the dashboard of the demo diver.

### While in demo mode

- A persistent strip on every screen (in the `MainScaffold` slot next to
  `UpdateBanner`, desktop and mobile layouts) says the user is exploring sample
  data, with an "Exit demo" button.
- Everything works normally on the demo data, including edits, the planner,
  calculators and adding dives by hand, except the sealed-off features below.
- **Sealed off: nothing comes in and nothing goes out.** Disabled while demo
  mode is on:
  - every file import (universal import, the import wizard, UDDF, CSV,
    Subsurface, MacDive, FIT and the rest, OCR import);
  - dive computer downloads (Bluetooth, USB, and the auto-connect background
    download);
  - cloud imports (Suunto, Garmin and other account-based imports);
  - adding photos or files from the device or a connected photo service
    (builder's call: treated as an import);
  - every export (UDDF, CSV, PDF logbooks, the documents ZIP, share images,
    the share sheet, sending to a buddy);
  - backup (manual "back up now", scheduled backups and their cloud upload);
  - restore;
  - cloud sync on every provider: automatic, manual, on launch and on resume;
  - shared dive-site library sync and publishing;
  - operations on the database file itself: changing the storage location,
    opening another folder, encryption settings, reset, and the setup assistant.
- Disabled entries stay visible with a short note that they are unavailable in
  demo mode, so the explorer can see the feature exists.
- Online services that only fetch data for display stay on: map tiles, tides,
  weather, geocoding, species and site lookups. They carry none of the user's
  data anywhere.

### Exiting

There are two ways out, and both run the same exit:

- the "Exit demo" button on the strip;
- an "Exit demo" entry in Settings > Data, in the place where "Explore with
  sample data" sits when demo mode is off.

Exiting asks for confirmation (changes to the sample logbook will be
discarded). Then:

- **The user had a logbook before:** the demo database is deleted, and the app
  restarts on their own logbook with the same diver selected and sync, backup
  and every other setting exactly as before.
- **The user came from first run:** the demo database is deleted and the app
  returns to the welcome screen with a clean slate.

Exiting cleans up everything demo mode created: the demo database with its
`-wal` and `-shm` files, the downloaded compressed file, the photos, the demo
directory itself, and any demo-only preferences. Nothing is cached for the next
time; entering demo mode again downloads afresh. If the app is killed during
the clean-up, the next launch finishes it before opening the user's logbook.

## How it works in the app

### Isolation

- The demo database is a separate file in the app's support directory, for
  example `<appSupport>/demo/submersion_demo.db`. It is opened with the
  existing runtime switch (`DatabaseService.reinitializeAtPath` plus
  `restartApp()`), the mechanism restore and "open folder" already use.
- The real database's location (`StorageConfig`, `DatabaseLocationService`) is
  never changed. Demo mode is a separate, persisted flag that overrides which
  file is opened, so a crash at any point leaves the real path intact.
- If the app is killed during demo mode, it relaunches into demo mode with the
  strip showing. The user leaves through "Exit demo" as usual. (Builder's call:
  resuming is the least surprising behaviour and never risks the real data.)
- The demo database is never encrypted, and entering or leaving demo mode never
  reads, applies or changes the user's database encryption key.

### Settings that live outside the database

Some settings are app-wide in SharedPreferences rather than in the database:
the current diver id, sync and backup preferences, and others. Demo mode must
not alter the user's values. The builder chooses the mechanism: namespacing the
affected keys while demo mode is on, or snapshotting them on entry and restoring
them on exit. Either way:

- after exit, every app-wide preference reads exactly as it did before entry;
- nothing demo mode writes is visible after exit;
- a crash during demo mode cannot leave demo values in the user's settings.

The demo diver's units and formats follow the user's current settings when they
have a logbook, and the locale-based defaults (`unit_preset_detector.dart`) on
first run, so the sample data is shown in units the user knows.

### Enforcing the seal

The seal is enforced at the engine level and the UI explains it:

- A single demo-mode gate is checked by the sync engine, the auto-sync and
  launch/resume triggers, the shared-library sync, the backup service, the
  Workmanager background jobs, the restore path, the import pipelines and the
  export services. A disabled UI is not enough on its own.
- The UI shows each sealed entry as unavailable, with the note.
- Tests prove each gate refuses while demo mode is on.

### Downloading and checking the file

- The sample logbook is published as assets on a dedicated GitHub release of
  this repository, for example the tag `demo-data`, which keeps a stable URL
  and is separate from app releases.
- A small manifest (`demo-manifest.json`) sits next to the files. Each entry
  lists a file's URL, size, SHA-256 and the database schema version it was
  built at.
- The app picks the newest entry whose schema version is not above its own, so
  an older app never downloads a file it cannot open. A newer app opens an
  older file through the normal migrations.
- The download is verified against the SHA-256 before use. A mismatch is
  treated as a failed download.
- The compressed file is downloaded into the demo directory and deleted on exit
  with everything else there.

### Dates

The sample logbook is built once and published, but its dates must never look
stale. The file records an anchor date. When the demo database is prepared, every
date and timestamp in it is shifted by the same whole number of weeks, so the
most recent dive lands one to two weeks before today. Whole weeks keep weekdays,
and keep certification expiry, gear service due dates, trip spans and
surface intervals consistent with each other. The builder enumerates the date
columns, and a test fails when a date column is added to the schema without
being covered by the shift.

## The demo diver

A fictional diver with a believable six-year progression. Every certification,
course, gear type and dive mode has a natural reason to exist:

1. **Years 1 to 2: recreational.** Open Water and Advanced, warm-water trips,
   many 10 to 30 m dives.
2. **Years 3 to 4: technical open circuit.** Nitrox, deco and trimix courses,
   deeper dives with gas switches and multiple tanks.
3. **Recently: a rebreather course, then 8 to 12 CCR dives.**

About 300 dives in total (builder's call, held to a compressed download of
5 MB or less). No real names anywhere: the diver, buddies, instructors, dive
centre staff and boat crews are fictional. Sites come from the app's public
dive-site and dive-centre catalogues (`assets/data/dive_sites.json`,
`assets/data/dive_centers.json`), never from a source logbook.

## Coverage: every part of the app is populated

The demo logbook fills every part of the app that holds the diver's data. That
includes dives with profiles, tank pressure, temperature, gas switches, deco and
ppO2 and cell data on CCR dives, multi-computer dives, scooter and route data,
sites, dive centres, trips, buddies and roles, certifications, courses and
training dives, equipment and its service history, gear passports, cylinder
passports, transmitters, tank presets, weight presets, checklists and pre-dive
sessions, documents, dive plans and missions, tags, custom fields, dive types,
marine life sightings, data quality and safety reviews, insights, tides and
weather on dives, and diver settings.

That list is illustrative, not the definition. The definition is the schema:

- The build tool checks, before it writes the file, that every table holding
  user data has rows. An explicit, commented exclusion list names the tables that
  should stay empty (sync bookkeeping, caches, built-in seeds), each with the
  reason.
- A test in CI runs the same check against a small committed synthetic shape
  fixture, so a new table added to the schema fails the test until the build
  tool fills it or the exclusion list explains why not.
- The builder also walks the app's screens in demo mode and fixes any screen
  that still shows an empty state.

### Photos and media

Dive photos are links only in Submersion: a media row points at a file or URL,
it never holds a copy. The demo logbook follows the same rule:

- A set of openly licensed underwater photos (CC0 or public domain, a few dozen,
  resized for a phone screen) is published as extra assets on the `demo-data`
  release, listed in the manifest with their sizes and SHA-256.
- They are downloaded with the database, verified, and stored next to it in the
  demo directory. The demo database's media rows link to those local files, and
  each photo's credit and licence are recorded on its media item.
- They are deleted with the demo database on exit.
- None come from the donated logbooks. The builder picks the photos so they fit
  the story's dive destinations and its marine life sightings, and records each
  one's source URL and licence in the build tool's input.
- The photo set is held to about 10 MB, so a first entry downloads 15 MB or
  less in total. (Builder's call on the exact figure.)

## The generator

The existing Python UDDF generator (`scripts/generate_uddf_test_data.py`) is
replaced, as approved. UDDF cannot carry much of what the app stores
(checklists, documents, courses, gear service, plans and more), and its
profiles are synthetic. The replacement is two Dart command-line tools built on
the app's own code, under `tool/demo_data/`. Both run only on the maintainer's
machine.

### Stage 1: harvest (local only, nothing committed)

- Input: paths given on the command line. The sources are the maintainer's
  test-data folder (real logbooks donated by divers, in Submersion, UDDF,
  Subsurface, MacDive, DiveMate, Diving Log, Shearwater Cloud, Garmin FIT and
  Seacraft CSV formats), the dive-data attachments on this repository's GitHub
  issues, and the maintainer's own database.
- The GitHub attachments that count as sources are the dive-data files on
  #810 (Shearwater Cloud databases and a Petrel 3 UDDF, CCR), #266 (Subsurface
  CCR dive with three cell readings), #87, #115, #158, #171, #172, #205, #279,
  #298, #320, #1195, #1445, #1772, #2152, #2603, #3055, #3343 and #3629. Debug
  logs, PDFs, design documents and #3506's generated ZIP are not sources.
- Excluded: computer-generated files, by name: `Synthetic dives 1000.uddf`,
  `submersion_multitank_500dives.uddf`, `scrubber-1500-dives` (and its ZIP).
  The tool refuses any file it recognises as one of them.
- It reads each source through the app's existing importers into a scratch
  Submersion database, rather than with new parsers.
- From each dive it keeps only the shape: the depth, temperature, tank pressure
  per tank, ppO2 and cell traces, setpoint changes, gas switches with their mixes,
  stops, events, and sample interval. It also keeps coarse descriptors (dive
  mode, number of tanks, mix families, max depth, runtime) to classify the
  shape: recreational, deep open circuit, multi-gas deco, trimix, CCR, scooter,
  multi-computer, and so on.
- Everything identifying is dropped: dates and times, GPS, sites, names,
  buddies, dive centres, notes, serial numbers, computer ids and firmware.
- Duplicates (the same dive exported in several formats) are collapsed.
- Output: a shape library written to a path outside the repository. It is never
  committed or published.

### Stage 2: build

- Input: the shape library, and a seed, so the same inputs give the same file.
- It writes the demo diver's whole history through the app's own database code,
  at the current schema version, and records the anchor date.
- Each dive takes a shape from the library that fits where it is in the story,
  and reshapes it so it matches no source dive one to one: time stretched,
  depth scaled within a small range, the pressure curve re-fitted to the tank
  and start pressure the demo dive uses, and the profile kept physically
  consistent (ascent rates, stops, gas use following depth). The builder chooses
  the transforms and their limits.
- A shape is reused only a limited number of times, and never twice on the
  same trip.
- CCR dives come from the few real CCR sources (#810's Shearwater dives and
  UDDF, #266's Subsurface dive with three cell readings), reshaped so the 8 to
  12 demo CCR dives do not look like copies of each other.
- It runs the coverage check (above) and refuses to write a file that fails it.
- It runs a privacy check and refuses to write a file that fails it: every demo
  profile is compared against every source shape, and any demo dive whose
  depth and pressure curves are closer to a single source dive than a set
  similarity threshold is rejected. The builder defines the measure and the
  threshold, documents them, and tests that the check rejects an unreshaped
  copy. It also confirms that no text field in the output (names, notes,
  serials, computer ids) contains a value from any source.
- Output: the compressed demo database and its manifest entry (URL, size,
  SHA-256, schema version).

### Publishing

The first file is built and published from this work: the harvest and build
run on the maintainer's machine with the sources above, the result is shown to
the maintainer, and the `demo-data` release is created only after their
explicit go-ahead. After that, the maintainer runs harvest and build, then
uploads the file and the updated
manifest to the `demo-data` release (a documented script or `gh release upload`
command). Older files stay listed so older apps keep a file they can open.
The `demo-data` release is created so it never becomes this repository's
"latest" release (`--latest=false`), because the in-app updater
(`github_update_service.dart`) and the beta appcast read `releases/latest`.
Publishing is manual and happens only when the generator changes or new
features should be shown.

### Entry points without a published file

Both entry points (the welcome card and the Settings entry) are shown only when
a manifest is reachable and lists a file this app can open. Offline on first
run, or before anything is published, they are hidden, so the user never meets
an option that cannot work. The check is quick and cached for the session, and
a failure to reach the manifest is silent.

### Retiring the Python generator

`scripts/generate_uddf_test_data.py` is deleted, together with everything that
depends on it:

- **Store screenshots** (`.github/workflows/screenshots.yml`,
  `scripts/release/capture_screenshots.sh`, the screenshot lane in
  `macos/fastlane/Fastfile`, `integration_test/helpers/uddf_screenshot_helper.dart`)
  are captured from the published demo database instead of an imported UDDF
  file: the pipeline downloads the current manifest's file, verifies it, and
  opens it the way demo mode does.
- **The UDDF round-trip test** (`test/integration/uddf_round_trip_test.dart`,
  via `test/helpers/python_script_runner.dart`) runs against committed UDDF
  fixtures instead of a freshly generated file. The fixtures are synthetic
  or already in the repository's test data, never donated real dives.
- **The script's own test** (`scripts/test_uddf_generator.py`) is deleted with it.
- Any other reference the builder finds is moved the same way.

## Constraints

- Architecture: feature code under `lib/features/demo_mode/` (data, domain,
  presentation), following the repo's layering and its file size limits.
- All new strings go through the ARB files in every supported language.
- Units and formats respect the active diver's settings.
- Paths are built with `p.join`, never by string concatenation.
- Tests that touch process-wide state (preferences, database service
  singletons) restore it, per `docs/developer/testing.md`.
- TDD, as the repository's development guide requires.

## Left to the builder

- The exact copy for the welcome card, the Settings entry, the strip, the
  confirmation and the error messages.
- Where in Settings > Data the entry sits.
- The mechanism for keeping app-wide preferences untouched (namespacing or
  snapshot and restore), within the guarantees above.
- The compression format.
- The reshaping transforms and their limits, and the classification of shapes.
- The number of dives (about 300, held to 5 MB or less compressed).
- The fictional names and the choice of catalogue sites along the story.
- How each sealed feature presents its "unavailable in demo mode" note.

