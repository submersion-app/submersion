# Bottom Nav Customization — Design

**Status:** Draft
**Date:** 2026-04-20
**Scope:** Phone-mode bottom `NavigationBar` only

## Overview

Phone-mode users today see a fixed 5-slot bottom navigation: Home, Dives, Sites, Trips, More. The "More" overflow contains 9 further destinations. This design lets users choose which 3 destinations occupy the three customizable middle slots (slots 2-4); Home and More remain pinned to slots 1 and 5. The preference is device-wide, persisted via `SharedPreferences`, and does not affect wide-screen behavior.

### Goals

- Let users swap items between the primary bottom bar and the "More" overflow.
- Preserve current behavior for users who never open the settings page.
- Keep the data model small, normalize aggressively on read, and remain durable across app upgrades that add or remove destinations.

### Non-goals

- Customizing the wide-screen `NavigationRail` (phone-only scope).
- Reordering items inside the "More" sheet (overflow stays in canonical order).
- Per-diver customization (preference is global).
- Changing which screens exist; only their placement in the nav.

## User flow

1. User opens **Settings → Appearance → Navigation bar**.
2. The page shows a single list: a pinned Home row at the top, 11 movable destinations in the middle (via `ReorderableListView`), a pinned More row at the bottom.
3. A non-draggable divider row labelled *"Items below appear in the More menu"* sits between the third and fourth movable items.
4. The user drags items up or down. The top 3 movable items become primary slots 2-4; the rest populate the "More" sheet in canonical order.
5. Changes persist immediately (no save button). The bottom nav rebuilds on the next settings state change.
6. A **Reset to defaults** button restores `["dives", "sites", "trips"]`; it is disabled when the list already matches defaults.

## Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Home pinned to slot 1; More pinned to slot 5 | Dashboard is always the expected "home" gesture; More is needed as long as any destination overflows |
| 2 | Phone-only (≥800px unaffected) | Wide-screen rail has no primary/overflow distinction; customization is a phone-ergonomics feature |
| 3 | Global preference (`AppSettings`) | Nav ergonomics are about the device user, not the diver profile |
| 4 | Dedicated settings page under Appearance | Discoverable via settings browsing; no custom gesture handling |
| 5 | Primary slots only (overflow stays in default order) | Simpler data model and UI; solves the stated user need without scope creep |
| 6 | Single `ReorderableListView` with divider | One gesture, one widget, one built-in Flutter primitive |

## Data model

### `NavDestination` (new)

Canonical metadata for each nav destination. Defined in `lib/shared/widgets/nav/nav_destinations.dart`.

```dart
class NavDestination {
  final String id;                                  // stable key for persistence
  final String route;                               // passed to context.go(...)
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations) label;    // localized label
  final String Function(AppLocalizations)? subtitle;// for Courses / Planning
  final bool isPinned;                              // true for dashboard, more

  const NavDestination({
    required this.id,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.subtitle,
    this.isPinned = false,
  });
}
```

The constructor is `const`; the top-level list `kNavDestinations` is `final` (closures prevent the list from being `const`).

Ids are lowercase, kebab-cased (matching the route slugs). The 13 routable ids are:
`dashboard`, `dives`, `sites`, `trips`, `equipment`, `buddies`, `dive-centers`, `certifications`, `courses`, `statistics`, `planning`, `transfer`, `settings`.

A 14th entry — the `more` sentinel — is included in `kNavDestinations` with `route: ''` and `isPinned: true`; it represents the overflow control, not a destination. Total registry size: **14 entries** (13 routable + 1 sentinel). Movable set: **11 entries** (all except `dashboard` and `more`).

### `AppSettings` addition

```dart
// in settings_providers.dart
class SettingsKeys {
  // ...existing keys...
  static const String navPrimaryIds = 'nav_primary_ids';
}

class AppSettings {
  // ...existing fields...
  final List<String> navPrimaryIds; // length == 3
}
```

**Default:** `["dives", "sites", "trips"]` — matches today's behavior.

**Storage:** `SharedPreferences.setStringList('nav_primary_ids', [...])`.

### Read-path normalizer

All reads flow through a pure function that enforces invariants:

1. Drop ids not present in the current movable registry (handles renamed/removed destinations after an upgrade).
2. Drop the pinned ids `dashboard` and `more` if they somehow appear.
3. Deduplicate while preserving first-occurrence order.
4. Truncate to 3 if longer.
5. Pad with defaults (skipping already-present ids) until length is exactly 3.

This function lives in `AppSettingsRepository` and is unit-tested independently.

### Write-path validation

The `StateNotifier` method `updateNavPrimary(List<String> ids)` asserts length is exactly 3, all ids are in the movable registry, and no duplicates. Then it calls `SharedPreferences.setStringList` and emits new settings state.

## Providers (Riverpod)

Defined in `lib/shared/widgets/nav/nav_primary_provider.dart`.

```dart
final navDestinationsProvider = Provider<List<NavDestination>>((ref) => kNavDestinations);

final navPrimaryDestinationsProvider = Provider<List<NavDestination>>((ref) {
  final settings = ref.watch(settingsProvider);
  final all = ref.watch(navDestinationsProvider);
  final home = all.firstWhere((d) => d.id == 'dashboard');
  final more = all.firstWhere((d) => d.id == 'more');
  final byId = {for (final d in all) d.id: d};
  final middle = settings.navPrimaryIds
      .map((id) => byId[id])
      .whereType<NavDestination>()
      .take(3)
      .toList();
  return [home, ...middle, more]; // always length 5
});

final navOverflowDestinationsProvider = Provider<List<NavDestination>>((ref) {
  final all = ref.watch(navDestinationsProvider);
  final primaryIds = ref.watch(settingsProvider).navPrimaryIds.toSet();
  return all.where((d) => !d.isPinned && !primaryIds.contains(d.id)).toList();
});
```

## UI components

### `NavCustomizationPage` (new)

Path: `lib/features/settings/presentation/pages/nav_customization_page.dart`
Route: `/settings/appearance/navigation` (named `navCustomization`).

Structure (top to bottom):

- `AppBar` with localized title.
- Info paragraph: *"Drag items to reorder. The top three appear in your bottom navigation bar."*
- Pinned Home row: plain `ListTile` with Home icon, label, and a trailing `Icon(Icons.lock_outline)` with tooltip *"Always shown first"*.
- `ReorderableListView.builder`:
  - `itemCount: 12` (11 movable destinations + 1 divider).
  - `buildDefaultDragHandles: false`.
  - Movable items wrap a drag handle in `ReorderableDragStartListener(index: i, child: ...)`.
  - Divider row (at logical index 3) is a non-draggable `ListTile` with a subtle top/bottom border and the label *"Items below appear in the More menu"*.
- Pinned More row: same locked style as Home.
- `TextButton.icon(Icons.restore)` "Reset to defaults", disabled when order equals defaults.

### Divider snap-back

The divider is part of the `ReorderableListView` but must remain at index 3. In `onReorder`:

1. Reconstruct the movable list *without* the divider.
2. Apply the reorder to this 11-item list (using the indices of movable items, not raw indices).
3. If the user attempted to move the divider itself, ignore the reorder entirely.
4. Call `settingsNotifier.updateNavPrimary(newMovableList.take(3).toList())`.

### `MainScaffold` changes

Modify only the mobile branch (`main_scaffold.dart:412-456`):

- Read `ref.watch(navPrimaryDestinationsProvider)` (always length 5) and map each entry to `NavigationDestination`.
- `_calculateSelectedIndex` becomes dynamic: walk the primary list; return matching index or `primary.length - 1` (More).
- `_onDestinationSelected` walks the same list; index `length - 1` opens `_showMoreMenu`.
- `_showMoreMenu` reads `ref.watch(navOverflowDestinationsProvider)` and renders a `ListTile` per entry in canonical order.

The wide-screen branch (`main_scaffold.dart:276-411`) is **not** modified.

### Appearance page entry

Add a new `ListTile` in `appearance_page.dart` under the existing items:

- Leading `Icon(Icons.view_quilt_outlined)` (or similar)
- Title: `l10n.settings_navCustomization_title`
- Subtitle: a preview of the current primary slots (e.g., *"Home · Dives · Sites · Trips · More"*)
- Trailing `Icon(Icons.chevron_right)`
- `onTap`: `context.go('/settings/appearance/navigation')`

### Router registration

Add under the existing `/settings/appearance` GoRoute in `app_router.dart`:

```dart
GoRoute(
  path: 'navigation',
  name: 'navCustomization',
  builder: (context, state) => const NavCustomizationPage(),
),
```

## Localization

New ARB keys (added to `lib/l10n/arb/app_en.arb` and the 10 sibling locale files):

| Key | English |
|-----|---------|
| `settings_navCustomization_title` | Navigation bar |
| `settings_navCustomization_description` | Drag items to reorder. The top three appear in your bottom navigation bar. |
| `settings_navCustomization_dividerLabel` | Items below appear in the More menu |
| `settings_navCustomization_resetButton` | Reset to defaults |
| `settings_navCustomization_pinnedTooltip` | Always shown |
| `settings_navCustomization_moveUpLabel` | Move {destination} up |
| `settings_navCustomization_moveDownLabel` | Move {destination} down |
| `settings_navCustomization_subtitlePreview` | {first} · {second} · {third} |

## Edge cases

| # | Case | Behavior |
|---|------|----------|
| 1 | Stored id references a destination that no longer exists | Normalizer drops it and pads with defaults |
| 2 | Stored list has length ≠ 3 | Normalized to length 3 |
| 3 | Stored list contains duplicates | Deduplicated (first-occurrence order preserved), then padded |
| 4 | Stored list contains `dashboard` or `more` | Dropped (pinned ids are not movable) |
| 5 | Deep link lands on a route now in "More" | `_calculateSelectedIndex` returns the More index; existing behavior |
| 6 | Download-in-progress navigation guard | Unchanged; guard fires on all `context.go` calls |
| 7 | Window resizes across the 800px breakpoint | Natural transition; both branches already read the same settings |
| 8 | Screen reader / keyboard user | Each movable row exposes "Move up" and "Move down" semantic actions via `IconButton` pairs alongside the drag handle |

## Testing

**Unit:**

- `test/shared/widgets/nav/nav_destinations_test.dart` — registry invariants (14 entries = 13 routable + `more` sentinel, exactly 2 with `isPinned: true`, no duplicate ids, all ids match `^[a-z][a-z-]*$`, the 11-item movable set is exactly the registry minus `dashboard` and `more`).
- `test/features/settings/data/repositories/app_settings_nav_test.dart` — the normalizer, table-driven for each edge case above.

**Widget:**

- `test/features/settings/presentation/pages/nav_customization_page_test.dart` — initial render, drag emits expected update, divider snap-back, reset button enable/disable, semantic move actions.
- `test/shared/widgets/main_scaffold_test.dart` (extend) — mobile nav reflects `navPrimaryIds`, selected index resolves correctly under customization, More sheet omits primaries, wide-screen rail unaffected.

**Integration:**

- `integration_test/nav_customization_test.dart` — navigate to settings page, perform drag, verify bottom nav updates, verify persistence across a simulated relaunch, verify reset.

## Files affected

**Created:**

- `lib/shared/widgets/nav/nav_destinations.dart`
- `lib/shared/widgets/nav/nav_primary_provider.dart`
- `lib/features/settings/presentation/pages/nav_customization_page.dart`
- Tests listed above.

**Modified:**

- `lib/features/settings/presentation/providers/settings_providers.dart` — new field, new key, notifier method.
- `lib/features/settings/data/repositories/app_settings_repository.dart` — read/write with normalizer.
- `lib/shared/widgets/main_scaffold.dart` — mobile branch only; wide-screen branch untouched.
- `lib/core/router/app_router.dart` — register `/settings/appearance/navigation`.
- `lib/features/settings/presentation/pages/appearance_page.dart` — entry tile.
- `lib/l10n/arb/app_en.arb` and 10 sibling ARB files — new keys.

**Estimated size:** ~700 LOC added, ~80 LOC modified. Single PR.

## Out of scope (possible follow-ups)

- Refactor the wide-screen `NavigationRail` to use the same registry.
- Allow reordering inside the "More" overflow.
- Per-diver nav customization.
- Long-press on the bottom nav as an additional entry point to the customization UI.
