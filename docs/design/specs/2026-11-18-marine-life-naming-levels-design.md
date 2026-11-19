# Marine life naming levels: how sure the app must be before it names a fish

Status: approved by the maintainer, 2026-11-18. Release v1.8.5.

## Why

Divers see many fish in their photos and videos that look clear enough to
name, yet the app gives them no name. The bars that decide whether a fish
is named were chosen for accuracy: at the published pack's bars about 90%
of names are right, but only about a third of the animals the detectors box
get one. A diver who would rather see more names, and catch the occasional
wrong one before tagging, has no way to say so.

This feature lets the diver choose how sure the app must be before it
names a fish, from a few levels whose accuracy has been measured, so the
setting can say plainly what each level costs.

## How it works today

- Nothing is tagged without the diver. The app suggests names: rows under
  "Suggested" below a photo, and name pills over a paused video. The diver
  taps to tag.
- A crop is suggestable when its box is at least `minCropSide` (64 px) on
  the shorter side, its open score is at least `minOpenScore` (it looks
  like something in particular, not a hand or open water), and its top
  candidate's score is at least `suggestScore`, or
  `suggestScoreNoLocation` when no dive location limited the candidates.
- The bars come from the pack's manifest (`naming` block). Each was chosen
  by `tool/species_pack/score.py` as the bar naming the most animals right
  whose one-sided 95% Wilson lower bound of precision is at least 85%
  (`bars.py`, `suggest_target=0.85`).
- Pack `2026.11.18.0356` (both detectors, centre crop): `minOpenScore`
  0.44, `suggestScore` 0.74, `suggestScoreNoLocation` 0.81. Held-out: 89.7%
  of suggestions right, 32.4% of boxed animals named. With no bar at all,
  the top guess for the largest box is right 56.7% of the time with a
  location and 48.1% without
  ([findings](../findings/2026-11-17-marine-life-measured-accuracy.md)).
- `suggestable`, `confident` and `specific` are worked out when a crop or
  track is named and stored on its `media_identifications` row. The row
  also stores what they were worked out from: the box's pixel size, the
  open score, whether a location limited the candidates, and the top
  candidates with their scores.
- Over a paused video, an undecided track gets a name pill when
  suggestable, a plain dot when only specific (and seen for at least a
  second), and nothing otherwise (`track_labels.dart`, `labelKind`).
- For a video, a species tag accepts only tracks the app could suggest
  (`identification_rules.dart`, `_acceptingTags`), so one tag does not
  label every distant fish whose weak guess is that species.

## Goals

- The diver picks one of three naming levels in Settings, Marine life
  identification. Each shows how often its names were right when
  measured.
- The chosen level applies at once to every photo and video already
  analysed with the installed pack, with no rescan, and to everything
  analysed later.
- Every level the app offers is measured on the pack it is used with.

## Non-goals

- Markers drawn over photos. Photos keep their "Suggested" list.
- Fish the detectors never box. The detector's own score threshold is
  unchanged.
- The "looks like something" floor (`minOpenScore`) and the minimum box
  size (`minCropSide`). They stay at the pack's values at every level.
- The confident bar. It stays as the pack sets it (today "never").
- A per-diver or synced setting. Identifications never sync; the level is
  per device, like "Identify fish when I open a photo or video".
- What a video scan covers. Names while playing, and stretches the scan has
  not reached yet, are PR #4715 (issue #4709).

## Anti-goals

This would be a failure even if it technically worked:

- Any level tags a species without the diver.
- Any level names hands, divers, gear or open water beyond the junk cap
  today's bars are held to: the floor stays, and each level passes the
  same 2% junk check.
- The app offers a level, or states an accuracy, that was not measured on
  the installed pack.
- Changing the level rewrites any decision the diver made.

## Approaches considered

1. **Measured levels (chosen).** The scorer measures extra suggest bars per
   pack at lower precision targets and the manifest carries them. The app
   offers only the levels the installed pack carries, each with its
   measured accuracy. Costs one scorer run and a manifest republish; keeps
   the rule that every bar the app uses is measured.
2. **Unmeasured steps, app only.** Lower bars as fixed fractions of the
   pack's bar. Ships without touching the pack, but the middle level's
   accuracy is unknown, so the setting cannot say what it costs.
3. **A raw score slider.** Most control, but a score means nothing to a
   diver, and the same position gives different accuracy with and without
   a location and from pack to pack.

The maintainer chose approach 1 on 2026-11-18.

## Design

### The levels

| Level | Suggest bars | Precision target |
| --- | --- | --- |
| Surer (default) | the pack's `suggestScore` and `suggestScoreNoLocation` | 85% (as today) |
| Balanced | measured, carried in the manifest | 75% |
| Eager | measured, carried in the manifest | 65% |

A target is met the same way as today's: the one-sided 95% Wilson lower
bound of precision on the tune half is at least the target. So a level's
observed accuracy is above its target (Surer's is about 90%).

The level moves only the two suggest bars. `minCropSide`, `minOpenScore`
and the confident bars are the pack's at every level.

### Measuring them (pack tooling)

- `bars.py` gains a search for a level's suggest bar at a given target,
  with `minOpenScore` and `minCropSide` held at the pack's chosen values
  and the bar no higher than Surer's.
- **Junk (maintainer's decision, 2026-11-18):** each level is held to the
  same junk cap as the pack's own bars, at most 2% of the tune half's junk
  crops named (`max_junk_rate`, with and without a location, as
  `junk_rate` counts it). A level that fails has its bars raised, a 0.01
  step at a time, until it passes; a level that reaches Surer's bars is
  left out. So a level can come out surer than its target alone would
  give, and a pack may carry one level or none.
- `score.py` measures Balanced and Eager for each detector set, with and
  without a location, applies the held-out gate to each (a level whose
  held-out interval lies wholly below its target is left out), and writes
  them to `results.json` (`measured` entries) and `report.md`: bar,
  held-out precision with its interval, coverage, and held-out junk named.
- `manifest.py`: each `NAMING_MEASURED` entry gains the level bars and
  precisions; `build_manifest` writes them. A provisional pack carries no
  levels.

Manifest `naming` block, new optional fields:

```json
"naming": {
  "provisional": false,
  "minCropSide": 64,
  "minOpenScore": 0.44,
  "suggestScore": 0.74,
  "suggestScoreNoLocation": 0.81,
  "precision": 0.897,
  "levels": [
    {"id": "balanced", "target": 0.75, "suggestScore": 0.0, "suggestScoreNoLocation": 0.0, "precision": 0.0},
    {"id": "eager", "target": 0.65, "suggestScore": 0.0, "suggestScoreNoLocation": 0.0, "precision": 0.0}
  ]
}
```

(Values shown as 0.0 are placeholders until the scorer runs.) `precision`
is the held-out share of suggestions that were right, with a location.
Changed by the follow-up
[accuracy without a location](2026-11-19-marine-life-level-accuracy-without-location-design.md):
`precision` is now the lower of the held-out shares with a location and
without one, so it can sit below the with-location figure.

The format version does not change: an older app ignores fields it does
not read, and keeps naming at the pack's suggest bars, which is Surer. A
pack still changes data, never features.

Measuring needs the photos, the converted models and the detections cache
in the maintainer's `build/species_accuracy_work`, on a Mac, so the
maintainer runs the scorer once the tooling is built (maintainer's
decision, 2026-11-18). The numbers land in this change, in
`NAMING_MEASURED` and the findings. The manifest is re-uploaded only on
the maintainer's explicit go-ahead. The numbers
go into `NAMING_MEASURED`, the manifest is regenerated over the published
files with `manifest.build_manifest` (not rebuilt), keeping the same
`packVersion`, and only `manifest.json` is re-uploaded to the
`species-pack` release.

### Reaching devices that already have the pack (designer's call)

Today the app offers an update only when the published `packVersion`
differs from the installed one, and it keeps the manifest it installed
with. A republished manifest under the same version would never reach a
device that has the pack; a new version would make every device download
the whole pack again and rename everything it has analysed.

So the app adopts a newer manifest in place: when the published manifest
has the installed `packVersion`, lists exactly the installed files (same
names, sizes and SHA-256), and differs from the installed manifest only in
`naming.levels`, `naming.precision` and `credits`, the controller's
refresh replaces the installed `manifest.json` (written atomically) and
reloads it, with nothing downloaded and nothing renamed. A same-version
manifest that differs in anything else is ignored, as today. Chosen
because it is the only way that reaches every device without a download,
and keeps everything already analysed with the pack comparable (below).
Because the levels are optional, the app change and the manifest
republish can ship in either order.

### The app

**Reading the manifest.** `NamingConfig` gains `precision` (nullable) and
`levels`. A level entry that is malformed, has an unknown id, or has a bar
above Surer's is dropped, without refusing the pack.

**The setting.** A per-device preference, `SettingsKeys` entry beside
`identifyFishOnOpen`, default Surer. The level in force is the chosen one
if the installed pack carries it, otherwise the nearest surer level it
does carry (so Eager falls back to Balanced, then Surer).

**Applying it at read time.** Whether an identification is suggestable is
worked out from its stored fields against the level in force:

```
suggestable = boxShorterSide >= minCropSide
           && openScore >= minOpenScore
           && top != null
           && top.score >= (locationLimited ? level.suggestScore
                                            : level.suggestScoreNoLocation)
```

This applies only to identifications whose run was named by the installed
pack (the run's `packVersion` equals the installed one). Any other row
shows its stored flag until it is named again: the installed pack's level
bars were never measured on another pack's scores (designer's call). Rows
from an older pack are renamed when the media is next opened, as today.
For a row of the installed pack, Surer equals the stored flag, since it is
the same arithmetic as `SpeciesNamer.name` with the same bars. Every
reader that decides on `suggestable` uses the level-applied value:

- a photo's suggestions (`groupSuggestions`, `mediaSuggestionsProvider`),
- the labels over a video (`labelKind`: a pill rather than a dot), and
- which video tracks a species tag may accept (`_acceptingTags`).

The stored `suggestable` column keeps meaning "suggestable at the pack's
own bars when named". Writes never store a level-applied value.

With no pack installed, identifications show as they were named (the
stored flag), since there are no level bars to apply.

**Changing the level** rebuilds the photo suggestions and the video labels
on screen. Decisions already made (accepted, rejected, claimed) never
change. A tag added while a lower level is in force may accept more video
tracks than it would at Surer, and those stay accepted after the level is
raised, as any accepted track does.

### The settings screen

On Settings, Data, Photos and videos, Marine life identification, below
"Identify fish when I open a photo or video":

```
Name a fish when the app is
 (o) Surer       About 90% of names right
 ( ) Balanced    More names. About 80% right
 ( ) Eager       Most names. About 70% right
```

- The percentages in the sketch are illustrations, not measurements.
- Each accuracy line is the level's measured `precision` from the
  installed manifest, rounded down to a multiple of 5 so it never
  overstates. Surer uses the naming block's `precision`; with none, its
  line says only "Fewest names, most often right".
- Only the levels the installed pack carries are listed. With no pack, or
  a pack with no levels, the section is hidden.
- New strings go in all 11 ARB files.

## Constraints

- Pure rules stay pure and tested without widgets, as the rest of
  `species_id/domain/services/` is.
- `docs/developer/species-identification.md` is updated (the levels, how to
  measure and publish them), and the findings gain the levels' measured
  numbers once the scorer runs.
- PR #4715 edits `labelKind` and the video scan. This change branches from
  `main`; whichever lands second resolves the overlap.

## Left to the builder

- Where the level is applied in code (a mapping at the provider boundary,
  or a bars argument to the rules), provided writes never store a
  level-applied flag.
- Names and placement of the new types, provider and preference key.
- Exact wording of the strings, within the sketch above.
- The `bars.py` search details and the shape of the report section.
