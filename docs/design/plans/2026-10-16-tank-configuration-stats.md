# Tank Configuration Statistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A "Tank configuration" card on the Insights Gas page that sorts every dive in scope into one base configuration and counts its extras, read only from existing tank data (issue #3421).

**Architecture:** A pure domain classifier decides each dive's configuration from its counted tanks, gas switches, dive mode and whether it has a profile. A repository part file loads those inputs in three scoped queries and folds them into counts. A provider feeds a card widget placed under Gas Mix.

**Tech Stack:** Flutter, Riverpod, Drift (custom SQL), ARB l10n.

**Spec:** `docs/design/specs/2026-10-16-tank-configuration-stats-design.md`

## Global Constraints

- No schema change, no new columns, no migration rung.
- Twin set by size: volume `>= 20.0` litres (`twinSetMinVolumeLiters`).
- Same gas: within `sameGasTolerancePct` (0.5) in O2 and in He, imported from `multi_cylinder_consumption.dart`, never a new constant.
- Starting-switch grace: `startingSwitchGraceSeconds` from `tank_usage_range.dart`.
- Scope: `DiveStatsScope` with `gas: false` (via `_diveFilter(filter, alias: 'd')`), plus the Insights filter.
- Every new user-facing string goes through `app_en.arb` and is translated into all 10 locale ARBs (ar, de, es, fr, he, hu, it, nl, pt, zh); `flutter gen-l10n` runs LAST.
- `insights_repository.dart` gets only a `part` line; the query lives in its own part file.
- No em-dashes anywhere, code comments included.

## Review Focus

1. A downloaded dive with two Back Gas tanks on different gases (air + EAN32, untouched) must read Single backmount, and not multi-gas when it has a profile and no switch. Pinned in Task 1.
2. A consolidated dive whose second computer left an unmatched copy of the cylinder must not read Twin backmount. Pinned in Task 2.
3. A twin-name matcher that fires on ordinary tank names ("AL80", "HP100", "Steel 12", "Dive 12", "D", "D123") would mislabel singles. Pinned in Task 1 with negative cases.
4. A dive excluded from gas statistics only must still be counted; one excluded from statistics must not. Pinned in Task 2.
5. Zero-count rows and an empty Extras group must not render as empty bars. Pinned in Task 3.

---

### Task 1: Domain classifier

**Files:**
- Create: `lib/features/insights/domain/tank_configuration/tank_configuration.dart` (enums, input, stats)
- Create: `lib/features/insights/domain/tank_configuration/tank_configuration_classifier.dart` (twin matcher, classify)
- Test: `test/features/insights/domain/tank_configuration/tank_configuration_classifier_test.dart`

**Interfaces:**
- Produces:
  - `enum TankBaseConfiguration { rebreather, sidemount, twinBackmount, singleBackmount, other, noTanks }`
  - `enum TankConfigurationExtra { stages, decoGas, multiGas }`
  - `class TankConfigurationDive` (immutable): `final DiveMode diveMode; final List<DiveTank> tanks; final List<({String tankId, int timestamp})> gasSwitches; final bool hasProfile;` with a const constructor, `gasSwitches` defaulting to `const []`.
  - `typedef TankConfigurationResult = ({TankBaseConfiguration base, Set<TankConfigurationExtra> extras});`
  - `const double twinSetMinVolumeLiters = 20.0;`
  - `bool looksLikeTwinSet(DiveTank tank)`
  - `TankConfigurationResult classifyTankConfiguration(TankConfigurationDive dive)`
  - `class TankConfigurationStats` (immutable, Equatable): `final int totalDives; final Map<TankBaseConfiguration, int> baseCounts; final Map<TankConfigurationExtra, int> extraCounts;`, `factory TankConfigurationStats.fromDives(Iterable<TankConfigurationDive> dives)` (maps hold only non-zero entries), `static const empty`.

- [ ] **Step 1: Write the failing tests.** Build `DiveTank`s with ids `t0`, `t1`, ... Helper `dive(tanks, {mode = DiveMode.oc, switches = const [], hasProfile = true})`. One test per line:
  - `no tanks` gives `noTanks`, extras `{}`.
  - `ccr mode with untagged tanks` gives `rebreather`.
  - `oc mode with a diluent tank` gives `rebreather`.
  - `diluent plus sidemountLeft` gives `rebreather` (precedence).
  - `one sidemountLeft tank` gives `sidemount`.
  - `sidemount pair plus a stage` gives `sidemount`, extras `{stages}`.
  - `two backGas at 21 and 21.3` gives `twinBackmount`.
  - `two backGas air and EAN32` gives `singleBackmount`.
  - `one backGas 24 L` gives `twinBackmount`; `18 L` gives `singleBackmount`; `null volume` gives `singleBackmount`.
  - `looksLikeTwinSet` is true for names `Twin 12`, `D12`, `d7`, `Doppel 10`, `Doubles 12`, `2x12`, `2 x 7`, `2×8.5`, `Manifold 12`, and for presetName `twin_12` and `d12` with a null name. It is false for `AL80`, `HP100`, `Steel 12`, `Dive 12`, `D`, `D123`, `ED12`, and a null name and preset.
  - `only a stage tank` gives `other`, `{stages}`; `only a pony` gives `other`, `{}`.
  - `backGas plus deco role` includes `decoGas`.
  - `air backGas with drop plus EAN50 deco switched to at 1800 s` includes `multiGas`.
  - `air plus EAN32 backGas, profile, no switches, no drops` excludes `multiGas` (Review Focus 1).
  - the same with `hasProfile: false` includes `multiGas` (fallback).
  - `sidemount pair on one gas, both with drops` excludes `multiGas`.
  - `ccr diluent air plus oxygenSupply 100` excludes `multiGas`.
  - `EAN32 vs 32.4, both with drops` excludes `multiGas`; `32 vs 33` includes it.
  - `fromDives` over four dives (sidemount, sidemount + stage, single, no tanks) gives `totalDives 4`, `baseCounts {sidemount: 2, singleBackmount: 1, noTanks: 1}`, `extraCounts {stages: 1}`.

- [ ] **Step 2: Run, expect compile failure.** `flutter test test/features/insights/domain/tank_configuration/`

- [ ] **Step 3: Implement.** Base configuration per the spec's ordered list. Twin backmount: any two Back Gas tanks satisfy `isMatchedPair`, or any Back Gas tank `looksLikeTwinSet`. Name matching lowercases and replaces `_` with a space, then checks `twin|double|doppel|manifold` as substrings, `2\s*[x×]\s*\d`, and `(?<![a-z0-9])d\d{1,2}(?![a-z0-9])`, on `name` and on `presetName`. Breathed cylinders for multi-gas, ignoring diluent and oxygenSupply:
  - a cylinder is breathed if `startPressure > endPressure` (both non-null), or a gas switch names it, or it is the starting cylinder;
  - the starting cylinder is the one named by the earliest switch at `timestamp <= startingSwitchGraceSeconds`, else `sacReferenceTankOf(tanks)`;
  - when `!hasProfile`, there are no switches and no tank has a drop, every tank is breathed.

  Multi-gas when two breathed mixes differ by more than `sameGasTolerancePct` in O2 or He.

- [ ] **Step 4: Run, expect PASS.** Same command.

- [ ] **Step 5: Commit** `feat(insights): classify dives by tank configuration`

### Task 2: Repository query

**Files:**
- Create: `lib/features/insights/data/repositories/insights_repository_tank_configuration.dart` (`part of 'insights_repository.dart';`)
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (one `part` line beside the others, plus the domain import)
- Test: `test/features/insights/data/repositories/insights_repository_tank_configuration_test.dart`

**Interfaces:**
- Consumes: Task 1's `TankConfigurationDive`, `TankConfigurationStats.fromDives`.
- Produces: `extension InsightsRepositoryTankConfiguration on InsightsRepository { Future<TankConfigurationStats> getTankConfigurationStats({String? diverId, DiveFilterState filter = const DiveFilterState()}) }`

- [ ] **Step 1: Write the failing tests.** Seed with Drift companions, as `insights_repository_multi_cylinder_sac_test.dart` does. Seed `dive_data_sources` and `dive_profile_series` rows the way the existing tests that touch them do. Tests:
  - `sorts dives into base configurations`: a sidemount pair, a single back gas, and no tanks gives totals 3 and the matching counts.
  - `leaves out excluded_from_stats but keeps excluded_from_gas_stats dives` (Review Focus 4).
  - `respects the insights filter`: one active filter axis narrows the count, using any axis `insights_repository_filter_test.dart` already seeds.
  - `counts only the primary computer's cylinders plus hand-added ones` (Review Focus 2). The dive has sources C1 (`is_primary = 1`) and C2. One air back-gas tank has `computer_id` C1 and an unmatched air copy has C2, giving `singleBackmount`. Adding a hand-added (null computer) stage tank gives the extra `stages`.
  - `a gas switch row marks a deco tank breathed`: a dive with a profile series row, air back gas and EAN50 deco, and a switch to the deco tank at 1500 s gives `multiGas`. Without the switch row, no `multiGas`.
  - `scopes to the diver` when `diverId` is given.

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement.** Three `customSelect`s, each scoped by `WHERE 1=1 $diverFilter ${df.clause}` on `dives d`:
  1. Dives: `d.id`, `d.dive_mode`, and `EXISTS (SELECT 1 FROM dive_profile_series s WHERE s.dive_id = d.id AND s.is_primary = 1) AS has_profile`.
  2. Tanks of those dives where `t.computer_id IS NULL OR NOT EXISTS (primary source with a computer on that dive) OR t.computer_id = (that source's computer_id)`.
  3. `gas_switches` (`dive_id`, `tank_id`, `timestamp`) of those dives.

  Map tank rows to `DiveTank` (role via `TankRole.values.byName` with a `backGas` fallback for unknown names; `GasMix(o2, he)`; volume, pressures, name and preset). Group by dive, then call `TankConfigurationStats.fromDives`. Use try/catch with `_log.error` and rethrow, like `getGasMixDistribution`. An unknown `dive_mode` falls back to `DiveMode.oc`.

- [ ] **Step 4: Run, expect PASS.** Also run `flutter test test/features/insights/data/repositories/`.

- [ ] **Step 5: Commit** `feat(insights): load tank configuration statistics`

### Task 3: Provider, card and Gas page (English strings)

**Files:**
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart`: add `tankConfigurationStatsProvider` beside `gasMixDistributionProvider`, with the same shape (`_keepAliveWithExpiry`, diver, filter).
- Modify: `lib/features/insights/presentation/widgets/horizontal_category_bar_chart.dart`: add an optional `String Function(int count)? formatCount`, defaulting to `count.toString()`.
- Create: `lib/features/insights/presentation/formatters/tank_configuration_labels.dart`: `String tankBaseConfigurationLabel(AppLocalizations l10n, TankBaseConfiguration c)` and `String tankConfigurationExtraLabel(AppLocalizations l10n, TankConfigurationExtra e)`.
- Create: `lib/features/insights/presentation/widgets/tank_configuration_card.dart`: `TankConfigurationCard extends ConsumerWidget`.
- Modify: `lib/features/insights/presentation/pages/insights_gas_page.dart`: place the card right after `_buildGasMixSection`, with the same spacing.
- Modify: `lib/l10n/arb/app_en.arb`: keys inserted by anchor line next to the `insights_gas_gasMix_*` group.
- Test: `test/features/insights/presentation/widgets/tank_configuration_card_test.dart`, plus one test in `insights_gas_page_widget_test.dart`.

**Interfaces:**
- Consumes: `getTankConfigurationStats`, `TankConfigurationStats`.
- Produces: `final tankConfigurationStatsProvider = FutureProvider<TankConfigurationStats>(...)`.

English strings (keys and exact copy):

| Key | Value |
| --- | --- |
| `insights_gas_tankConfig_title` | Tank configuration |
| `insights_gas_tankConfig_subtitle` | Dives by how the tanks were set up |
| `insights_gas_tankConfig_configurationHeading` | Configuration |
| `insights_gas_tankConfig_extrasHeading` | Extras |
| `insights_gas_tankConfig_rebreather` | Rebreather |
| `insights_gas_tankConfig_sidemount` | Sidemount |
| `insights_gas_tankConfig_twinBackmount` | Twin backmount |
| `insights_gas_tankConfig_singleBackmount` | Single backmount |
| `insights_gas_tankConfig_other` | Other |
| `insights_gas_tankConfig_noTanks` | No tanks logged |
| `insights_gas_tankConfig_stages` | Stage(s) |
| `insights_gas_tankConfig_decoGas` | Deco gas |
| `insights_gas_tankConfig_multiGas` | Multi-gas |
| `insights_gas_tankConfig_countAndPercent` | `{count} · {percent}` (count int, percent String) |
| `insights_gas_tankConfig_note` | Twin sets logged as one cylinder are counted when the name says so (twin, double, D12, 2x12) or the cylinder is larger than any common single tank. Set Sidemount Left and Right on a dive's tanks for it to count as sidemount. |
| `insights_gas_tankConfig_empty` | No dives to show |
| `insights_gas_tankConfig_error` | Unable to load tank configuration |

- [ ] **Step 1: Write the failing widget tests** (override `tankConfigurationStatsProvider`, `locale: Locale('en')`):
  - `shows configuration rows by count with count and percent`: stats with total 10 and sidemount 6, single 4. The first bar label is `Sidemount`, and the text `6 · 60%` is shown.
  - `hides zero rows` (Review Focus 5): no `Rebreather` text when its count is absent.
  - `hides the extras group when no dive has an extra`: no `Extras` text.
  - `shows extras as a share of all dives`: stages 3 of 10 gives `3 · 30%`.
  - `shows the note`: finds text containing `Sidemount Left and Right`.
  - `empty stats show the empty state`: `TankConfigurationStats.empty` gives `No dives to show`.
  - Gas page test `tank configuration card sits below gas mix`: the card's top is greater than the Gas Mix card's top.

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement.**
  - Use `StatSectionCard` with title and subtitle.
  - Each group is a small `labelMedium` heading followed by a `HorizontalCategoryBarChart` whose `formatCount` renders `countAndPercent`. Format the percent with `NumberFormat.percentPattern(locale)` of `count / totalDives`.
  - Configuration bars use `colorScheme.primary` and extras bars use `colorScheme.tertiary`, so both stay legible in dark mode.
  - Rows are sorted by count, descending.
  - The note sits below the bars in `bodySmall` with `onSurfaceVariant`.
  - Loading and error states match the Gas Mix section.
  - Run `flutter gen-l10n` once here to compile against the English keys. Task 4 regenerates.

- [ ] **Step 4: Run, expect PASS.** Also run `flutter test test/features/insights/` and `test/architecture/`.

- [ ] **Step 5: Commit** `feat(insights): show tank configuration card on the Gas page`

### Task 4: Translations

**Files:** `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` and the generated `app_localizations*.dart`.

- [ ] **Step 1:** Insert the 17 keys by anchor line next to each locale's `insights_gas_gasMix_*` keys. Match each locale's existing terms (Sidemount, Stage, Deco, back gas) from neighbouring keys, keep `{count}` and `{percent}` verbatim, and do not json round-trip.
- [ ] **Step 2:** Run `flutter gen-l10n`. Expect no new untranslated messages for these keys. Check `grep -A1 "get insights_gas_tankConfig_title" lib/l10n/arb/app_localizations_de.dart` shows German.
- [ ] **Step 3:** `git diff --numstat lib/l10n/arb/` shows identical per-locale insert counts.
- [ ] **Step 4: Commit** `i18n(insights): translate tank configuration card`

### Task 5: Finish

- [ ] **Step 1:** `dart format .`, `flutter analyze`, `flutter test test/features/insights/ test/architecture/ test/shared/`. All green.
- [ ] **Step 2:** After screenshots with the throwaway harness (not committed): Gas page light, dark, desktop and phone, with sample stats showing every row type.
