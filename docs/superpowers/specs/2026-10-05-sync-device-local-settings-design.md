# Persist certification and course view modes; sync viewport and pSCR settings

Issue: #2948 (from discussion #1334). Depends on #2946, fixed by #2963.

## Problem

Most "what to show" preferences already live in `diver_settings` and sync.
The remaining gaps:

- The certification and course list view modes are in-memory
  `StateProvider`s that reset to detailed on every restart. Every other list
  stores its view mode in `diver_settings`.
- "Profile metrics follow viewport" and the pSCR ratio are device-local
  (SharedPreferences), although neither depends on the device.

## Decisions

| Setting | Decision | Reason |
| --- | --- | --- |
| Certification list view mode | Persist in `diver_settings` (syncs) | A clear gap; matches every other list |
| Course list view mode | Persist in `diver_settings` (syncs) | Same |
| Profile metrics follow viewport | Move to `diver_settings` (syncs) | A viewing preference with no screen-size dependency |
| pSCR ratio | Move to `diver_settings` (syncs) | Describes the diver's pSCR unit, belongs with the other deco settings |
| Home layout (hidden chips, card order, hidden cards) | Stays device-local | Phone and desktop show different amounts of the dashboard |
| O2 cell unit, Perdix overlay | Stays device-local | Out of scope; the overlay position is screen-specific |

## Data model (schema v262)

One rung adds four `diver_settings` columns, re-asserted by the
`before_open.dart` backstop:

| Column | Type |
| --- | --- |
| `certification_list_view_mode` | `TEXT NOT NULL DEFAULT 'detailed'` |
| `course_list_view_mode` | `TEXT NOT NULL DEFAULT 'detailed'` |
| `profile_metrics_follow_viewport` | `INTEGER` nullable |
| `pscr_ratio` | `REAL` nullable |

- A null in a nullable column means the row has never held a value. It drives
  the one-time adoption below.
- `_mapRowToAppSettings` maps null to the current defaults (`false`, `100.0`),
  so `AppSettings` keeps non-nullable `bool` and `double` fields.
- `_storedColumns` includes all four columns, so the partial-write diff
  (#2963) covers them. `createSettingsForDiver` writes the two view modes and
  leaves the two nullable columns null.
- `minimumCompatibleSchemaVersion` stays 240 (additive change).

## Sync

- Export needs no change (`row.toJson()` carries the new columns).
- Import: `_withSchemaDefaults` fills the two NOT NULL view modes for payloads
  from older versions; they are also added to `_applyDiverSettingDefaults`
  following the house convention.
- A payload from an older version omits the two nullable columns, and the
  import keeps this device's value for an omitted key. An explicit null in
  either of them is treated the same way: null means "never held a value",
  so it carries no choice and must not clear a value this device holds.

## Adoption of the existing device-local values

Rule: **a diver row with no value adopts this device's pref if it differs
from the default, otherwise it reads the default.** This covers every diver
that exists at upgrade, divers created later on the device, and a value set
while no diver existed.

Revised after the final review: before v262 every save wrote both prefs, so
almost every device holds pSCR 100 and viewport off without the diver having
chosen them. Adopting such a value would stamp a fresh clock on the whole row,
so the device upgraded last would overwrite a ratio chosen on another device
(and its stale copies of every other setting would win too). A default-valued
pref is therefore never adopted; the column stays null and reads the default.

- **Load with a diver.** Before `getOrCreateSettingsForDiver`, a repository
  probe reports which of the two nullable columns are null for this diver
  (mirroring `hasSeascapeAppearance`). For each null column whose pref differs
  from the default, the value is written through immediately so it syncs. The
  write bypasses the save diff (which cannot see a change in a null column)
  and fills a column only while it is still null, so a value a sync applied
  after the probe wins; the load then re-reads the row.
- **The prefs are not removed**, so every other diver on the device can adopt
  them too.
- **A column that holds a value always wins** over the pref.
- **Load with no diver.** Unchanged: the prefs are the store.
- **Save.** The two prefs are written only while no diver exists. With a
  diver, the row is the single source of truth, so a stale pref cannot
  resurrect a value changed on another device.
- **Synced reload.** Both fields are removed from `_withDeviceLocalPrefs`, so
  a synced change from another device shows on this one.

## Certification and course view modes

The same chain as the six existing lists:

- `AppSettings.certificationListViewMode` and `courseListViewMode` (default
  `detailed`), with `copyWith` and the repository mapping (insert,
  `_storedColumns`, row mapping).
- `SettingsNotifier.setCertificationListViewMode` and
  `setCourseListViewMode`, also added to the two test fakes that implement
  `SettingsNotifier` without `noSuchMethod` (`test/helpers/mock_providers.dart`,
  `test/features/insights/presentation/pages/records_page_test.dart`).
- `certificationListViewModeProvider` and `courseListViewModeProvider` are
  seeded once from `ref.read(settingsProvider)`, with the same contract as
  `tripListViewModeProvider`.
- Settings > Appearance > section page persists them through the new setters
  and updates the session provider; `_getCurrentViewMode` reads them from
  `settingsProvider`.
- The in-list overflow menu stays session-only, as for every other list.
- Modes stay detailed and table only. `ListViewMode.fromName` falls back to
  `detailed` for any other stored value.

## Testing

- **Migration** (`migration_v262_*_test.dart`, v237 template): ladder
  membership and order, unchanged sync floor, fresh-database column
  definitions, a v260 database gains the columns, the backstop restores them.
  The v260 test's exact version assertion relaxes to `>= 260`.
- **Repository**: round trip of the four fields; null maps to `100.0` and
  `false`; the null-column probe.
- **Notifier adoption** (seascape test pattern): an empty row adopts the pref
  and writes it; a pref equal to the default is not adopted; a stored value wins
  over a stale pref; a second diver also adopts; a new diver adopts; with a
  diver the setters write the row and not prefs; with no diver the prefs stay
  the store.
- **Sync**: all four columns export and re-import unchanged; an older payload
  without them applies, view modes default to `detailed`, nullable columns
  null.
- **Sync reload** (`settings_sync_reload_test.dart`): the "pSCR survives a
  synced reload" assertion flips to "a synced pSCR and viewport change shows
  on the receiving device".
- **Widgets**: the section appearance page persists the certification and
  course modes; both list providers seed from settings.
