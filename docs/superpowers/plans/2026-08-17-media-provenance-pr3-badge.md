# Media Provenance PR 3: The Status Badge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make media health scannable at a glance in the grids, and give the library grid a route into the info panel.

**Architecture:** One combined badge derived from PR 2a's cheap `mediaProvenanceProvider`, replacing the transfer-only badge. A pure ladder function decides the state so it can be tested without a widget tree.

**Spec:** `docs/superpowers/specs/2026-08-16-media-provenance-design.md` section 8.

**Predecessor:** PR 2b (`#1122`), itself stacked on PR 2a (`#1120`). Retarget down the stack as each merges.

**Branch / worktree:** `worktree-media-provenance-pr3` at `.claude/worktrees/media-provenance-pr3`.

## Global Constraints

- **No em-dashes** (U+2014), stated by codepoint so this file does not trip its own check. No emojis.
- **No schema change.** No new capability: this renders state PR 2a already computes.
- All 11 ARB catalogs stay at exact key parity.
- `dart format --set-exit-if-changed .` exits 0; `flutter analyze` reports no issues.

## Verified Facts (do not re-derive)

1. **`MediaStoreBadge` has exactly ONE consumer in lib:** `media_grid.dart:138`. Its state enum is `MediaBadgeState { none, queued, transferring, failed, notBackedUp }`, and it reads `mediaBadgeStateProvider`, a `StreamProvider.family` keyed by the whole `MediaItem`.
2. **`MediaLibraryTile`** (`media_library_grid.dart:8-52`) is a `StatelessWidget` with `onTap` and `onLongPress`, wrapping `MediaItemView` in a `Stack`. Top-right holds the selection check; **top-left is free**.
3. **Long-press is unavailable.** `MediaLibraryTile.onLongPress` is claimed by selection toggling in `media_library_view.dart:114-116`. The context-menu channel is `onSecondaryTapDown` plus `showMenu`, matching `dive_media_section.dart:595-600`.
4. **Test surface to migrate:** `test/features/media_store/media_store_badge_test.dart` (245 lines) plus ONE test in `media_store_providers_test.dart` ("the badge provider is defensive when the cache DB is ...").

## Why this supersedes rather than extends

The spec said "extends the existing `MediaStoreBadge`". It does not, and the reason is measurable rather than stylistic: `mediaBadgeStateProvider` opens its own `watchLatestForMedia` stream per tile, and PR 2a's `mediaQueueFactsProvider` opens another. Keeping both would make **every visible thumbnail subscribe to the transfer queue twice**, which is exactly the per-tile cost PR 2a's provider split existed to avoid.

The new badge is also a strict superset: it covers all four meaningful `MediaBadgeState` values and adds `broken` and `cloudOnly`. So `MediaStoreBadge`, `MediaBadgeState` and `mediaBadgeStateProvider` are deleted along with their tests, rather than left as dead code with a contradictory ladder.

## The ladder

Ordered, first match wins.

| State | Condition | Glyph |
| --- | --- | --- |
| `broken` | origin missing AND not (backed up AND store attached) | `error_outline`, error tint |
| (stop) | source not eligible for backup | nothing |
| `transferFailed` | queue state `failed` | `cloud_off`, error tint |
| `transferring` | queue state `transferring` | `cloud_upload` |
| `queued` | queue state `pending` | `schedule` |
| `cloudOnly` | origin missing AND backed up AND store attached | `cloud` |
| `notBackedUp` | store attached AND nothing uploaded | `cloud_off` |
| `none` | otherwise | nothing |

Two rules that are easy to get wrong:

- **`broken` is evaluated BEFORE the eligibility gate**, so a dead URL still reads as broken. It also renders with no store attached, unlike everything below it.
- **`cloudOnly` requires the store to be attached.** An item whose local file is gone and whose bytes are only in a store this device cannot reach is not "cloud only", it is unviewable, which is `broken`.

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/features/media/domain/entities/media_status.dart` | Create: `MediaStatus` and the pure ladder | 1 |
| `lib/l10n/arb/app_*.arb` (11) | Modify: 6 tooltip keys plus a menu label | 2 |
| `lib/features/media/presentation/widgets/media_status_badge.dart` | Create: the badge widget | 3 |
| `lib/features/media/presentation/widgets/media_grid.dart` | Modify: swap the badge | 3 |
| `lib/features/media/presentation/widgets/media_library_grid.dart` | Modify: badge slot plus right-click menu | 4 |
| Deletions | `media_store_badge.dart`, its test, `mediaBadgeStateProvider`, `MediaBadgeState`, one provider test | 3 |

---

### Task 1: The ladder

**Files:**
- Create: `lib/features/media/domain/entities/media_status.dart`
- Test: `test/features/media/domain/entities/media_status_test.dart`

**Interfaces:**
- Produces: `enum MediaStatus { none, broken, transferFailed, transferring, queued, cloudOnly, notBackedUp }` and `MediaStatus mediaStatusFor(MediaProvenance provenance)`.

A pure function so the ladder is table-testable without pumping a widget.

- [x] **Step 1: Write the failing test.** Table-driven over every state, plus these specifically:

```dart
test('a missing row with no backup is broken', ...);
test('broken outranks everything below it', ...);
test('a missing INELIGIBLE row is still broken', ...);   // gate comes after
test('an ineligible row is otherwise silent', ...);       // url rows never nag
test('a failed queue row outranks notBackedUp', ...);
test('a transferring row outranks notBackedUp', ...);
test('a missing but backed-up row is cloudOnly', ...);
test('a missing backed-up row with NO store attached is broken', ...);
test('a healthy backed-up row is silent', ...);
test('a healthy unbacked row with no store attached is silent', ...);
```

- [x] **Step 2: Run and confirm failure.**
- [x] **Step 3: Implement**, exhaustive over the queue-state strings with a default of "no transfer in flight".
- [x] **Step 4: Run.** Expected PASS.
- [x] **Step 5: Format, analyze, commit.**

---

### Task 2: Tooltip strings

**Files:** all 11 `lib/l10n/arb/app_*.arb`; extend `test/l10n/media_info_strings_test.dart`.

7 keys, added with the same script pattern as PR 2a and 2b (textual insertion, re-parse to prove valid JSON).

```
media_status_broken         "Missing and not backed up"
media_status_transferFailed "Upload failed"
media_status_transferring   "Uploading"
media_status_queued         "Waiting to upload"
media_status_cloudOnly      "Stored in the cloud only"
media_status_notBackedUp    "Not backed up"
media_tile_infoMenuItem     "Media info"
```

- [x] **Step 1** Extend the strings test, expecting failure.
- [x] **Step 2** Add keys to all 11, `flutter pub get` to regenerate.
- [x] **Step 3** `flutter test test/l10n/`. Expected PASS.
- [x] **Step 4** Format and commit with the regenerated files.

---

### Task 3: The badge widget, and the deletions

**Files:**
- Create: `lib/features/media/presentation/widgets/media_status_badge.dart`
- Modify: `lib/features/media/presentation/widgets/media_grid.dart`
- Delete: `lib/features/media_store/presentation/widgets/media_store_badge.dart`, `test/features/media_store/media_store_badge_test.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart` (drop `mediaBadgeStateProvider`), `test/features/media_store/media_store_providers_test.dart` (drop its one test)
- Test: `test/features/media/presentation/widgets/media_status_badge_test.dart`

**Interfaces:**
- Produces: `class MediaStatusBadge extends ConsumerWidget { const MediaStatusBadge({super.key, required this.item}); }`

Keeps `MediaStoreBadge`'s visual contract: a 10-radius `CircleAvatar`, 13px icon, `SizedBox.shrink()` when silent. Adds a `Tooltip` and a tap that opens the info panel.

The tap must not also open the viewer. Wrap the badge in its own `GestureDetector` with `behavior: HitTestBehavior.opaque`, which claims the gesture before the tile's `onTap`.

- [x] **Step 1: Write the failing test.** Cover: silent state renders nothing; each visible state renders its icon; the tooltip resolves; tapping opens `MediaInfoPanel` and does NOT fire the tile's onTap.
- [x] **Step 2: Run and confirm failure.**
- [x] **Step 3: Implement,** then swap `media_grid.dart:138` and perform the deletions.
- [x] **Step 4: Run** the media and media_store suites. Expected: PASS with the deleted tests' counts removed and the new ones added.
- [x] **Step 5: Format, analyze, commit.**

---

### Task 4: The library tile

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_library_grid.dart`
- Test: `test/features/media/presentation/widgets/media_library_tile_test.dart`

Adds the badge in the free top-left corner, and `onSecondaryTapDown` opening a `showMenu` with a single Media info item. Desktop-only, matching `dive_media_section`: `onSecondaryTapDown` does not fire on touchscreens, so this is a desktop affordance and mobile keeps the viewer's info button as its route in.

- [x] **Step 1: Write the failing test.** Cover: the badge renders for an unhealthy entry; long-press still reaches `onLongPress` (selection must not regress); tap still reaches `onTap`.
- [x] **Step 2: Run and confirm failure.**
- [x] **Step 3: Implement.**
- [x] **Step 4: Run** the media presentation suites. Expected: PASS, existing counts unchanged.
- [x] **Step 5: Format, analyze, commit.**

---

### Task 5: Full verification

- [x] `dart format --set-exit-if-changed .` exits 0.
- [x] `flutter analyze` reports no issues. Do not pipe through `tail`.
- [x] `flutter test` redirected to a file, exit code captured explicitly.
- [x] `git diff --stat origin/main...HEAD -- lib/core/database lib/features/sync` is empty.
- [x] No em-dash entered source:
  ```bash
  EMDASH=$(printf '\xe2\x80\x94')
  git diff origin/main...HEAD -- lib test | grep -n "^+.*$EMDASH" || echo "clean"
  ```
- [x] Push and open the PR against `worktree-media-provenance-pr2b`.

## Self-Review

**Spec coverage.** Section 8's ladder is Task 1, its gating rules are Task 1's tests, mounting is Tasks 3 and 4, and the tile entry point deferred from PR 2a lands in Task 4.

**Deviation.** The spec says "extends" `MediaStoreBadge`; this supersedes and deletes it, justified above by the double queue subscription. Stated at the point of deletion in the commit as well.

**Type consistency.** `mediaStatusFor(MediaProvenance) -> MediaStatus` from Task 1 is used in Task 3. `MediaStatusBadge({required MediaItem item})` from Task 3 is used in Tasks 3 and 4.
