# Calm summary panes

Date: 2026-10-17
Issue: #3434
Release: unassigned

## 1. Problem

On a wide window every list section (Dives, Sites, Trips, and so on) is a
master-detail layout, and the detail pane with nothing selected shows a
summary widget. All eleven of those widgets are built the same way: a header
with an icon, a wrap of 140 px stat cards in assorted Material colours, a
"Recent" list card, and a row of quick-action buttons. They are dashboards,
and they look like the rest of the app, which is technical and dense by
nature.

The maintainer wants those panes to do the opposite job: to be the calm place
in the app. The feeling to invoke is the one a diver has hanging at a safety
stop, where everything moves but nothing hurries, and the water puts you in
another realm. A pane like that should make people want to open the app, and
should rest the eye between the data-heavy screens on either side of it.

## 2. Decisions

Made during the brainstorming session on 2026-10-16 and 2026-10-17, from
animated mockups. Do not reopen without a reason.

| Question | Decision |
| --- | --- |
| What a summary pane becomes | A scene: one slowly moving underwater or nautical picture, with three to five facts and one sentence on it |
| How many scenes | Ten, one family. Each page is assigned a scene; some scenes serve two pages with different facts |
| Does the data-rich summary survive | Yes. A small button at the top right of every pane flips between the scene and today's summary widget |
| Where the default lives | Settings > Appearance, a per-device setting with the scene as the shipped default |
| Which pages | The eleven master-detail summary panes, plus the Insights overview pane and the Transfer home pane |
| Phones | Nothing changes. Summary panes only exist at master-detail widths (1100 px and up) |
| Home page | Out of scope, but the scene engine is built so the home hero can adopt a scene later |
| Motion | One shared slow clock, a few frames a second, paused when the window is unfocused or covered, still under reduce motion |
| Planning's profiles | Schematic, drawn from the plan summary; no full plan load, no deco engine |
| Insights observations strip | Stays on the details view behind the toggle |
| Pages with no data | Show the details view regardless of the setting, so the quick actions remain a new diver's way in |

Rejected along the way, so a builder does not reintroduce them: pastel
breathing blobs, warm or dry above-water scenes (a boat deck, a moonlit sea),
a refraction filter over ordinary content, a caustic light texture, an
ink-wash illustration, the diver's profile turned into hills, a diver
silhouette, a breathing-paced bubble column, raindrop rings on still water,
a drop-off wall, a cenote shaft, and a torch-lit night dive for Equipment.
The night dive itself was liked and is benched for the home page (see
section 12).

## 3. Goals

- Every summary pane opens as a scene by default: calm, slow, organic, and
  unmistakably about water or the sea, so it offsets the rest of the app.
- Every scene still gives real summary information: the same facts the
  page's summary widget gives today, reduced to the three to five that
  matter, plus one sentence that says what they mean.
- The ten scenes read as one family. Someone who has seen two of them
  recognises the third.
- Nothing is lost. The data-rich summary is one tap away on every pane, and
  the diver can make it the default.
- The scenes cost nothing while the app is idle: a few frames a second at
  most, nothing when the window is in the background, nothing under reduce
  motion.
- Light and dark themes each get a palette per scene, and all five theme
  presets look right with them.
- Everything is localised, right-to-left aware, and accessible: the facts
  are text, the picture is decoration.

## 4. Non-goals

- Changing the master pane (the list) or the detail pane for a selected item.
- Redesigning the data-rich summary widgets. They stay as they are and become
  the "details" view behind the toggle.
- A phone or narrow-window version. Below 1100 px there is no summary pane.
- The home page. Section 12 records the intent; nothing on Home changes in
  this work.
- Photos, video or any raster artwork. Every scene is drawn with code.
- Sound.
- Interactivity inside the picture (dragging, hovering effects, parallax that
  follows the pointer). The only interactive things are the facts that link
  somewhere and the toggle button.

## 5. Anti-goals

These would make the work a failure even if it shipped:

- Busy. A scene that draws the eye to its motion instead of resting it.
  Motion is slow (periods of 8 to 60 seconds), low contrast, and never
  synchronised across elements.
- Decorative clutter. No cards, no grid of coloured icon tiles, no section
  headings, no buttons in the scene. The facts float on the picture.
- Battery drain. A scene painter that repaints on every vsync, or keeps
  running when the window is not visible, is a bug (compare #3044 on the
  existing ocean hero).
- Theme clash. A scene whose fixed colours fight the Tropical or Console
  preset.
- Wrong numbers. The facts come from the same providers the data-rich
  widgets use, and they must agree with them and with the Insights overview.

## 6. The family: what every scene pane shares

A scene pane is a `Stack` of three layers inside the detail pane:

1. **The picture.** A `CustomPainter` driven by the scene clock, inside a
   `RepaintBoundary`, excluded from semantics. It fills the pane edge to
   edge with no rounded corners, no border and no card.
2. **The facts.** Ordinary widgets (text, a few hairlines) positioned on the
   picture with directional insets, so Arabic and Hebrew mirror them. The
   picture itself does not mirror.
3. **The toggle.** A 30 px round icon button at the top end corner, low
   opacity until hovered, with a tooltip. Section 8.

### 6.1 The content budget

Each page gets exactly this, in this order of importance:

- An eyebrow: the page name in small caps with wide tracking, low opacity.
- One headline fact, light weight, about 26 px. Usually a count ("214 dives")
  or the one thing that matters now ("Advanced Nitrox, in progress").
- One sentence of prose that gives the headline its meaning and carries one
  or two more facts ("48 sites. You return most to Blue Hole.").
- Up to three secondary facts, placed where the scene wants them: a column
  on the end side, markers in the picture, a quiet row along the bottom.
- Optionally one footer line at the bottom, 12 px, 60 % opacity.

That is the whole budget. If a page's data-rich widget has more to say, the
rest stays in the details view.

### 6.2 Type and colour on the picture

- Type follows the preset's text theme family (Nunito under Tropical,
  JetBrains Mono under Console, the platform sans elsewhere) at the
  lightest weight that family offers, `w300` where it exists; a diver who
  chose a monospace preset chose it everywhere. Labels are lower case, 12
  to 13 px, 70 % opacity. The horizon scene alone uses a serif for its
  sentence (section 10, fonts).
- Type colour is defined by the scene, not by the colour scheme: near-white
  on dark water, ink on paper and on the light strata band. Every scene
  defines its own light and dark palette (section 7); the theme preset does
  not recolour the picture.
- A fact that links somewhere (a record dive, a site, a buddy) is plain text
  with a dotted underline at 50 % opacity, and the pointer changes. No
  buttons, no chevrons, no accent colour.
- Nothing in the scene uses `colorScheme.onSurfaceVariant` or any secondary
  role: those collapse to the primary role in nine of the ten preset
  schemes, which is why the current widgets look flat.

### 6.3 The clock

One `SceneClock` per visible pane, modelled on `OceanBackground`
(`lib/core/presentation/widgets/ocean_background.dart`):

- A `Timer.periodic` at 24 frames a second, not a vsync ticker. The value
  it publishes is elapsed seconds as a double; each scene derives its own
  periods from it.
- It runs only while the app lifecycle is resumed (a null state counts as
  resumed), `TickerMode` is enabled for the route, and
  `MediaQuery.disableAnimations` is false. Otherwise it stops and the
  painter draws its last frame as a still.
- Under reduce motion the painter draws one representative frame at a fixed
  clock value, chosen so the scene reads well as a picture.
- Randomness is seeded from a constant per scene, never from `Random()`
  without a seed, so a frame at a given clock value is reproducible in
  tests.

### 6.4 Width and height

The master pane is resizable from 280 to 700 px and the scaffold reserves
only 400 px for the detail pane, so a summary pane can be as narrow as
400 px at the 1100 px breakpoint and as wide as 2000 px and more on a
large monitor, at any height. Scenes lay out in fractions of the pane and
must look right across that range: the facts keep a maximum measure (about
60 characters for the sentence), the picture scales, and nothing
overflows. Below 560 px every scene collapses the same way: the end column
drops under the sentence, marker labels shorten to their value, and the
footer wraps. Test at 400 x 400, 900 x 700 and 1600 x 1000.

## 7. The scenes and the page mapping

Ten scenes serve thirteen panes. Each entry gives the picture, what moves,
what data (if any) drives the picture, the facts for each page it serves,
and palette notes for light and dark. Pixel values are in the mockups
(section 13); the numbers here are the ones that matter.

| Pane | Scene |
| --- | --- |
| Dives | Water column |
| Gas calculators | Water column, with MOD markers |
| Dive sites | Chart |
| Trips | Chart, the passage variant |
| Buddies | Kelp, one blade per buddy |
| Certifications | Strata |
| Courses | Strata |
| Equipment | Shoal |
| Dive centres | Snell's window |
| Planning | Tracing |
| Settings | Horizon |
| Insights (overview pane) | Constellation |
| Transfer (home pane) | Current |

### 7.1 Water column (Dives, Gas calculators)

The pane is the water: a vertical gradient from a bright surface band to
near black at the bottom. A rippling surface line runs along the top edge
(two offset sine waves sliding at different speeds). Three soft light rays
fan down from the top, each swaying a few degrees over 18 to 26 seconds.
Marine snow, about ninety faint particles, sinks slowly with a sideways
wobble. A hairline depth scale sits on the end side with three ticks.

Markers are placed on the scale at real depths: a glowing dot, a hairline
across the pane, a 24 px number and a 12 px label, bobbing a few pixels over
9 to 11 seconds.

- Dives: eyebrow "dive log"; headline "214 dives · 61 h 20 m below"
  (career totals including prior dives, as the current widget and the
  Insights overview do, issue #808); sentence "48 sites. You return most to
  Blue Hole." (site count and top site). Markers: average maximum depth
  ("your usual depth") and the deepest dive (depth, site, month and year),
  both from `diveStatisticsProvider` and `diveRecordsProvider`. The deepest
  marker links to its dive the way the records list does today
  (`goInPlace` with the selected query parameter). While the dive list is
  filtered (`diveFilterProvider.effective.hasActiveFilters`), the facts
  come from the scoped providers as today and the filter banner's text
  becomes a quiet line under the headline instead of a banner.
- Gas calculators: eyebrow "gas calculators"; headline "Six calculators"
  (the count of calculators the section lists); sentence "Your mixes,
  placed at their limits." Markers: the two gas mixes the diver uses most,
  taken from the log's cylinder mixes, each at its maximum operating depth
  for the diver's working ppO2 setting (air at 1.4 bar when the log has no
  mixes), the trimix one adding its equivalent narcotic depth at the
  diver's deepest dive. The scale runs to 60 m here. The existing
  disclaimer text is the footer line.

Palette: dark, deep navy to black with white light; light, aqua to navy
with brighter rays and whiter snow. Type is white in both.

### 7.2 Chart (Dive sites, Trips)

A paper nautical chart: a coastline on the end side with a land fill,
three dashed depth contours following it, a dozen soundings in a small
serif, a compass rose at the top start corner. The whole sheet drifts two
per cent and breathes a two per cent scale over 70 seconds, and a soft band
of light sweeps across it every 42 seconds. Site marks are small filled
dots with a pulsing halo (8 second period) and a label.

- Dive sites: eyebrow "dive sites"; headline "48 sites, 6 countries";
  sentence names the most dived, the best rated and the most recently
  dived site (the three lists the current widget already derives); marks
  for those three, each linking to the site; footer "41 with GPS · 5 not
  yet dived". All from the site statistics the current widget reads.
- Trips, the passage: the same chart, but the marks are the last trip and
  the next trip, with a dashed course in a muted vermilion running from a
  "Home" mark through the last trip to the next, its dashes creeping along
  the course over 40 seconds. Headline "23 trips, 96 days diving"; sentence
  "Next: Komodo, in 23 days. Last: Bali, in May."; footer "4 liveaboards ·
  214 dives away". Trips carry no country, so no country count here. The
  countdown reuses the upcoming-trip formatting the current widget has.

Mark positions are not geographic: the chart is a drawing, and the builder
places marks at three fixed, pleasing positions. A future version may use
real coordinates; this one must not pretend to.

Palette: light, parchment with brown-grey ink and teal marks; dark, slate
with pale ink and cyan marks. Type is ink in light, pale in dark.

### 7.3 Kelp (Buddies)

Open water with two faint light rays. Seven tall blades of kelp rise from
the bottom edge, three paler and blurred behind, four dark in front, each
swaying through plus or minus two degrees of rotation and skew at its own
period between 8.5 and 13 seconds with staggered phases. A blade is a single
tapered path.

The three front blades are the diver's three most frequent buddies, scaled
so the tallest has the most shared dives, each with the buddy's name and
"42 dives together" at its tip; the name links to the buddy. The rest of
the forest stands for everyone else. Headline "31 buddies"; sentence "19
with a card on file. Twelve of them in the water with you this year." The
counts come from what the current widget reads; the "this year" count is
new and comes from the dives of the current calendar year.

Palette: dark, teal-navy water and near-black blades; light, turquoise
water and deep green blades. Type is white in both.

### 7.4 Strata (Certifications, Courses)

Three horizontal painted bands: a sunlit band at the top, a twilight band,
and a midnight band at the bottom, their two boundaries undulating sine
waves that slide in opposite directions over 44 and 58 seconds. A static
paper-grain overlay at 6 to 7 % opacity. Tiny labels "sunlit", "twilight"
and "midnight" sit at the end edge of each band at 50 % opacity.

One thought per band, deeper as you go:

- Certifications: sunlit "7 certifications" with "6 valid, 1 expiring soon,
  none expired"; twilight the highest card with agency and year; midnight
  whatever renews next with its countdown. Each card name links to the
  certification.
- Courses: sunlit "3 courses" with "2 completed, 1 in progress"; twilight
  the course in progress with its agency and the dives logged against it
  so far ("3 dives so far", counted through the dive-course links; a
  course has no required-dive count); midnight the most recently completed
  course with its completion date. A course has no planned state, so
  nothing is invented for one.

Palette: light, pale aqua, mid blue, deep blue; dark, teal, navy, near
black. Type is ink on the light sunlit band and white elsewhere.

### 7.5 Shoal (Equipment)

Open blue water. Thirty-two small fish, one per equipment item, move as a
single slow shoal: a flocking model (alignment, cohesion, separation, and a
slow wandering target) tuned to a tenth of the usual boid speed, so the
group drifts and turns without ever darting. Each fish is a small teardrop
with a tail, oriented along its velocity. The number of fish equals the
item count, capped at sixty, with a floor of eight so the shoal still
reads as one when the diver owns little.

Items due for service are stragglers: they turn amber, glow faintly, and
are pushed gently away from the group's centre. Headline "32 items, 29 in
use"; sentence "Every fish is an item. Three have strayed from the shoal."
Under it, a short list of the stragglers with amber dots, one line each
(name and what is due), each linking to the item, capped at four with a
"and 2 more" line. Footer: total value and wish-list value as today, in
the diver's currency.

Palette: dark, deep blue water and pale fish; light, bright turquoise water
and dark fish. Amber (#F0B060) for stragglers in both. Type is white.

### 7.6 Snell's window (Dive centres)

Looking up from the stop: a bright, roughly elliptical window of sky at
upper centre, its edge wobbling with three superimposed sine terms, a soft
glow bleeding into dark water all around. Eleven bubbles rise from the
bottom into the window, darker-stroked where they cross it. The facts sit
inside the window in dark ink: eyebrow "dive centres", headline "14
centres", sentence "6 countries · 11 with GPS". Below the window, in pale
type on the dark water, a footer with the highest rated centre and the
first of the current widget's recent centres, each linking to its centre.
(Centres are not dated by dive, so there is no "last visited".)

Palette: dark, near-black surround and a pale cyan window; light, teal
surround and a near-white window. Window type is ink in both.

### 7.7 Tracing (Planning)

A plain surface (near white in light, near black in dark). A faint surface
line and two depth marks define a plot area in the lower half. A saved plan
is drawn slowly as a single thin line from left to right, the way a pen
would, over about 26 seconds, holds for 4, fades over 3, and the next plan
begins; the cycle runs through the saved plans in order and loops. A
caption under the plot names the plan being drawn: name, depth, runtime
and mode, and links to the plan.

The profiles are schematic, drawn from the plan summary the page already
reads (maximum depth, runtime, time to surface, mode) and nothing else: a
straight descent at a fixed schematic rate to the maximum depth, a flat
bottom until runtime minus time to surface, then a stepped ascent whose
stops are evenly spread across the time to surface. No full plan is
loaded and the deco engine never runs for this pane. The caption carries
the true numbers; the line is a drawing of them, not a computed schedule,
and it names no gases.

Headline "6 saved plans"; sentence "Drawn one at a time."; end column with
the deepest plan, the longest, and the count on CCR. With no saved plans,
the plot area draws nothing and the sentence becomes the current widget's
"No saved plans yet", linking to the planner.

Palette: light, paper white with a teal-blue line; dark, charcoal navy
with a pale cyan line. Type is ink in light, pale in dark.

### 7.8 Horizon (Settings)

The most restrained scene. The upper half is the page surface; the lower
half is a darker water band. The boundary is an undulating line: two
stacked waves sliding in opposite directions over 32 and 46 seconds. Two
large soft caustic patches drift across the water band over 38 and 46
seconds. Nothing else.

The upper half carries one sentence in a serif at 29 px with a second,
smaller sentence under it. The water band carries a row of four quiet
numbers with small-caps labels, and a footer line.

- Settings: "Eric, diving in metres and bar." then "Gradient factors 40/85.
  Deep theme, dark, following the system. Last backup three days ago."
  Row: units preset, gradient factors, theme preset and mode, time since
  the last backup (from the backup providers the home chip uses). Footer:
  the current backup tip. The active diver's name comes from the current
  diver provider the widget reads today.

Palette: light, warm paper above pale blue-grey water; dark, navy above
deeper navy. Type is ink in light, pale in dark.

### 7.9 Constellation (Insights overview pane)

A night sky: one point per logged dive, 214 of them, in two layers that
drift at different speeds (parallax) and twinkle slowly. Points are
clustered: each cluster is a trip, and dives without a trip are scattered
between. Point brightness follows maximum depth. Three record dives are
drawn brighter and joined by a thin line into a small constellation, each
with a label: deepest, longest, coldest, with value and site, each linking
to its dive.

Headline "214 dives, 61 h 20 m" (career totals); sentence "Every point is
a dive. The brighter ones went deeper. Three records are joined."; footer
"This year: 38 dives, 24 h. Last year: 52." from the year statistics the
home page's year-in-review card reads (calendar year against the previous
one; those are the only year figures that exist).

The points come from a new lean repository query returning id, maximum
depth, trip id and date for every dive, never from hydrated `Dive`
entities: the pane must stay cheap on a log of thousands. The scene honours
the Insights filter the overview honours (`insightsFilterProvider`), the
way the Dives scene honours the list filter, and shows the whole log when
no filter is set.

The details view behind the toggle is the existing Insights overview page,
which already serves as this pane. The observations strip that page shows
on the summary pane (placed there deliberately in #2381, because the
Overview category detail is the same page and would repeat it) stays on
the details view, one tap away; the scene does not show it.

Palette: dark, deep navy to black with pale points; light, a dusk navy with
slightly warmer points (the light theme does not get a light sky; a
constellation needs a dark field). Type is pale in both.

### 7.10 Current (Transfer home pane)

Water seen side-on with a slow current running left to right: about 170
fine streaks of plankton drawn as short fading trails that follow a smooth
time-varying vector field. Three rounded chips drift with the current from
beyond the start edge to beyond the end edge over 85 to 115 seconds,
bobbing gently. A column of three numbers stands still on the start side.

- Transfer: numbers "3 new dives in the last import", "2 computers paired",
  "2 cloud sources connected"; chips carrying the last three transfer
  events: the last computer download (device, dives, how long ago), the
  last cloud sync, the last export. Each chip links to its section. When
  no history exists, the chips are omitted and the numbers stand alone.
  The builder confirms which of these facts the transfer, dive computer and
  cloud providers already record and drops any that would need new
  storage.

The details view behind the toggle is the existing "select a section" pane.

Palette: dark, deep teal-navy with pale streaks; light, pale aqua with dark
teal streaks. Type is white in dark, ink in light.

## 8. The toggle and the Appearance setting

- Every scene pane has an `IconButton` in the top end corner, 30 px round,
  `Icons.grid_view` while the scene shows and `Icons.water` (or the closest
  Material glyph the builder finds) while the details show, tooltip "Show
  details" / "Show scene". It sits on a translucent disc so it reads on any
  scene, and it has a 48 px hit box regardless of its drawn size (see the
  icon-button density trap in `docs/developer/testing.md`).
- Pressing it flips that pane for the rest of the session. The override is
  per page and in memory only; relaunching the app returns every pane to
  the default.
- Settings > Appearance gains a "Summary panes" choice with two options,
  "Scene" and "Details", default "Scene". It is per device, stored in
  SharedPreferences next to `hidden_home_cards`, not synced and not
  per-diver, and it needs no schema rung.
- Settings has two appearance UIs: the phone `AppearancePage` and the
  desktop `_AppearanceSectionContent` inside `settings_page.dart`. The
  choice goes in both, or wide windows will not see it.
- The Settings summary pane itself also carries the toggle, so a diver who
  prefers details can get there from any page.
- A page with nothing to summarise (no dives, no sites, no buddies, and so
  on) shows the details view whatever the setting says, because today's
  quick actions (log a dive, import from a computer, add a site) are a new
  diver's way in and the scene has no buttons. The toggle is still there.
  The scene takes over once the page has data. `SummaryPaneSwitcher` takes
  an `isEmpty` flag from the page for this.
- Two master-detail panes are not in the list and keep what they have: the
  Documents placeholder and the Equipment Sets placeholder. Neither gets a
  scene or a toggle in this work.

## 9. Where the facts come from

The scenes read the providers the data-rich widgets read today, and never
compute a number those widgets do not. The current widgets are the source
of truth for each page's provider set:

| Pane | Today's widget |
| --- | --- |
| Dives | `lib/features/dive_log/presentation/widgets/dive_summary_widget.dart` |
| Dive sites | `lib/features/dive_sites/presentation/widgets/site_summary_widget.dart` |
| Trips | `lib/features/trips/presentation/widgets/trip_summary_widget.dart` |
| Buddies | `lib/features/buddies/presentation/widgets/buddy_summary_widget.dart` |
| Certifications | `lib/features/certifications/presentation/widgets/certification_summary_widget.dart` |
| Courses | `lib/features/courses/presentation/widgets/course_summary_widget.dart` |
| Equipment | `lib/features/equipment/presentation/widgets/equipment_summary_widget.dart` |
| Dive centres | `lib/features/dive_centers/presentation/widgets/dive_center_summary_widget.dart` |
| Planning | `lib/features/planning/presentation/widgets/planning_summary_widget.dart` |
| Gas calculators | `lib/features/gas_calculators/presentation/widgets/gas_calculators_summary_widget.dart` |
| Settings | `lib/features/settings/presentation/widgets/settings_summary_widget.dart` |
| Insights | `lib/features/insights/presentation/pages/insights_overview_page.dart` |
| Transfer | `_TransferSummaryWidget` in `lib/features/transfer/presentation/pages/transfer_page.dart` |

Five facts are new and need a provider or a small query, and they are the
only additions: buddies dived with in the current year (7.3), the diver's
most used gas mixes (7.1, gas calculators), dives logged against a course
(7.4, through the existing dive-course links), the lean per-dive points
query (7.9), and the transfer history chips (7.10). Each falls back
gracefully when its data is absent, as described in its section. Anything
else a scene says is a fact the page's current widget already derives.

Every number that carries a unit goes through `UnitFormatter` with the
active diver's settings, and every string is an ARB key in all eleven
locales.

## 10. Constraints

- **Performance.** One scene clock per visible pane at 24 fps, stopped when
  unfocused, covered, or under reduce motion. A scene painter must not
  allocate in `paint` beyond what it draws (precompute particle arrays and
  paths), and `shouldRepaint` compares the clock value only. The flocking
  model for the shoal is O(n²) at n of 60 at most, which is fine; cap it.
- **Themes.** Each scene defines a light and a dark palette as constants.
  Scenes are checked against all five presets in both brightnesses; the
  acceptance test is that no scene looks wrong next to the preset's app bar
  and navigation rail.
- **Fonts.** The horizon's serif comes from a platform fallback list
  (Iowan Old Style, Palatino, Georgia, Noto Serif, DejaVu Serif, serif).
  No font asset is bundled in this work; if no serif resolves, the app sans
  is used and the scene still works. Arabic, Hebrew and Chinese use
  whatever serif the platform provides for them.
- **Localisation.** All scene strings are ARB keys in every locale, inserted
  next to their feature's existing summary keys (every ARB is feature
  grouped). Sentences with numbers use placeholders, never concatenation,
  and plural forms use ICU plural syntax.
- **Right to left.** Facts use directional insets and alignment. Pictures do
  not mirror. The depth scale, the end column and the toggle sit at the
  end edge.
- **Accessibility.** The painter is `ExcludeSemantics`. Every fact is a
  `Text` or a `Semantics`-labelled tappable, read in content order. Reduce
  motion stops the clock. The toggle has a tooltip and a 48 px target.
- **Tests.** Each scene painter has a unit test that paints at a fixed
  clock value and seed into a recorder and asserts it draws (no exceptions,
  non-empty picture) and is deterministic. Each scene pane has a widget
  test at the three sizes in 6.4 asserting no overflow and that the facts
  render from fake providers. The toggle and the setting have widget tests
  on both appearance UIs. The clock has tests for pause on lifecycle,
  `TickerMode` and reduce motion, using fake time, and every test puts back
  any process-wide state it replaces (CI bundles test files in one
  isolate). Run `test/architecture` and `test/shared` after adding files
  under `lib/`: the adoption guards scan all of it.
- **File layout.** Many small files, none over 800 lines. The shared engine
  lives under `lib/shared/widgets/scenes/`: `scene_clock.dart`, a
  `Scene` base, and one painter file per scene. The pane scaffold (picture,
  facts, toggle) and the setting live under `lib/shared/widgets/summary/`.
  Each feature adds a `<feature>_summary_scene.dart` next to its existing
  summary widget that composes that page's facts, and its page's
  `summaryBuilder` returns a `SummaryPaneSwitcher(scene: ..., details:
  ...)` that reads the setting and the session override.
- **Screenshots.** This is a UI change under `lib/**/presentation/` and
  `lib/shared/widgets/`, so every PR carries before and after screenshots
  in light and dark, at a master-detail width.
- **Attribution.** No tool or model attribution anywhere in the repository
  or on GitHub.

## 11. Delivery

One PR per scene is the natural grain, with the engine, the switcher, the
setting and the Dives water column in the first PR, since Dives is the
page people open most and proves the whole path. A suggested order after
that: Chart (Sites, then Trips), Strata (Certifications, Courses),
Constellation (Insights), Current (Transfer), Kelp, Shoal, Snell's window,
Tracing, Horizon, and the Gas calculators water column last, because it
needs the most-used-mixes query. Each PR links the tracking issue with
`Refs`, and the last one closes it.

## 12. Later: the home page and the benched scene

The maintainer may apply the same thought to the home page. The scene
engine is shared so the home hero (today the `OceanBackground` gradient
with bubbles and caustics) can become a scene without new plumbing. The
night dive, a scene that was liked but ended up without a page, is the
natural candidate: near-black water, a torch beam sweeping slowly from a
corner, bioluminescent specks pulsing and drifting. One idea worth keeping:
the home hero could show the water column by day and the night dive after
dark. None of this is in scope now.

## 13. Mockups

The animated mockups the decisions were made from are checked in next to
this document:

- `assets/2026-10-17-calm-summary-panes-mockup-realms.html`: the ten scenes
  side by side with sample Dives content.
- `assets/2026-10-17-calm-summary-panes-mockup-pages.html`: the eleven pages
  in their first-round scenes (Trips, Buddies, Equipment, Courses and Gas
  calculators were reassigned afterwards; see the next file).
- `assets/2026-10-17-calm-summary-panes-mockup-rework.html`: the final Trips,
  Buddies, Equipment and Gas calculators scenes, the inherited Courses,
  Insights and Transfer panes, and a working corner toggle that flips each
  pane to a wireframe of today's data-rich view.

Open any of them in a browser. Each has a Dark/Light switch at the top
right. The timings, opacities, particle counts and palettes in the CSS and
script are the reference values for the painters; the builder may tune
them, but should start there.

## 14. Left to the builder

- The exact geometry of each painter (the kelp blade paths, the coastline,
  the window's wobble terms) within the descriptions above and the mockup
  values.
- Where on the chart the three marks go, and how the passage course is
  drawn between them.
- How the shoal spawns and despawns fish when the item count changes.
- The Material glyph for the toggle's "scene" state.
- Which transfer facts exist today and which chips to drop.
- Test helpers for driving the scene clock with fake time.
