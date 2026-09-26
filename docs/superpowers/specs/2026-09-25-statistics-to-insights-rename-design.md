# Rename the Statistics section to Insights

Issue: not yet filed. An umbrella issue ("Insights: broaden the Statistics
section") and a phase-1 issue for this rename are opened before the PR.

## Problem

The Statistics section has outgrown its name. The equipment page already shows
condition findings (drawn with `Icons.insights_outlined`), which are
interpretation rather than counts, and planned work points the same way: the
Connections explorer (#2321), on-device natural-language search (#2195), and
derived observations such as "your SAC improved 12% this year". "Statistics"
promises charts and tables; the section is becoming the place where the app
tells a diver what their log means.

## The Insights program

The broader scope splits into four sub-projects. This spec covers only the
first.

| # | Sub-project | Shape |
| --- | --- | --- |
| 1 | The rename (this spec) | Visible strings in 11 locales, icon, routes, folders, code names, l10n keys |
| 2 | Surface existing findings | Redesign the Insights landing page so findings and trends lead, not a category list. Own spec. |
| 3 | Home for upcoming features | Revise the specs of Connections (#2321), NL search (#2195) and similar programs to live under Insights. Mostly spec work. |
| 4 | Derived observations | New subsystem: rules that turn statistics into sentences, significance, ranking, dismissal. Own spec. |

Sub-project 1 lands first and alone, because 2 and 4 would otherwise build on
paths that are about to move.

## Decisions

- The rename covers internals as well as visible text: routes, folders, file
  names, classes, providers and l10n keys all move from "statistics" to
  "insights".
- The dive-level "Exclude from statistics" wording stays. Those flags decide
  whether a dive counts in the numbers, so "statistics" is still the accurate
  word.
- The persisted nav id changes from `'statistics'` to `'insights'`, with a
  read-time alias so a stored `'statistics'` keeps its position.
- The l10n key rename lands in the same PR as its own scripted commit.
- Translations use the literal word for "insights" where it is the natural
  product term, and the word for "analysis" where the literal one is awkward.
- The nav icon becomes `Icons.insights`.

## Approach

A Python script, `scripts/rename_statistics_to_insights.py`, carries an
explicit rename table (paths, identifiers, route strings, l10n keys). It runs
`git mv` for folders and files and rewrites only the identifiers in the table.
Anything not in the table is left alone, which is what protects the names that
must stay (see "What stays").

A blanket `Statistics` to `Insights` replace is rejected: outside the feature,
"statistics" is still correct in the dive-level exclusion code, the field
category, other features' "Dive Statistics" labels and the Excel export.

An IDE rename per symbol is rejected because it cannot be replayed. If main
moves under the branch, the script is rerun rather than the merge being done
by hand.

The script has a `--check` mode that exits non-zero if any old name from the
table still appears under `lib/` or `test/`, ignoring the stay list.

## Commit structure

One PR, five commits:

1. **Nav id alias (TDD).** Tests first, then the alias in `normalizeNavOrder`.
2. **Code rename.** The script plus its output: paths, identifiers, routes,
   string ids, imports.
3. **l10n key rename.** The script renames keys and their `@` metadata entries
   in all 11 ARB files and at every call site, then `flutter gen-l10n`
   regenerates. Values are not touched.
4. **Visible changes.** English and translated values for the section name, and
   the icon switch.
5. **Docs.** User guide, sidebar, README, developer docs.

## The nav id alias

`nav_primary_ids` and `nav_rail_ids` store the user's nav order as a list of
destination ids, and `nav_primary_ids` syncs across devices. Both are read and
written through `NavOrderNotifier`
(`lib/shared/widgets/nav/nav_order_provider.dart`), which calls
`normalizeNavOrder` (`lib/shared/widgets/nav/nav_destinations.dart`) on load and
on save. `normalizeNavOrder` drops ids it does not recognise and appends
missing ones in canonical order, so an unbridged rename would move Insights to
its default slot for every user who reordered their nav.

The alias maps `'statistics'` to `'insights'` inside `normalizeNavOrder`,
before the recognised-id check. The stored value is never rewritten on read;
the next save simply writes `'insights'`.

Older builds on synced devices are covered by writing both ids. Every save
goes through `withLegacyNavIds`, which writes each renamed id's old id right
after it (`['equipment', 'insights', 'statistics', 'buddies']`). A build from
before the rename drops the unknown `'insights'` and finds `'statistics'` in
the same slot; this build reads `'statistics'` as `'insights'` and drops it as
a duplicate. The extra write goes away with its `kRenamedNavIds` entry once no
supported build predates the rename. (The first draft of this spec accepted
the older-build gap; review of the PR changed that decision.)

`lib/shared/widgets/nav/nav_id_aliases.dart` is the only place in `lib/` where
the literal `'statistics'` nav id survives.

## Rename table

### Paths

| Old | New |
| --- | --- |
| `lib/features/statistics/` | `lib/features/insights/` |
| `test/features/statistics/` | `test/features/insights/` |
| `statistics_repository.dart` | `insights_repository.dart` |
| `statistics_{page,overview,gas,progression,conditions,social,geographic,marine_life,time_patterns,equipment,profile}_page.dart` | `insights_*` |
| `statistics_{providers,filter_provider,gas_lane_provider}.dart` | `insights_*` |
| `statistics_{filter_action,filter_bar,list_content}.dart` | `insights_*` |
| `species_statistics.dart` | `species_insights.dart` |
| `equipment_condition_statistics_providers.dart` | `equipment_condition_insights_providers.dart` |
| Test files, by the same token rule | e.g. `insights_repository_sac_test.dart`, `filtered_insights_attr_refresh_test.dart`, `species_insights_test.dart` |

`statistics_repository_site_dive_statistics_test.dart` becomes
`insights_repository_site_dive_statistics_test.dart`: the trailing
`site_dive_statistics` names `SiteDiveStatistics`, which stays.

### Code names

| Old | New |
| --- | --- |
| `StatisticsRepository`, `statisticsRepositoryProvider` | `InsightsRepository`, `insightsRepositoryProvider` |
| `StatisticsPage`, `StatisticsMobileContent`, `StatisticsListContent` | `InsightsPage`, `InsightsMobileContent`, `InsightsListContent` |
| `Statistics{Overview,Gas,Progression,Conditions,Social,Geographic,MarineLife,TimePatterns,Equipment,Profile}Page` | `Insights*Page` |
| `StatisticsCategory`, `_StatisticsCategoryTile`, `statisticsCategoriesOf` | `InsightsCategory`, `_InsightsCategoryTile`, `insightsCategoriesOf` |
| `StatisticsFilterBar`, `StatisticsFilterAction`, `statisticsFilterProvider` | `InsightsFilterBar`, `InsightsFilterAction`, `insightsFilterProvider` |
| `statisticsGasLaneProvider`, `statisticsGasLaneOverrideProvider` | `insightsGasLaneProvider`, `insightsGasLaneOverrideProvider` |
| `statisticsFilteredDiveIdsProvider` | `insightsFilteredDiveIdsProvider` |
| `SpeciesStatistics`, `speciesStatisticsProvider`, `getSpeciesStatistics` | `SpeciesInsights`, `speciesInsightsProvider`, `getSpeciesInsights` |
| `watchStatisticsChanges` | `watchInsightsChanges` |

### Routes and string ids

| Old | New |
| --- | --- |
| `/statistics`, `/statistics/:id` | `/insights`, `/insights/:id` |
| Route names `statistics`, `statisticsOverview`, `statisticsGas`, `statisticsProgression`, `statisticsConditions`, `statisticsSocial`, `statisticsGeographic`, `statisticsMarineLife`, `statisticsTimePatterns`, `statisticsEquipment`, `statisticsProfile` | `insights`, `insightsOverview`, ... |
| Nav destination id, `sectionId`, `featureId` | `'insights'` |
| `'statistics'` keys in `feature_accent_colors.dart` (light and dark) | `'insights'` |
| `ValueKey('statistics-filter-action')`, `Key('statistics-excluded-footnote')` | `insights-filter-action`, `insights-excluded-footnote` |

Every in-app `context.go('/statistics')` and route list moves with it:
`app_shortcuts.dart`, `quick_actions_card.dart`, `dive_summary_widget.dart`,
`finish_step.dart`. No redirect from `/statistics` is kept: nothing outside the
app links to it (no app-links or home-widget package).

`/records` is a separate top-level route and does not move.

### l10n keys

All 363 `statistics_*` keys become `insights_*`, with their `@statistics_*`
metadata entries. Every locale currently holds all of them (each ARB file
changed 369 key lines, the 363 plus the six below), but the script still
renames whichever keys each file actually holds rather than assuming every key
is present, so a locale that later falls back to English for a key is handled.
Six keys outside that prefix also name the section:

| Old | New |
| --- | --- |
| `nav_statistics` | `nav_insights` |
| `dashboard_quickActions_statistics` | `dashboard_quickActions_insights` |
| `dashboard_quickActions_statisticsTooltip` | `dashboard_quickActions_insightsTooltip` |
| `accessibility_shortcut_goToStatistics` | `accessibility_shortcut_goToInsights` |
| `setup_finish_feature_statistics` | `setup_finish_feature_insights` |
| `diveLog_summary_action_viewStats` | `diveLog_summary_action_viewInsights` |

Key suffixes that repeat the word follow it: `insights_error_loadingStatistics`
becomes `insights_error_loadingInsights`, and
`insights_tooltip_refreshStatistics` becomes `insights_tooltip_refreshInsights`.

## What stays

The rule: rename a name when "Statistics" refers to the feature; keep it when
the name is built around a type that another feature owns.

- **Types owned elsewhere, and names built on them:** `DiveStatistics`,
  `diveStatisticsProvider`, `getStatistics` (dive_log); `SiteDiveStatistics`
  (dive_sites), `getSiteDiveStatistics`, `filteredDiveStatisticsProvider`;
  `DiveTypeStatistic`, `TagStatistic`, `SiteTypeStatistic`.
- **Dive-level exclusion:** `lib/core/database/dive_stats_scope.dart`, the
  `excluded_from_stats` columns, `StatisticsSection` in
  `dive_log/presentation/widgets/edit_sections/statistics_section.dart` and its
  `'statistics'` expander id in `dive_edit_page.dart`, every
  `diveLog_*ExcludeFromStats*` key and value, `diveLog_edit_group_statistics`,
  and the excluded-from-statistics badge and filter icons in
  `dive_list_page.dart` and `dive_filter_sheet.dart`.
- **Field category:** the `'statistics'` category in `TripField`,
  `BuddyField` and `entity_field.dart`, with `enum_fieldCategory_statistics`.
- **Other features' labels:** `buddies_section_diveStatistics`,
  `buddies_error_unableToLoadStats`, `diveSites_detail_section_diveStatistics`,
  `divers_detail_diveStatisticsTitle`, `trips_detail_sectionTitle_statistics`,
  `marineLife_speciesDetail_sightingStatsTitle`,
  `diveComputer_detail_statisticsTitle`, `maps_offline_cacheStatistics`, and the
  dashboard stats-bar keys.
- **Also:** the Excel export's `Statistics` sheet, historical code comments
  (such as the retired `statisticsVersionProvider`), and existing specs, plans
  and release notes.

## Localisation

### English values

Thirteen values name the section and change. Three describe numbers or the
dive-level exclusion and stay.

| Key (new name) | Old value | New value |
| --- | --- | --- |
| `nav_insights` | Statistics | Insights |
| `insights_appBar_title` | Statistics | Insights |
| `dashboard_quickActions_insights` | Statistics | Insights |
| `accessibility_shortcut_goToInsights` | Go to Statistics | Go to Insights |
| `diveLog_summary_action_viewInsights` | View Statistics | View Insights |
| `dashboard_quickActions_insightsTooltip` | View dive statistics | View dive insights |
| `setup_finish_feature_insights` | Explore statistics about your diving | Explore insights about your diving |
| `insights_summary_header_title` | Statistics Overview | Insights Overview |
| `insights_summary_header_subtitle` | Select a category to explore detailed statistics | Select a category to explore detailed insights |
| `insights_categoryCard_semanticLabel` | {title} statistics category | {title} insights category |
| `insights_tooltip_filter` | Filter statistics | Filter insights |
| `insights_tooltip_refreshInsights` | Refresh statistics | Refresh insights |
| `insights_error_loadingInsights` | Error loading statistics | Error loading insights |

Unchanged: `insights_timePatterns_surfaceInterval_title` ("Surface Interval
Statistics"), `insights_summary_tagUsage_emptyHint` ("Add tags to dives to see
statistics"), `insights_excludedDivesFootnote` ("... dives excluded from
statistics").

The landing header title and subtitle are placeholders until sub-project 2
redesigns that page.

### Section name per locale

| Locale | Old | New | Kind |
| --- | --- | --- | --- |
| de | Statistiken | Einblicke | literal |
| es | Estadísticas | Análisis | analysis |
| fr | Statistiques | Analyses | analysis |
| it | Statistiche | Analisi | analysis |
| pt | Estatísticas | Análises | analysis |
| nl | Statistieken | Inzichten | literal |
| hu | Statisztikák | Elemzések | analysis |
| ar | الإحصائيات | الرؤى | literal |
| he | סטטיסטיקות | תובנות | literal |
| zh | 统计 | 洞察 | literal |

Each of the thirteen values is rewritten in every locale with that locale's
term inflected into the sentence, not substituted word for word. The three
unchanged values keep their existing translations. Native-speaker review is
requested on the PR.

## Icon

- Nav destination: `Icons.bar_chart_outlined` / `Icons.bar_chart` become
  `Icons.insights_outlined` / `Icons.insights`.
- Entry buttons: the dashboard quick action (`quick_actions_card.dart`) and the
  dive-log summary's "View Insights" button (`dive_summary_widget.dart`) switch
  to `Icons.insights`.
- The excluded-from-statistics badge, filter and dive-edit group keep
  `Icons.bar_chart_outlined`.

The equipment condition findings card already uses `Icons.insights_outlined`;
after the rename it matches the section, which suits sub-project 2.

## Docs

- `docs/guide/statistics.md` becomes `docs/guide/insights.md`; `_sidebar.md` and
  `docs/guide/README.md` follow.
- README: the "Statistics & Records" feature section and the `statistics/`
  entry in the project tree. The `07-statistics.jpg` screenshot keeps its file
  name until it is retaken.
- Developer docs that name the folder or route: `docs/developer/navigation.md`,
  `docs/developer/architecture.md`, `docs/ARCHITECTURE.md`.
- Historical specs, plans and release notes are not edited.

## Testing

- **Alias (TDD), in the `normalizeNavOrder` tests:**
  - a stored `'statistics'` normalizes to `'insights'` in the same position;
  - a stored order holding both `'statistics'` and `'insights'` yields one
    `'insights'`, at the first position;
  - unknown ids are still dropped and missing ids still appended.
- **Rename completeness:** `scripts/rename_statistics_to_insights.py --check`
  passes after commits 2 and 3.
- **l10n:** `flutter gen-l10n` succeeds (it rejects a key whose `@` metadata
  no longer matches), placeholders `{title}` and `{count}` are intact, and the
  pre-push generated-l10n staleness check passes.
- Widget tests that look up the text `'Statistics'` are updated in commit 4.
- One `flutter analyze`, one full test run, and `test/architecture/`.
- **Manual, on macOS:** with a customised nav order that puts Statistics in a
  non-default slot, launch the new build and confirm Insights keeps that slot
  with the new icon; check master-detail, `/insights/<category>` in a narrow
  window, the dashboard quick action and the keyboard shortcut.

## Deliberately out of scope

- Any change to what the section shows or how the landing page is laid out
  (sub-project 2).
- Derived observations (sub-project 4).
- Retaking the README screenshot.
- Renaming the dive-level exclusion or any other feature's "statistics" label.

## Risks

- **Branches that merge after this.** Any branch still importing
  `features/statistics/...` stops compiling on the merge result, and it fails on
  main rather than on its own PR run. Open PRs touching the folder at spec time:
  #2315 and #2196, one file each. Both are rebased after this lands, rerunning
  the script on them if needed.
- **ARB conflicts.** The key rename touches about 4,000 ARB lines. Keeping it a
  scripted commit means a conflict is resolved by rerunning the script on the
  new base, not by hand-merging.
- **Mixed-version sync.** Covered under "The nav id alias": both ids are written, so an older build keeps the slot too.
- **Translation quality.** The section name is new in ten locales; native
  review is requested on the PR.

## Rollout

- Before the PR: open the umbrella issue and the phase-1 issue. The PR body
  carries `Closes #<phase-1>` and `Refs #<umbrella>`.
- After merge: rebase #2315 and #2196; note "Statistics is now Insights" in the
  next release notes; start sub-project 3 by revising the Connections and NL
  search specs.
