# Buddy swap screen redesign

Date: 2026-11-15. Release: v1.8.5. Builds on
[2026-10-28-buddy-card-swap-design.md](2026-10-28-buddy-card-swap-design.md).

## Why

Swapping details with a buddy on the swap screen felt messy and confusing.
Today the screen stacks a nearby list, a spinner, a hint paragraph, a
run-on "Sharing: name, phone, email, cert, 412 dives [Change]" sentence,
then six identical outlined buttons in a wrap. Those buttons mix giving
your card (show code, send file, write sticker) with getting theirs (scan
code, open file, tap), so nothing says which half you need or which to try
when your buddy does not appear nearby.

## Goals

- Show what you are about to share before you swap, at a glance.
- Make the direction of every method obvious: give your card, or get theirs.
- Keep every fallback visible on the page, so a failed nearby search never
  leaves the diver hunting for the next step.
- Use the width of a desktop or tablet window instead of stretching rows.

## Non-goals

- No change to the swap protocol, the nearby session, the request sheet,
  the share choices sheet, the QR sheet or the card preview page.
- No new swap methods, and no change to which platforms get which method.

## Anti-goals

- Hiding fallbacks behind tabs or a fold: that is where the diver got stuck.

## Approaches

| Option | What it is | Trade-off |
| --- | --- | --- |
| A. Your card plus two groups (picked) | Your card at the top, the nearby list, then "Give your card" and "Get their card" as two labelled lists of rows; two columns on wide windows | Longest page, but nothing hidden |
| B. Send / Receive tabs | Your card and nearby, then tabs that switch between the two method groups | Shorter, but the half you need may be the hidden tab |
| C. Nearby first, rest folded | Nearby fills the screen; the methods sit behind an "Other ways to swap" row | Cleanest when nearby works, worst when it does not |

The user picked A from mockups on 2026-11-15.

## Design (as decided)

### Phone width (one column), top to bottom

1. **Your card.** A tinted card: your avatar (photo or initials) and name,
   the label "Your card", an Edit button that opens the existing share
   choices sheet, and one chip per shared item: phone, email, the headline
   certification, dive count, and the other shared fields the card carries.
   This replaces the "Sharing: ..." sentence.
2. **Nearby.** Section heading, one row per diver with a trailing Swap
   action (the row shows "Waiting for <name>" while asked), then one quiet
   line merging today's spinner and hint: "Looking for divers. Your buddy
   needs this screen open too." When Bluetooth is off, denied, unsupported
   or failed, the section shows that message compactly in place of the
   list, with the existing Try again / Open settings actions.
3. **Give your card.** Rows with an icon, a name and a one-line hint: Show my
   code, Send as a file, Write an NFC sticker (phones only).
4. **Get their card.** Rows: Scan their code, Open a card file, Receive by
   tap (Android) / Tap an Android phone (iPhone).

### Wide window (two columns)

Your card and Nearby on the left; Give your card and Get their card on the
right. Phone width keeps one column.

### Wording

Method names say which side you are on, and each gets a hint line:

| Today | New |
| --- | --- |
| Show my code | Show my code |
| Scan code | Scan their code |
| Send file | Send as a file |
| Open card file | Open a card file |
| Write NFC sticker | Write an NFC sticker |
| Receive by tap / Tap an Android phone | unchanged |

New strings go in every ARB file.

### Card could not be built

Today a failed card replaces the page with an error and two buttons. In the
new layout the Your card section shows the error, Nearby and the Give group
are absent (the nearby session needs your card to start, and there is
nothing to give), and Get their card renders as usual (receiving still
works).

## Left to the builder (calls made here, open to correction)

- The wide breakpoint: the page body's own width (a LayoutBuilder), two
  columns from 720 logical pixels, since the page sits beside the nav rail
  on desktop.
- Hint wording for each method, the exact chip set and chip order (follows
  the share choices order).
- Splitting the page widget into section widgets under
  `lib/features/buddies/presentation/widgets/swap/` so the 570-line page
  keeps only session and action logic.
