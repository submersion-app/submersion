# Buddy swap screen redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Swap with a buddy screen as option A: your card on top,
nearby divers, then "Give your card" and "Get their card" groups, with two
columns on wide windows.

**Architecture:** The page keeps all session, request-queue, NFC, file and
QR logic; only its `build` changes. The layout moves into three section
widgets under `lib/features/buddies/presentation/widgets/swap/`, each driven
by plain values and callbacks, so they test without a session.

**Tech Stack:** Flutter, Riverpod, flutter_localizations ARB files (11
locales), flutter_test widget tests.

**Spec:** `docs/design/specs/2026-11-15-buddy-swap-screen-redesign-design.md`
(issue #4598).

## Global Constraints

- No change to the swap protocol, `BuddySwapSession`, the request sheet, the
  share choices sheet, the QR sheet or the card preview page.
- Platform rules for methods stay as today: NFC sticker on iOS and Android
  only; "Tap an Android phone" on iOS only; "Receive by tap" on Android only.
- Two columns when the page body is at least 720 logical pixels wide.
- Every new or changed string is translated in all 11 ARB files
  (ar, de, en, es, fr, he, hu, it, nl, pt, zh); `flutter gen-l10n` runs after
  the translations are in, never before.
- No em-dashes anywhere; no emojis.

## Review Focus

1. A long email or certification name in a chip at phone width (320 px):
   chips ellipsize, no overflow. Test in Task 2.
2. Width exactly 719 vs 720: one column vs two. Test in Task 5.
3. Card could not be built: card error shown, nearby and Give absent, Get
   present and working. Test in Task 5.
4. A diver already asked: their row shows "Waiting for <name>", is not
   tappable, and shows no Swap label. Test in Task 3.
5. macOS: no NFC rows in either group. Test in Task 4.

---

### Task 1: Strings

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

ARB files are feature-grouped: insert new keys beside the existing
`buddySwap_*` keys in each file.

- [ ] **Step 1: Add these keys to every ARB** (English values below; write a
  real translation for each other locale, with `@` metadata for
  placeholders in `app_en.arb`):

| Key | English |
| --- | --- |
| `buddySwap_yourCard` | Your card |
| `buddySwap_nearby_title` | Nearby |
| `buddySwap_nearby_status` | Looking for divers. Your buddy needs this screen open and Submersion 1.8.4 or later. |
| `buddySwap_give_heading` | Give your card |
| `buddySwap_get_heading` | Get their card |
| `buddySwap_hint_showCode` | Your buddy scans it |
| `buddySwap_hint_sendFile` | AirDrop, Quick Share, email or a message |
| `buddySwap_hint_writeSticker` | Anyone who taps it gets your card |
| `buddySwap_hint_scanCode` | Point the camera at your buddy's code |
| `buddySwap_hint_openFile` | A card file your buddy sent you |
| `buddySwap_hint_receiveByTap` | Hold your phone against your buddy's |
| `buddySwap_hint_tapAndroid` | Read the card an Android phone is sharing |
| `buddySwap_chip_since` | Diving since {year} (`year`: String) |
| `buddySwap_chip_lastDive` | Last dive {date} (`date`: String) |

- [ ] **Step 2: Change these values in every ARB** (keys unchanged):
  `buddySwap_action_scanCode` "Scan their code",
  `buddySwap_action_sendFile` "Send as a file",
  `buddySwap_action_openFile` "Open a card file",
  `buddySwap_action_writeSticker` "Write an NFC sticker",
  `buddySwap_qr_tooLarge` "Your card is too long for a code. Try Send as a
  file instead."

- [ ] **Step 3: Remove these keys from every ARB** once Tasks 3 to 5 no
  longer use them (do this step at the end of Task 5):
  `buddySwap_nearby_heading`, `buddySwap_nearby_tapToSwap`,
  `buddySwap_nearby_looking`, `buddySwap_nearby_hint`, `buddySwap_sharing`,
  `buddySwap_sharing_change`. Confirm with
  `grep -rn "<key>" lib test` that nothing else uses each.

- [ ] **Step 4: Generate and verify**

Run: `flutter gen-l10n && grep -A1 "get buddySwap_give_heading" lib/l10n/arb/app_localizations_de.dart`
Expected: the German text, not "Give your card". `git diff --numstat lib/l10n/arb/` shows an even count across locales.

- [ ] **Step 5: Commit** `i18n(buddies): strings for the swap screen redesign`

### Task 2: Your card section

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/swap/card_summary.dart`
- Create: `lib/features/buddies/presentation/widgets/swap/your_card_section.dart`
- Test: `test/features/buddies/presentation/widgets/swap/your_card_section_test.dart`

**Interfaces:**
- Produces: `List<String> buddyCardChips(BuddyCard card, AppLocalizations l10n, String Function(DateTime) formatDate)`
  in `card_summary.dart`: in order phone, email, social, first cert name,
  `buddySwap_dives(dives)`, `buddySwap_chip_since('$since')`,
  `buddySwap_chip_lastDive(formatDate(last))`; nulls and an empty cert list
  are skipped. `buddyCardSummary` stays (the request sheet uses it).
- Produces: `YourCardSection({required BuddyCard? card, required VoidCallback onEdit})`.
  `card == null` means the card could not be built: shows
  `buddySwap_cardFailed`, no Edit. Otherwise a tinted rounded container
  (`colorScheme.surfaceContainerHighest`) with `ProfileAvatar(photo, initials)`,
  the name, `buddySwap_yourCard` under it, a `TextButton` `common_action_edit`
  calling `onEdit`, and a `Wrap` of `Chip`s whose labels have
  `maxLines: 1, overflow: TextOverflow.ellipsis` inside a width-capped box.
  The section reads the date formatter from `UnitFormatter(ref.watch(settingsProvider)).formatDate`
  (make it a `ConsumerWidget`).

- [ ] **Step 1: Write failing tests**
  - `buddyCardChips lists shared values in share-sheet order`: card with
    phone, email, cert "Advanced Open Water Diver", dives 342, since 2014
    gives `['+1 555 0199', 'j@x.com', 'Advanced Open Water Diver', '342 dives', 'Diving since 2014']`.
  - `buddyCardChips skips what the card does not carry`: name-only card gives `[]`.
  - `section shows name, Your card, chips and Edit calls back`.
  - `a missing card says it could not be built and offers no Edit`.
  - `a long email ellipsizes at 320 wide` (Review Focus 1): no
    `tester.takeException()`.
- [ ] **Step 2: Run and see them fail**
  Run: `flutter test test/features/buddies/presentation/widgets/swap/your_card_section_test.dart`
- [ ] **Step 3: Implement** both interfaces above.
- [ ] **Step 4: Run and see them pass** (same command).
- [ ] **Step 5: Commit** `feat(buddies): your card section for the swap screen`

### Task 3: Nearby section

**Files:**
- Create: `lib/features/buddies/presentation/widgets/swap/nearby_section.dart`
- Delete: `lib/features/buddies/presentation/widgets/swap/nearby_divers_list.dart`,
  `test/features/buddies/presentation/widgets/nearby_divers_list_test.dart`
- Test: `test/features/buddies/presentation/widgets/swap/nearby_section_test.dart`

**Interfaces:**
- Produces: `NearbySection({required NearbyAvailability? availability, required bool failed, required List<NearbyCardPeer> peers, required Set<String> waitingFor, required ValueChanged<NearbyCardPeer> onTap, required VoidCallback onRetry})`.
  Heading `buddySwap_nearby_title`. Ready: one `ListTile` per peer
  (avatar, name; trailing `Text(buddySwap_request_swap)` in
  `colorScheme.primary` unless waiting; waiting rows show subtitle
  `buddySwap_waiting(name)` and `enabled: false`), then a row with a 14 px
  spinner and `buddySwap_nearby_status` in `bodySmall`. Null availability
  and not failed: a centered spinner. Otherwise the compact message, icon
  and Try again / Open settings actions moved verbatim from the page's
  `_Unavailable`.

- [ ] **Step 1: Write failing tests**
  - `a diver without a photo shows their initials` (port of the old test).
  - `tapping a diver calls back with them`.
  - `a diver already asked shows Waiting, no Swap, and ignores taps`
    (Review Focus 4).
  - `the looking line carries the version hint`.
  - `Bluetooth off shows the message and Try again calls back`.
  - `unsupported offers no Try again`.
- [ ] **Step 2: Run and see them fail**
  Run: `flutter test test/features/buddies/presentation/widgets/swap/nearby_section_test.dart`
- [ ] **Step 3: Implement** `NearbySection`; delete the old list and its test.
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** `feat(buddies): nearby section for the swap screen`

### Task 4: Give and Get groups

**Files:**
- Create: `lib/features/buddies/presentation/widgets/swap/swap_method_groups.dart`
- Delete: `lib/features/buddies/presentation/widgets/swap/swap_fallback_buttons.dart`,
  `test/features/buddies/presentation/widgets/swap_fallback_buttons_test.dart`
- Test: `test/features/buddies/presentation/widgets/swap/swap_method_groups_test.dart`

**Interfaces:**
- Produces: `GiveCardGroup({required VoidCallback onShowCode, required ValueChanged<Rect?> onSendFile, required VoidCallback onWriteSticker})`
  rows: Show my code (`Icons.qr_code`), Send as a file (`Icons.ios_share`,
  passes `shareAnchorFrom(rowContext)`), Write an NFC sticker
  (`Icons.nfc`, iOS and Android only).
- Produces: `GetCardGroup({required VoidCallback onScanCode, required VoidCallback onOpenFile, required VoidCallback onReadTag})`
  rows: Scan their code (`Icons.qr_code_scanner`), Open a card file
  (`Icons.file_open_outlined`), then `Icons.tap_and_play` with
  "Tap an Android phone" on iOS or "Receive by tap" on Android.
- Each group: a `labelLarge` heading, then `ListTile`s with leading icon,
  title, `buddySwap_hint_*` subtitle and `onTap`. Platform checks copied
  from `SwapFallbackButtons`.

- [ ] **Step 1: Write failing tests**
  - `Send as a file hands over the row rectangle` (port of the iPad anchor test).
  - `each Give row calls its callback`; `each Get row calls its callback`.
  - `on macOS neither group offers NFC` (Review Focus 5,
    `debugDefaultTargetPlatformOverride = TargetPlatform.macOS`, reset in
    `addTearDown`).
  - `iOS shows Tap an Android phone; Android shows Receive by tap`.
- [ ] **Step 2: Run and see them fail**
  Run: `flutter test test/features/buddies/presentation/widgets/swap/swap_method_groups_test.dart`
- [ ] **Step 3: Implement** both groups; delete the old buttons and test.
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** `feat(buddies): give and get groups for the swap screen`

### Task 5: Compose the page

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_swap_page.dart` (build and the three private widgets)
- Modify: `test/features/buddies/presentation/pages/buddy_swap_page_test.dart`

**Interfaces:**
- Consumes: `YourCardSection`, `NearbySection`, `GiveCardGroup`,
  `GetCardGroup` (Tasks 2 to 4).
- `build`: card still loading and not failed: centered spinner (as today).
  Otherwise a `LayoutBuilder`; `constraints.maxWidth >= 720` gives a `Row`
  of two `Expanded` `ListView`s (left: card + nearby; right: give + get),
  else one `ListView` in the order card, nearby, give, get. A failed card
  (`_cardFailed`) shows `YourCardSection(card: null)` and `GetCardGroup`
  only. Delete `_SharingLine`, `_Unavailable`, `_CardFailed`; Edit calls
  `_changeChoices`.

- [ ] **Step 1: Update and add failing tests** in the page test:
  - Rename strings: `Scan code` to `Scan their code`, `Send file` to
    `Send as a file`, `Open card file` to `Open a card file`; the too-large
    message to the new text; `Change` to `Edit`.
  - Request-sheet taps on `Swap` become
    `find.widgetWithText(FilledButton, 'Swap')` (the rows also say Swap).
  - The hint test expects the `buddySwap_nearby_status` text.
  - `the card failing hides nearby and give, keeps get` (Review Focus 3):
    `Your buddy card could not be built.`, `Scan their code` found,
    `Show my code` and `Nearby` not found.
  - `719 wide is one column, 720 is two` (Review Focus 2): at 720 the
    `Give your card` heading's left edge is greater than the `Nearby`
    heading's; at 719 they are equal.
- [ ] **Step 2: Run and see the new ones fail**
  Run: `flutter test test/features/buddies/presentation/pages/buddy_swap_page_test.dart`
- [ ] **Step 3: Rewrite `build`** as above.
- [ ] **Step 4: Run the swap tests and see them pass**
  Run: `flutter test test/features/buddies/presentation/`
- [ ] **Step 5: Task 1 Step 3** (remove the retired keys), then
  `flutter gen-l10n`, `dart format .`, `flutter analyze`,
  `flutter test test/architecture/ test/shared/`.
- [ ] **Step 6: Commit** `feat(buddies): swap screen in two groups with your card on top`
