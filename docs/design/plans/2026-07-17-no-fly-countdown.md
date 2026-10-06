# Flying-After-Diving (Safety Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** DAN/UHMS guideline no-fly countdown surfaced on the dashboard and a new Safety hub, plus the altitude-UX flag from the spec.

**Architecture:** Pure `NoFlyService` classifier over a lightweight trailing-window dive query (end time + had-deco flag from `dive_profiles.deco_type`/`ceiling` aggregates). New `lib/features/safety/` slice hosts the hub page. Settings gain a conservatism preset (schema v125, renumbered from v117/v124 as main advanced past it at merge time). Spec: `docs/superpowers/specs/2026-07-16-safety-features-design.md` Phase 2.

**Tech Stack:** Flutter, Drift, Riverpod, go_router. Branch `safety-phase2-no-fly` stacked on `worktree-safety-features`.

## Global Constraints

- Same as Phase 1 plan (worktree-only, `dart format .` before commits, tests by file, no emojis, l10n all 11 locales, units respect diver settings, commit per task, no attribution lines).
- Schema: **v125** (renumbered from the originally-claimed v117 as main advanced past it at merge time; v123 = phase 1 safety review, v124 = equipment attributes). Update the exact-latest tripwire and `migrationVersions`.
- Spec deviations (documented in spec): the educational tissue view is a labeled link to the existing Surface Interval tool (its chart is hardwired to its own input providers; seeding from a recorded dive is a follow-up). Planner altitude surfacing already exists (`plan_settings_panel.dart` `_AltitudeInput`); no planner change needed. No-fly expiry notification (stretch, off by default) is deferred.

## Tasks

### Task 1: NoFlyService (pure classifier)
- Create `lib/features/safety/domain/services/no_fly_service.dart`, test `test/features/safety/domain/services/no_fly_service_test.dart`.
- Produces: `enum NoFlyPreset { standard, strict }` (dbValue/fromDbValue), `enum NoFlyCategory { single, repetitive, deco }`, `class NoFlyDiveInput { DateTime endTime; bool hadDecoObligation; }`, `class NoFlyStatus { DateTime until; NoFlyCategory category; Duration remaining(DateTime now); }`,
  `class NoFlyService { static const lookback = Duration(hours: 48); NoFlyStatus? evaluate({required List<NoFlyDiveInput> dives, required NoFlyPreset preset, required DateTime now}); }`.
- Rules: dives ending within `lookback` of `now`; none → null. Category: any deco → deco; else >1 dive in window OR dives spanning >1 calendar day → repetitive; else single. Intervals: standard 12/18/24 h, strict 18/24/48 h from the latest dive end. Returns null when `until <= now`.
- TDD: single no-deco, two dives, deco dive, strict preset, expired, empty.

### Task 2: Trailing-window dive query + provider
- Modify `dive_repository_impl.dart`: `Future<List<NoFlyDiveInput>> getNoFlyDiveInputs({required DateTime since, String? diverId})` — SQL over `dives d`: end ms = `COALESCE(d.exit_time, COALESCE(d.entry_time, d.dive_date_time) + COALESCE(d.runtime,0)*1000)`; filter end >= since; deco flag = `EXISTS(SELECT 1 FROM dive_profiles p WHERE p.dive_id = d.id AND (p.deco_type = 2 OR p.ceiling > 0))`.
- Create `lib/features/safety/presentation/providers/no_fly_providers.dart`: `noFlyStatusProvider = FutureProvider<NoFlyStatus?>` (reads repository + `settingsProvider.noFlyPreset`, `DateTime.now()`), self-invalidating on dive changes via `watchDivesChanges` tick (mirror existing usage) with a periodic-ish recompute left to consumers.
- Test: repository test with in-memory DB (deco vs no-deco profiles, window filtering).

### Task 3: Settings preset (schema v117)
- `DiverSettings.noFlyPreset` text default 'standard'; migration `_assertNoFlySettingsColumn()` in onUpgrade `if (from < 117)` + beforeOpen backstop; bump `currentSchemaVersion` 116→117; append 117 to `migrationVersions`; update tripwire test.
- `AppSettings.noFlyPreset` (NoFlyPreset, default standard) + copyWith + notifier `setNoFlyPreset` + repository row mapping + MockSettingsNotifier stubs (all 4 mock sites) + notifier test.
- Safety settings page: preset selector (SegmentedButton or dropdown) under a "Flying after diving" header.

### Task 4: Safety hub page + routes + dashboard surfacing
- Create `lib/features/safety/presentation/pages/safety_hub_page.dart`: no-fly status card (countdown "until <time>", category label, guideline text, or all-clear), educational link to `/planning/surface-interval`, link to safety settings. Route `/safety` (name `safety`) as a direct child of the root ShellRoute (mirror `/gps-log`).
- Dashboard: add `noFlyUntil`/`noFlyCategory` to `DashboardAlerts` + provider population + `_alertText`/`_onTap` (route to `/safety`) in alerts_card. Not counted as a "problem" alert? It IS an alert (spec: ambient visibility) — include in hasAlerts/alertCount while active.
- Widget test for hub page with overridden providers.

### Task 5: Altitude flag in dive detail
- In `_buildAltitudeSection` / section builder: when `dive.altitude == null && (dive.site?.altitude ?? 0) > 100` show an informational row (site is at altitude, dive not altitude-adjusted; link opens edit). When `dive.altitude` set, unchanged behavior. Adjust altitude section builder gating accordingly. Widget-level test optional; unit-test the predicate helper.

### Task 6: l10n sweep + verification
- All new strings into `app_en.arb` + 10 locales; `flutter gen-l10n`; `dart format .`; `flutter analyze`; run new + neighboring test files.
