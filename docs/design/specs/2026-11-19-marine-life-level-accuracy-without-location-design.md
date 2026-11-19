# Marine life naming levels: accuracy without a location

Refs #4721. A follow-up to the
[naming levels design](2026-11-18-marine-life-naming-levels-design.md).

## Why

Each naming level's line in settings ("About 80% right") comes from its
held-out precision with a location. A level's bar without a location can
sit lower than its bar with one, so on photos named without a location it
can be right less often than its line says. A photo is named without a
location when it has no position of its own and its dive site has none,
or when the place has fewer than 200 recorded species.

On the published pack (`2026.11.18.0356`, both detectors, held-out half):

| Level | With a location | Without one | Line today |
| --- | --- | --- | --- |
| Surer | 89.7% right, names 32.4% | 90.3% right, names 14.7% | About 85% right |
| Balanced | 82.5% right, names 45.4% | 80.8% right, names 28.9% | About 80% right |
| Eager | 82.5% right, names 45.4% | 75.5% right, names 46.4% | About 80% right |

Eager's line overstates by one step on exactly the photos where it differs
from Balanced. The naming levels design says the figure shown never
overstates.

## Goals

- Every accuracy line in settings is at most what was measured, with a
  location or without one.

## Non-goals

- Showing two figures on a line.
- Any app change, or a change to the manifest format or to the bars.

## Anti-goals

- A line that overstates for a diver whose photos have no location.
- A level shown as more often right than the level above it.

## Approaches

- **The lower of the two figures (chosen).** The tools publish, as each
  level's `precision` and as Surer's, the lower of its held-out precision
  with and without a location. The app shows it as it does today, so every
  app version gets the corrected lines, Eager's line now differs from
  Balanced's, and nothing on the screen changes shape. The cost: for
  photos with a location, a line can understate by one step (Eager's 75%
  where it is about 80% right).
- **Both figures on each line.** "About 80% right, 75% without a dive
  site". The full picture, but it needs a new manifest field, app parsing,
  a new string in 11 languages and longer lines; set aside for that cost.
- **The figure for the diver's own photos** (weighted by how many of their
  photos have a location). Dropped: the line would change from diver to
  diver and with every import, which is harder to trust than a fixed
  figure.

## Design

- `levels.rates` measures held-out precision and coverage both with and
  without a location. Without a location is the crops' "without" naming,
  which `bars.named` already judges against the no-location bar.
- The figure shown for a level is the lower of its two held-out
  precisions. A side that names nothing held out has no figure, and the
  other side stands. Surer's figure follows the same rule at the pack's own
  bars.
- A side that names only a few crops still sets the figure, with no
  minimum count (the maintainer's decision, 2026-11-19): it can only lower
  a figure or drop a level, never make a line overstate. The report warns
  when the deciding side names fewer than 30 held-out crops, so the
  maintainer sees it before publishing.
- The rules that drop a level use the shown figure: a level is dropped
  when its figure is higher than the level above's, or when it has none.
- `score.py` writes the shown figures into its measured entries, and
  `results.json` keeps both sides for each level and for Surer.
- `report.md`'s "Naming levels" table shows precision and coverage both
  ways, and the shown figure.
- `NAMING_MEASURED` takes the shown figures from a fresh scorer run on the
  published pack, and the findings' "Naming levels" section gains the
  no-location columns and this rule. Expected for the published pair:
  Surer 0.897, Balanced 0.808, Eager 0.755, shown as 85%, 80% and 75%.
- The relevelled manifest is rebuilt from these figures. It is uploaded to
  the `species-pack` release only on the maintainer's go-ahead.

## Left to the builder

- The report table's exact columns, test names, and where in `levels.py`
  the two figures are combined.
