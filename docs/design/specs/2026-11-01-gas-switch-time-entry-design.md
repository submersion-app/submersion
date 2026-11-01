# Richer Gas Switch Time Entry

Target release: v1.8.4. Issue #4089. Builds on the gas switch editor from
PR #4073 (issues #32 and #3058).

## Why

The dive edit page lets a diver add, change and remove gas switches, but the
time is a minutes-and-seconds text field. "I switched to the deco gas at the
6 m stop" has to become "15:00" in the diver's head before it can be typed, and
a misremembered time is not caught.

The data to do better is already stored. A cylinder with a transmitter shows
when it was breathed: its pressure holds, then falls. Every dive with a profile
shows where the diver was at any moment.

## Goals

- For a switch onto a cylinder with a transmitter, offer the moments that
  cylinder started being breathed as one-tap fills.
- For a switch on any dive with a profile, let the diver pick the time on a
  profile chart, reading the depth as they move.
- Keep the text field as the fallback and as the place the result lands.

## Non-goals

- Long-pressing the full profile chart on the dive detail page. The issue calls
  it last if at all, and #4073 keeps one entry point for switch editing.
- Any change to how switches are stored, saved, re-parsed, resynced or read by
  analysis. All of that is settled by #4073.
- Deciding a switch happened. The feature suggests times for rows the diver
  has; it never adds a row, and it never changes a row until tapped.

## Anti-goals

- A suggestion built from an estimated pressure curve. Those curves are
  synthesised partly from the switches, so a suggestion would echo the diver's
  own entry back as evidence. Only recorded transmitter series count.
- A suggestion raised by a cylinder cooling in the water in ordinary conditions.
  A false "this was breathed" is worse than no suggestion. The one known
  exception, a very large thermocline, is listed under the limits below.
- A second write path. A suggestion or a picked time is the same edit as a
  typed time.

## Constraints

- Time stays the stored truth and depth stays derived from the profile at that
  time, as in #4073, so none of this changes a calculation.
- A hand-entered dive with no profile and no transmitter looks exactly as it
  does after #4073.
- Depth and time read through the active diver's unit settings. Pressure is not
  shown.
- Strings go through the l10n process in every locale. No file over 800 lines;
  `dive_edit_page.dart` is far over, so everything new lands in its own file or
  in the existing `dive_edit_page_gas_switches.dart` part.
- Series are the primary source's, from `tankPressuresProvider`, which matches
  the profile and the switches the editor already shows on a dive logged by
  more than one computer.

## The design

### Suggested times

Under a switch row, a line reading `Started dropping at` followed by tappable
chips, each a time at which the row's selected cylinder started being breathed:
`14:50`. Changing the row's cylinder changes the chips. Tapping a chip fills the
row's time.

A sidemount diver rotates cylinders, so a cylinder can have many starts. The row
offers every start of its cylinder except:

- the one the row already holds (the same second),
- one on the second another row sits on, whatever its cylinder, since two
  switches cannot share a second, and
- one another row on the same cylinder already claims, meaning that row's time
  is within 60 seconds of it. A computer-logged switch at 14:55 claims a start
  at 14:50, so a second row is not offered the same moment.

When more than three remain, the row shows the three nearest its current time,
in time order. A sidemount diver filling in a rotation row by row sees the next
start because each tap claims the last one.

There are no chips when:

- the cylinder has no recorded series, or a series with no start,
- the dive has no saved series yet (a new dive),
- the cylinder's role is CCR diluent or oxygen supply, which feed the loop and
  are not breathed directly, so their pressure says nothing about a switch, or
- a start lies outside the dive (past the row's upper time limit).

### What counts as a start

A pure function over one cylinder's recorded series returns the seconds at which
it went from holding to falling. It first cleans the series with the shared
`withoutPressureGlitches` filter (issue #2441), which takes out signal dropouts,
transient dips and spikes, and a lead-in logged before the valve was open.

It then compares each reading with the reading 90 seconds earlier. The cylinder
is **falling** at a reading when that comparison shows at least 2 bar lost. A
rate test ignores slow change by design: a cylinder cooling at 0.5 bar a minute
is never falling.

A **turn** on the cylinder begins at the first falling reading. It ends once the
cylinder has not been falling for 120 seconds, or at the end of the series. A
turn gives a start when all of these hold:

- **A hold came first.** At least 120 seconds of not falling lie before the turn.
  A series that is already falling as it begins gives no start, so the cylinder
  the dive began on is not offered, and neither is one that starts cooling hard
  the moment it enters the water.
- **It lost at least 5 bar net.** The loss runs from the reading the fall was
  measured from to the reading at which the turn ended, so a dip that recovers
  counts for nothing, and neither does opening a valve at depth, which drops the
  reading 2 or 3 bar as the hose fills.
- **It kept falling.** At least 240 seconds lie between the start and the last
  falling reading. Cooling decays and stops within minutes; breathing carries on.
- **The start can be located.** The time of a start is the first reading more
  than 0.5 bar below the reading the fall was measured from. If more than 60
  seconds of no readings lie just before it, the series cannot say when the fall
  began, and the turn gives no start.

### Why these numbers

The thresholds sit together as named constants in the service. They were checked
on a read-only copy of a real log: 36 dives, 58 series, sampled every 2 seconds.
Every one of those dives breathes one cylinder from the start, so the real series
are a negative control, and breathing starts were built by splicing holds into
real breathing, which keeps the real noise. The log itself is not in the repo;
the committed tests model the same shapes.

| Scenario | Starts found | False starts | Timing |
| --- | --- | --- | --- |
| All 58 real series, untouched | not applicable | 0 | not applicable |
| Deco bottle, held 40 min | 33 of 33 | 0 | 10 s late, 95% within 28 s |
| Sidemount, 8 min turns and holds | 209 of 228 | 0 | 10 s late, 95% within 28 s |
| Sidemount, 4 min turns and holds | 361 of 439 | 0 | 10 s late, 95% within 26 s |
| Sidemount 8 min, 0.5 bar/min drift in holds | 212 of 228 | 0 | up to 78 s early |

Unbreathed cylinders, each of which must give no start, and does:

- a recovered dip of 4.5 bar over 20 seconds, and of 8 bar over 40 seconds
- a two-reading dropout to 3 bar
- a 3 bar hose fill, then steady, and then with 0.5 bar/min drift
- 0.5 bar/min drift for a whole dive
- a cylinder that held, then cooled through a thermocline of 5 or 10 degrees

Limits, all but the last of which fail by offering nothing:

- A hold shorter than about 3.5 minutes can run two turns together, because the
  90 second comparison keeps reading "falling" after the fall stops. Oxygen deco
  air breaks of 5 minutes are fine.
- A turn shorter than about 4 minutes gives no start, so a 3 minute turn on a
  bottle is left to the text field or the picker.
- Twin 12 L cylinders breathed at 6 m (about 1 bar a minute) are below the falling
  rate. The rule covers about 1.3 bar a minute and up, which takes in a 7 L oxygen
  bottle at 6 m (3.4 bar a minute) and a single 12 L cylinder at 6 m (2 bar a
  minute).
- A cylinder that held, then cooled through a thermocline of 14 degrees or more
  within a few minutes, can raise a false chip, because that cooling is as fast
  and as sustained as slow breathing. Only depth or temperature could tell them
  apart. A chip changes nothing until tapped, and the fall it names did happen.

### Picking on the profile

A chart icon button in the row, beside the time, opens a bottom sheet. It shows
only when the dive has a profile. A vertical drag does not close the sheet, since
it belongs to the chart. The sheet holds:

- The dive detail page's own profile chart, the same widget with the same look,
  axes, gestures and hover tooltip, limited to depth and pressure. Whatever the
  diver's legend says, every other line stays off, and there is no legend, no
  options menu and no right-axis menu. Nothing the sheet does changes the diver's
  chart settings.
- Every cylinder's recorded pressure, in its gas colour on the labelled right
  axis, with the row's cylinder permanently drawn heavier. A switch reads as one
  line going flat where the other starts falling. Cylinders the diver removed in
  this session are left out, and estimated curves never appear.
- The chart's markers at the dive's other switches, so the diver can place this
  one relative to them, and its cursor at the chosen time, which starts at the
  row's time.
- A readout of the chosen time and the depth there in the diver's unit, updated
  live.
- A slider under the chart over the same span, inset to the plot so its thumb
  sits under the cursor at the default zoom, for keyboard and screen reader use
  and for times between the samples of a sparse profile.
- Cancel and Set time. Cancel leaves the row untouched.

Hovering shows the tooltip and chooses nothing. A tap, or the end of a drag across
the plot, chooses the nearest sample however sparse the profile.

### Writing the time

A chip or Confirm goes through the same callback a typed time does: the page's
`_onGasSwitchChanged` with `GasSwitchField.time`, followed by the settle step
that re-sorts the rows. So the depth refills from the profile unless the diver
has typed one, the row is validated as a typed time is, and the save, the
re-parse protection and the sync staging are unchanged. A depth the diver typed
stands, as it does after typing a new time; the sheet's readout shows the
profile's depth whichever applies.

Nothing here blocks an out-of-range or same-second time separately: the row's
existing validation reports it and blocks Save.

## Builder's calls

These are mine, made so the builder can plan.

- **Thresholds:** 90 seconds, 2 bar, 120 seconds, 5 bar, 240 seconds, 0.5 bar and
  a 60 second gap as above, pinned by synthetic tests that model breathing, drift
  up to 0.5 bar a minute, glitches, a hose fill, cooling, sidemount rotation and a
  gap in the readings.
- **Chips under the row,** not in the row, because the row is already three
  fields wide on desktop and two lines on a phone.
- **Three chips at most** on a row, so a long sidemount rotation does not push
  the rest of the form down.
- **The start time** is the first reading below the level, not an estimate
  worked back from the fall, so it never claims more than the data shows.
- **Diluent and oxygen supply** get no chips. Other roles do.
- **A detection result is cached per dive** in a provider derived from
  `tankPressuresProvider`, so typing in the form does not re-run it.
- **A new file for each piece:** the detector in
  `lib/features/dive_log/domain/services/`, the chip line and the sheet under
  `lib/features/dive_log/presentation/widgets/edit_sections/`.
- **The glitch filter** is the shared `withoutPressureGlitches`, not the narrower
  filter private to `ccr_bailout_timeline.dart`, which stays where it is.
- **Depth typed before picking stands,** per the issue's constraint that a
  picked time behaves exactly as a typed one.

## Left to the builder

- Chip and icon styling within the page's existing form style.
- Exact sheet layout at phone and desktop widths (`SheetMessengerScope` is not
  needed; the sheet raises no snackbar).
- Test placement, following the repo's layers.

## Screenshots

The gas and gear group before and after on a dive with two cylinders, and the
sheet, at phone and desktop widths, in light and dark.
