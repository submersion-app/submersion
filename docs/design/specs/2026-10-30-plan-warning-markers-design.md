# Plan warning markers on the profile (issue #3738)

## Intent

When the planner finds a problem with a plan, the diver sees where in the
dive it starts, not just that it exists. Each warning that begins at one
moment of the dive gets a small marker on the profile chart at that moment,
and the marker and its row in the warnings list point at each other.

## Goals

- A marker on the profile line at the time and depth each warning starts.
- Severity colours that match the warnings list: red for critical, amber
  for an alert or a warning.
- Warnings that start together share one marker.
- Hovering or tapping a marker shows its warnings, worded as the list words
  them. Picking a marker highlights its list rows, and picking a list row
  highlights its marker.
- Markers follow the plan as it is edited, and go when their warning goes.
- A repetitive dive that starts with a carried-in total already over its
  limit shows that warning at the start of the profile.

## Non-goals

- Shading the stretch over which a problem lasts. The marker shows where it
  starts.
- Times or depths added to the warnings list rows.
- Markers on the bailout picture. It is a different dive from the one the
  warnings describe, so the chart shows none while it is drawn.

## When a warning starts

`PlanIssue.atRuntime` is the elapsed dive time, in seconds, at which the
issue first starts. It is 0 when the dive starts with it and null when the
issue has no single moment. `atDepth` keeps its old meaning: the depth the
message names, such as the deepest point of the leg, which need not be the
depth at `atRuntime`.

| Warning | Starts at |
|---|---|
| ppO2 over the working or deco limit, hypoxic gas, END, gas density, diluent MOD | the point on the leg where the limit is first passed (`legOnsetRuntime`) |
| ceiling violated | the breach the ceiling replay found |
| CNS warning or critical, OTU | where the running total, including what earlier dives carried in, first reaches the threshold (`runtimeReaching`) |
| reserve, minimum gas, out of gas | where the cylinder's pressure first drops below that limit. Problem-solving gas counts as one lump where the diver leaves the bottom, and metabolic O2 counts only while on the loop |
| a hand-set MOD over its limit | the first schedule row breathed from that cylinder |
| no deco gas, no bailout carried, no usable gas in a fill | no single moment: list only |

A depth limit changes only once across a leg (deeper is worse for ppO2, END
and gas density, shallower for a hypoxic gas), so the crossing is found by
bisection on the leg's depth. The deco ppO2 check uses the same per-O2-band
or explicit-O2-depth ceiling (#3580) as the warning itself, so a marker
never starts where the warning would not.

Gas issues also carry `tankId`, the cylinder they are about.

The CNS and OTU a dive starts with are worked out as the dive's total less
every stretch the dive itself added. `main` does not yet carry exposure
into a planned dive, so today that start is always 0. When repetitive dive
planning (#3565, #3739) seeds the engine's totals with a series' carried-in
CNS and OTU, a dive that starts over a limit is marked at 0 with no change
here. An engine test for that case belongs with whichever of the two lands
second.

## Markers

`planIssueMarkers` makes one marker per warnings-list row that has a moment,
at its earliest issue's runtime, so a marker reads exactly as the list does.
Rows starting at the same runtime share a marker. On the chart, markers
whose points land within 16 px of each other also merge, so they never pile
up at the current zoom.

A marker is a small warning sign drawn 5 px above the line, or below it at
the top of the plot, so it never covers the line it points at. A dot marks
the start on the line. A highlighted marker shows a ring centred on that
dot in place of its sign, so nothing moves when a marker is picked. The
sign is outlined in the chart backdrop so it reads over the profile, the
fill and the ceiling band, in light and dark themes alike.

The popup sits beside the sign and the ring's space together, whichever is
showing, so it stays in the same place from hover to click and never
covers either. It goes to the right when it fits, else to the left, else
below, else above.

## Interaction

- **Hover (desktop):** a waypoint first, then a corner of the computed
  profile such as a deco stop (#3775), then a marker, otherwise the
  position line follows the cursor. A marker on a waypoint or a stop shows
  its popup while the line stays locked onto that point.
- **Tap:** a marker toggles its popup and highlights its list rows. A tap
  elsewhere on the chart lets go. A marker tap never selects a segment or
  adds a waypoint.
- **A marker on a waypoint:** a click or tap picks the marker. A press that
  moves drags the waypoint instead: the popup hides as the drag starts,
  whether it showed from hover or from a pick, and the marker is not
  picked. A touch shows nothing until it lifts, so a touch drag never
  flashes the popup up. Right-click and a long-press open the waypoint's
  menu, as anywhere else.
- **Scrolling the list:** when a marker tap picks out warnings that are
  scrolled out of the results panel, the panel scrolls up to show the
  whole warnings list, or, when the list is taller than the panel, just
  enough to show the picked rows. It does not move when they are already
  in view, when a marker is let go, or when a row is picked in the list.
  The phone's Results tab scrolls with the page, chart and all, so there
  the list is left where it is rather than scrolling the chart away. The
  sheet lays out in full rather than lazily, so the list can be measured
  while it is out of view.
- **List:** a row with a marker is tappable and highlights it. A row with no
  moment is not.
- The highlight lives in `highlightedPlanIssuesProvider` and clears when
  another plan is opened.

## Accessibility

- Touch hit targets reach 24 px around a marker, the 48 px a fingertip
  needs. Mouse targets reach 16 px.
- Each marker is a screen-reader button labelled with its time, depth and
  warnings. Its target is the same 48 px, moved inside the chart when a
  marker sits by the edge, so it is never clipped short.
- Colours come from the theme (`planIssueSeverityColor`), the same as the
  warnings list.

## Testing

- `issue_onset_test.dart`: running totals and leg crossings.
- `plan_engine_issue_onset_test.dart`: each issue type's start in a computed
  plan, including a deco ppO2 ceiling set by the explicit O2 depth.
- `plan_issue_markers_test.dart`: grouping and sharing.
- `plan_issue_marker_layer_test.dart`: placement, hit-testing, the popup,
  highlighting both ways, and hover over a marker on a deco stop.
- `plan_issue_marker_on_waypoint_test.dart`: hover, click, drag, touch,
  long-press and right-click on a marker that sits on a waypoint.
- `plan_warnings_reveal_test.dart`: the results panel scrolling to the
  warnings a marker tap picks out.
