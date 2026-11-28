# Species videos open at the sighting

## Intent

On a dive's Marine life card, a sighting row's photo chip opens the dive's
photos and videos tagged with that species. Every video in that viewer starts
at 0:00, so the diver scrubs through a long clip to find the animal. The
chip should land the diver on the animal: each video opens at the moment the
species was seen, the first one and every later one paged to, and within a
video the diver can step from one sighting of the species to the next.

## Goals

- Each video in the viewer opened from the sighting row's chip opens paused
  at the start of the species' first sighting in that video.
- This holds for every video in the list, each time its player opens (the
  viewer releases a video's player when it is paged away and makes a new one
  on return).
- While the viewer follows a species, a video's scrub bar shows a band for
  each sighting of that species, and, when there are two or more, a button
  after the bar jumps to the next sighting.

## Non-goals

- Other ways into the viewer (the dive's media gallery, the library, trips,
  sites) are unchanged: they follow no species.
- No new stored data. Sighting times come from the identification tracks
  already stored on the video (`media_identifications.start_ms` and
  `end_ms`).

## Anti-goals

- Taking control from the diver: a video the diver has already played or
  scrubbed is never moved by a sighting lookup that finishes late.
- Covering the video: the control sits in the controls bar, not over the
  picture.

## Constraints

- A species tag on a video made by hand from the chips has no time. Such a
  video opens at 0:00, as today, with no bands and no button.
- Only accepted identifications of the species count, the same set the crop
  sheet's "Seen at" chips use (`cropsOfSpecies`), merged into stretches with
  `videoStretches` (tracks that overlap or start within 1 s of the last
  one's end are one sighting).
- A school of fish can give many sightings in a long video: bands stay one
  row on the bar at any count, and a sighting shorter than a few pixels still
  draws at a minimum width.

## Approaches

1. **The viewer follows one species; each video looks up its own sightings
   (chosen).** The chip passes the species id. A provider keyed on
   (video, species) returns the stretches and refreshes when identifications
   change. The viewer seeks a new player to the first stretch; the controls
   bar draws the bands and the button from the same provider. Lazy per
   video, live while the viewer is open, and the same shape as the face-tag
   marks (`VideoTagMarks`).
2. **Read every video's sightings before the viewer opens.** The wrapper
   reads a `mediaId -> stretches` map for the dive and hands it down. Plain
   data, but a snapshot (a scan finishing while open does not show) and one
   more argument for every viewer caller.
3. **Turn `initialVideoPosition` into a per-video map.** Seeks each video,
   but cannot give the next-sighting control, so it was ruled out.

The diver picked approach 1.

## Design

- `MediaViewerPage` gains an optional `focusSpeciesId`.
  `DiveSpeciesPhotoViewerPage` (the sighting chip's route) passes its
  species. No other caller sets it.
- A new provider, `videoSpeciesSightingsProvider((mediaId, speciesId))`,
  reads `MediaIdentificationRepository.forMedia`, applies `cropsOfSpecies`
  then `videoStretches`, and invalidates itself on the repository's
  `watchChanges()`.
- Seek on open: when a video's player reports in
  (`_onVideoControllerChanged`) and the viewer follows a species, the viewer
  reads that video's sightings and, if there is one and the player is still
  at its start, not playing and not scrubbed, seeks it to the first
  stretch's start. The existing one-shot `initialVideoPosition` keeps
  working for the Species page's crop strip; when both are present for the
  initial item, `initialVideoPosition` wins (it names an exact moment).
- Bands: teal marks on the scrub bar from each stretch's start to its end,
  at least 3 px wide, drawn under the amber face-tag marks and ignoring
  pointer events, so a tap on the bar still seeks.
- Next-sighting button: after the total time (before the mute button), shown
  only when the video has two or more sightings of the species. It seeks to
  the first stretch starting more than half a second after the current
  position, wrapping to the first after the last. It keeps the play state:
  a playing video plays on from there, a paused one stays paused on it.
  Tooltip and screen-reader label "Next sighting".
- Fullscreen controls use the same `VideoControlsBar`, so they get the bands
  and button too.

## Left to the builder

- Exact teal shade (from the theme's species or tertiary colour, legible on
  the dark controls bar).
- Where the provider lives (the species_id presentation providers sit with
  the other identification reads).
- Test layout: provider unit tests (no tracks, pending tracks, other
  species, merged stretches), widget tests for the bands, the button's
  presence, its next and wrap behaviour, and the seek on open, including
  the "diver already pressed play" guard.
