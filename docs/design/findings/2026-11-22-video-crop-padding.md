# Species identification on video: how wide to crop a small fish

Findings behind issue #4882, measured on 2026-11-22 with pack
`2026.11.20.0513` (the trained naming layer, see
[the naming layer](2026-11-20-marine-life-naming-layer.md)) at the default
naming level, Eager. That pack carries only the Balanced level, so Eager
names at Balanced's bars: open score at least 0.19, best name at least 0.33
with a place.

## Method

Three 4K reef videos from one shore dive at Salt Pier, Bonaire (5 May
2026), 333 tracks. The raw detector boxes came from the app's own
`VisionPipeline.swift` over the videos; a replay of the app's filter,
tracker (version 4: two-pass links, #4744) and `bestMoments` made the same
tracks. Each track's best three moments were cropped from the full frames
at paddings 0.1, 0.3 and 0.6 and embedded with the app's own
`cropAndEmbed`: 1,251 moments in all. A copy of `SpeciesNamer` named each
moment on its own, and `chooseNamingView` (#4748) named each track.

The classifier and detectors of this pack are byte-identical to those of
pack `2026.11.18.0356`, which the moments were first embedded with; a fresh
embedding of 24 of them with this pack's classifier matched exactly. The
same replay on the earlier pack reproduces the earlier measurement
exactly.

Every track whose suggestion differed between paddings (138 tracks) was
put on a contact sheet and each suggested name judged by eye as right,
wrong or unsure. The 41 tracks suggested with the same name at every
padding were not judged.

## Results

Tracks suggested, of 333:

| Crop padding | Surer | Eager (Balanced bars) |
| --- | --- | --- |
| 0.1 (the pack's, as before) | 61 | 70 |
| 0.3 | 107 | 121 |
| 0.6 under 256 px, else 0.1 | 132 | 147 |
| 0.6 | 133 | 149 |

By eye, on the 138 tracks whose suggestion changed (Eager):

| Crop padding | Right | Wrong | Unsure |
| --- | --- | --- | --- |
| 0.1 | 14 | 10 | 5 |
| 0.3 | 58 | 10 | 12 |
| 0.6 under 256 px, else 0.1 | 73 | 10 | 23 |
| 0.6 | 77 | 9 | 22 |

- Most of what wider crops add is brown chromis, all right or unsure by
  eye.
- Wider crops drop the tight crop's worst names: Bluntnose sixgill shark
  and Orangespotted trevally on a chromis and a yellowtail snapper, and
  Mahogany snapper on a yellowtail.
- Padding 0.3 adds six Sunshinefish on fish that look like the brown
  chromis around them.
- Padding 0.6 adds a few names read from the surroundings: Blue Chromis on
  a dark chromis in open blue water, twice. On a box covering most of the
  frame it names something else in the scene.
- Several chromis in one wide crop share the fish's name, so a crop of the
  school is not counted wrong.

## Decision

A video moment's box under 256 px on its shorter side, in the frame's
pixels, is cropped with a padding of 0.6; a larger box, and every photo,
keeps the pack's padding of 0.1 (`VisionModels.momentPadding`, both
engines). A small box is never cropped tighter than the pack's padding, so
a pack that pads more than 0.6 keeps its own padding for every box. It
suggests more than twice as many tracks as before for about
the same number of wrong names. Keeping 0.1 for big boxes keeps them on the
crop the naming bars were measured with on photos, and avoids naming the
scene around a box that already fills much of the frame. Padding 0.6 for
every box measured about the same, one wrong name fewer, but names that
scene. Videos scanned before are scanned again once (tracker version 5).

The measurement is one dive, judged by one person from small crops.
