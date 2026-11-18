# Swap with a buddy in Quick Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start the buddy card swap from the home Quick Actions card and from the Buddies summary pane, with the same browser and demo-mode rules as the Buddies list icon.

**Architecture:** One shared open helper and one labelled button live beside the existing `SwapWithBuddyButton`; the icon button, the home card and the Buddies pane all use them, so the rules cannot drift.

**Tech Stack:** Flutter, Riverpod, go_router.

**Spec:** `docs/design/specs/2026-11-15-quick-actions-buddy-swap-design.md` (issue #4591)

## Global Constraints

- Label is the existing `buddySwap_title` ("Swap with a buddy"); icon `Icons.swap_horiz`. No new strings.
- Hidden when `deviceCapabilitiesProvider.nearby` is false, leaving no spacing behind.
- Tap runs `demoSealGuard(context, DemoSealedFeature.share)` first, then `context.push('/buddies/swap')` (push, never go).
- Tests that set `DemoModeGate.instance.debugActive` restore it with `tearDown(applyGlobalTestDefaults)`.

## Review Focus

- A browser: no button and no 8 px gap in the home card (Task 1 size test, Task 2 absence test).
- Demo mode: the button stays visible, shows the note, and does not navigate (Task 1 demo test).
- Back from the swap returns to home, not to Buddies: push, not go (Task 1 navigation test asserts the pushed route sits above the start route).
- The home card's order: Plan Dive above Swap above Insights (Task 2 order test).
- The card still fits the phone column and the desktop side column without overflow (Task 2 tests pump the card in its existing 400 px test box; after screenshots check both widths).

---

### Task 1: Shared open helper and labelled button

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/swap/swap_with_buddy_button.dart`
- Test: `test/features/buddies/presentation/widgets/swap/swap_with_buddy_button_test.dart`

**Interfaces:**
- Produces:
  - `void openBuddySwap(BuildContext context)`: guard, then push `/buddies/swap`.
  - `class SwapWithBuddyActionButton extends ConsumerWidget` with
    `const SwapWithBuddyActionButton({super.key, this.padding = EdgeInsets.zero, this.expand = false})`
    (`EdgeInsetsGeometry padding`, `bool expand`). Renders an
    `OutlinedButton.icon` (icon `Icons.swap_horiz`, label `buddySwap_title`)
    inside `padding`; full width when `expand`; `SizedBox.shrink()` (padding
    included) when nearby is unavailable.
  - `SwapWithBuddyButton` keeps its API and calls `openBuddySwap`.

- [ ] **Step 1: Write the failing tests** (a `GoRouter` with `/` hosting the button and `/buddies/swap` showing `Text('SWAP-PAGE')`, via `testAppRouter`)
  - `labelled button opens the swap on top of the current page`: tap `find.text('Swap with a buddy')`, settle; `find.text('SWAP-PAGE')` found; `router.canPop()` is true.
  - `labelled button is absent in a browser, padding and all`: override `DeviceCapabilities.web`, pump `SwapWithBuddyActionButton(padding: EdgeInsets.only(top: 8), expand: true)`; `find.byType(OutlinedButton)` finds nothing; `tester.getSize(find.byType(SwapWithBuddyActionButton))` equals `Size.zero`.
  - `demo mode explains the seal and stays put`: `DemoModeGate.instance.debugActive = true`; tap; `find.text('Not available in demo mode')` found, `SWAP-PAGE` not found.
  - `the header icon opens the swap too`: tap `find.byIcon(Icons.swap_horiz)` on `SwapWithBuddyButton`; `SWAP-PAGE` found.

- [ ] **Step 2: Run to verify the new tests fail**

Run: `flutter test test/features/buddies/presentation/widgets/swap/swap_with_buddy_button_test.dart`
Expected: compile failure, `SwapWithBuddyActionButton` not defined.

- [ ] **Step 3: Implement `openBuddySwap` and `SwapWithBuddyActionButton`; point `SwapWithBuddyButton.onPressed` at `openBuddySwap`.**

- [ ] **Step 4: Run the tests to verify they pass** (same command; all PASS, the two existing tests included).

- [ ] **Step 5: Commit** `feat(buddies): shared swap button for quick actions`

### Task 2: Home Quick Actions card

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/quick_actions_card.dart`
- Test: `test/features/dashboard/presentation/quick_actions_card_test.dart`

**Interfaces:**
- Consumes: `SwapWithBuddyActionButton(padding: EdgeInsets.only(top: 8), expand: true)` from Task 1, placed between the Plan Dive button and the Insights block (the Insights block keeps its own leading `SizedBox(height: 8)`).

- [ ] **Step 1: Write the failing tests** (add `/buddies/swap` → `Text('SWAP-PAGE')` to the file's router)
  - `Swap with a buddy sits between Plan Dive and Insights`: the `dy` of `find.text('Plan Dive')` < `find.text('Swap with a buddy')` < `find.text('Insights')`.
  - `Swap with a buddy opens the swap screen`: tap, settle, `SWAP-PAGE` found.
  - `a browser shows no swap action`: override `DeviceCapabilities.web`; `find.text('Swap with a buddy')` finds nothing; Insights still present.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dashboard/presentation/quick_actions_card_test.dart`
Expected: the first two FAIL (text not found).

- [ ] **Step 3: Insert the button.**

- [ ] **Step 4: Run the card, home layout, dashboard card and dashboard page tests**

Run: `flutter test test/features/dashboard/presentation/`
Expected: all PASS.

- [ ] **Step 5: Commit** `feat(dashboard): swap with a buddy in home quick actions`

### Task 3: Buddies summary pane

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_summary_widget.dart` (`_buildQuickActions`)
- Test: `test/features/buddies/presentation/widgets/buddy_summary_widget_test.dart`

**Interfaces:**
- Consumes: `const SwapWithBuddyActionButton()` from Task 1, after the Add Buddy `FilledButton.icon` in the same `Wrap`.

- [ ] **Step 1: Write the failing tests**
  - `Quick Actions offers Swap with a buddy beside Add Buddy`: `find.text('Swap with a buddy')` found once; its `dx` is greater than `find.text('Add Buddy')`'s at a wide surface.
  - `a browser shows only Add Buddy`: override `DeviceCapabilities.web`; swap text not found; `Add Buddy` found.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_summary_widget_test.dart`
Expected: the first FAILS.

- [ ] **Step 3: Add the button.**

- [ ] **Step 4: Run** `flutter test test/features/buddies/` **, then** `dart format .` **,** `flutter analyze` **and** `flutter test test/architecture/`
Expected: all PASS, no analyzer issues.

- [ ] **Step 5: Commit** `feat(buddies): swap with a buddy in the Buddies quick actions`
