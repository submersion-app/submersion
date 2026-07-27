# Enable Beta Features Toggle

**Date:** 2026-07-27
**Status:** Approved
**Branch:** `worktree-beta-features-toggle`

## Problem

Submersion has no way to ship in-progress functionality to users who opt in
while keeping it hidden from everyone else. The existing gating mechanisms do
not fit this need:

- `lib/core/constants/feature_flags.dart` holds mutable globals flipped only
  in tests; they are not user-togglable and not reactive at runtime.
- Debug mode (`debugModeNotifierProvider`) is runtime-togglable but hidden
  behind a 5-tap gesture and scoped to diagnostics.

The first consumer is the reef data feature (PR #728), which should merge and
ship behind an opt-in gate while its data sources and UI stabilize.

## Decision Summary

A single, visible "Enable beta features" switch in Settings, stored
device-locally, gating UI surfaces only. Delivered in two steps: an
infrastructure PR to main, then guards added to PR #728.

Decisions made during brainstorming:

| Question | Decision |
| --- | --- |
| Audience / discoverability | Visible toggle for everyone, in Settings |
| Granularity | Single master toggle; no per-feature toggles |
| Scope | Device-local (SharedPreferences); never synced or backed up |
| First consumer | Reef data (PR #728) |
| Delivery | Two PRs: infrastructure to main, then gating on the reef branch |

Rejected alternatives: a per-feature registry enum (speculative structure for
one gated feature), storage in the synced global `settings` k/v table (a rough
beta surface should never appear on a device the user did not opt in from),
and extending `feature_flags.dart` (not reactive).

## Design

### 1. Storage and provider

New file `lib/features/settings/presentation/providers/beta_features_provider.dart`,
modeled on `debug_mode_provider.dart`:

- `BetaFeaturesNotifier extends StateNotifier<bool>`
  - Seeds synchronously from SharedPreferences key `beta_features_enabled`;
    default `false`. Synchronous seeding means the state is correct on first
    frame with no loading flicker, because `sharedPreferencesProvider` is
    populated at startup in `main.dart`.
  - One method: `Future<void> setEnabled(bool value)` — sets state, persists.
  - No side effects (unlike debug mode's LoggerService hookup).
- `betaFeaturesEnabledProvider = StateNotifierProvider<BetaFeaturesNotifier, bool>`
  watching `sharedPreferencesProvider`.
- `StateNotifier` is imported via the `core/providers/provider.dart` barrel
  (Riverpod 3 legacy location).

Device-local by design: no Drift change, no schema bump, no sync or backup
participation.

### 2. Settings UI

A `SwitchListTile` in the About section (`_AboutSectionContent` in
`settings_page.dart`), in its own card above the version info:

- Title: "Enable beta features"
- Subtitle: "Try features still in development. They may change or have
  rough edges."

Turning the switch off hides beta surfaces and nothing else. Cached beta data
(for reef: rows in `submersion_local.db`) is left in place; it is local-only
and re-derivable.

All new user-visible strings go through l10n: added to `app_en.arb` and all
10 non-English locales, then regenerated.

### 3. Gating policy

Beta gating follows the policy already documented in `feature_flags.dart`:
**gate UI surfaces only**. Routes, tiles, sections, and cards are hidden;
services, providers, repositories, and database schema stay intact. Because
Riverpod providers are lazy, hiding the widgets also prevents the gated
feature's network calls and computation from running.

Gating a surface is one guard:

```dart
if (ref.watch(betaFeaturesEnabledProvider)) ...
```

Graduating a feature out of beta is deleting its guards.

### 4. First consumer: reef data (step two, on PR #728)

After the infrastructure PR merges to main, merge main into
`worktree-reef-data` and add exactly two guards:

- `lib/features/dive_sites/presentation/pages/site_detail_page.dart` —
  render `ReefSection` only when the flag is on.
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart` — hide
  the `DiveDetailSectionId.reefHealth` section when the flag is off.

Reef providers, services, cache DAO, and the local-cache schema are untouched.

## Testing

Infrastructure PR:

- Unit tests for `BetaFeaturesNotifier`: defaults to false, `setEnabled`
  persists across notifier instances.
- Widget test for the settings tile: renders in About, toggling updates the
  provider.

Reef gating (PR #728):

- Widget tests asserting the reef surfaces appear when the flag is on and are
  absent when off, on both detail pages.

Known traps to verify against:

1. Watching a new provider from `dive_detail_page` / `site_detail_page` can
   break their existing widget tests if SharedPreferences is not mocked;
   `flutter analyze` will not catch this. Run the full suite on both PRs.
2. Dive-detail section-count tests are not compiler-checked against
   conditional sections; check them explicitly after gating `reefHealth`.

## Out of Scope

- Per-feature beta toggles (add only if the single switch proves insufficient).
- Syncing the flag across devices.
- A beta update channel or TestFlight-only builds.
- Fixing or migrating existing `feature_flags.dart` consumers (Lightroom).
