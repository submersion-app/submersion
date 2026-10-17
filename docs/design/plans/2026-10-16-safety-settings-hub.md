# Safety Settings Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, per the build-feature workflow). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Settings > Safety into a hub of three sub-pages (Safety review, Decompression, Equipment condition) with live-state subtitles, remove the top-level Decompression entry, and redirect old Decompression links.

**Architecture:** A new `SafetyHubPage` lists the three rows. On phone each row pushes a child route of `/settings/safety`; on desktop a `SafetySettingsPane` inside the settings detail pane reads a `safetyPage` query parameter and swaps hub and sub-page, with `goInPlace` driving the URL. Decompression content moves out of `settings_page.dart` into its own page, with its two dialogs split into widget files. Old links are rewritten by a pure resolver that `SettingsPage` applies post-frame.

**Tech Stack:** Flutter, Riverpod (`StateNotifier` settings), go_router, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-10-16-safety-settings-hub-design.md`

## Global Constraints

- Hub row order: Safety review, Decompression, Equipment condition.
- Subtitles (en): `On, {enabled} of {total} rules, no-fly {preset}` / `Off, no-fly {preset}`; `GF {gfLow}/{gfHigh}`; `On, {enabled} of {total} rules` / `Off`. Preset words: `Standard`, `Strict`.
- Top-level Safety subtitle (en): `Review rules, decompression & equipment`.
- Phone routes: `/settings/safety` (hub), `/settings/safety/review`, `/settings/safety/decompression`, `/settings/safety/equipment-condition`.
- Desktop: `/settings?selected=safety[&safetyPage=review|decompression|equipment-condition]`; unknown `safetyPage` shows the hub.
- Every new or changed ARB value is translated into all 10 non-en ARBs; `flutter gen-l10n` runs LAST, after all ARBs are written.
- No file over 800 lines; no em-dashes anywhere; no setting semantics change.
- Tests pin `locale: Locale('en')`.

## Review Focus

1. Phone URL `/settings?selected=safety` (or with `safetyPage`) must not render the generic wrapper with two app bars: it redirects to the phone route. Test in Task 5.
2. Desktop `selected=decompression` must leave the left list highlighting Safety (URL really rewritten). Test in Task 5.
3. A desktop sub-page's back arrow must return to the hub, not pop the settings route off the stack. Test in Task 4.
4. All rules disabled while the review is on reads `On, 0 of 6 rules, ...`, not "Off". Test in Task 1.
5. Hub subtitles update live when a setting changes on a sub-page and the user returns. Test in Task 3 (rebuild on notifier state change).

## File Structure

| File | Responsibility |
| --- | --- |
| Create `lib/features/settings/presentation/widgets/safety_hub_summaries.dart` | Pure functions: hub row subtitles from `AppSettings` + `AppLocalizations` |
| Create `lib/features/settings/presentation/widgets/settings_section_helpers.dart` | Public `buildSettingsSectionHeader` / `buildSettingsInfoCard` (moved from settings_page.dart) |
| Create `lib/features/settings/presentation/widgets/gradient_factor_dialog.dart` | `GfPreset`, `GradientFactorDialog` (moved) |
| Create `lib/features/settings/presentation/widgets/ppo2_limit_dialog.dart` | `PpO2LimitDialog` (moved) |
| Create `lib/features/settings/presentation/pages/decompression_settings_page.dart` | `DecompressionSettingsPage` (Scaffold + moved content + CNS source URLs) |
| Rename `safety_settings_page.dart` to `safety_review_settings_page.dart` | `SafetyReviewSettingsPage`: today's page minus the Equipment condition row, plus `onBack` |
| Create `lib/features/settings/presentation/pages/safety_hub_page.dart` | `SafetyHubPage`, `SafetySubPage` enum, `SafetySettingsPane` |
| Create `lib/features/settings/presentation/settings_legacy_links.dart` | `resolveLegacySettingsLocation` |
| Modify `settings_page.dart`, `settings_list_content.dart`, `equipment_condition_settings_page.dart`, `app_router.dart`, ARBs | wiring |

---

### Task 1: Hub subtitle strings and summaries

**Files:**
- Create: `lib/features/settings/presentation/widgets/safety_hub_summaries.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (insert next to the `safetySettings_*` group; change `settings_section_safety_subtitle` value)
- Test: `test/features/settings/presentation/widgets/safety_hub_summaries_test.dart`

**Interfaces:**
- Produces: `String safetyReviewSummary(AppLocalizations l10n, AppSettings s)`, `String decompressionSummary(AppLocalizations l10n, AppSettings s)`, `String equipmentConditionSummary(AppLocalizations l10n, AppSettings s)`.
- New ARB keys: `safetyHub_reviewOn(enabled:int,total:int,noFly:String)`, `safetyHub_reviewOff(noFly:String)`, `safetyHub_noFlyStandard`, `safetyHub_noFlyStrict`, `safetyHub_conditionOn(enabled:int,total:int)`, `safetyHub_off`. Decompression reuses `settings_decompression_gfValue`.

- [ ] **Step 1: Write failing tests** (en `AppLocalizations` via `lookupAppLocalizations(const Locale('en'))`):
  - default settings: review = `On, 6 of 6 rules, no-fly Standard`; decompression with gfLow 30 gfHigh 70 = `GF 30/70`; condition = `On, 10 of 10 rules`.
  - review disabled + strict = `Off, no-fly Strict`.
  - all six rules in `safetyReviewDisabledRules`, review on = `On, 0 of 6 rules, no-fly Standard`.
  - `conditionEngineEnabled: false` = `Off`; two condition rules disabled = `On, 8 of 10 rules`.
  - Totals come from `SafetyRuleId.values.length` / `ConditionRuleId.values.length`, so assert against those, not literals, for the totals.
- [ ] **Step 2:** Run `flutter test test/features/settings/presentation/widgets/safety_hub_summaries_test.dart`; expect compile FAIL.
- [ ] **Step 3:** Add en ARB keys with `@` metadata (placeholders typed `int`/`String`); update `settings_section_safety_subtitle` en value. Write all 10 translations for the new keys and the changed value. Then `flutter gen-l10n`. Verify `grep -A1 "get safetyHub_off" lib/l10n/arb/app_localizations_de.dart` is German.
- [ ] **Step 4:** Implement the three functions. Enabled counts ignore disabled-rule entries that are not current enum values.
- [ ] **Step 5:** Tests pass. Commit `feat(settings): live-state summaries for the Safety hub`.

### Task 2: Move Decompression into its own page

**Files:**
- Create: `settings_section_helpers.dart`, `gradient_factor_dialog.dart`, `ppo2_limit_dialog.dart`, `decompression_settings_page.dart`
- Modify: `settings_page.dart` (delete `_DecompressionSectionContent`, the two dialogs, `GfPreset`, `_cnsSource*` consts, the helper bodies; rename helper call sites to the public names)
- Modify tests whose harness opens `?selected=decompression`: `cns_method_picker_test.dart`, `icd_warnings_toggle_test.dart`, decompression groups in `settings_page_test.dart`
- Test: `test/features/settings/presentation/pages/decompression_settings_page_test.dart`

**Interfaces:**
- Produces: `class DecompressionSettingsPage extends ConsumerWidget { const DecompressionSettingsPage({super.key, this.onBack}); final VoidCallback? onBack; }`. AppBar title `settings_section_decompression_title`; when `onBack != null` the AppBar `leading` is a back `IconButton` (tooltip `MaterialLocalizations.of(context).backButtonTooltip`) calling it.
- `Widget buildSettingsSectionHeader(BuildContext, String)`, `Widget buildSettingsInfoCard(BuildContext, String, String)`, `class GradientFactorDialog`, `enum GfPreset`, `class PpO2LimitDialog` (same constructors as the private originals).

- [ ] **Step 1:** Write `decompression_settings_page_test.dart`: pumps `DecompressionSettingsPage` in a plain `MaterialApp`; expects AppBar text `Decompression`, `GF 50/85`-style current value tile present (use default settings' gf), `GTR reserve pressure` present after scroll; with `onBack` given, tapping `find.byTooltip('Back')` calls it.
- [ ] **Step 2:** Run; expect compile FAIL.
- [ ] **Step 3:** Move code verbatim (content body unchanged; drop the unused `ref` constructor field). Content sits in the Scaffold body.
- [ ] **Step 4:** Repoint the three existing decompression test harnesses to pump `DecompressionSettingsPage` directly (keep their assertions). Run them plus the new test and `flutter analyze`; all pass. `wc -l` every touched lib file under 800 except `settings_page.dart`, which must shrink.
- [ ] **Step 5:** Commit `refactor(settings): move Decompression settings into their own page`.

### Task 3: Safety review page and hub

**Files:**
- Rename: `safety_settings_page.dart` to `safety_review_settings_page.dart` (`git mv`), class `SafetyReviewSettingsPage`; test file likewise
- Create: `lib/features/settings/presentation/pages/safety_hub_page.dart`
- Modify: `equipment_condition_settings_page.dart` (add `onBack`)
- Test: `test/features/settings/presentation/pages/safety_hub_page_test.dart`

**Interfaces:**
- `SafetyReviewSettingsPage({super.key, this.onBack})`, `EquipmentConditionSettingsPage({super.key, this.onBack})`: same `onBack` AppBar rule as Task 2. Review page loses the Equipment condition row; AppBar title stays `safetySettings_title`.
- `enum SafetySubPage { review, decompression, equipmentCondition }` with `String get id` (`review`, `decompression`, `equipment-condition`), `String get phoneRoute` (`/settings/safety/<id>`), `static SafetySubPage? fromId(String?)`.
- `class SafetyHubPage extends ConsumerWidget { const SafetyHubPage({super.key, this.onOpenPage}); final void Function(SafetySubPage)? onOpenPage; }`. Null `onOpenPage` means `context.push(page.phoneRoute)`. Title `settings_section_safety_title`. Rows: icons `Icons.fact_check_outlined`, `Icons.timeline`, `Icons.build_circle_outlined`; titles `safetySettings_title`, `settings_section_decompression_title`, `settings_section_equipmentCondition_title`; subtitles from Task 1; trailing chevron. Row keys `Key('safety-hub-<id>')`.

- [ ] **Step 1:** Write hub tests: three rows in order with the Task 1 subtitles; with `onOpenPage` given, tapping each row reports the right `SafetySubPage`; with a GoRouter and no callback, tapping Decompression pushes `/settings/safety/decompression` (stub page text) and back returns to the hub; changing notifier state (`setSafetyReviewEnabled(false)`) re-renders the review subtitle as `Off, no-fly Standard`.
- [ ] **Step 2:** Update the moved review page test: remove the "equipment condition entry" group; add a test that no `Equipment condition` text exists; keep sweep-lock tests.
- [ ] **Step 3:** Run; expect FAIL. Implement. Run hub, review, equipment condition tests; pass.
- [ ] **Step 4:** Commit `feat(settings): Safety hub with Safety review sub-page`.

### Task 4: Routes and the desktop pane

**Files:**
- Modify: `app_router.dart` (safety builder becomes `SafetyHubPage`; add children `review` -> `SafetyReviewSettingsPage`, `decompression` -> `DecompressionSettingsPage`)
- Modify: `safety_hub_page.dart` (add `SafetySettingsPane`)
- Modify: `settings_page.dart` (`_buildSectionContent` 'safety' -> `SafetySettingsPane`; remove 'decompression' cases and its title/subtitle switch arms), `settings_list_content.dart` (remove the Decompression `SettingsSection` and its switch arms)
- Modify: `settingsSectionDedicatedRoutes`: add `'decompression': '/settings/safety/decompression'`
- Test: `safety_hub_page_test.dart` (pane group), `test/core/router/app_router_test.dart`

**Interfaces:**
- `class SafetySettingsPane extends StatelessWidget`: reads `GoRouterState.of(context).uri.queryParameters['safetyPage']` via `SafetySubPage.fromId`; null shows `SafetyHubPage(onOpenPage: (p) => context.goInPlace('${uri.path}?selected=safety&safetyPage=${p.id}'))`; a page shows its widget with `onBack: () => context.goInPlace('${uri.path}?selected=safety')`. Each child gets `ValueKey` of its id.

- [ ] **Step 1:** Pane tests with a GoRouter at `/settings?selected=safety` rendering `SafetySettingsPane`: hub visible; tap Decompression row -> location has `safetyPage=decompression` and `Decompression` app bar shows; tap back -> location `/settings?selected=safety`, hub visible; `safetyPage=bogus` -> hub.
- [ ] **Step 2:** Router tests: `/settings/safety/review` and `/settings/safety/decompression` resolve; `redirectFor('decompression')` == `/settings/safety/decompression`; root settings list has no Decompression row (`settings_page_test`: `find.text('Decompression')` nothing on the root list).
- [ ] **Step 3:** Run; FAIL. Implement. Run settings and router tests; pass. Fix any existing test that counted root rows or tapped Decompression on the root list.
- [ ] **Step 4:** Commit `feat(settings): route the Safety sub-pages on phone and in the desktop pane`.

### Task 5: Legacy link resolution

**Files:**
- Create: `lib/features/settings/presentation/settings_legacy_links.dart`
- Modify: `settings_page.dart` (`SettingsPage.build`: compute target; if non-null, `addPostFrameCallback` -> mounted check -> phone `context.go(target)`, desktop `context.goInPlace(target)`)
- Test: `test/features/settings/presentation/settings_legacy_links_test.dart`, plus a widget test in `settings_page_test.dart`

**Interfaces:**
- `String? resolveLegacySettingsLocation(Uri uri, {required bool masterDetail})`:
  - desktop: `selected=decompression` -> `/settings?selected=safety&safetyPage=decompression`; else null.
  - phone: `selected=decompression` -> `/settings/safety/decompression`; `selected=safety` with valid `safetyPage` -> its `phoneRoute`; `selected=safety` otherwise -> `/settings/safety`; any other `selected` in `settingsSectionDedicatedRoutes` -> that route; else null.
  - Does not consult `uri.path` beyond passing it through (always `/settings`).

- [ ] **Step 1:** Unit tests for every row above, plus `selected=units` -> null on both, and no `selected` -> null.
- [ ] **Step 2:** Widget tests: phone GoRouter (real child routes from Task 4, stub pages) at `/settings?selected=decompression` settles on the Decompression page with exactly one `AppBar`; desktop (1280 wide) at the same URL settles with location `/settings?selected=safety&safetyPage=decompression`.
- [ ] **Step 3:** Run; FAIL. Implement. Pass. `flutter analyze`; `flutter test test/features/settings test/core/router test/architecture test/shared`.
- [ ] **Step 4:** `dart format .`; commit `feat(settings): redirect old Decompression and Safety links`.
