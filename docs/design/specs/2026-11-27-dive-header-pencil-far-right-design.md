# Dive header card: pencil at the far right (issue #4888)

## Problem

On an unlocked dive page the header card's pencil is drawn right after the
dive or site name (`DiveHeroHeader.titleTrailing`). Every other section card
draws its pencil at the far right of its title row (`RecordCardHeader`), so
the header's pencil moves with the length of the name and sits somewhere
else than on the cards below it.

## Design

- `DiveHeroHeader.titleTrailing` becomes `trailing` plus `trailingWidth`.
  `trailing` is laid over the header's top right corner (a `Stack` with a
  `Positioned(top: 0, right: 0)`), not drawn inside the title row.
- The rating/mode row, the top row of the badge column at the header's
  right edge, ends with a `SizedBox(width: trailingWidth)`. That keeps the
  pencil's room exactly where it is laid, so it cannot collide with the
  rating, the mode badge or the type badges below them, at any width.
- Only that row gives up width. The text column (name, site, location,
  entry and exit) keeps its width, so unlocking does not wrap a line or make
  the card taller, except when the rating/mode row plus the pencil becomes
  wider than the type badges.
- The pencil stays at the top of the card whichever column is the taller,
  so it does not float to the middle of a tall header.
- `RecordCardPencil.widthOf(context)` returns the width the pencil takes
  under the current frame: 0 with no frame, while locked or while the card
  is open, otherwise the changed-dot slot, the gap and the disc's diameter
  (`RecordPencilDisc.diameterOf`, the same value the disc is drawn at). The
  dive page passes it as `trailingWidth`.

## Alternatives rejected

- A column of its own for the pencil beside the badge column: it takes the
  pencil's width from every text line, so unlocking can wrap the site or
  time lines and grow the card. It also leaves the pencil above the title
  when the badge column is the taller.
- Appending the pencil to the rating/mode row: that row is vertically
  centred in the header, so the pencil would float at the middle of a tall
  header instead of at the top like the other cards.
- An unseen copy of the pencil in the rating/mode row to hold its room: two
  pencils in the tree, one of them still a focus and semantics node unless
  wrapped carefully, and every test that looks for "the" pencil sees two.

## Tests

- `dive_hero_header_test`: trailing at the card's top right inside its
  padding, right of the rating and mode badge, independent of the name's
  length, at the top when the badge column is the taller, no overflow at
  phone width, and the card's height and location line unchanged at phone
  width when a trailing widget is added.
- `record_card_pencil_test`: `widthOf` is 0 with no frame and while locked,
  and equals the drawn width when unlocked at text scales 0.85, 1 and 2.
- `dive_detail_page_unlock_header_block_test`: on the page, the unlocked
  pencil sits at the card's far right, right of the name, and the hero keeps
  its size.
