# Trip day timeline: day, night, sunrise and sunset

Date: 2026-11-09
Release: v1.8.5

## Intent

On a trip's story view, each dive day's summary band has a 24-hour bar
(`DayRhythmBar`, `lib/features/trips/presentation/widgets/story/day_rhythm_bar.dart`)
that draws the day's dives as blocks on one flat neutral track. A diver
looking back at a trip day wants to see at a glance how the dives sat against
the light: which were in the dark, which straddled dawn or dusk, and when the
sun actually rose and set at that place. The track itself should show that
instead of being a blank grey strip.

## The approved look

Mockups were reviewed in chat; the chosen direction is "sky gradient with sun
times" (option A's colouring with option B's labels).

- **Night** hours are a deep, dark blue band.
- **Sunrise** is a short warm amber glow that peaks at the sunrise time and
  fades into a pale daylight band.
- **Day** hours are a pale sky band.
- **Sunset** is a short warm orange glow that peaks at the sunset time and
  fades back into the night band.
- Under the bar, the **sunrise and sunset times** are labelled with small
  sunrise and sunset icons, each centred under its moment on the bar. They
  replace the 6:00 and 18:00 hour ticks; the midday tick stays.
- Light and dark mode each get their own sky palette (dark mode is darker and
  less saturated, as in the mockup) so the bar does not glare in dark mode.

Reference values from the mockup (a starting point, not a contract):

| Part | Light | Dark |
| --- | --- | --- |
| Night | `#24305A` | `#0D1222` |
| Sunrise glow | `#F3A35E` | `#A8622F` |
| Day | `#DCEAF6` | `#2F4157` |
| Sunset glow | `#EE8A5E` | `#A65236` |
| Sun time label | `#8A5A1E` | `#E8B871` |

Gradient stops (*builder's call made in design*, following real twilight,
which is on the dark side of the event):

- Sunrise: night colour until 40 minutes before sunrise, glow colour exactly
  at sunrise, day colour from 30 minutes after.
- Sunset: day colour until 30 minutes before sunset, glow colour exactly at
  sunset, night colour from 40 minutes after.

The point is that the change of light reads as gradual without the glow
smearing across hours. Stops that fall before 00:00 or after 24:00 are simply
cut off at the bar's ends.

## Where the sun times come from

- `SunCalculator.wallClockFor` (`lib/core/util/sun_times.dart`) with the site
  clock from `SiteTimeZone.wallClockConverterFor`, the same path
  `TimeOfDayClassifier` uses, so the bar and the night-dive classification
  agree on when sunrise and sunset were.
- The place is the **first dive of the day (in the bar's order) whose site has
  usable coordinates** (not null, not 0,0, valid per
  `SunCalculator.isValidCoordinate`; the same rules as
  `TimeOfDayClassifier.classify`). *Builder's call made in design:* one place
  per day; a day spanning two far-apart sites is rare enough that the first
  site is good enough.
- The date is the calendar date of that dive's entry wall clock (the bar
  already places dives by their wall-clock time of day).
- The times are formatted with the diver's time-format setting via
  `UnitFormatter.formatTime`, so a 12-hour diver sees "6:12 AM". The bar
  receives the `UnitFormatter` the day card already holds. *Builder's call
  made in design:* the hour ticks (midday, and 6 and 18 in the fallback case)
  follow the same setting, so a 12-hour diver never sees "6:12 AM" beside
  "18:00". Today they are hard-coded 24-hour.
- When the time-format setting changes, the labels and semantics update (the
  bar recomputes when its `UnitFormatter` settings change, not only when the
  dives do).

### Sun events near midnight

At high latitude, or where the site clock runs far from the sun, a day's
sunset can fall after midnight or its sunrise before it. *Builder's call made
in design:* the bands are built from the sun events of the day before, the
day itself and the day after, keeping every sunrise and sunset whose wall
clock lands on this calendar date. So an early-morning stretch after a late
sunset the previous evening is drawn as dusk then night, not as day. Only
those events that land on this date are labelled, at most one sunrise label
and one sunset label (the first of each).

## Cases

| Case | Bar colouring | Labels under the bar |
| --- | --- | --- |
| Site with coordinates, sun rises and sets | Gradient at the computed times | Sunrise time, 12:00, sunset time |
| No dive that day has usable coordinates (decided by the user) | Same gradient at the fallback 06:00 and 18:00 (`TimeOfDayClassifier.fallbackSunriseHour` / `fallbackSunsetHour`) | 6:00, 12:00, 18:00 ticks as today; no sun icons or times, so a guess is never shown as a real sunrise |
| No sun event that date (polar day or polar night), or `wallClockFor` returns null for any other reason | Same as the fallback row: gradient at 06:00 and 18:00 | Same as the fallback row |

*Builder's call made in design (changed after review):* polar day and night
use the same 06:00/18:00 fallback as a site with no coordinates, exactly as
`TimeOfDayClassifier` does for the night-dive tint. This keeps the bands and
the dive blocks agreeing, needs no new `SunCalculator` API (`wallClockFor`
returns null for both and cannot tell them apart, and at a pole there is no
answer), and the case is very rare on a dive trip.

## Labels never collide

Sun time labels are wider than the old ticks, and in some places sunrise is
late or sunset early.

- Each label is clamped inside the bar's width, as the ticks are today.
- If the midday tick would overlap either sun label, the midday tick is
  dropped.
- If the sunrise and sunset labels would overlap each other (a very short
  day), the sunset label is nudged right far enough to clear the sunrise
  label (and clamped to the bar); if there is still no room, the sunset label
  is dropped. This is extremely rare and only needs to avoid overprinting.

## Dive blocks

- Block positions and widths are unchanged (`computeRhythmBlocks`).
- Night is still decided per dive by `TimeOfDayClassifier` (unchanged).
- Day dives keep the primary colour.
- A block can sit on any band: a dawn or dusk dive straddles night and day,
  and a dive at a second site is classified at its own site while the bands
  come from the first. *Builder's call made in design:* every block gets a
  thin outline that contrasts with both bands (light in dark mode, and a
  light hairline in light mode), so no block disappears whatever is behind
  it. Day dives keep the primary colour; night dives use a lighter tertiary
  tone than today so they also read on the night band. Exact tones are the
  builder's, as long as every block stays clearly visible on every band in
  both modes.
- *Accepted in design:* on a day spanning two sites, or under the fallback,
  a block's colour can disagree slightly with the band behind it. That is
  the classifier's per-dive answer and is left as is.

## Accessibility

The bar's semantics label today is "Dive times during this day". When real
sun times are known it also gives them, for example "Dive times during this
day. Sunrise 06:12, sunset 18:34." with the times in the diver's time
format (new ARB string with placeholders, translated into every shipped
locale like other trip story strings). With no real sun times the label
stays as it is. If only one of the two events lands on the date, only that
one is spoken.

## Goals

- The track shows night, sunrise, day and sunset for that day and place.
- Real sunrise and sunset times are readable under the bar.
- Looks right in light and dark, at large text sizes, and in right-to-left
  locales (the bar is a time axis drawn left to right today; it stays so).

## Non-goals

- No bar on days without dives (surface days and future planned days); they
  do not show this bar today and still will not.
- No change to the Time patterns chart, the night-dive classification, or
  any stored data. No schema or settings change.
- No twilight bands (civil or nautical); the glow stands in for twilight.

## Anti-goals

- A fallback day must never show times that look like real sunrise and sunset.
- The colouring must not hide a dive block.

## Testing

- Pure layout logic (sun band positions as fractions of the day, which
  basis was used, polar day versus night, label placement and dropping) lives
  in a testable function next to `computeRhythmBlocks`, with unit tests for
  each case in the table above, a sunset after midnight, and a site whose
  clock runs far from the sun.
- Widget tests: semantics label with and without sun times; the times follow
  the 12 and 24-hour settings; no exception at large text scale and small
  height (existing test kept).
