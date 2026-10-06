# Customizable Home Screen — Design

**Date:** 2026-08-07
**Status:** Approved
**Feature area:** `lib/features/dashboard/`, `lib/features/settings/`

## Goal

Let users choose which home screen cards appear and in what order. Editing
happens on the existing Settings > Appearance > Home page. Preferences are
per-device. The urgent banner (safety alert) is pinned and exempt.

## Decisions (user-approved)

| Decision | Choice |
| --- | --- |
| Scope | Hide/show and reorder cards |
| Edit surface | Settings > Appearance > Home (reorderable list + toggles) |
| Persistence | Per-device, SharedPreferences (no DB schema change) |
| Pinned blocks | Urgent banner only; everything else customizable |
| Layout model | Flat ordered card list + pure layout pass (Approach A) |
| Span control | Out of scope (rejected as YAGNI; data model allows adding a per-card span override later if demanded) |

## Data model

New enum `HomeCardType`, one value per customizable card (11):

```
hero, gaugeStrip, preDive, recentDives, quickActions, milestones,
photoRibbon, onThisDay, yearInReview, activeCourses, recentSitesMap
```

`UrgentBanner` is intentionally excluded: when triggered, it renders above
all customizable content (top of page). This replaces its current third-slot
position, which stops being a stable anchor once the hero and gauge strip
can move or hide.

Two new `AppSettings` fields, mirroring the existing `hiddenHomeChips`
pattern (SharedPreferences, per-device):

- `homeCardOrder: List<String>` — `HomeCardType.name` values in display
  order. Default: the current hardcoded order.
- `hiddenHomeCards: Set<String>` — cards toggled off. Default: empty.

Hiding a card does not remove it from `homeCardOrder`; it keeps its slot so
re-enabling restores its position.

### Reconciliation on read

- Unknown strings in the stored order are dropped (card removed in a future
  app version).
- `HomeCardType` values missing from the stored order (card added in a
  future app version) are inserted so new cards surface automatically after
  an update. Explicit rule: walk the default order; insert each missing card
  immediately after its closest preceding default-order neighbor that is
  present in the stored order, or at the front if no such neighbor exists.
- Reconciliation runs on read; the reconciled order is what both the
  dashboard and the settings page use, so users always edit the true
  effective order.

## Layout pass

Pure function in a new file
`lib/features/dashboard/presentation/home_layout.dart`:

```dart
List<DashboardEntry> buildDashboardEntries(List<HomeCardType> visibleCards)
```

`visibleCards` = user order, minus hidden cards, minus conditional cards
whose existing `show()` content gate failed. Packing rules:

| Card | Placement |
| --- | --- |
| `hero`, `gaugeStrip`, `preDive`, `photoRibbon`, `recentSitesMap` | `FullBlock` |
| `onThisDay`, `yearInReview`, `activeCourses` | `ThirdBlock` |
| `recentDives` | Lead of a `LeadSideGroup`; absorbs up to 2 side-capable cards that immediately follow it; with none following, renders as `FullBlock` |
| `quickActions`, `milestones` | Side-capable: packed into Recent Dives' side column when directly after it, otherwise standalone `ThirdBlock` |

Properties:

- The default order reproduces today's layout exactly (Quick Actions and
  Milestones follow Recent Dives by default, forming the current
  `LeadSideGroup`).
- Every card has exactly one fallback shape; no reachable configuration
  requires a rendering the grid does not already support.
- `DashboardPage.build` changes from a hardcoded literal list to: watch the
  two settings plus existing content providers, compute `visibleCards`, call
  `buildDashboardEntries`. `DashboardGrid`, the providers, and `show()`
  gating are untouched. Existing `DashboardGrid` constraints hold (no
  `IntrinsicHeight`; no `Expanded` inside cards).

**Empty state:** if no cards are visible (all hidden, or all remaining cards
empty), the page shows a centered message with a button to
Settings > Appearance > Home instead of a blank scroll view.

## Settings UI

`HomeAppearancePage` gains a **Cards** section above the existing gauge-chip
toggles:

- Reorderable list, one row per `HomeCardType` in the user's current order:
  drag handle, localized card name, visibility `Switch`. Hidden cards stay
  in the list (switch off, de-emphasized) and remain draggable.
- Conditional cards get the subtitle "Hides automatically when empty".
- **Reset to default** action restoring both order and visibility, behind a
  confirmation dialog.
- The Gauge chips section remains below, unchanged — chip toggles stay the
  finer-grained control inside the gauge strip card.
- Implementation note: use a single `CustomScrollView` with
  `SliverReorderableList` for the cards section; a shrink-wrapped
  `ReorderableListView` nested in a scrollable column disables
  auto-scroll-while-dragging.

Navigation is unchanged: phone route `/settings/appearance/home` and the
desktop `_sectionHubEntries` special-case already exist.

**Dashboard-side discoverability:** none in v1; the settings page is the
only entry point (matches chip toggles today). A dashboard overflow
"Customize…" shortcut is a possible follow-up.

**l10n:** ~14 new keys (11 card names, section title, auto-hide subtitle,
reset label and dialog text) in all 11 ARB files with real translations.

## Error handling

- Corrupt or malformed pref values fall back to defaults silently (same
  posture as `hiddenHomeChips`). The dashboard must never fail to render
  because of a bad pref.
- Reconciliation handles version skew in both directions.
- Per-card error containment is unchanged: always-on blocks contain their
  own error states; conditional cards resolve to hidden on error via
  `show()`.

## Testing

TDD; 80%+ coverage target.

**Unit — layout pass:**

- Default order produces today's exact block structure.
- Side cards adjacent / non-adjacent / split around Recent Dives.
- Recent Dives hidden → side cards render as `ThirdBlock`s.
- Recent Dives last in order → lead with empty side column.
- Empty visible list.
- Reconciliation: unknown names dropped; missing types inserted at default
  position.

**Unit — settings:**

- Order and hidden set round-trip through SharedPreferences.
- Corrupt value → defaults.
- All four mock `SettingsNotifier` classes gain the two new methods via
  `getBaseOverrides({settingsNotifier})` (Riverpod 3 forbids
  double-override).

**Widget — dashboard:**

- Respects a custom order; hidden card absent.
- Urgent banner renders on top regardless of order.
- All-hidden empty state with working settings link.
- One phone-width (~400 px) page test — the redesign's `RenderFlex`
  collapse was invisible at the default 800 px test width.

**Widget — settings page:**

- Drag reorder persists; toggle persists.
- Reset restores defaults after confirmation.
- May need `scrollUntilVisible` at 800×600.

## Out of scope

- Per-card span control (grid designer).
- Per-diver / synced persistence (would need a schema bump; revisit if users
  ask for cross-device layouts).
- Dashboard-side edit mode or customize shortcut.
- Any change to gauge-chip toggles or `DashboardGrid` internals.
