# Dive header card: pencil at the far right (issue #4888)

## Problem

On an unlocked dive page the header card's pencil is drawn right after the
dive or site name (`DiveHeroHeader.titleTrailing`). Every other section card
draws its pencil at the far right of its title row (`RecordCardHeader`), so
the header's pencil moves with the length of the name and sits somewhere
else than on the cards below it.

## Design

- `DiveHeroHeader.titleTrailing` becomes `trailing` plus `trailingSize`.
  `trailing` is laid over the header's top end corner (a `Stack` with a
  `PositionedDirectional(top: 0, end: 0)`, so the top left in a
  right-to-left language), not drawn inside the title row.
- The rating/mode row, the top row of the badge column at the header's end
  edge, ends with a `SizedBox(width: trailingSize.width)`. That keeps the
  pencil's width exactly where it is laid, so it cannot collide with the
  rating or the mode badge at any width. Only the width: reserving the
  disc's height too made that row taller than its text and the card grow
  by a few points on unlock. The type badges start below the row and its
  8 point gap, which is already lower than the disc's 24 points.
- Only that row gives up width. The text column (name, site, location,
  entry and exit) keeps its width while the type badges are the widest part
  of the badge column. When they are not (no type badges, or a rating and a
  long mode label), the column widens by the pencil's width and the text
  column loses it, as the title row alone did before. Avoiding that would
  need a custom layout that measures the badge column's slack; not worth it
  for this issue.
- The pencil stays at the top of the card whichever column is the taller,
  so it does not float to the middle of a tall header.
- `RecordCardPencil.sizeOf(context)` returns the size the pencil takes
  under the current frame: `Size.zero` with no frame, while locked or while
  the card is open, otherwise the changed-dot slot, the gap and the disc's
  diameter (`RecordPencilDisc.diameterOf`, the same value the disc is drawn
  at), built from the same constants and frame check as `build`. The dive
  page passes it as `trailingSize`.
- Reading order: the pencil is the header's last node, after the badges,
  where `RecordCardHeader` cards also read their pencil after the title.

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
  phone width, the card's height and location line unchanged at phone width
  when a trailing widget is added, clear of the type badges below it, and
  at the top left clear of the badges right to left.
- `record_card_pencil_test`: `sizeOf` is zero with no frame and while locked,
  and equals the drawn size when unlocked at text scales 0.85, 1 and 2.
- `dive_detail_page_unlock_header_block_test`: on the page, the unlocked
  pencil sits at the card's far right, right of the name, and the hero keeps
  its size.
