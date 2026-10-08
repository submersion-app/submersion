# Enforcing the provider change-tick convention

Issue: [#974](https://github.com/submersion-app/submersion/issues/974). Closes the
symptom side of [#958](https://github.com/submersion-app/submersion/issues/958)
(trips) and [#970](https://github.com/submersion-app/submersion/issues/970)
(courses) as a side effect.

## Outcome

Measured at the end of implementation, superseding the pre-implementation
survey below.

| | Planned | Actual |
| --- | --- | --- |
| Violations fixed | 137 | **161** |
| New repository tick streams | 14 | **16** |
| Tick declarations in `lib/` | 27 | **44** |
| `invalidateSelfWhen` call sites | 92 | **218** |
| `// no-tick:` exemptions | "few" | **15** |

The count grew twice, both times because the checker itself was wrong rather
than because the codebase was worse than surveyed:

1. **Direct construction.** Unresolved parsing reports `DiveRepository()` as a
   `MethodInvocation`, not an `InstanceCreationExpression` -- the parser cannot
   tell a constructor from a function call without type resolution. Caught by a
   fixture test before the checker ever ran against `lib/`.
2. **Chained calls.** `ref.watch(repoProvider).getTrack()` never binds the
   repository to a local, so the call target was not an identifier the scanner
   tracked. This hid 23 providers.
3. **Path-shaped tick discovery.** The vocabulary scan looked only in
   `data/repositories/`, so `MediaStoresRepository` (at
   `media_store/data/media_stores_repository.dart`) contributed no tick and its
   correctly-subscribed consumer was reported as a violation. The scan now
   covers all of `lib/`.

Two rules were generalised during implementation, each replacing a category of
`// no-tick:` comment with a checkable fact:

- **A `watch`-prefixed repository method is a subscription, not a read.** This
  covers live Drift queries (`watchFindings`, `watchEntries`, `watchSummary`)
  as well as change ticks. Both re-emit on every write.
- **A provider whose value is a function is not a cache.** Action providers
  shaped `Provider((ref) => (args) async { ... })` run their repository call
  when a caller invokes the callback, so no row is held.

### The 15 exemptions

Every one carries a written reason at the declaration. They fall into four
kinds, and the kinds are worth knowing because they are what a syntactic rule
cannot decide:

| Kind | Examples |
| --- | --- |
| Value is a closure or service, read happens in a callback | `mediaVerifyRunnerProvider`, `mediaStoreRuntimeProvider`, `networkFetchPipelineProvider` |
| Recomputing would re-run a side effect | `mediaTransferQueueReclaimProvider` (a second reclaim pass), `selectedSyncAccountProvider` (rewrites the account), `seedSpeciesProvider` (re-seeds) |
| Remote or write-once cache with no local write path | `bathymetryGridProvider`, the three `reef*` providers |
| Short-lived `autoDispose`, read fresh at action time | `firstSyncCutoffDefaultProvider`, `eligibleImportedDivesProvider` |

### Corrections to this spec, made during implementation

- **Debouncing is not the house convention.** Only 3 of the 28 pre-existing
  ticks debounce. New ticks follow the plain un-debounced form; only
  `DiveComputerRepository` debounces, because registering a computer happens
  inside a download that also writes dives, profiles, tanks, and data sources.
- **`TrackGeometryCacheRepository` is not a write-once cache.** `invalidate()`
  drops every LOD on a trim or split and the next render rewrites them, so it
  received a tick rather than the exemption planned here.
- **`nextDiveNumberProvider` is not exempt.** #974 filed it under short-lived
  `autoDispose` reads, but it is a plain `FutureProvider` watched by the import
  wizard's review step, so a stale number rendered for the process lifetime.

### Verification

`flutter analyze` clean project-wide, full suite green, and the invariant test
was confirmed to fail (naming the provider) when a single `invalidateSelfWhen`
line was deleted. Performance tests show no regression:
`getDiveSummaries` <100ms, `getDiveById` <50ms, `getDiveProfile` <50ms.

---

## Problem

A Riverpod provider whose body queries a database table must self-invalidate on
that table's change tick:

```dart
final fooProvider = FutureProvider.family<Foo, String>((ref, id) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  return repository.getFoo(id);
});
```

Writes reach the database through paths that bypass every notifier --
`DiveRepository.bulkDeleteDives` (called from `dive_merge_service.dart` and
`dive_consolidation_service.dart`), sync pulls applying remote deletions, and
repository-level bulk edits. None of them call `ref.invalidate` on a caller's
behalf, so a provider that does not subscribe to the tick serves a stale cache
until something else happens to invalidate it.

The convention is followed at 92 call sites across 41 files and violated in a
long tail. Nothing enforces it, and the only way to audit it is grep. That is
how #958 and #970 both happened.

### Verified state at `d055e9cd3b9`

Every violation claimed in #974 is still present. The survey below covers the
`dives` tick only; the other 26 ticks have never been surveyed.

| Area | Providers | Note |
| --- | --- | --- |
| `statistics_providers.dart` | 33 | Ride `_keepAliveWithExpiry`, whose only reactivity is `ref.watch(statisticsVersionProvider)` |
| `dashboard_providers.dart` | 2 | `yearInReviewProvider`, `dashboardQuickStatsProvider` -- same version counter |
| `buddy_providers.dart` | 3 | `buddyStatsProvider`, `diveIdsForBuddyProvider`, `divesForBuddyProvider` |
| `dive_providers.dart` | 3 | `orderedDiveIdsProvider`, `diveRecordsProvider`, `diveSearchProvider` |
| `profile_analysis_provider.dart` | 1 | `weeklyOtuProvider` |
| `equipment_providers.dart` | 4 | `equipmentDiveCountProvider` plus three neighbours |
| `species_providers.dart` | 2 | `siteSpottedSpeciesProvider`, `siteExpectedSpeciesProvider` |
| `plan_canvas_providers.dart` | 1 | `loggedAverageSacProvider`, cached for the process lifetime |
| `trip_providers.dart` | 3 | #958, still open |
| `course_providers.dart` | 2 | #970, still open |

`statisticsVersionProvider` is declared once (`dive_providers.dart:243`) and
incremented from exactly one line in the repository
(`dive_providers.dart:747`, inside `PaginatedDiveListNotifier`). Merge,
consolidate, import, and sync pulls never touch it.

A counter is only as reliable as the set of writers that remember to bump it. A
change tick originates at the database (`tableUpdates(...)`), so every writer
bumps it whether or not the writer knows the tick exists. The version counter is
not a weaker tick; it is a different mechanism that cannot be made correct.

`_keepAliveWithExpiry`'s doc comment claims the providers "refresh when dives
are mutated." They do not. The comment is why this grew to 33 providers without
being noticed.

## Approach

An architecture test that parses `lib/` with `package:analyzer` and asserts the
invariant.

Rejected alternatives:

- **`custom_lint` rule.** The only option with inline IDE feedback, but it costs
  `custom_lint` + `custom_lint_builder` + `riverpod_lint` dev dependencies, a new
  `plugins:` section in `analysis_options.yaml`, a separate lint package in the
  repository, and a `dart run custom_lint` CI step. `riverpod_lint` pinning
  against `riverpod: ^3.1.0` is a live risk.
- **Shared helper only.** A `diveScopedFutureProvider(...)` wrapper reads well
  but enforces nothing; nothing stops the next provider being written the old
  way.
- **Fix the tail by hand, add no tooling.** Legitimate, but #958 and #970 have
  already demonstrated the recurrence rate.

The test wins on cost: `analyzer 9.0.0` is already in `pubspec.lock` as a
transitive dependency of `build_runner`/`drift_dev`, so promoting it to an
explicit `dev_dependency` carries no resolution risk. The test runs inside the
existing `flutter test` suite, which the pre-push hook and CI already invoke, so
there is no new wiring. `test/l10n/arb_parity_test.dart` and
`test/macos_entitlements_test.dart` are existing precedents for repository-wide
invariant tests that read source files.

Parsing is **syntactic only** (`parseFile`). Resolved analysis of a Flutter
application this size takes minutes; unresolved parsing takes milliseconds per
file. The consequence is that types cannot be resolved, so "is this a
repository" is decided by identifier name.

## The rule

> A provider that **invokes a method on a repository** must reference at least
> one **change-tick method**, directly or through a same-file helper, or carry an
> explicit `// no-tick: <reason>` marker.

Deliberately *not* checked: which tick. The survey found zero instances of a
provider subscribing to the wrong tick, and deriving the required tick per call
site needs name heuristics that would cry wolf on the junction-table reads
(`getDiveIdsForBuddy` lives on `BuddyRepository` but goes stale on a `dives`
cascade delete). The failure message names this trap explicitly so that a reader
silencing a failure does not reach for the nearest tick.

## Test design

`test/architecture/provider_change_tick_test.dart`.

### Step 1 -- build the tick vocabulary

Walk `lib/**/data/repositories/`, parse each file, collect every method declared
`Stream<void> watchX()`. This yields 27 names.

Deriving the set rather than hardcoding a `watch<Noun>Changes` pattern is
required: `diver_weight_entry_repository.dart`, `emergency_chamber_repository.dart`,
and `incident_repository.dart` each declare a bare `watchChanges()`, which a name
pattern would silently skip.

The test asserts the set is non-empty and has at least 25 entries, so it cannot
pass vacuously if the scan path breaks or the repository layout moves.

### Step 2 -- decide whether a provider reads

Walk all of `lib/`. Providers are not confined to `*/providers/` directories --
`lib/features/dive_3d/application/` and
`lib/features/settings/presentation/widgets/pending_setup_card.dart` declare them
too -- so scanning the whole tree avoids a blind spot.

For each top-level variable whose initializer constructs a provider
(`Provider`, `FutureProvider`, `StreamProvider`, `NotifierProvider`,
`StateNotifierProvider`, including `.family` and `.autoDispose` chains):

1. Bind local identifiers to repositories. Three shapes count:
   `ref.watch(fooRepositoryProvider)`, `ref.read(fooRepositoryProvider)`, and a
   bare `FooRepository()` constructor call.
2. The provider **reads** if the body contains a `MethodInvocation` whose
   *target* is one of those identifiers.

The target-versus-argument distinction removes the largest false-positive class
without an allowlist. Service-constructor providers (`exportServiceProvider`,
`syncServiceProvider`, import-wizard adapters) pass a repository as an
*argument* to a constructor; the repository is never a method-invocation target,
so they are skipped mechanically rather than by human judgement.

### Step 3 -- check for a tick

A reading provider is compliant if its body, **or the body of a same-file
top-level or private function it calls (resolved one level deep)**, invokes any
name from step 1.

One level of indirection is what makes all three legitimate shapes pass:

| Shape | Where it appears |
| --- | --- |
| `ref.invalidateSelfWhen(repo.watchDivesChanges())` | the 92 existing correct call sites |
| `repo.watchDivesChanges().listen(...)` + `ref.onDispose` | `StateNotifier`s, which cannot call the `Ref` extension |
| a helper such as `_keepAliveWithExpiry(ref)` | `statistics_providers.dart` after the fix below |

The checker therefore blesses the shared-helper pattern instead of fighting it.

### Step 4 -- escape hatch

`// no-tick: <reason>` on the line immediately above the declaration. An empty
reason fails. The marker lives at the provider so it appears in review diffs and
forces a written justification, matching the ergonomics of `// ignore:`.

Expected legitimate uses, per #974's "deliberately not flagged" list: short-lived
`autoDispose` providers read fresh at action time (`nextDiveNumberProvider`,
`eligibleImportedDivesProvider`, `firstSyncCutoffDefaultProvider`), where a stale
cache never renders. Dead providers with no consumer are deleted rather than
marked.

### Step 5 -- reporting

Failures report `file:line`, provider name, and the repository method that
triggered the check, followed by the convention and the wrong-tick warning.

### Known limitation

The test checks provider *declarations*, not `Notifier` classes.
`DiveListNotifier`, `PaginatedDiveListNotifier`, and `TripListNotifier` are
skipped automatically -- their provider bodies construct a class rather than
calling repository methods. All three are currently correct. Extending coverage
to notifier classes is out of scope, and the test says so in its doc comment so
the gap is documented rather than silently missed.

## Fixes

### Statistics block

`_keepAliveWithExpiry` gains a dives-tick subscription and loses its
`statisticsVersionProvider` watch. One edit fixes 33 providers. The tick to use
matches whatever `filteredDiveStatisticsProvider` already subscribes to.

`statisticsVersionProvider` is then deleted along with its single increment in
`PaginatedDiveListNotifier._invalidateStatistics()`. Its two remaining readers
are `dashboard_providers.dart`'s `yearInReviewProvider` and
`dashboardQuickStatsProvider`, both converted to the tick in the same change.

Deleting the counter is part of the fix, not adjacent cleanup: leaving it in
place leaves a second, broken reactivity mechanism for the next reader to trust.

### Remaining providers

The per-file table in "Verified state" above. Each is a one-line
`ref.invalidateSelfWhen(...)` addition matching the 92 existing call sites.

Two bodies in `trip_providers.dart` construct `DiveRepository()` and
`EquipmentRepository()` inline. Both are routed through their providers, which
is a prerequisite for attaching the tick cleanly and also restores their
testability via provider override.

### Violations against the other 26 ticks

The survey covered the `dives` tick only. Running the checker will surface
violations against the other 26, count unknown. All of them are in scope and get
fixed, so the test lands with no allowlist entries beyond the deliberate ones. If
the count turns out large enough to change the shape of the work, that gets
raised before grinding through it rather than silently expanding the change.

### Redundant hand-invalidation is left in place

Roughly 15 manual `ref.invalidate(...)` call sites (`records_page.dart`,
`dive_edit_page.dart`, `site_providers.dart`, `TripListNotifier`) become
redundant once the ticks land. They are harmless, and removing them would spread
the diff into files this change does not otherwise touch. Noted as follow-up.

## Testing

- **The architecture test** covers the convention itself. The one-line tick
  additions are correct by construction once it passes.
- **One behavioral regression test** for the statistics block: a dive write that
  bypasses the notifiers (the `bulkDeleteDives` path) must refresh a
  `_keepAliveWithExpiry` provider. That is the change with real behavioral
  surface -- 33 providers and a mechanism swap, not a one-liner.
- Per-provider regression tests are not written. The tick mechanism is already
  exercised by 92 existing call sites; the value here is structural.

### Performance check

Ticking 33 aggregate statistics providers means a bulk import fires many
invalidations, and statistics queries are expensive on a large database. The
expectation is that Riverpod does not recompute a `keepAlive`d provider with no
listeners, and that the 300 ms `changeTickDebounce` (#427) absorbs bursts. This
is verified empirically during implementation rather than assumed; if it does not
hold, the statistics fix needs a different shape.

## Out of scope

- Which tick a provider subscribes to (see "The rule").
- `Notifier` and `StateNotifier` class bodies (see "Known limitation").
- Removing redundant hand-invalidation call sites.
- IDE-inline feedback, which would require the `custom_lint` route.

## Related

- #431 -- `Ref.invalidateSelfWhen`, the pause-aware helper
- #427 -- the 300 ms `changeTickDebounce`
- #217 -- the original "stale after a table write" lesson, cited in
  `dive_providers.dart:255`
