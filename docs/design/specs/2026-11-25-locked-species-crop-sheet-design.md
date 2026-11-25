# Species crop sheet on a locked photo or video

## Intent

In the media viewer, with the photo or video locked, the diver taps a
species chip in the bottom row to see what that species looks like in
their own media: the cropped image of the animal the app found. Today
that tap opens the species page, which shows the species in general,
not the diver's own animal.

## Goals

- A tapped species tag on a locked photo or video opens a sheet showing
  the crop of that species from this media, large.
- The species page stays one tap away, from the sheet.

## Non-goals

- Unlocked photos and videos keep their current behaviour.
- Suggestion chips (the app's guesses, "+" with a percentage) stay inert
  while locked; unlocking shows their crop with the Add buttons, as now.
- No change to the name pills or dots drawn over the picture.
- No zooming of the viewer onto the animal (considered and not chosen).

## Anti-goals

- A suggestion's crop must never be shown as if it were a confirmed
  animal.
- A tap must never open an empty sheet.

## Behaviour

Which chips:

- The diver's own tags and the app's tags awaiting confirmation both open
  the crop sheet while locked. Both are backed by accepted
  identifications whose `decidedSpeciesId` is the chip's species (the
  auto applier accepts the identifications behind its tags).
- A tag with no accepted identification behind it (tagged by hand)
  opens the species page, as today.
- The "+N" list sheet follows the same rule for its tags.

The sheet:

- Title: the species name as the viewer shows it, the scientific name
  under it when known.
- The selected crop large, at most about 320 logical pixels high,
  contained (not cut).
- With more than one crop of the species: a horizontally scrolling row
  of thumbnails under it, the selected one outlined, and a count ("3 in
  this photo", "3 in this video"). Tapping a thumbnail shows it large.
  Photos order left to right by box; videos by the time the animal
  first appears.
- A "Species page" button that closes the sheet and opens the species
  page.
- A crop not on this device shows the existing "crop unavailable"
  placeholder in its place.

Range: one crop on a reef photo up to dozens in a school or a long video;
the thumbnail row scrolls, and the sheet works at phone and desktop
widths.

## Approaches

1. **New view-only crop sheet (chosen).** A small widget in
   `species_id/presentation/widgets`, fed by the accepted identifications
   of the species on the media, reusing `IdentificationCrop` to draw each
   crop. The chips decide before opening: crops found opens the sheet,
   none pushes the species page.
2. Reuse `SuggestionCropView` in a read-only mode. Rejected: it is built
   around one suggestion with alternatives, Add buttons and an editing
   session; flags to switch all of that off would mix two jobs.
3. Show the crops on the species page. Rejected: the diver chose a sheet
   over leaving the viewer.

## Left to the builder

- How the chips learn the viewer is locked (an explicit parameter rather
  than inferring it from a null suggestion callback).
- The read that lists accepted identifications for a species on a media
  item, and where it lives.
- Localized strings for the count and the button.
