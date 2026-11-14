# Media hover marks the moment on the dive profile

Builds on the pinned profile strip of issue #4423
([design](2026-11-10-pinned-profile-strip-design.md)) and its floating
tooltip ([styling design](2026-11-13-pinned-profile-strip-styling-design.md)).

## Why

In dive details the media section sits well below the profile card, so by the
time a diver is looking at their photos the full chart has scrolled away and
only the pinned strip is left. Nothing connects a thumbnail to the dive: to
learn where a photo was taken the diver has to scroll back up and find its
camera chip on the full chart. Pointing at a thumbnail should answer "where in
the dive was this?" on the spot, with the same readout the chart gives for any
other moment.

## Goals

- Hovering a media thumbnail in dive details marks that item's moment on the
  pinned profile strip.
- The strip's own tooltip shows at that moment, with its usual metrics.
- Moving the pointer off the thumbnail clears the mark.

## Non-goals and anti-goals

- No touch gesture. Tap still opens the viewer and long-press still starts
  selection.
- No new marker style. The mark is the strip's existing cursor (line, dot,
  tooltip); no camera badge on the strip (approach B was declined).
- No change to the camera chips on the full chart.
- A hover must never leave the cursor stuck on the chart after the pointer
  has left, or after the hovered thumbnail has gone away.

## Approaches

- **A. The thumbnail hover moves the shared profile cursor (picked).** The
  page already has one "where am I in the dive" value per dive,
  `profileTrackingIndexProvider`, read by the full chart, the pinned strip and
  the cards that follow the chart. The SAC segments chart and the buoyancy
  chart already write it from outside the profile. A thumbnail hover becomes
  one more writer. Smallest change, and it reuses the tooltip as asked.
  Trade-off: the mark looks like any scrub cursor; nothing on the strip says
  "photo".
- **B. A, plus a camera badge on the strip.** Reads as "the photo is here",
  but needs a second shared value (which item is hovered) and new drawing in a
  44 px strip where a 22 px chip covers much of the line. Declined.
- **C. A separate photo marker that leaves the cursor alone.** Needs its own
  copy of the tooltip, which works against showing the chart's tooltip, and is
  the most code. Dropped.

## Design

### Behaviour

- Pointer enters a thumbnail in the dive details media grid: if the item has a
  place on the profile, the dive's shared cursor moves to that moment. Pointer
  leaves: the cursor clears.
- Everything that follows the cursor follows the hover, exactly as for a
  scrub: the pinned strip (line, dot, floating tooltip), the full chart if it
  is still on screen, and the cards that track the chart.
- Which items have a place on the profile is the rule the full chart's camera
  chips already use (`photoMarkersFromMedia`): not a signature, has an
  enrichment with a time and a depth, the match is not `noProfile`, and the
  capture time is inside the dive window (a manual position always passes).
  Documents and unmatched items therefore do nothing on hover. The time is
  clamped to the profile's range, as the chips clamp it.
- A video marks its start time (the one position its enrichment holds).
- Hover works the same in selection mode.
- A dive with no profile: hover does nothing.
- Mouse and trackpad only; a touch never hovers.

### Structure

- **One rule, one place.** The "does this item have a place on the profile,
  and at what second" rule is pulled out of `photoMarkersFromMedia` into a
  small pure function beside it in `photo_marker_layout.dart`, and
  `photoMarkersFromMedia` calls it. The chips and the hover cannot then
  disagree about an item.
- **The media section stays ignorant of the profile.** `DiveMediaSection`
  gains an optional `onHoverMedia(MediaItem? item)` callback (null when the
  pointer leaves). Each grid thumbnail is wrapped in a small hover-reporting
  widget that calls it.
- **The dive details section list wires it.** `DiveDetailSectionList` passes a
  handler that reads the series the chart draws (the same series
  `watchChartProfile` resolves, read at hover time so the section does not
  rebuild on a source switch), asks the rule above for the second, and calls
  `setProfileCursorSeconds`.
- **No stuck cursor.** Flutter does not call a `MouseRegion`'s `onExit` when
  the region is removed while hovered (an unlinked item, a rebuilt grid). The
  hover-reporting widget therefore reports "left" when it goes away while
  hovered, deferred out of the build and dispose phase so the provider write
  is legal. A leave only clears the cursor if the item leaving is the one
  that set it, so an enter and a leave arriving out of order cannot clear the
  new item's mark.

### Units and text

No new text and no new numbers: the tooltip is the strip's existing one,
which already follows the diver's unit settings. No new localization keys.

## Testing

- Unit: the extracted rule (signature, no enrichment, `noProfile`, outside
  the dive window, manual position, clamping) and that `photoMarkersFromMedia`
  still returns what it did.
- Widget: the hover-reporting widget calls enter and leave, and reports a
  leave when removed while hovered.
- Widget: the section list's handler moves `profileTrackingIndexProvider` to
  the item's sample on enter, clears on leave, ignores an unplaced item and a
  dive with no profile, and does not clear another item's mark.

## Left to the builder

- The name and file of the hover-reporting widget and of the handler.
- How the deferred "left" on removal is scheduled.
