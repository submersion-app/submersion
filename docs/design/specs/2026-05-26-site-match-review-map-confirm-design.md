# Site Match review: map, richer info, and staged confirm — Design

- **Date:** 2026-05-26
- **Branch:** `feat/gps-site-matching` (refines the unmerged work in PR #287)
- **Refines:** `2026-05-26-gps-site-matching-design.md` (the original matching feature)

## Goal

Upgrade the "Match Sites" review screen so the diver can:

1. See an **interactive map** with their dive's GPS location plus the auto-matched /
   suggested sites, and **choose a site from the list or by tapping the map**.
2. See **richer information** for each candidate site (depth, region, rating,
   type, etc.).
3. **Confirm** that the matches will be applied, with a clear way to **back out** —
   replacing today's single "Done" button that closes a screen whose matches were
   already silently written.

## Decisions (locked during brainstorming)

1. **Staged apply model.** Nothing is written while reviewing. **Confirm** commits
   all selected matches at once; **Cancel** (or backing out) discards everything.
   This reverses the original "pre-applied" model.
2. **Layout: one map on top, compact dive list below.** A single map reflects the
   *focused* dive; the dive list is a compact accordion whose focused row expands
   to rich candidate cards. Wide screens use the app's master-detail pattern.
3. **Rich, but lazy info.** Rich candidate cards render only for the *focused*
   dive's candidates; the dive list itself stays compact. Fields omit gracefully
   when a source lacks them.
4. **Choose from list or map drive one selection** — pin tap and card tap both call
   the same `select(diveId, candidateId)`.

## Why staged is a simplification

Today `SiteMatchingService.run()` computes **and writes** (auto-applies, creates
bundled `DiveSites` rows, tracks rollback so `unlink` can delete orphaned created
rows). The staged model removes all of that:

- No `_appliedSiteByDive` / `_createdSiteRefs` bookkeeping.
- No orphan deletion on unlink (there is no unlink — just change the selection).
- The PR-review "spurious `unlink` write" comment becomes moot.
- Backing out = simply not calling apply.

## Architecture

### Domain (unchanged)

The pure matcher (`matchDive`, `MatchThresholds`, `SiteMatchSensitivity`,
`SiteMatchOutcome`) is unchanged. `AutoMatch | Suggested | NoMatch` still classify
a dive's candidates.

### Data layer — `SiteMatchingService` (split compute / apply)

Replace `run()` + `link()` + `unlink()` with:

```dart
/// Computes proposals for the given dives. NO database writes.
Future<List<MatchProposal>> computeProposals(List<Dive> dives);

/// Applies the confirmed selections in a single DB transaction.
/// Returns counts for the result message.
Future<ApplyResult> applyConfirmed(List<ConfirmedMatch> confirmed);
```

- `computeProposals` gathers user sites (`SiteRepository`) + bundled sites
  (`DiveSiteApiService.searchNearby`), runs `matchDive`, and builds enriched
  candidate views. It retains the resolved `DiveSite` / `ExternalDiveSite` objects
  per `(diveId, candidateId)` so apply can act on a chosen id later.
- `applyConfirmed` performs, per confirmed match: link existing (`DiveRepository.setSite`)
  or materialize bundled (`ExternalDiveSite.toDiveSite` → `SiteRepository.createSite`
  → `setSite`), with **batch dedup** (one row per bundled `externalId`) and the
  **~100 m coincidence guard** (link an existing near-duplicate instead of creating).
  The whole pass is wrapped in a DB **transaction** (all-or-nothing).

`ApplyResult` carries `{ divesLinked, sitesCreated }` for the snackbar.

### Data model

```dart
enum ProposalStatus { clear, review, none }

class MatchCandidateView {
  final String id;          // existing site id or bundled externalId
  final String name;
  final bool isExisting;
  final double distanceMeters;
  final GeoPoint location;  // NEW — for the map
  final double? minDepth;   // NEW (existing sites)
  final double? maxDepth;   // NEW (both)
  final String? country;    // NEW (both)
  final String? region;     // NEW (both)
  final double? rating;     // NEW (existing sites)
  final String? difficulty; // NEW (existing sites)
  final List<String> features; // NEW (bundled sites: wreck/reef/shore...)
  final String? description;   // NEW (both)
}

class MatchProposal {
  final Dive dive;
  final ProposalStatus status;
  final List<MatchCandidateView> candidates;   // distance-sorted
  final String? recommendedCandidateId;         // matcher's pick (clear only)
  // selection is held in notifier state, not here
}

class ConfirmedMatch {
  final String diveId;
  final String candidateId; // existing site id or bundled externalId
}
```

Matcher → proposal mapping: `AutoMatch` → `clear` (recommended candidate
**pre-selected**); `Suggested` → `review` (candidates listed, **nothing
pre-selected**); `NoMatch` → `none`.

### Presentation — notifier

`SiteMatchReviewState`:

```dart
final bool isLoading;
final String? errorMessage;
final List<MatchProposal> proposals;
final String? focusedDiveId;                 // drives the map
final Map<String, String?> selections;       // diveId -> candidateId (null = skip)
final bool isApplying;
```

Initialization: `computeProposals`, then seed `selections` with each `clear`
proposal's `recommendedCandidateId`; `review`/`none` start unselected.
`focusedDiveId` defaults to the first proposal needing attention (first `review`,
else first dive).

Actions: `focusDive(id)`, `select(diveId, candidateId)`, `skip(diveId)`,
`confirm()` (builds `ConfirmedMatch` list from non-null `selections`, calls
`applyConfirmed` in `isApplying` state, pops with a result), and Cancel = pop
(a "Discard changes?" dialog only if `selections` differ from the seeded defaults).

Counts (derived): `selected`, `toReview` (status `review`, no selection),
`skipped`/`none`.

### Presentation — screen (`SiteMatchReviewPage`)

Full rewrite. **Narrow / mobile:**

- AppBar "Match Sites".
- **Map** (pinned, ~200 px): focused dive's entry point (distinct non-tappable
  pin) + candidate pins (existing vs. import styling; selected enlarged/highlighted).
  Tapping a candidate pin selects it. Fits to dive+candidates, `maxZoom: 16`.
- **Summary line:** `N selected · M to review · K skipped`.
- **Dive list** (compact accordion): each row shows the dive and its current
  selection (site name + distance, or "tap to choose" / "no nearby site") + a
  status glyph. The **focused** row expands to rich candidate cards (tap to select)
  plus a "Skip this dive" action. Tapping any row focuses it (map recenters,
  previous row collapses).
- **Bottom bar** (pinned): `[Cancel]` and `[Confirm N matches]`. Confirm runs
  `applyConfirmed`, shows a result snackbar ("Linked 5 dives · added 2 new sites"),
  and pops.

**Wide screen:** `MasterDetailScaffold` — dive list (master) left, map + rich
candidates for the focused dive (detail) right; Confirm/Cancel along the bottom.

### Presentation — map widget

New `lib/features/dive_sites/presentation/widgets/match_sites_map.dart`:

- Inputs: dive entry `GeoPoint`, `List<MatchCandidateView>`, `selectedCandidateId`,
  `void Function(String candidateId) onSelectCandidate`.
- `FlutterMap` with the shared `TileLayer` (via `mapTileUrlProvider` /
  `mapTileMaxZoomProvider`), a dive pin, candidate `Marker`s (tappable via
  `GestureDetector`, styled by source + selection like `site_map_content.dart`),
  and `const MapAttribution()`.
- Camera: `CameraFit.bounds` over dive + candidate points, `maxZoom: 16` (reusing
  the existing tile-blanking guard); recenters when the focused dive changes.

## Entry points (unchanged)

The dives-list overflow "Match Dives to Sites" action and the post-download
"Match N dives to sites" button both still navigate to `/dives/match-sites`. The
`eligibleImportedDivesProvider` and `getDivesNeedingSiteMatch` query are unchanged.

## Impact on existing PR #287 code (refactor in place)

| File | Change |
|---|---|
| `site_matching_service.dart` | `run`→`computeProposals`; add `applyConfirmed`; remove `link`/`unlink` + rollback state; enrich `MatchCandidateView`; `DiveMatchEntry`→`MatchProposal`; add `ConfirmedMatch`/`ApplyResult` |
| `site_match_review_notifier.dart` | New state (focus/selections/isApplying); actions focus/select/skip/confirm; remove link/unlink |
| `site_match_review_page.dart` | Full rewrite (map + accordion + confirm bar + master-detail) |
| `match_sites_map.dart` | **New** map widget |
| l10n `app_en.arb` | Add map/skip/confirm/cancel/rich-field/snackbar keys; retire unlink/newly-added-only strings |
| Their three test files | Rewrite for compute/apply + select/confirm + new UI |

Unchanged: `DiveRepository.setSite`/`getDivesNeedingSiteMatch`, the v76
`siteMatchSensitivity` setting + migration, the entry points and their tests.

## Error handling

- `computeProposals` failure → `errorMessage` shown (matcher/gather errors).
- Bundled asset load failure → degrade to existing-sites-only (today's behavior).
- `applyConfirmed` failure → transaction rolls back; surface an error snackbar; the
  screen stays open with selections intact so the user can retry.
- Reverse-geocoding of created bundled sites stays best-effort.

## Testing strategy (TDD, ≥90% patch coverage)

- **Matcher** unit tests — unchanged.
- **`computeProposals`** — proposals + selections; assert **no** repository writes.
- **`applyConfirmed`** — link existing, materialize bundled, batch dedup,
  coincidence guard, skipped dives, transaction rollback on failure.
- **Notifier** — seed selections from clear matches; focus/select/skip; confirm
  builds the right `ConfirmedMatch` list; cancel writes nothing.
- **Page widget** — map renders; accordion focus; select via card updates summary;
  confirm bar enabled/disabled; result snackbar.
- **Map widget** — renders dive + candidate markers; tap calls `onSelectCandidate`.

## Out of scope (YAGNI)

- Searching for / creating an **arbitrary** site not among the candidates (stays in
  the normal dive-edit flow).
- Marker clustering (candidates per dive are few).
- Changing which dives are **eligible** (GPS + unsited, unchanged).
- Editing site details from this screen.

## Open guardrails

- `applyConfirmed` writes `siteId` (user-authored); the reparse path must still
  never overwrite it (already verified; keep the regression test).
- The DB transaction must wrap **all** writes in a confirm (links + bundled
  creations) so a partial failure leaves the database clean.
