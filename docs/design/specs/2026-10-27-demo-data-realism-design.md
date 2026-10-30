# Demo mode: a realistic six-year logbook

Status: approved design. Builds on the demo mode design
([2026-10-26-demo-mode-design.md](2026-10-26-demo-mode-design.md)).

## Why

The first sample logbook (#3708, #3729) fills every table, but it does not
read like six years of a real diver's life. It has 300 dives, ten people,
seven destinations, three trips a year and about 38 flat gear items. Someone
who dives can see at once that it is thin: a diver with that much technical
and rebreather training has dived with far more people, at far more places,
with far more kit. The equipment screens show the most, and they show least
of what they can do: regulators are single items, no service clock is
overdue, no condition finding is raised, nothing is ever sold, lent or lost.

The maintainer wants every part of the logbook to be as realistic as possible
for its time span. Above all, the equipment tracking and monitoring features
should be fully expressed, so an explorer sees what they do.

## Goals

Decided by the maintainer:

- **About 700 dives over the six years**, so that the trip count below and
  weekend diving at home add up. The download grows accordingly (see Size).
- **People.** 60 to 100 named people, with dive counts skewed toward a few:
  - 5 to 10 home regulars who appear on most local dives;
  - a technical team of 2 or 3 who appear on the technical and rebreather
    dives;
  - trip guides and boat buddies, each seen on one trip or a handful of dives;
  - instructors, one per course, appearing on that course's dives.
- **Trips and places.**
  - About 6 to 8 trips a year, and dives at 30 or more dive centres.
  - Dives spread throughout the world.
  - Lakes and other freshwater diving remain, as now.
- **Scooter (DPV) tracks** generated, so the route and scooter features show
  real content.
- **The gear tells a full story,** and the diver owns every piece of gear
  their diving needs, for each kind of diving they do.
- **Regulators are built from their parts:** first stage, second stages,
  hoses, transmitter, SPG and so on, each a separate item, joined as an
  assembly.
- **Every equipment tracking and monitoring feature is expressed** (listed
  below).
- **Publish when ready.** Once the new package is built and its checks pass,
  publish it to the `demo-data` release. The maintainer gave that go-ahead
  in advance.

## Non-goals

- No change to the app itself. This is the generator and the published
  package only. If an equipment feature cannot be shown without an app
  change, that is reported, not worked around (see Left to the builder).
- No change to how demo mode is entered, exited, sealed or downloaded.
- No change to the privacy rules or the harvest stage.

## Anti-goals (failure even if it works)

- **Anything a diver would notice as impossible.** For example:
  - gear used on a dive before it was bought, or after it was sold or lost;
  - a drysuit in 29 degree water, or a 3 mm wetsuit in a 6 degree lake;
  - a service recorded on a day the diver was on a liveaboard on the other
    side of the world;
  - a hydro test date after the fill that needed it;
  - a buddy who lives at the home lake guiding in Raja Ampat;
  - two trips overlapping;
  - a rebreather dive before the rebreather course.
- **Visible repetition.** The same dive shape, buddy pair, site or note
  recurring so often that the logbook looks generated.
- **Real people or private data.** Every name stays fictional. Every site and
  centre comes from the public catalogue, as before.
- **Dives beyond the diver's training.** Each dive must sit within the
  certifications held on its date: depth, gas, deco, overhead and rebreather.

## The diver's six years

The phases stay as they are: recreational, then technical open circuit, then
a rebreather course and rebreather dives at the end. With 700 dives the
phase boundaries move. Today the technical phase starts at dive 136 only as a
side effect of 300 dives. The builder sets the boundaries so each phase has a
believable length and every certification comes before the first dive that
needs it.

The rebreather phase stays short and recent: 15 dives, the most the harvest's
rebreather shapes allow (maintainer's choice, first 15 to 18). The shapes go
to 39 to 107 m, so a rebreather shape may be squeezed to 0.7 of its depth,
against 0.85 for open circuit, and the dives sit at 29 to 40 m inside the
rebreather card: the course at 29 to 32 m, the dives after it at 38 to 40 m
(maintainer's choice, over a trimix rebreather card or only six dives). The cell drift,
the cell swap, scrubber repacks and the Rebreather kit set all fit inside it.
The rebreather's annual service shows as due soon, not done, because the
diver has owned it for less than a year.

### Places (maintainer's choices, my proposal for the spread)

**Revised after walking the first build (maintainer's choices):** the diver
lives in Princeton, New Jersey, not Germany, and about half the trips go to
the Caribbean.

- **Home:** the central New Jersey coast, from Long Branch to Barnegat:
  shore dives and boat dives to wrecks and artificial reefs, a summer
  thermocline over cold bottom water, quiet in winter. The site catalogue,
  harvested from OpenStreetMap, had no New Jersey ocean sites, so a curated
  supplement (`scripts/dive_sites_curated.json`) adds about 20 researched
  sites, and the harvester merges it on every harvest so they survive.
  Positions come from public sources (NOAA wreck data, the New Jersey DEP
  reef program), and the descriptions are our own words.
- **Near home:** weekend trips to the St. Lawrence River wrecks at
  Brockville, Ontario, replace the Austrian and Swiss lakes.
- **The Caribbean, about half the trips:** Bonaire, Cozumel, Curaçao, Grand
  Cayman, Guadeloupe, San Andrés, the Dominican Republic and Bocas del Toro,
  as the catalogue has sites for them. The rest go worldwide as below.
- **Units and kit:** the diver logs in feet, °F, psi, pounds and cubic feet,
  and dives aluminium 80s on trips and steel HP100s at home.
- **Fewer places, by design:** with half the trips revisiting seven islands
  and a weekend near home each year, the story reaches about 20 to 24
  destinations rather than 25 or more.
- **Home dives by depth:** a home dive goes to a wreck, reef or inlet deep
  enough for it, a quarter of the recreational days are beach dives at an
  inlet, and technical dives at home are decompression dives on the wrecks
  to about 46 m; the trimix course is taught away from home.

The first proposal, kept for the record:

- **Home:** the lake region, as now, dived all year, in every season.
- **Other freshwater:** Austrian and Swiss lakes, a quarry or two, and
  Mexico's cenotes. Cenote dives stay within the diver's training: cavern
  only, unless the story adds a cave course first.
- **Warm water, worldwide:**
  - the Red Sea and the Maldives (liveaboards);
  - Indonesia, the Philippines and Thailand;
  - Micronesia and Palau;
  - the Caribbean (Curaçao, the Dominican Republic);
  - Australia, Japan and Malaysia.
- **Cooler sea water:** Mediterranean wrecks (France, Croatia, Malta) once the
  diver is technical, and Norway or the UK for cold-water sea diving.
- **About 25 destinations or more** in total. Some are revisited, as a real
  diver revisits a favourite, and none dominates the trips.

Trips run 4 to 14 days. Liveaboards have 3 to 4 dives a day, resorts 2 to 3,
and a few short weekend trips sit closer to home. Each trip uses one or two
dive centres from the catalogue near its sites. Water temperature, exposure
suit, time zone and gas (air, nitrox, trimix) follow the destination and the
phase. A dive's temperature trace comes from its destination's water in that
season (a summer lake's thermocline, a degree or so in the tropics), read
through a slow sensor, never from the harvested shape, whose source water
may have been anywhere.

### People (maintainer's choices)

As in Goals. In addition, my calls:

- Names are fictional and plausible for where each person dives. Guides at a
  destination have local names, and home regulars have names that fit the
  home region.
- Instructors appear on the dives of their course and on nothing else, except
  where the story gives a reason.
- Buddy roles in the logbook match the person: buddy, guide, instructor,
  divemaster, or student when the diver later assists on a course, if the
  story reaches that.

## The gear story

Approved in conversation. Exact brands and models are the builder's call,
using real product names, which the privacy check already allows.

### Bought as the diver progresses

- **Open water year:**
  - mask, snorkel, fins, boots, a 5 mm wetsuit, hood, gloves;
  - a jacket BCD and a first computer;
  - an SMB with a spool, and a knife.
- **First regulator.** Rented for the first trips (the rental is recorded at
  the dive centre), then bought as separate parts:
  - a first stage;
  - a primary second stage and an octopus;
  - an inflator hose, a high-pressure hose, an SPG and a compass.

  Each part is its own item, joined into a regulator assembly.
- **Years two and three:**
  - a drysuit with undersuit, base layer and socks for the cold lakes;
  - a cold-water regulator set;
  - lights;
  - an air-integrated computer with a transmitter on the first stage;
  - a camera rig: housing, ports, tray, arms, strobes, float arms.
- **Technical phase:**
  - backplate, wing, harness and tank bands;
  - twin cylinders with two regulator sets (a long hose and a necklace);
  - stage bottles, each with its own regulator;
  - reels and a second computer;
  - a scooter with its battery.
- **Rebreather phase:**
  - a rebreather with three oxygen cells and a battery installed inside it;
  - a bailout regulator;
  - scrubber material.
- **Cylinders.** The diver owns cylinders, with fill records and cylinder
  passports.

### Looked after

Every service clock the app has runs on schedule, through the built-in
service kinds:
- regulator services, BCD inspections and drysuit seals;
- computer and transmitter batteries;
- hydro tests and visual inspections;
- oxygen cleaning for deco bottles;
- oxygen cell replacement, scrubber repacks and the rebreather's annual
  service;
- general service for other items.

Service records fall on home days, between trips, with a believable shop or
technician.

### Things go wrong

- A second stage free-flows in the cold lake more than once. Observations are
  recorded with issue tags, the condition program raises a finding, and a
  service follows.
- A transmitter drops out mid-dive on some dives, so the pressure data has
  real gaps.
- One oxygen cell drifts across several rebreather dives, so its millivolt
  readings disagree with the others, and the cell is swapped. The swap is
  recorded as the new cell's install date.
- A hose bulges and is replaced, a neck seal tears and is replaced, a fin
  strap breaks.

### Gear leaves

- The jacket BCD is sold after the move to a backplate.
- A spare regulator is lent to a buddy and is still out.
- A mask is lost on a trip.
- The first computer is retired.
- One item sits on the wish list.

### Today

On the newest dive's date, which the date shift puts one to two weeks before
the day the explorer opens the logbook:
- two service clocks are overdue, a few are due soon, and the rest are fine;
- named kit sets ("Warm water single", "Cold lake drysuit", "Tech doubles",
  "Rebreather"), with the lake set applied automatically at the home lake
  through a geofence;
- trip packing lists, rental notes at dive centres, weights on each dive, and
  gear items on the pre-dive checklist.

### Equipment features that must each show something

Each of these is in the schema today. The builder confirms each one shows
something on screen in demo mode:

- **Assemblies:** regulator assemblies built with typed hoses and lengths,
  with the SPG and transmitter among the parts. The parts are carried onto
  each dive the assembly is used on.
- **Installed parts:** oxygen cells and batteries installed inside a parent
  item, with install dates and cell slots.
- **Item details:**
  - statuses across the set: active, spare, needs service, in service,
    retired, sold, loaned, lost, wanted;
  - type-specific attributes;
  - purchase details.
- **Kit sets:** default, auto-apply, the figure view, and geofences.
- **Usage:** dive counts through every path the app counts, namely the gear
  list, the tank's cylinder, the tank's regulator, the transmitter serial and
  the parent item.
- **Service:**
  - schedules, both automatic and added by hand;
  - exposure counted in each unit the app knows: days, dives, hours, salt
    water hours, cold dives, oxygen hours, deep cycles and cycles;
  - every status: fine, due soon, overdue.
- **Transmitters:** configured, and linked to their equipment items.
- **Cylinders:** hydro and visual inspection dates, fills, passports, and the
  cylinders taken on trips.
- **Condition:** observations with issue tags, and findings from each rule the
  data can trigger (recurring issue, cold-correlated, depth-correlated,
  incident-linked, cell drift, transmitter dropout). The condition program is
  switched on in the diver's settings.
- **Where gear is:** storage locations, moves between them, and a loan to a
  person.
- **Ownership:** shares and ownership events.
- **Dive-centre gear notes:** what was rented where.
- **Weights:** weights on dives, and weight presets.
- **Checklists:** gear items on the pre-dive checklist.
- **Trip gear:** what was taken on each trip.

## Tracks (maintainer's choice: scooter tracks; my proposal for the rest)

- **Scooter dives.** From the scooter's purchase, a share of the technical and
  rebreather dives use it, and each of them carries an underwater route. The
  routes vary: out and back along a wall, a loop in a lake, a long run along
  a reef or a wreck field, each with a believable speed for a scooter, and
  each matching its dive's depth trace and duration. No scooter dives in the
  cenotes: a long scooter run there is cave diving, which the diver is not
  trained for. (My call.)
- **The scooter's own clocks.** Each scooter dive adds to the scooter's and
  its battery's exposure.
- **Planning.** At least one scooter plan or mission in the planner, as now.
- **Boat tracks.** GPS tracks for a share of boat days, from harbour to site
  and back, rather than the three placeholder circles there are today.

## Constraints

- **The existing checks stay:** the coverage check (every user data table has
  rows) and the privacy check (no dive too close to a harvested shape; no
  personal text equal to a source value). Both must pass on the new package.
- **Shapes.** 700 dives come from the same harvested shapes, reshaped. The
  privacy distance holds for each. No shape is used more than three times
  (`ShapeLibrary.maxUses`), so dives do not visibly repeat. The harvest the
  first package was built from holds 3,342 shapes: 3,083 recreational, 187
  deep open circuit, 66 multi-gas deco and 6 rebreather. That covers 700 dives
  in every kind but the rebreather, which is why that phase stays short.
- **The harvest is not in the repository.** It sits in an earlier session's
  scratch folder
  (`/private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion--claude-worktrees-demo-mode-bundled-data-3b6a53/679dec60-dbc3-431d-8db2-80f141f409ed/scratchpad/harvest_real`,
  with the photos and their `credits.json` beside it in `demo_photos`), which
  the system may clear. The builder copies both to a lasting place outside the
  repository before relying on them, and re-harvests only if they are gone.
- **Fault signals live in the dive data itself.** Transmitter dropout and cell
  drift are detected from the pressure samples and the cell millivolt series,
  so the generator writes those into the profiles. A note alone is not
  enough.
- **Size.** Today's package is 9.4 MB: about 3 MB of compressed database and
  about 6.4 MB of photos, which do not compress. The database grows roughly in
  step with the dive count, so about 700 dives means about 7 MB compressed,
  and a package of about 13 to 14 MB. The new dives carry more per dive
  (longer multi-tank dives, cell series, routes, tracks), so the real figure
  may be higher. The maintainer accepted a download of around 20 MB, so the
  build's limits become 12 MB for the compressed database and 20 MB for the
  package. This replaces the earlier design's 15 MB promise. (The figures
  are my call, within the 20 MB the maintainer accepted.) After walking the
  first build the maintainer asked for many more photos and accepted about
  25 MB for about 150 of them, so the package limit is now 28 MB.
- **Dates.** All dates are generated relative to the anchor and shifted at
  open time, as now, so "overdue" and "due soon" stay true on any day the
  logbook is opened.
- **Determinism.** A given seed builds the same logbook.
- **Repository rules.** The generator's tests come first (TDD). Files stay
  within the size guards, so the planner and the gear seeder split into
  smaller files as they grow. Paths use `p.join`. `dart format` runs.

## Delivery

- The work happens in its own branch and worktree, with an issue of its own.
  The release it targets is the maintainer's call when the issue is opened.
- The pull request covers the generator, its tests, the README and the size
  limits. Nothing the harvest reads is committed.
- After the pull request's checks pass, the package is rebuilt from the
  maintainer's harvest, checked, and published to the `demo-data` release as
  the README describes, with the existing manifest merged.
- The builder walks the app in demo mode and confirms that the equipment
  screens, trips, buddies, dive centres, maps and routes show the new data.

## Left to the builder

- Exact destinations, sites, centres, trip dates and lengths, within the
  places above.
- Every fictional name, and each person's exact dive count.
- Gear brands, models, prices and purchase dates.
- The phase boundaries and the course schedule.
- Which service clocks end overdue or due soon, and which items carry which
  faults, within the story above.
- Route geometry and scooter speeds.
- How the planner and seeders are split into files.
- If any feature in the equipment list cannot be shown from the generator
  alone, list it in the pull request and the issue. Do not change the app
  for it in this work.
