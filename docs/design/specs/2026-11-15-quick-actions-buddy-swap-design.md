# Swap with a buddy from Quick Actions

Date: 2026-11-15. Release: v1.8.5.

## Intent

The buddy card swap (issue #3728, PR #3785) is used on the boat after a dive,
standing next to a new buddy, often with wet hands. Today it is reached only
through a small swap icon in the Buddies list header. The home page is where
the app opens, so its Quick Actions card should start the swap in one tap.

## Goals

- A "Swap with a buddy" button in the home page Quick Actions card.
- The same button in the Buddies section's own Quick Actions box (the desktop
  summary pane shown when no buddy is selected), beside Add Buddy.

## Non-goals

- No change to the swap screen itself.
- No new home card, and no change to which cards are shown by default.

## Anti-goals

- A button that opens the "not available in a browser" page, or that bypasses
  the demo-mode seal. Every entry point to the swap behaves like the existing
  Buddies list icon.
- A stray gap in the card where a hidden button would have been.

## Approaches

| Approach | Trade-off |
| --- | --- |
| **A. Third button, outlined (chosen)** | Sits after Log Dive and Plan Dive, above Insights; reachable without scrolling on a phone; Log Dive stays the one filled button. |
| B. Second button, tonal | More prominent, but two tonal buttons compete or Plan Dive is demoted. |
| C. Last button | Smallest change, slowest to reach in the moment it is for. |

A separate home card for the swap was ruled out: more surface for one
button, and a user who hid Quick Actions has already opted out of shortcuts.

## Design

- **Home Quick Actions card** (`lib/features/dashboard/presentation/widgets/quick_actions_card.dart`):
  new full-width `OutlinedButton.icon` in third place, icon `Icons.swap_horiz`,
  label `buddySwap_title` ("Swap with a buddy", already translated).
- **Buddies summary pane** (`buddy_summary_widget.dart`, `_buildQuickActions`):
  an outlined "Swap with a buddy" button after the filled Add Buddy button in
  the same `Wrap`.
- **Shared rules** in `lib/features/buddies/presentation/widgets/swap/`, used by
  the existing header icon and both new buttons, so the three cannot drift:
  - hidden when `deviceCapabilitiesProvider.nearby` is false (a browser), with
    no leftover spacing;
  - on tap, `demoSealGuard(context, DemoSealedFeature.share)` first, then
    `context.push('/buddies/swap')` (push, so back returns to where the user
    was, matching the other Quick Actions).
- No new strings, no schema change.

## Left to the builder

- The exact shape of the shared helper (a function plus a labelled button
  widget beside the existing icon button is the expected form).
- Widget tests: the button shows and pushes `/buddies/swap` on a device with
  nearby support, is absent (and leaves no gap) without it, and is blocked in
  demo mode; for both the home card and the Buddies pane.
