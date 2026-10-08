# Highlight Last-Visited Item in Phone-Mode Lists

## Problem

In phone mode, the list → detail → back flow gives the user no visual anchor on return. Every card looks identical to its neighbors, so after reading a dive (or site, trip, buddy, etc.) the user cannot see which one they just left. This is especially disorienting in long lists and in views sorted in non-obvious ways.

The problem spans eight list features, all of which use the same navigation pattern and all of which already have most of the plumbing to fix this.

## Goal

When the user taps an item in a phone-mode list (detailed or compact card view) and later returns to the list, that item's card is tinted using the existing `primaryContainer.withValues(alpha: 0.3)` highlight color, so the user can see at a glance where they left off.

## Scope

Applies to these features in phone-mode card lists (detailed and compact variants):

- Dives
- Sites
- Trips
- Equipment (gear)
- Buddies
- Dive Centers
- Certifications
- Courses

## Out of Scope

- Desktop/tablet master-detail layouts (already highlight correctly via `widget.selectedId`).
- Table view in Dives (already highlights via `highlightedId` passed to `DiveTableView`).
- Dense view variants where they exist — users who pick dense generally prioritize density over chrome; no requests in flight to add highlight there. Can be layered in later if needed.
- No new colors, no fade animation, no auto-scroll-into-view.
- No changes to bulk-selection mode (already clears the highlight on entry).
- No behavioral changes to the detail pages themselves.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Highlight persistence | Until next tap or leaving the tab | Matches existing desktop/master-detail behavior already shipped on Sites/Trips/Buddies; lowest-risk, one line per feature. |
| Scroll-into-view on return | No | Phone lists are kept alive by the ShellRoute, so scroll position is usually already showing the tapped item. Adding scroll animation risks surprising users who scrolled after returning. Revisit if it feels wrong in practice. |
| Color / tint | Reuse `primaryContainer.withValues(alpha: 0.3)` via `isSelected` | All tiles already apply this tint when `isSelected == true` in master-detail mode; no new theming surface. |
| Providers | Reuse existing `highlighted<X>IdProvider` StateProviders | All 8 exist already; adding parallel state would split the source of truth. |
| Stale-ID handling on diver switch | Ignore | A stale highlighted ID won't match any visible item, so it's invisible. Clearing it adds coupling to diver-switch code for no user-visible benefit. |
| Stale-ID handling on delete | Ignore | Same reasoning — if the highlighted dive is deleted, no card matches and nothing renders highlighted. |

## Root Cause of the Bug

For each of the 8 features, three wiring pieces exist:

1. `highlighted<X>IdProvider` — a `StateProvider<String?>` that holds the last-tapped item ID.
2. The phone-mode tap handler sets this provider on tap.
3. Tiles accept an `isSelected` bool and render the highlight tint when true.

The phone-mode `ListView.builder` path, however, passes a value to `isSelected` that is derived only from:

- `_selectedIds.contains(item.id)` — bulk-selection checkbox state
- `widget.selectedId == item.id` — master-detail state, which is `null` in phone mode

It does **not** observe the `highlighted<X>IdProvider`. So the provider is set correctly on tap, but no tile ever reads it.

This is visible in [dive_list_content.dart:1357-1376](../../lib/features/dive_log/presentation/widgets/dive_list_content.dart#L1357-L1376):

```dart
final isSelected = _selectedIds.contains(dive.id);
final isMasterSelected = widget.selectedId == dive.id;   // null on phone
// ...
isSelected: _isSelectionMode
    ? isSelected
    : (isSelected || isMasterSelected),
```

Desktop/table paths work because they do read the provider. For example the table branch at [dive_list_content.dart:1280](../../lib/features/dive_log/presentation/widgets/dive_list_content.dart#L1280) passes `highlightedId: ref.watch(highlightedDiveIdProvider)` into `DiveTableView`, which applies the tint internally. Phone-mode cards don't have that read.

## Architecture

Per-feature pattern — identical across all 8, applied in the list-content widget's phone-mode `ListView.builder`.

**Step 1.** Watch the highlighted provider at the top of the builder closure (or in `build`):

```dart
final highlightedId = ref.watch(highlighted<X>IdProvider);
```

**Step 2.** OR the match into `isSelected` for each tile:

```dart
final isHighlighted = highlightedId == item.id;
// ...
isSelected: _isSelectionMode
    ? isBulkSelected
    : (isBulkSelected || isMasterSelected || isHighlighted),
```

**Step 3.** Verify the tap handler sets the provider. Dives already does this at [dive_list_content.dart:808](../../lib/features/dive_log/presentation/widgets/dive_list_content.dart#L808). The pattern is:

```dart
ref.read(highlighted<X>IdProvider.notifier).state = item.id;
// ...then navigate
```

### Per-feature touch points

Each feature's list content widget has a single phone-mode `ListView.builder` (sometimes inside a switch over view mode — detailed / compact). The patch per feature is:

- Add one `ref.watch(highlighted<X>IdProvider)` read.
- In both the detailed and compact branches, OR `highlightedId == item.id` into the `isSelected` expression already passed to the tile.
- Confirm tap handler sets the provider; add the write if missing.

Files to modify (verified during exploration):

- `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- `lib/features/dive_sites/presentation/widgets/site_list_content.dart`
- `lib/features/trips/presentation/widgets/trip_list_content.dart`
- `lib/features/equipment/presentation/widgets/equipment_list_content.dart`
- `lib/features/buddies/presentation/widgets/buddy_list_content.dart`
- `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`
- `lib/features/certifications/presentation/widgets/certification_list_content.dart`
- `lib/features/courses/presentation/widgets/course_list_content.dart`

Providers already exist and do not need to be created or moved.

### Audit findings for tap-handler writes

A deeper grep of each feature's `_handleItemTap` method (the phone-mode tap path) found that only **Dives** writes to its `highlighted<X>IdProvider` before navigating ([dive_list_content.dart:808](../../lib/features/dive_log/presentation/widgets/dive_list_content.dart#L808)). The other 7 features write to the provider only in the table view's `onEntityTapDown` callback, which isn't on the phone-mode code path. So each of the 7 needs a one-line addition to its phone tap handler in addition to the read-side change.

Per-feature `_handleItemTap` locations to patch:

- [site_list_content.dart:136-159](../../lib/features/dive_sites/presentation/widgets/site_list_content.dart#L136-L159)
- [trip_list_content.dart:106-113](../../lib/features/trips/presentation/widgets/trip_list_content.dart#L106-L113)
- [buddy_list_content.dart:129-141](../../lib/features/buddies/presentation/widgets/buddy_list_content.dart#L129-L141)
- [equipment_list_content.dart:96-101](../../lib/features/equipment/presentation/widgets/equipment_list_content.dart#L96-L101)
- [dive_center_list_content.dart:129-147](../../lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart#L129-L147)
- [certification_list_content.dart:105-109](../../lib/features/certifications/presentation/widgets/certification_list_content.dart#L105-L109)
- [course_list_content.dart:49-55](../../lib/features/courses/presentation/widgets/course_list_content.dart#L49-L55)

For features with bulk-selection mode (Sites, Buddies, Dives), the provider write must be gated on `!_isSelectionMode` to match the existing pattern. Dives already does this via an early-return path; others should follow suit.

## Testing

One widget test per list-content widget (8 total), each asserting:

1. Setting `highlighted<X>IdProvider` to a known item's ID causes that tile to receive `isSelected == true` (or renders the highlight tint).
2. Clearing the provider removes the highlight.
3. Bulk-selection mode takes precedence (already tested via existing tests where present; extend if needed).

Use Riverpod's `overrides` on `ProviderScope` to seed the provider state for each test. No repository mocks required — the list-content widgets render from in-memory data that can be supplied via existing provider overrides or minimal fake summaries.

Coverage target: 80% of modified code, consistent with CLAUDE.md project rules.

## Rollout

No migration, no feature flag, no settings change. The visible effect is strictly additive: previously blank-on-return, now tinted-on-return. Reversible by a single git revert if any unforeseen regression appears.
