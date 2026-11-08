# Dive drafts, automatic Apple Health import and heart rate

Issue #637, part 1 of 5 (the phone side of the watch app). Closes #2639.
The twelve phone-side ideas were approved in chat on 2026-11-08; the details
below marked "my call" were settled by the designer and are open to review.

## Why

Many divers use a computer that downloads only by cable, at home, sometimes
days after the dive. The issue's reporter has a Suunto Vyper Air. At the site
the phone knows where and when the dive happened, and the diver remembers who
was there and what they saw. At home the computer knows depth and time. Today
nothing in the logbook holds the site facts until the download, Apple Health
dives must be imported by hand, and a Health dive can never merge with a later
download.

This part builds the phone-side pipeline that every later part feeds: a
**draft** dive made at the site, which the download fills in. The Apple Watch
app (parts 2 to 4) and the Wear OS app (part 5) will create the same drafts.

## The program (order agreed in chat)

1. Phone side: this document.
2. Apple Watch app: entry and exit marks, water detection, drafts sent to the
   phone.
3. Apple Watch app: notes after the dive, nearby site, bearing back to entry.
4. Apple Watch app: glances and watch-face complications.
5. Wear OS app: parts 2 to 4 where Android watches allow, plus Health Connect
   so the heart rate, recovery and sleep features reach Android.

Each later part gets its own design pass.

## Goals

### 1. Draft dives

A draft is a dive that really happened but has no dive computer readings yet:
no profile, maximum depth, measured bottom time or gas data. It holds the
entry and exit times and positions, plus anything the diver adds.

- **Its own state, not a planned dive** (my call). A draft is marked by a new
  flag on the dive. Planned dives are left out of surface interval and no-fly
  (`diveUndivedSql`), and a draft really happened, so reusing `isPlanned`
  would drop today's dives from the no-fly countdown.
- **Counts for no-fly** (decided in chat), and for surface interval and "last
  dive" everywhere. With no depth or deco data, today's no-fly code would
  give a draft the shortest wait (12 h single, 18 h repetitive on the
  standard preset). A draft instead counts as a deco dive (24 h) until its
  readings arrive (my call, the conservative choice). An open draft counts
  from now until "Surfaced" is tapped; once one has been open for 6 hours,
  the next app open asks whether the diver surfaced and when. Once filled,
  the dive's real readings set the wait. "Mark as complete" turns a draft
  into an ordinary hand-added dive, which no-fly treats as it does today.
- **Not in totals, no number** (decided in chat). Until it is filled, a draft
  is left out of the dive count, hours, every statistic and Insights, and
  has no dive number; renumbering skips it. When a download or Health
  workout fills it, it takes the next free dive number, as a filled planned
  dive does today (`convertPlanToActualDive`), and joins the totals. A draft
  filled after newer dives were numbered therefore lands out of date order,
  as any late import does today; the existing renumber tool fixes that, and
  filling never renumbers other dives on its own (my call).
- **Times:** entry time from the "Entered water" tap, exit time from
  "Surfaced" (empty while the diver is still in the water). Total dive time
  is exit minus entry and is shown as an estimate. A draft has no bottom
  time, and its estimated time adds nothing to SAC, gear hours, scrubber
  time, CNS or OTU.
- **Editing:** the normal dive editor works on a draft (site, buddies, gear,
  notes, rating, sightings, tags, conditions).
- **List:** the dive card shows a "Waiting for download" chip, built like
  `PlannedDiveChip`. An open draft (entered, not surfaced) shows "In the
  water" instead (my call).
- **Detail page:** a banner like `PlannedDiveBanner` with two actions:
  "Download now" (opens the dive computer download, as in goal 5) and "Mark
  as complete" (clears the flag for a dive that will never be downloaded, for
  example a lost computer).
- **Sync and backup:** the flag syncs like any dive column. UDDF export
  writes it and UDDF import reads it back, as both already do for planned
  dives (my call).

### 2. Making drafts on the phone

- While a GPS track is recording, the recording card on the Tracks page and
  the recording strip show "Entered water" and, once a draft is open,
  "Surfaced". Tapping "Entered water" on the card when nothing is recording
  starts a recording first (my call), because the positions come from the
  track.
- Each Entered/Surfaced pair makes one draft; a recording can hold any number
  of them.
- **A plan becomes the draft** (my call). When "Entered water" is tapped and
  an unfilled planned dive of the same diver starts within 2 hours of the
  tap on the same local day (the diver's own plan, or one a linked buddy
  mirrored), that planned dive becomes the draft instead of a new row. It
  keeps its site, tanks and buddies, so one real dive never shows as two and
  the download has a single candidate to fill. With several candidates, the
  nearest start time wins.
- Entry and exit positions are the recorded track's position at the tap time.
  The existing GPS sweep is not needed for drafts, but must not overwrite
  their positions (it already writes only empty columns).
- Stopping a recording while a draft is open asks whether the diver surfaced
  now. The app never invents an exit time on its own.
- **Lock screen buttons:** while recording, a notification carries "Entered
  water" and "Surfaced" action buttons on Android and iOS
  (`flutter_local_notifications` actions). On Android this can be the
  recording's own foreground notification or a companion one; builder's
  call. The recorded time is the moment of the tap. Where the OS allows, a
  tap works without unlocking. If iOS cannot deliver a background action to
  the running app, the fallback is an action that opens the app and records
  the tap. The builder tries this first, before building on it.

### 3. Automatic Apple Health import (iOS)

- A setting "Import Apple Watch dives automatically", off until the diver
  turns it on; turning it on asks for Health permission.
- It runs at app start and on resume, reading diving workouts since the last
  check (a stored watermark) and skipping workouts already imported (the
  existing workout-UUID import id). There is no HealthKit background
  delivery; the `health` package cannot do it.
- Each new workout:
  - **Overlaps a draft clearly:** fills the draft. The watch's readings
    become the dive's profile, everything the diver typed stays, and the
    draft flag clears.
  - **Overlaps a downloaded dive clearly:** joins it as a second set of
    readings (consolidation). This lifts the "HealthKit consolidation"
    non-goal in
    `docs/design/specs/2026-07-02-multi-computer-consolidation-completion-design.md`.
  - **No match:** a new dive, as today.
  - **Ambiguous** (two candidates, or a partial overlap): nothing is merged.
    The diver gets a notification that opens the Health import review for
    that workout.
- After each new or filled dive, a local notification "New dive from your
  Apple Watch: add details?" opens that dive. In the foreground a SnackBar
  replaces the notification (my call).
- The manual Health import in the import wizard gains the same fill and
  consolidate choices, sharing the matching code, so both paths agree.
- **The watch becomes a dive computer record** (my call). Consolidation
  attributes every second set of readings to a computer, so the first Health
  import or merge after this change creates an "Apple Watch" computer for
  the diver, shown in the Dive Computers list like any other. Watch dives
  already in the log are not rewritten; for them the review step offers
  consolidation but does not preselect it. "Download now" never preselects
  the watch.
- **Two devices, one dive** (my call). An iPad on iPadOS 17 or later sees the
  same Health data as the iPhone. The imported dive's id is derived from the
  workout's UUID, so two devices importing the same workout converge on one
  dive through sync instead of making two.

### 4. The cable download pairs with drafts

- The dive computer download's review step pairs each downloaded dive with a
  draft whose entry-to-exit window overlaps it, and defaults that row to
  fill, as it does for planned dives today. Rows with two candidates, or no
  clear overlap, are left for the diver. The builder chooses a tolerance for
  computer clock drift.
- Filling reuses the planned-dive fill path (`PlannedDiveFillService`): the
  download becomes the primary profile and sets the measured fields; what the
  diver typed stays; the draft's tap positions stay; the draft flag clears.
- A download that overlaps a dive the watch recorded defaults to
  consolidate when the overlap is clear. Today that row is never defaulted
  because the watch dive has no computer id.
- **The first readings stay main** (decided in chat). When readings from a
  second device join a dive, whichever set reached the dive first stays the
  main profile (the chart line and the headline numbers), and the newcomer
  is kept as a second set. This holds both ways: a download joining a watch
  dive, and a Health workout joining a downloaded dive. A draft has no
  readings, so the first to fill it becomes main. The diver can still switch
  the main set per dive from the data sources section, as today.
- The review step stays. A manual download never merges anything the diver
  has not seen.

### 5. "Waiting for download" dashboard card

- A dashboard card shows how many drafts are waiting and the newest few, and
  hides itself when there are none (like `PreDiveDashboardCard`).
- "Download now" opens the dive computer download with the expected computer
  already chosen: the computer of the diver's most recent download (my call),
  or the normal picker when there is none.

### 6. Reminder for drafts left waiting

- A local notification when a draft has waited 3 days (my call on the
  number), once per draft. Off by default, with a switch in the notification
  settings. Scheduled through `NotificationScheduler` like the other
  reminders.

### 7. Conditions and site for drafts

- When a draft gets its exit, weather and tide are fetched for its entry
  position and time, filling only empty values. The existing services
  require a site with coordinates; they are extended to take a position.
  Offline, the fetch retries at the next app open.
- The existing site suggestion card on the detail page offers the nearest
  saved site, or "create a site here", from the draft's entry position. No
  site is linked silently (existing rule).

### 8. Heart rate from Apple Health on any dive (iOS, #2639)

- For any dive with times (downloaded, hand-added, draft or watch), read
  heart rate samples from Health in the dive's window, from any workout or
  none. This is the drysuit case in #2639: the watch is only a heart rate
  sensor and the dive computer is the authority.
- Shown on the profile chart as the heart rate line, with average and maximum
  on the detail page.
- Stored apart from the dive computer's own readings, so a re-parse of the
  computer's data never wipes it: a second profile series attributed to the
  "Apple Watch" computer (goal 3), holding heart rate only. It syncs and is
  backed up like the watch heart rate that imported watch dives already
  carry in their profiles (my call, following that precedent).
- Never replaces heart rate the dive computer measured itself (for example
  from a strap).
- Added automatically to new dives when the Health features are on (at
  import, fill or consolidation time), and on demand from an "Add heart rate
  from Apple Health" action on the dive's detail page for older dives.

### 9. Recovery after the dive (iOS)

- From Health: heart rate at surfacing and 5 and 15 minutes later, and
  overnight heart rate variability (SDNN) in the sleep after the day's last
  dive.
- Shown in a "Recovery" section on the dive's detail page as plain numbers
  with a one-line explanation. No verdicts such as "good" or "poor".
- Stored on the dive and synced, like goal 8 (my call). Values that are not
  in Health yet (the overnight HRV in particular) are read again on later
  app opens until they arrive or a few days have passed.

### 10. Sleep the night before (iOS)

- Total sleep in the night before the day's first dive, shown on each dive
  of that day as a quiet note ("Slept 6 h 40 min the night before"). Not a
  warning. Stored and synced like goal 9.

### Settings

One Apple Health section (my call) holds two switches: "Import Apple Watch
dives automatically" (goal 3) and "Add heart rate, recovery and sleep from
Apple Health" (goals 8 to 10). Each asks only for the Health permissions it
needs, when it is turned on. Both appear only on iOS.

**Whose Health it is** (my call). Apple Health belongs to one person, while
the app can hold several divers. Both switches are stored on the device, not
synced, and are bound to the diver who turned them on; the section shows
"For: <diver name>". Imports, merges and heart rate always go to that
diver's dives, whoever is active, and nothing from Health is attached to
another diver's dives.

## Non-goals

- Any watch app (parts 2 to 5) and Health Connect on Android (part 5).
- An iOS Live Activity or any new native extension target.
- HealthKit background delivery.
- Writing dives to Apple Health (#2931).
- Any depth, decompression or gas estimate for a draft.
- Linking a site to a dive without the diver choosing it.

## Anti-goals (failure even if it works)

- A draft missing from surface interval or no-fly.
- A draft's estimated time treated as measured anywhere.
- A fill or merge that loses something the diver typed.
- A manual download merging into a dive without the review step.
- Health numbers presented as a medical judgement.
- Heart rate from Health overwriting heart rate the dive computer measured.

## Constraints

- Everything shown respects the active diver's units and locale; new strings
  go in the ARB files with translations.
- New dive columns get a default for fresh rows only; existing rows are not
  rewritten. The schema rung goes in
  `lib/core/database/migrations/ladder/rungs_v340_onward.dart` as v347
  (current is v346; v345 is reserved by another open PR). Renumber if main
  moves first.
- When the planner follows a dive with no profile it already warns that
  tissue loading is missing (`plan_follow_prompt.dart`), so drafts need no
  new planner work.
- Any new synced table or column follows the sync rules (serializer arms,
  change-log columns, guard tests).
- Drafts and lock screen buttons work on Android and iOS (GPS recording is
  mobile only). Every Health feature is iOS only in this part.

## Left to the builder

- Names of the new flag, columns, table, providers and settings keys.
- How heart rate from Health is stored, within the rules in goal 8.
- The overlap tolerance for pairing, and how many drafts the card lists.
- Notification channel, wording and the exact lock screen mechanism, within
  goal 2.
- Watermark storage and how resume-time import is throttled.
