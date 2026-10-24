# Downloads follow the dive computer's owner

Issue: #2050. Release: v1.8.3.

## Intent

In a library with several diver profiles, a dive computer download always
lands in the active profile. Downloading Mitchell's computer while Bill's
profile is active files Mitchell's dives in Bill's log, applies Bill's
default equipment set, and fails to recognise Mitchell's computer because the
lookup only searches Bill's computers. The only workaround is remembering to
switch profile first, and a misfiled dive cannot be moved afterwards (#2051).

Each `dive_computers` row already records its owner (`diver_id`). The
download should use it.

## Goals

- A known computer is recognised whichever profile is active.
- By default, a download from a computer owned by another profile goes to the
  owner's log, and the review screen says so.
- When the computer belongs to another profile, the person downloading can
  send this one download to any profile instead (for example Mitchell's
  computer lent to Bill for the day), without changing who owns the computer.
- Everything that describes the diver follows the chosen profile.
- A setting under Settings > Data > Import options turns the default off.

## Non-goals

- Moving dives already filed under the wrong profile (#2051).
- Changing a computer's owner from the review screen. Ownership is edited
  where it is today.
- Merging computer records that the old behaviour already duplicated across
  profiles. The lookup copes with them (see Lookup) but leaves them alone.
- File imports (UDDF, Subsurface, and so on). Only dive computer downloads
  over Bluetooth or USB are in scope.
- Garmin Connect and Suunto cloud imports (the builder's call). They also look
  computers up only in the active profile, but they import from a cloud
  account that the active profile connected, so the account holder and the
  computer's owner are almost always the same person. They can follow in a
  later change if the duplicate case turns up.
- The reverse lent case: Bill lends Mitchell his own computer, then downloads
  it with his own profile active. The owner and the active profile are both
  Bill, so no picker appears and the download goes to Bill as today (the
  user's decision, number 5 below).

## Anti-goals

- Registering one physical computer a second time because another profile is
  active. This happens today by accident and must not survive in either
  setting.
- Silently filing a download somewhere the person did not expect. Whenever the
  computer's owner differs from the active profile, the review screen shows
  where the dives will go.

## Decided by the user

1. **The setting:** a switch in Settings > Data > Import options, on by
   default.
2. **A different profile picked on the review screen applies to that download
   only.** The computer's owner does not change, and the next download from it
   defaults to the owner again.
3. **With the switch off, the computer is still recognised as the owner's.**
   No duplicate record is created and incremental download still works. The
   switch only decides which profile the picker starts on:
   - on: the computer's owner;
   - off: the active profile.
   The message and picker appear in both modes whenever the owner differs from
   the active profile. With the switch off the message reads, for example,
   "This computer belongs to Mitchell. Dives will be added to Bill's log."
4. **The default tank follows the chosen diver.** The "default tank for
   imported dives" preset comes from the chosen diver's settings, not the
   active profile's.
5. **The picker appears only when the owner differs from the active
   profile.** Downloads of the active profile's own computer look exactly as
   they do today.

## Behaviour

### When the message and picker appear

They appear on the review step of a dive computer download when all of these
hold:

- the computer is a known record with a non-null `diver_id`;
- that diver still exists;
- that diver is not the active profile.

Otherwise nothing changes from today: no message, and dives go to the active
profile. This covers a computer seen for the first time (registered to the
active profile, as today), a computer owned by the active profile, a computer
with no owner, and an unscoped single-profile library.

### The message and picker

- A single line sits directly under the source card at the top of the review
  step, above the tabs: "This computer belongs to {owner}. Dives will be added
  to {chosen}'s log." When the chosen profile is the owner, the second half
  names the owner.
- A profile dropdown sits beside it, listing every profile and preselected per
  the switch (decision 3).
- Changing the selection recomputes everything on the review step that depends
  on the diver: duplicate matches, planned-dive fills and the dive-number
  preview. It applies only to this download session.

### What follows the chosen profile

- the diver the dives are written to;
- dive numbering, and the dive-number preview on the review step;
- the default equipment set (`DiveEquipmentDefaulter`) and the computer's
  equipment-set linker;
- the computer's linked gear item (the gear linker already reads the computer
  row with no diver filter, so it needs no change);
- transmitter matching, which today reads the active profile directly through
  `validatedCurrentDiverIdProvider` and must take the chosen diver instead;
- duplicate detection (source keys and fuzzy matching) and planned-dive
  filling;
- the auto-tag and the logbook rules run after import (the wizard's
  `setDiverId` call, or `diverOutcomes`);
- the default tank preset for imported dives, including whether that diver has
  "also apply to imported dives" switched on (decision 4).

### What stays with the active profile

These are preferences of the person running the download, not facts about the
diver (the builder's call, confirmed in conversation):

- units shown on the review step;
- cylinder pressure at surfacing (applied during the download, before anyone
  is chosen);
- site-match sensitivity;
- whether a new import session is auto-tagged (the tag itself follows the
  chosen diver).

### Lookup

- A connected computer is looked up across all profiles, first by this
  device's address for it (before the download, enabling incremental download)
  and then by hardware identity (serial) once the download reports it. The
  repository's `findByBluetoothAddress` and `findByHardwareIdentity` already
  search every profile when given no `diverId`.
- When more than one record matches (a duplicate the old behaviour created),
  prefer the active profile's record, then the most recently updated. Without
  this rule a library with old duplicates would start filing a download under
  another profile's stale copy.
- A computer not found anywhere is created owned by the active profile, as
  today.
- The "last downloaded dive" marker belongs to the computer, not the person.
  If Bill downloads Mitchell's computer, Mitchell's next download from it picks
  up only the dives after that.
- The dives keep pointing at the owner's computer record even when another
  profile is chosen.

### First-sync cutoff (the builder's call)

When a computer has no stored "last downloaded dive" marker, the download step
offers a cutoff date whose default is the newest dive in a log, and dives at or
before it arrive on the review step already set to skip.

- The default comes from the profile the download will initially go to: the
  owner when the owner is known before the download and the switch is on,
  otherwise the active profile. In discovery mode the owner is often unknown
  until after the download, so the active profile's log is used there.
- Changing the profile on the review step does not move the cutoff. The date
  was shown to the person and accepted before the download, so it stays as
  chosen; they can still un-skip rows on the review step.

### After the import (the builder's call)

When the dives went to a profile other than the active one, the summary step
says where they went. The wizard reports the import through
`UnifiedImportResult.diverOutcomes`, which already drives the summary's "By
profile" section (it tells the person how to see dives in a profile that is
not active) and makes tagging and the logbook rules target that profile.
"View dives" therefore does not lead to an empty list without explanation.

### Entry points

Both ways into a download behave the same:

- scanning for a device (discovery, `_DiveComputerDiscoveryWizardRoute`);
- opening a computer's page and tapping Download (known-computer mode). The
  computer list is filtered to the active profile, but another diver's computer
  page is reachable from one of that diver's dives, from the transfer page and
  from the connections card.

In known-computer mode the owner is known before the download. In discovery
mode it may only become known after the download reads the serial (a device
that has never connected to that computer has no address for it). Either way it
is known by the review step, which is where the choice is made.

## The setting

- Lives in `ImportPreferencesGroup` (Settings > Data > Import options), beside
  the existing import switches.
- Stored per diver in `diver_settings` like the other import preferences, and
  read from the active profile's settings. A new boolean column, default true,
  needs a schema rung, the sync serializer, the settings conflict catalogue and
  the repository mappings, as the neighbouring switches have.
- Suggested copy (the builder may refine it): title "Add downloads to the
  computer's owner", subtitle "When a dive computer belongs to another
  profile, its dives go to that profile's log. You can change it on the review
  screen."

## Constraints

- All new strings go through the ARB files for every locale.
- Names in the message use the profile's display name.
- The project's file-size limits apply. `dive_computer_adapter.dart` is
  already over 1,000 lines, so new adapter logic goes in a part or helper
  file.
- Tests come first (TDD), per the repository's CLAUDE.md.

## Left to the builder

- How the adapter holds the active and chosen diver (for example an active id
  fixed at construction plus a mutable chosen id), and how the review step
  tells it about a change.
- How `DiveImportService`'s transmitter-matcher and default-tank loaders
  receive the chosen diver (for example a diver id parameter in place of
  reading the active profile).
- Whether the dropdown reuses or extracts the diver row from
  `diver_mapping_step.dart`.
- The exact schema version, which must be the next free one when the PR
  lands.
