# Settings > Data: one status per feature, carried into its page

Date: 2026-11-14
Release: v1.8.5
Builds on: [2026-10-17-settings-data-health-dashboard-design.md](2026-10-17-settings-data-health-dashboard-design.md)
(the health strip, #3390; row marks, #3394; row statuses, #3482)

## Intent

Settings > Data repeats the same status too often. A failed backup shows as
a red symbol in the horizontal strip, again as a red symbol on the attention
line under it (with the reason), and a third time as a red mark beside the
Backups row title, whose subtitle often repeats the same sentence. The strip
squeezes each symbol to a one-word label, so the colour has no words beside
it; the words live elsewhere.

The diver should see each feature's status once, as a colour with a full
sentence beside it, and then find that same colour on the item that causes
it when they open the feature's page. Today the pages underneath carry
almost none of it: only the Backup page's status line and a library tile
turn red, each in its own ad hoc way, and nothing points at a setting that
is off.

## Goals

1. Settings > Data shows each of the four features (Backups, Sync, Photos
   and videos, Shared libraries) once: the health symbol, the feature name,
   one sentence, a chevron.
2. The sentence beside an amber or red symbol says why it is that colour.
3. On each feature's page, every item with a problem carries the same
   colour, not only the item behind the headline.
4. The Data row and the page can never disagree: both read one evaluation.

## Non-goals

- New health rules or levels, with one exception (an unreachable photo
  store, section 4). Otherwise the rules in `backup_health.dart`,
  `sync_health.dart`, `media_health.dart` and `shared_library_health.dart`
  decide the same things they decide today.
- A healthy mark on page items. Pages mark problems only; green lives on the
  Data row.
- Changing Connected accounts, Change log or the Advanced rows.

## Anti-goals

- A row that jumps position with its severity. The order is fixed.
- Meaning carried by colour alone. Every mark keeps its glyph and a
  semantics label.
- A page mark and a Data row that tell different stories, or a page that
  shows two status colours for one thing.

## Approaches considered

**A. One evaluation reports every finding (chosen).** Each feature's health
evaluation returns all its findings. The headline the Data row shows is
picked from them with today's precedence. Page items look up their reasons
in the findings through one shared widget. Chosen because both views read
one list, so they cannot disagree.

**B. Each page checks its own items.** The Backup auto row reads
`settings.enabled` itself, and so on. Fewer shared files, but a second copy
of every rule, which is the drift #3482 was built to remove. Rejected.

For the Data page, merging the status section into the "Your data" rows was
chosen over keeping a vertical status list above rows that lose their marks:
the second keeps the words twice.

## Design

### 1. Findings in the health model

`FeatureHealth` stays the headline (feature, level, reason, when, count,
name) and gains `findings`: every problem the evaluation found, each with
its level, reason and the values its text needs. A library finding also
carries the library's id, so the Shared libraries page can mark the right
tile.

- The headline is exactly what each evaluator returns today. The existing
  evaluator tests pin it and must pass unchanged.
- Healthy and not set up have no findings.
- Backup: when automatic backups are off, the headline stays `backupAutoOff`
  (or `backupCloudSignIn`, as today). The findings are that one plus the
  copy findings (cloud copy missing, extra copy missing, no copy off this
  device). Schedule findings (failed, overdue, never backed up) are left out
  while the schedule is off: they describe a schedule that is not running.
- Sync: the custom folder and sync off early returns stay; each has only its
  own finding (custom folder has none). Otherwise every candidate today's
  list builds is a finding.
- Libraries: one finding per library that has failed or holds edits, each
  with that library's id and name. The headline keeps today's shape (first
  failure with the count, else first held library).
- Media: every candidate is a finding, including the new unreachable store
  (section 4).

- Backup extra copies (builder's call): one
  `backupExtraCopyMissing` finding per account that missed its copy, each
  with that account's id from `lastExtraCopyMissingIds`, so only those tiles
  are marked.
- Media finish setup (builder's call): the finding records whether the
  pending item is the media store (attach, reconnect, its account's sign-in)
  or Lightroom (its account's sign-in), so the mark lands on the row that
  item belongs to.

`LibraryHealthInput` gains the library id. A finding carries an optional
subject id (a library id or an account id) for these per-tile cases.

### 2. Settings > Data rows

The horizontal strip (`DataHealthStrip`) and its attention lines are
removed. The four feature rows under "Your data" become the status:

```
[ Set up this device card, while unfinished ]
12 dives · 4 sites · 30 media · 12 MB
----------------------------------------
Your data
 (x)  Backups                                   >
      Last backup failed 2h ago
 (x)  Sync                                      >
      Signed out of iCloud        [Sign in again]
 (-)  Photos & videos                           >
      Off · Set up
 (v)  Shared libraries                          >
      2 libraries, updated 5m ago
 [i]  Connected accounts                        >
 [i]  Change log                                >
Advanced ...
```

- The leading slot holds the `HealthSymbol` at list-icon size, in place of
  the feature icon. The title has no mark beside it.
- Order is fixed: Backups, Sync, Photos and videos, Shared libraries.
- Amber or red: the subtitle is the headline's reason sentence
  (`healthReasonText`). Green or not set up: today's status sentence
  (`dataRowStatusText`). The "Set up" action stays where it is offered today.
- Not set up shows the hollow dash. A photos-off row, which today hides its
  mark because Lightroom alone reads healthy, shows the hollow dash too.
- "Sign in again" moves from the attention line into its row, beside the
  sentence while it fits and under it on a narrow phone at large text, as
  the attention line does now.
- Semantics: the row reads its feature, level and sentence ("Backups, Needs
  attention, Last backup failed 2h ago") and stays one tappable button.
- Demo mode: rows are disabled as today and show their plain feature icons,
  since no status is evaluated for the user's real data.
- Layout above the rows: the Set up this device card, then the facts line,
  then the divider. The strip's slot is gone.
- Connected accounts, Change log and the Advanced rows are unchanged.

### 3. Marks on the feature pages

One shared widget marks an item when the feature's findings hold any of the
item's reasons: the `HealthSymbol` at 16 dp beside the item's title, in the
most severe matching level's colour, with a semantics label giving the level
and the reason sentence. Items with no matching finding look as they do
today.

The mark is the only status colour on a page (decided by the diver, option
C of three mocked up). Items that colour their own icon from what is
happening now keep the glyph and the words but drop the colour: the Sync
status card's icon (green after a sync, red on an error, orange with
conflicts), the Photos status line's red icon (unreachable, paused, finish
setting up), the Backup status line's red icon on a failure, and the
library tile's red icon on an error. A page therefore never shows a green
icon beside an amber mark.

So that an unreachable photo store does not lose its colour, it becomes a
health finding (section 4). Rejected alternatives: keeping the live-state
colours beside the marks (a green sync cloud above an amber mark, a red
Photos icon while the Data row says Photos is fine), and dropping the
colours without the new rule (an unreachable store would show no colour
anywhere).

### 4. New media finding: store unreachable

`HealthReason.mediaStoreUnreachable`, level attention, when a media store
is attached here and `photosStoreReachableProvider` reports false (the
runtime could not be built with this device's keys). Its sentence reuses
the Photos status line's existing text
(`settings_photos_status_unreachable(account)`, or
`settings_photos_status_pausedUnreachable` when the account has no label),
so no new strings. On the Photos page it marks the status line.

Cost, accepted: Settings > Data now watches the media store runtime while a
store is attached, which builds it if nothing else has (keychain read,
store build, queue drain). Today `mediaHealthInputsProvider` deliberately
avoids this. Not attached: nothing is watched, as today. While the runtime
is loading, the finding is absent (never reported as unreachable).

| Page | Item | Reasons |
| --- | --- | --- |
| Backup | Status line (`BackupStatusLine`) | failed, overdue, never |
| Backup | Back up automatically (`BackupAutoRow`) | auto off |
| Backup | Copy row (`BackupCopyRow`) | cloud copy missing, cloud sign-in, no copy off this device |
| Backup | Each extra copy tile (`BackupExtraCopyRows`) | that account's extra copy missing |
| Sync | "Sync using" row (`SyncUsingRow`) | sync off |
| Sync | Status card | signed out, needs passphrase, awaiting adoption, failed, offline, never synced, peers held |
| Sync | Conflicts section | conflicts |
| Sync | Keep in step switch | auto-sync off |
| Photos | "Using" row (`PhotosUsingRow`) | finish setup, for a media store item |
| Photos | Photo sources row | finish setup, for a Lightroom item |
| Photos | Status line (`PhotosStatusLine`) | transfers paused, store unreachable |
| Libraries | Each library tile | that library's failure or held edits |

Cloud sign-in on the Backup page (builder's call): the sign-in sentence
and the "Sign in again" button move from the status line to the Copy row,
which carries the mark. The status line goes back to its plain "last backed
up" sentence. The explanation, its mark and its action sit on one row.

## Constraints

- Text uses the shared `StatusColors` accents through `HealthSymbol`; no new
  colours.
- No new user-visible strings are expected: the sentences and level labels
  already exist. If a semantics label needs a new pattern, it goes in every
  ARB file.
- Files stay under the 800-line guard; the shared mark gets its own file.

## Left to the builder

- The exact shape of a finding (a small class, or `FeatureHealth` reused
  with a nullable library id) and where the shared mark widget lives.
- How the Sync status card hosts the mark (beside its title row).
- Removing `DataHealthStrip` and its tests, and moving the tests that read
  `dataHealth_attentionLine` to the rows.
