# Home header style and Quick Actions card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver choose, per device and separately for phone width and wider screens, between today's compact Home header and the original welcome banner, and add an optional Quick Actions card that looks like the original.

**Architecture:** Two device-local SharedPreferences keys hold the header style names; `DashboardPage` picks one by width tier and builds either today's bar or, inside the scroll view, the restored banner plus a pinned row holding the + menu and status lights. The Quick Actions card returns as a new hidden-by-default Home panel with its own row height. The banner, its avatar and the card are restored from git history at `dce6b49217b^`.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, flutter_test, ARB l10n (`flutter gen-l10n`).

**Spec:** `docs/design/specs/2026-11-25-home-header-style-and-quick-actions-design.md`

## Global Constraints

- Compact is the default for both widths; nothing stored, or an unknown stored value, reads as Compact.
- Nothing syncs and nothing touches the database: no schema bump, no `diver_settings` column.
- "Phone width" is `HomeWidthTier.phone` (below 800 pt); tablet and desktop read the wide key.
- Quick Actions is hidden in every preset and in every upgraded stored layout.
- Safety lights (gear, insurance, flight window) show in banner mode even when their chip is hidden.
- Restored widgets match `dce6b49217b^` except where the spec says otherwise: avatar shown with any number of profiles; banner logo opens About; quiet stats from 800 pt (`ResponsiveBreakpoints.isDesktop`).
- Every string in all 11 ARB files (`lib/l10n/arb/app_*.arb`); regenerate with `flutter gen-l10n`.
- No em-dash or en-dash punctuation anywhere; no emojis; `dart format .` before each commit.
- Run only the test files written or changed, by path; never a folder or the suite.
- Paths in tests built with `p.join`; any global state a test sets is restored in `addTearDown`.

## Review Focus

1. A Mac window resized across 800 pt while on Home: the header must switch between the two stored styles in place, with no stale header and no exception. (Task 5 test `switches header when resized across 800`.)
2. The Quick Actions card at text scale 2 on a 320 pt phone: no overflow; the card must fit its row height. (Task 6 test `quick actions card fits at text scale 2`.)
3. Banner mode with the gauges failing to load: the pinned row shows the retry chip, and tapping it reloads. (Task 4 test `banner row shows retry chip on gauge error`.)
4. A diver whose stored layout predates this change switches Quick Actions on: it appears directly after Key numbers, not at the end. (Task 6 test `upgraded layout slots quick actions after key numbers`.)
5. Banner mode with no diver row (fresh install, or the diver failed to load): the avatar slot collapses and the greeting reads "Good morning!" with no name gap. (Task 3 test `avatar collapses when no diver`.)

---

### Task 1: Header style setting

**Files:**
- Create: `lib/features/dashboard/presentation/home_header_style.dart`
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (SettingsKeys near line 185; AppSettings fields near 813, constructor near 1061, copyWith near 1312 and 1597; `_withDeviceLocalPrefs` near 1863; load near 1933 and 1969/2042; `_saveSettings` device prefs near 2123; setters near 2781)
- Test: `test/features/dashboard/presentation/home_header_style_test.dart`, `test/features/settings/presentation/providers/home_panel_settings_test.dart`

**Interfaces:**
- Produces:
  - `enum HomeHeaderStyle { compact, banner }`
  - `HomeHeaderStyle homeHeaderStyleFromName(String? name)` (null or unknown gives `compact`)
  - `HomeHeaderStyle homeHeaderStyleFor(AppSettings s, HomeWidthTier tier)` (phone tier reads `homeHeaderStylePhone`, else `homeHeaderStyleWide`)
  - `SettingsKeys.homeHeaderStylePhone = 'home_header_style_phone'`, `SettingsKeys.homeHeaderStyleWide = 'home_header_style_wide'`
  - `AppSettings.homeHeaderStylePhone` and `.homeHeaderStyleWide`, both `String?`, device-local, null when never set
  - `SettingsNotifier.setHomeHeaderStyle({required bool phone, required String style})`

- [ ] **Step 1: Write failing tests**

In `home_header_style_test.dart`: `homeHeaderStyleFromName(null) == compact`, `('banner') == banner`, `('bogus') == compact`; `homeHeaderStyleFor` returns the phone value for `HomeWidthTier.phone` and the wide value for `tablet` and `desktop`.

In `home_panel_settings_test.dart` (follow its existing SharedPreferences mock setup): `header styles default to null`; `setHomeHeaderStyle(phone: true, style: 'banner')` writes `home_header_style_phone` = `'banner'` and leaves `home_header_style_wide` absent; a stored `home_header_style_wide` = `'banner'` is read back on load; a non-string stored value reads null without blocking the other Home keys; the values survive a diver switch (`_withDeviceLocalPrefs`).

- [ ] **Step 2: Run, expect FAIL**

Run: `flutter test test/features/dashboard/presentation/home_header_style_test.dart test/features/settings/presentation/providers/home_panel_settings_test.dart`
Expected: compile errors for the missing names.

- [ ] **Step 3: Implement**

Enum and the two functions in `home_header_style.dart`. In settings, mirror `homePanelOrder` exactly: read with a try/catch `getString` per key, carry through both AppSettings construction sites, write in the `devicePrefs` block only when non-null, include in `_withDeviceLocalPrefs`. `setHomeHeaderStyle` uses `_update` with `copyWith` on the chosen field.

- [ ] **Step 4: Run, expect PASS** (same command)

- [ ] **Step 5: Commit** `feat(dashboard): store a Home header style for phone and wider screens`

### Task 2: Restore the banner strings and add the new ones

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (11 files), regenerated `lib/l10n/arb/app_localizations*.dart`
- Script (scratchpad, not committed): reads `git show dce6b49217b^:lib/l10n/arb/app_<locale>.arb` and copies these keys (and their `@` metadata in `app_en.arb`) into the current files, keeping each file's key order convention.

**Interfaces:**
- Produces (restored, every locale): `dashboard_greeting_morning`, `dashboard_greeting_afternoon`, `dashboard_greeting_evening`, `dashboard_greeting_withName`, `dashboard_greeting_withoutName`, `dashboard_hero_divesLoggedOne`, `dashboard_hero_divesLoggedOther`, `dashboard_hero_divesTotalOne`, `dashboard_hero_divesTotalOther`, `dashboard_hero_error`, `dashboard_hero_hoursUnderwater`, `dashboard_hero_loading`, `dashboard_hero_minutesUnderwater`, `dashboard_hero_noDives`, `dashboard_hero_diverFallbackName`, `dashboard_hero_statDives`, `dashboard_hero_statHours`, `dashboard_hero_statSites`, `dashboard_hero_statCountries`, `dashboard_semantics_greetingBanner`, `dashboard_quickActions_sectionTitle`, `dashboard_quickActions_insights`.
- Produces (new, every locale, translated): `settings_homeHeader_sectionTitle` "Header", `settings_homeHeader_phone` "Phone width", `settings_homeHeader_wide` "Wider screens", `settings_homeHeader_compact` "Compact", `settings_homeHeader_banner` "Banner", `settings_homeHeader_description` "Compact is a slim bar with status lights. Banner is the welcome banner with your dive totals. Saved on this device."

- [ ] **Step 1:** Run the restore script; confirm each key appears once per file: `for k in dashboard_greeting_morning dashboard_quickActions_insights; do grep -c "\"$k\"" lib/l10n/arb/app_*.arb; done` prints 1 for every file.
- [ ] **Step 2:** Add the six new keys with translations to all 11 files (`@` descriptions in `app_en.arb`).
- [ ] **Step 3:** `flutter gen-l10n` then `flutter analyze lib/l10n` with no errors.
- [ ] **Step 4: Commit** `i18n(dashboard): restore the welcome banner strings and add the header setting strings`

### Task 3: Restore the welcome banner and its diver avatar

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/hero_header.dart`, `lib/features/dashboard/presentation/widgets/hero_diver_avatar.dart` (from `dce6b49217b^`)
- Modify: `lib/features/dashboard/presentation/providers/dashboard_providers.dart` (new countries provider)
- Test: `test/features/dashboard/presentation/widgets/hero_header_test.dart`, `test/features/dashboard/presentation/widgets/hero_diver_avatar_test.dart` (from `dce6b49217b^`, adapted)

**Interfaces:**
- Consumes: Task 2 strings.
- Produces:
  - `class HeroHeader extends ConsumerWidget` (const constructor)
  - `class HeroDiverAvatar extends ConsumerWidget`
  - `final homeCountriesVisitedProvider = FutureProvider<int?>` : `insightsRepositoryProvider.getCountriesVisited(diverId: currentDiverId, limit: null).length`, invalidated on `watchInsightsChanges()`, logging and returning null on failure (the old `_quickStat` behaviour).

Changes from the restored code:
- `_QuietStats` reads countries from `homeCountriesVisitedProvider` in place of `dashboardQuickStatsProvider`.
- `HeroDiverAvatar` drops the `diverCountProvider` check: shown with any number of profiles. With no diver: the 44 pt placeholder while `isLoading && !hasError`, otherwise `SizedBox.shrink()` (the rule `_DiverSwitcher` in `home_header_bar.dart` uses).
- The 64 pt icon becomes an `IconButton`-style 44 pt minimum target that calls `showAboutSubmersion(context)`, tooltip from the existing About string the compact bar's logo uses; `ExcludeSemantics` is removed so it is named.

- [ ] **Step 1:** Restore both test files from history; adapt overrides (`dashboardQuickStatsProvider` to `homeCountriesVisitedProvider`); flip the "hidden with one diver" avatar test to expect the avatar; add `avatar collapses when no diver` (diver provider returns null: no placeholder, greeting reads the withoutName form); add `logo opens About` (tap, expect the About dialog).
- [ ] **Step 2:** Run both files, expect FAIL (missing widgets).
- [ ] **Step 3:** Restore and adapt the two widgets and add the provider.
- [ ] **Step 4:** Run `flutter test test/features/dashboard/presentation/widgets/hero_header_test.dart test/features/dashboard/presentation/widgets/hero_diver_avatar_test.dart`, expect PASS.
- [ ] **Step 5: Commit** `feat(dashboard): restore the welcome banner with an always-shown avatar`

### Task 4: The row under the banner

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/home_banner_row.dart`
- Modify: `lib/features/dashboard/presentation/widgets/home_header_bar.dart` (share the + menu and the light builders)
- Test: `test/features/dashboard/presentation/widgets/home_banner_row_test.dart`

**Interfaces:**
- Produces:
  - `class HomeQuickActionsMenu extends ConsumerWidget` (the renamed `_QuickActionsMenu`, same key `HomeHeaderBar.quickActionsKey`)
  - `class HomeBannerRow extends ConsumerWidget`: height `HomeHeaderBar.barHeight` (48, keeps 44 pt targets), surface colour, hairline bottom border; children: `HomeQuickActionsMenu`, then the lights: phone tier the phone strip's short form, wider the dense scrolling chips, the retry chip on error.
  - `class HomeBannerRowDelegate extends SliverPersistentHeaderDelegate`: min and max extent `HomeHeaderBar.barHeight`, builds `HomeBannerRow`.
- Refactor in `home_header_bar.dart`: extract `List<Widget> homePhoneLightChips(BuildContext, WidgetRef)` from `HomeStatusStrip` and `Widget homeWideLights(BuildContext, WidgetRef)` from the bar's `lightsRow`, used by both the bar/strip and the row. `home_header_bar_test.dart` must still pass unchanged.

- [ ] **Step 1:** Tests: `+ menu opens the four actions` (Swap present only when `deviceCapabilitiesProvider.nearby`); `safety light shows when hidden` (overdue gear with the gear chip in `hiddenHomeChips`); `phone shows short form` (390 pt: attention lights named, the rest counted); `banner row shows retry chip on gauge error` (gauges throw: retry chip present; tap invalidates and the lights appear on the next load).
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Implement the row and the delegate; do the extraction.
- [ ] **Step 4:** Run `flutter test test/features/dashboard/presentation/widgets/home_banner_row_test.dart test/features/dashboard/presentation/widgets/home_header_bar_test.dart`, expect PASS.
- [ ] **Step 5: Commit** `feat(dashboard): a row of quick actions and status lights under the banner`

### Task 5: Choose the header on Home

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- Test: `test/features/dashboard/presentation/pages/dashboard_page_test.dart`

**Interfaces:**
- Consumes: `homeHeaderStyleFor`, `HeroHeader`, `HomeBannerRowDelegate`.

Behaviour: `final style = homeHeaderStyleFor(ref.watch(settingsProvider), homeWidthTierOf(context))` (select the two fields only). Compact: unchanged. Banner: no `HomeHeaderBar` or `HomeStatusStrip` in the `Column`; slivers in order `DemoModeDashboardCard`, `SliverToBoxAdapter(Padding(12, HeroHeader))`, `SliverPersistentHeader(pinned: true, delegate: HomeBannerRowDelegate())`, `HomeSpeciesBanner`, the grid. `_refresh` also invalidates `careerTotalsProvider`, `logbookDiveCountsProvider` and `homeCountriesVisitedProvider`.

- [ ] **Step 1:** Tests: `compact by default` (bar present, no `HeroHeader`); `banner on phone when phone key is banner` (390 pt: `HeroHeader` and `HomeBannerRow` present, no `HomeHeaderBar`, no `HomeStatusStrip`); `wide key drives desktop` (1400 pt with only the phone key set: compact); `switches header when resized across 800` (phone banner, wide compact; pump 390 then 1000 then 390, expecting the matching header each time and no exception); `banner row stays pinned` (scroll the grid 600 pt: `HeroHeader` off screen, `HomeBannerRow` still at the top); `banner page order` (demo card, banner, row, species offer, grid, by vertical position with demo mode on).
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run `flutter test test/features/dashboard/presentation/pages/dashboard_page_test.dart`, expect PASS.
- [ ] **Step 5: Commit** `feat(dashboard): show the welcome banner when the diver picks it`

### Task 6: Quick Actions card as an optional panel

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/quick_actions_card.dart` (from `dce6b49217b^`)
- Modify: `lib/features/dashboard/presentation/home_panels.dart` (enum value, spec), `lib/features/dashboard/presentation/widgets/home_panel.dart` (height), `lib/features/dashboard/presentation/home_panel_labels.dart`, `lib/features/dashboard/presentation/pages/dashboard_page.dart` (`_panel`)
- Test: `test/features/dashboard/presentation/quick_actions_card_test.dart` (from `dce6b49217b^`, adapted), `test/features/dashboard/presentation/home_panels_test.dart`, `test/features/dashboard/presentation/home_presets_test.dart`, `test/features/dashboard/presentation/home_layout_test.dart`

**Interfaces:**
- Consumes: Task 2 strings.
- Produces:
  - `HomePanelType.quickActions`, declared directly after `keyNumbers`
  - `HomePanelHeight.extraTall`, appended last to the enum (row height is the max by index), base 340.0 in `homeRowHeight`
  - `homePanelSpec(quickActions) == HomePanelSpec(HomePanelWidth.sList, HomePanelHeight.extraTall)`
  - `homePanelLabel(..., quickActions) == l10n.dashboard_quickActions_sectionTitle`
  - `class QuickActionsCard extends StatelessWidget`, as restored, filling its slot (`Card` margin kept; the column's buttons as before)

- [ ] **Step 1:** Restore `quick_actions_card_test.dart` (six buttons and their routes; Swap absent when unsupported). Add: `quick actions card fits at text scale 2` (pump inside a `SizedBox` of `homeRowHeight(extraTall)` width 320 at text scale 2: no overflow exception); in `home_panels_test` the spec; in `home_presets_test` `quick actions hidden in every preset` and `upgraded layout slots quick actions after key numbers` (stored order without `quickActions`: resolved order has it at index of `keyNumbers` + 1 and hidden); in `home_layout_test` every row still sums to `homeRowUnits` at every tier with `quickActions` among randomised panels, and a row holding it has height `extraTall`.
- [ ] **Step 2:** Run the four files, expect FAIL.
- [ ] **Step 3:** Implement. If the text-scale test overflows, raise the base height or let the column shrink buttons to fit; the card's look at text scale 1 must not change.
- [ ] **Step 4:** Run `flutter test test/features/dashboard/presentation/quick_actions_card_test.dart test/features/dashboard/presentation/home_panels_test.dart test/features/dashboard/presentation/home_presets_test.dart test/features/dashboard/presentation/home_layout_test.dart`, expect PASS. Then `flutter analyze` (an exhaustive switch elsewhere may need the new values).
- [ ] **Step 5: Commit** `feat(dashboard): an optional Quick Actions card like the original`

### Task 7: Header choice in Settings > Home, and user docs

**Files:**
- Modify: `lib/features/settings/presentation/pages/home_appearance_page.dart`, `docs/user/dashboard.md`, `docs/user/settings.md`, `docs/user/how-to-customize-display.md`
- Test: `test/features/settings/presentation/pages/home_appearance_page_test.dart`

**Interfaces:**
- Consumes: `HomeHeaderStyle`, `homeHeaderStyleFromName`, `setHomeHeaderStyle`, Task 2 strings.

UI: a "Header" `sectionHeader` before the layout section; two rows (`settings_homeHeader_phone`, `settings_homeHeader_wide`), each a `SegmentedButton<HomeHeaderStyle>` with Compact and Banner, keyed `ValueKey('home-header-phone')` and `ValueKey('home-header-wide')`; then `sectionDescription(settings_homeHeader_description)`. Rows must not overflow at 320 pt (label above the selector there if needed).

- [ ] **Step 1:** Tests: `header section shows both rows on Compact by default`; `tapping Banner on phone row saves phone key only`; `no overflow at 320 wide and text scale 2`; `quick actions listed in the panel list, switched off`.
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Implement; update the three user docs (Header choice in Settings > Home; banner mode; Quick Actions card in the panel list).
- [ ] **Step 4:** Run `flutter test test/features/settings/presentation/pages/home_appearance_page_test.dart`, expect PASS; `dart format .`; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(settings): choose the Home header for phone and wider screens`
