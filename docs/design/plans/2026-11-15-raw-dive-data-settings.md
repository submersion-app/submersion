# Raw Dive Computer Data in Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move raw dive computer data discard off the dive computer pages onto
a new Settings > Data > Advanced > Data tools > Raw dive computer data page,
with discard all and per-computer discard.

**Architecture:** `RawDiveDataService` gains a per-computer usage query; a
provider exposes it; a new settings page lists the total (existing
`rawDiveDataUsageProvider`) and the breakdown, each action going through the
existing `confirmAndDiscardRawDiveData`. The Dive Computers list tile and the
per-computer button on a computer's page are removed with their now-unused
code.

**Tech Stack:** Flutter, Riverpod, Drift (custom SQL), go_router, ARB l10n.

**Spec:** `docs/design/specs/2026-11-15-raw-dive-data-settings-design.md`
(issue #4590)

## Global Constraints

- What a discard does, its dialogs and their messages do not change.
- Library-wide scope: every diver's data, as `getUsage()` and `discard()`
  already are.
- The tool row shows on every platform (no `web_unavailable_routes` entry).
- New strings go into all 11 ARB files, translated; plural strings use
  `one{...}` / `other{...}` with `{count}` in each branch (never a literal
  digit in `=1{}`). Regenerate with `flutter gen-l10n`.
- No em-dashes anywhere, no emojis.

## Review Focus

- A source whose `computer_id` points at no `dive_computers` row (sync order,
  deleted computer): must fold into the single Unknown computer row, not
  produce one row per dangling id. Test in Task 1.
- A dive recorded by two computers: counts once in each computer's row and
  once in the total, matching `getUsage`. Test in Task 1.
- A computer with an empty `name`: the row names it by manufacturer and
  model, as `DiveComputer.displayName` does. Test in Task 1.
- The breakdown refreshes after a discard (rows disappear, total shrinks)
  without leaving the page. Provider watches `dive_data_sources`; Task 2
  asserts the provider is invalidated by a table update.
- No raw data at all: the page shows the empty sentence and no buttons.
  Test in Task 2.

---

### Task 1: Per-computer usage query

**Files:**
- Modify: `lib/features/dive_computer/data/services/raw_dive_data_service.dart`
- Modify: `test/helpers/fake_raw_dive_data_service.dart`
- Test: `test/features/dive_computer/data/services/raw_dive_data_service_test.dart`

**Interfaces:**
- Produces:
  `typedef ComputerRawDiveDataUsage = ({String? computerId, String? name, int diveCount, int storedBytes});`
  (`computerId` and `name` both null for the Unknown computer row) and
  `Future<List<ComputerRawDiveDataUsage>> RawDiveDataService.getUsageByComputer()`.
  Order: known computers by name (case-insensitive), the unknown row last.
- Fake: `List<ComputerRawDiveDataUsage> byComputer = const [];` returned by
  the fake's `getUsageByComputer()`.

- [ ] **Step 1: Write the failing tests** in a new `group('getUsageByComputer')`
  using the file's `seedLibrary`, `seedMultiSourceDive`, `seedComputer`,
  `seedSource`:
  - `'lists each computer holding raw bytes, the deleted one last as unknown'`:
    after `seedLibrary()`, result ids are `['c1', 'c2', null]`, dive counts
    `[2, 1, 1]`, every `storedBytes > 0`, last row `name` is null.
  - `'counts a dive recorded by two computers under each'`: after
    `seedMultiSourceDive()`, two rows each with `diveCount == 1`.
  - `'folds sources whose computer row is missing into one unknown row'`:
    seed sources with `computerId: null` and with `computerId: 'gone'` while
    foreign keys are off for the insert (`PRAGMA foreign_keys = OFF` then ON);
    expect exactly one row with `computerId == null` and `diveCount == 2`.
  - `'names a computer with no name by its maker and model'`: insert a
    computer with `name: ''`, `manufacturer: 'Shearwater'`, `model: 'Teric'`
    and a raw source; row `name == 'Shearwater Teric'`.
  - `'is empty when no source holds raw bytes'`.
- [ ] **Step 2:** Run `flutter test test/features/dive_computer/data/services/raw_dive_data_service_test.dart`; expect compile failure on the missing method.
- [ ] **Step 3: Implement** `getUsageByComputer()`: one `customSelect` over
  `dive_data_sources s LEFT JOIN dive_computers c ON c.id = s.computer_id
  WHERE s.raw_data IS NOT NULL GROUP BY c.id`, selecting `c.id`, `c.name`,
  `c.manufacturer`, `c.model`, `COUNT(DISTINCT s.dive_id)`,
  `COALESCE(SUM(LENGTH(s.raw_data)), 0)`, `readsFrom` both tables. Name in
  Dart: `name` if non-empty, else the `DiveComputer.fullName` rule
  (manufacturer + model, then either, then `name`). Sort in Dart. Add the
  fake's override.
- [ ] **Step 4:** Rerun the test file; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): count raw dive data per computer`.

### Task 2: Raw dive computer data page and its route

**Files:**
- Modify: `lib/features/dive_computer/presentation/providers/raw_dive_data_providers.dart`
- Create: `lib/features/settings/presentation/pages/raw_dive_data_page.dart`
- Modify: `lib/features/settings/presentation/pages/data_tools_page.dart`
- Modify: `lib/core/router/app_router.dart` (beside `reparse-dives`)
- Modify: all `lib/l10n/arb/app_*.arb`, regenerated `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/settings/presentation/pages/raw_dive_data_page_test.dart`
- Test: `test/features/settings/presentation/pages/data_tools_page_test.dart`

**Interfaces:**
- Consumes: Task 1's `getUsageByComputer()`; existing
  `rawDiveDataUsageProvider`, `confirmAndDiscardRawDiveData(context, ref, {required String message, String? computerId})`, `formatBytes`.
- Produces: `rawDiveDataByComputerProvider`
  (`FutureProvider<List<ComputerRawDiveDataUsage>>`, invalidated on
  `dive_data_sources` and `dive_computers` table updates, like
  `rawDiveDataUsageProvider`); `class RawDiveDataPage extends ConsumerWidget`;
  route `/settings/raw-dive-data`, name `rawDiveData`.
- Keys: `raw_dive_data_discard_all` on Discard all,
  `raw_dive_data_discard_<computerId>` on each computer's Discard.
- Strings (en; group them beside the `settings_reparseDives_*` keys):
  - `settings_rawDiveData_subtitle`: "See and discard the download data kept for re-parsing dives"
  - `settings_rawDiveData_discardAll`: "Discard all"
  - `settings_rawDiveData_byComputer`: "By dive computer"
  - `settings_rawDiveData_unknownComputer`: "Unknown computer"
  - `settings_rawDiveData_none`: "No dives keep raw dive computer data."
  - `settings_rawDiveData_computerUsage`: "{count, plural, one{{count} dive, {size}} other{{count} dives, {size}}}" (count int, size String)
  - Page title reuses `diveComputer_rawData_tileTitle`; the total line reuses
    `diveComputer_rawData_tileSubtitle`; per-row button reuses
    `diveComputer_rawData_discardAction`; dialogs reuse
    `diveComputer_rawData_discardAllMessage` and
    `diveComputer_rawData_discardComputerMessage`.

- [ ] **Step 1: Write the failing page tests** (`testApp` helper with
  `FakeRawDiveDataService` and provider overrides, as
  `raw_dive_data_discard_test.dart` does):
  - `'shows the total and each computer, the unknown one without a Discard'`:
    usage `(diveCount: 4, storedBytes: 4096)`, byComputer c1 (Perdix, 3,
    3072) and unknown (1, 1024); expect the total sentence
    "4 dives, 4.0 KB. Kept so these dives can be re-parsed when the parser
    improves.", "Perdix", "3 dives, 3.0 KB", "Unknown computer",
    "1 dive, 1.0 KB", key `raw_dive_data_discard_c1` found, two Discard
    buttons in total (all + c1).
  - `'Discard all confirms with the every-computer message and discards everything'`:
    dialog text contains "from every dive computer (4.0 KB)"; after
    confirming, `service.calls == [null]` and the snackbar
    "Discarded raw data for 3 dives" shows.
  - `'a computer\'s Discard names it and discards only its data'`: dialog
    contains "from Perdix"; `service.calls == ['c1']`.
  - `'cancelling discards nothing'`: `service.calls` empty.
  - `'with no raw data says so and offers no action'`: usage zero, empty
    list; "No dives keep raw dive computer data." shown, no `FilledButton`
    / `TextButton` labelled Discard.
- [ ] **Step 2: Extend `data_tools_page_test.dart`:** add
  `'/settings/raw-dive-data'` to the stub routes; test
  `'Raw dive computer data opens its page, in a browser too'` taps the
  "Raw dive computer data" row and finds `page /settings/raw-dive-data`,
  once natively and once with `browser: true`.
- [ ] **Step 3:** Run both test files; expect FAIL.
- [ ] **Step 4: Implement** the provider, the ARB keys in all 11 locales
  (translated), `flutter gen-l10n`, the page (a `ListView` with the total
  sentence and an outlined error-coloured Discard all button, a section
  header, then a `ListTile` per computer whose trailing is a `TextButton`
  Discard, absent on the unknown row; empty state when total `diveCount` is
  0), the route, and the Data tools row (`Icons.memory`, after Re-parse dives,
  not gated on `canReparse`).
- [ ] **Step 5:** Rerun both test files; expect PASS.
- [ ] **Step 6: Commit** `feat(settings): raw dive computer data page in Data tools`.

### Task 3: Remove discard from the dive computer pages

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_list_page.dart` (drop `RawDiveDataTile` and its import)
- Modify: `lib/features/dive_computer/presentation/widgets/dive_computer_actions_card.dart` (drop the `discard_raw_data_button` `Align` and the import)
- Modify: `lib/features/dive_computer/presentation/widgets/raw_dive_data_discard.dart` (delete `RawDiveDataTile` and `confirmAndDiscardComputerRawDiveData`; keep `confirmAndDiscardRawDiveData`; logger `forClass` moves to a name that still exists)
- Modify: `test/features/dive_computer/presentation/widgets/raw_dive_data_discard_test.dart` (tile tests go; the dialog flow is covered by Task 2's page tests, so delete the file if nothing remains)
- Modify: `test/features/dive_computer/presentation/widgets/dive_computer_controls_raw_data_test.dart`
- Modify: `test/helpers/fake_raw_dive_data_service.dart` (drop `usage`, `usageRequests`, `usageFailure` if no test uses them; keep `getUsage` returning zero)
- Modify: `docs/user/settings.md` (Data tools list), `docs/user/dive-computer.md` if it mentions discard

- [ ] **Step 1: Rewrite the controls test** to pin the removal:
  `'a computer\'s page offers no raw data discard'`: with counts
  `(withRawData: 5, withoutRawData: 0)`, the Re-parse all button shows and
  `find.byKey(ValueKey('discard_raw_data_button'))` and
  `find.text('Discard raw data')` find nothing. Delete the old discard tests.
- [ ] **Step 2:** Run it; expect FAIL (the button is still there).
- [ ] **Step 3: Implement** the removals listed above, and the user docs line
  for the new tool.
- [ ] **Step 4:** Run `flutter analyze`, the controls test,
  `test/features/dive_computer/presentation/`, `test/features/settings/presentation/pages/`,
  and `test/architecture/`; expect all PASS and no analyzer issues (an unused
  ARB key for `diveComputer_rawData_discardButton` stays only if a guard
  allows it; otherwise remove it from all locales).
- [ ] **Step 5: Commit** `feat(dive-computer): move raw data discard to Settings > Data`.
