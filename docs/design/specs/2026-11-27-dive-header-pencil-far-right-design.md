# Dive header card: pencil at the far right (issue #4888)

## Problem

On an unlocked dive page the header card's pencil is drawn right after the
dive or site name (`DiveHeroHeader.titleTrailing`). Every other section card
draws its pencil at the far right of its title row (`RecordCardHeader`), so
the header's pencil moves with the length of the name and sits somewhere
else than on the cards below it.

## Design

- `DiveHeroHeader.titleTrailing` becomes `trailing`: a widget drawn at the
  top right of the card, after the rating/mode/type column, not inside the
  title row.
- The header row gets one more child, after the badge column, aligned to the
  top of the row. The badge column keeps its vertical centring, so the
  locked layout is unchanged.
- The pencil sits in its own column, so it cannot overlap the rating, the
  mode badge or the type badges at any width. `RecordCardPencil` takes no
  room while locked and carries its own leading gap (changed-dot slot plus
  4 px) while unlocked, so no extra spacer is needed.
- The title now gets the full width of its column again; a long name wraps
  under itself instead of pushing the pencil.

## Alternatives rejected

- Appending the pencil to the rating/mode row: that row is vertically
  centred in the header, so the pencil would float at the middle of a tall
  header instead of at the top like the other cards.
- A `Positioned` overlay in the corner: it would have to reserve room in the
  badge column by hand and would collide with the rating at narrow widths.

## Tests

- The trailing widget sits right of the mode badge and the rating, at the
  top of the header, and its x position does not depend on the name's length.
- Phone width (360 px) with a long name, a rating, a CCR badge and type
  badges: no overflow, the trailing widget stays inside the card.
