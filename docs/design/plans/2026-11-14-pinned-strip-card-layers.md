# Pinned Strip Card Layers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The pinned profile strip on dive details draws the time-series data of the cards currently in view, fading each layer in and out, growing to 72 px while a line layer shows, and reading every active layer in its tooltip (issue #4562).

**Architecture:** The overlay that pins the strip already measures the profile card in scroll-content coordinates; it now also measures the cards wrapped in a `PinnedStripCardMarker` and computes, per scroll frame, which are in view. A `PinnedStripLayerHost` turns that set into per-layer strengths and a grow factor, animated, and hands them with the layer data to the strip. Pure builders turn provider data into `PinnedStripLayerData`; three painters draw it beneath and above the existing depth painter.

**Tech Stack:** Flutter, Riverpod (`core/providers/provider.dart`), CustomPainter, flutter_test.

**Spec:** `docs/design/specs/2026-11-14-pinned-strip-card-layers-design.md`

## Global Constraints

- Files 200 to 400 lines typical, 800 max.
- Units through `UnitFormatter` (active diver's settings).
- New strings in every ARB file under `lib/l10n/arb/`, then `flutter gen-l10n`.
- No new dependencies; no schema change; no new setting.
- Strip grows from `kPinnedStripHeight` (44) to `kPinnedStripGrownHeight` (72).
- A card is in view once 75% of it (or, for a card taller than the room, 75% of the room) lies between a fixed edge 72 px below the overlay's top and the viewport's bottom, with 16 px of hysteresis. (Changed from the first build's 96 px at the diver's request; Task 2's tests were rewritten to match.)
- Fades and growth: 250 ms, `Curves.easeInOut`; none with `MediaQuery.disableAnimations`.
- Layers and growth only while the strip is settled (condense 1).
- No em dashes; immutable data; `dart format .` before each commit.

## Review Focus

1. A dive with none of the data (no temperature, no transmitter, no media): the card in view draws nothing and the strip stays 44 px. Pinned by Task 3 and Task 4 tests.
2. A card scrolled out mid-fade reverses from its current strength rather than jumping. Pinned by Task 4.
3. The strip growing must not change the in-view result (fixed 72 px edge). Pinned by Task 2.
4. Curves shorter than the profile, and tank series whose timestamps run past the profile, draw no further than the profile. Pinned by Task 3.
5. Scrolling back up to the profile card: layers fade and the strip shrinks while the condense reverses, and the depth line still lands on the chart's. Pinned by Task 8 (overlay test: no layer strength once condense < 1).

---

### Task 1: Layer catalogue and card mapping

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_test.dart`

**Interfaces:**
- Produces:
  - `enum StripLayer { temperature, cns, surfaceGf, tankPressure, gtr, gasSwitches, sac, phases, media, tts, heartRate, annotations, safetyFindings, plannedDepth, sourceDepths }` with `bool get isLine` (true for temperature, cns, surfaceGf, tankPressure, gtr, sac, tts, heartRate).
  - `const Map<DiveDetailSectionId, List<StripLayer>> kStripLayersByCard` exactly per the spec's table (environment, tissueLoading, tanks, sacSegments, media, decoStatus, health, notes, safetyReview, diveLab, dataSources).
  - `Set<StripLayer> stripLayersFor(Iterable<DiveDetailSectionId> cards)`.

- [ ] **Step 1: Write the failing tests**: `tanks maps to pressure, GTR and gas switches`; `cards with no timeline data map to nothing` (altitude, tide, navTrack, sightings, details give an empty set); `two cards union their layers` (environment + tissueLoading gives {temperature, cns, surfaceGf}); `only line layers are lines` (phases, media, annotations, gasSwitches, safetyFindings, plannedDepth, sourceDepths have `isLine` false).
- [ ] **Step 2: Run** `flutter test test/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_test.dart`; expect compile failure.
- [ ] **Step 3: Implement** the enum, map and function.
- [ ] **Step 4: Run** the test; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): pinned strip layer catalogue`.

### Task 2: Which cards are in view

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_cards_in_view.dart`
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart` (add `const double kPinnedStripGrownHeight = 72;`)
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/layers/strip_cards_in_view_test.dart`

**Interfaces:**
- Produces: `const double kCardInViewMinPx = 96;` and
  `Set<DiveDetailSectionId> cardsInView({required Map<DiveDetailSectionId, Rect> cardsInContent, required double pixels, required double viewportHeight})`.
  A card's on-screen rect is its content rect shifted up by `pixels`; visible span = `min(bottom, viewportHeight) - max(top, kPinnedStripGrownHeight)`; in view when span >= `min(kCardInViewMinPx, rect.height)`.

- [ ] **Step 1: Failing tests**: `card fully below the strip edge is in view`; `card with 95 px below the 72 px edge is not`; `card with 96 px is`; `short card (60 px tall) counts once all of it shows`; `card past the viewport bottom is not`; `card entirely above the edge is not`; `result does not depend on strip height` (same inputs give the same set; the function takes no strip height).
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): decide which cards show below the pinned strip`.

### Task 3: Layer data and its builders

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart` (model)
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_sources.dart` (pure builders)
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_sources_test.dart`

**Interfaces:**
- Produces (model, all `@immutable`, value lists unmodifiable):
  - `StripPoint(int seconds, double value)`.
  - `StripLine({required StripLayer layer, required String key, required Color color, required List<StripPoint> points, required double min, required double max, bool estimated = false, required String label})`. `double? valueAt(int seconds)` interpolates linearly between neighbours, null outside the series.
  - `StripBand({required StripLayer layer, required int start, required int end, required Color color, required double alpha, String? label})`.
  - `StripTick({required StripLayer layer, required int seconds, required Color color, required StripTickEdge edge, bool hollow = false})` with `enum StripTickEdge { top, bottom }`.
  - `StripDot({required int seconds, required double depthMeters})`.
  - `StripGhost({required StripLayer layer, required String key, required String label, required Color color, required List<StripPoint> points})` (value = depth metres).
  - `PinnedStripLayerData({lines, bands, ticks, dots, ghosts})` with `static const empty`, `bool hasData(StripLayer layer)`, `double ghostMaxDepth(Set<StripLayer> layers)`.
- Produces (builder):
  `PinnedStripLayerData buildStripLayerData(StripLayerInputs inputs)`, where `StripLayerInputs` is a record-like class holding: `profile`, `analysis`, `EstimatedTankPressures? tanks`, `List<DiveTank> diveTanks`, `List<GasSwitchWithTank> gasSwitches`, `List<SacSegment>? phases`, `List<PhotoChartMarker> photos`, `List<ProfileEvent> annotations`, `List<ProfileEvent> computerEvents`, `List<SafetyFinding> findings`, `ChartSourceOverlay? plan`, `List<ChartSourceOverlay> otherSources`, and `StripLayerStyle style` (palette, brightness, colorScheme, l10n strings for labels).
  Ranges: TTS and GTR `[0, 3600]` (`ProfileMetricBands.tts/gtr`), surface GF `[0, 150]`, CNS `[0, dive max]`; temperature, SAC, heart rate, pressure: the series' own min and max; all tanks share one pressure range. Index-aligned curves map index to `profile[i].timestamp`; values at indices past `profile.length` are dropped. Each line thinned with `decimateSeriesIndices` to `kPinnedStripPointBudget`. Results cached with an `Expando` on the inputs' source lists, as `pinned_strip_layers.dart` does.
  Colours: lines `palette.colorOf(metric)`; tanks `GasColors.forGasMix(tank.gasMix)`; gas switch ticks `GasColors.forGasMix` of the new tank's mix (bottom edge); phases `SacSegmentColors.forPhase(phase, brightness)`, alpha 0.18; findings `safetySeverityColor(severity, colorScheme)`, alpha 0.22, label `safetyRuleLabel`; annotations ticks top, solid, palette annotation colour; bookmarks top, hollow; ghosts the overlay's own `color`.

- [ ] **Step 1: Failing tests** (each builds inputs by hand):
  `temperature line from profile temperatures`; `no temperature samples gives no temperature line`;
  `cns line ranges 0 to the dive max`; `surface GF ranges 0 to 150`;
  `tank pressure lines share one range and mark estimates` (two tanks, one id in `estimatedTankIds`);
  `gtr line in seconds, 0 to 3600`;
  `gas switch tick at each switch in the new gas colour`;
  `phases become bands with phase colours`;
  `media markers become dots`;
  `only bookmark events become hollow ticks` (a `gasSwitch` event is ignored);
  `findings: dismissed and start-less are skipped, end-less is a tick`;
  `plan and other sources become ghosts; ghostMaxDepth is the deepest ghost`;
  `a curve longer than the profile draws no further than the profile`;
  `hasData is false for a layer with nothing`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** model and builder.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): build the pinned strip's card layers from dive data`.

### Task 4: Strengths, growth and their animation

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_host.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_host_test.dart`

**Interfaces:**
- Consumes: Task 1 `stripLayersFor`, Task 3 `PinnedStripLayerData`.
- Produces:
  - `@immutable class StripLayerState { PinnedStripLayerData data; Map<StripLayer, double> strengths; double grow; double strengthOf(StripLayer l); Set<StripLayer> get active; static const none; }` where `active` is layers whose target is on (card in view and data present).
  - `class PinnedStripLayerHost extends ConsumerStatefulWidget { Dive dive; Set<DiveDetailSectionId> cardsInView; bool settled; Widget Function(BuildContext, StripLayerState) builder; }`. Watches the providers (`watchChartProfile`, `sourceProfileAnalysisProvider`, `watchChartTankSeries`, `gasSwitchesProvider`, `phaseSegmentsProvider`, `mediaForDiveProvider` + `photoMarkersFromMedia`, `diveAnnotationsProvider`, `diveComputerEventsProvider`, `safetyReviewProvider`, `watchPlannedProfileForChart`, `sourceProfilesProvider` minus `activeDiveSourceProvider`) with `.value`, builds data with `buildStripLayerData`. A layer's target is 1 when `settled`, its card is in `cardsInView` and `data.hasData(layer)`. One `AnimationController` per layer (created on first use) and one for grow, 250 ms, `Curves.easeInOut` applied on read; grow target 1 when any active layer `isLine`. With `MediaQuery.disableAnimations` values jump to targets.

- [ ] **Step 1: Failing tests** (ProviderScope overrides feed a dive with temperature samples only):
  `no cards in view: every strength 0 and grow 0`;
  `environment in view while settled fades temperature to 1 over 250 ms` (pump 125 ms: strength strictly between 0 and 1; pump 125 ms more: 1; grow 1);
  `not settled: nothing shows even with the card in view`;
  `card leaves mid-fade: strength reverses from where it was` (pump 100 ms in, change set, next frame value not lower than 0 by a jump, strictly decreasing to 0);
  `media in view with photos: media 1, grow stays 0`;
  `a card whose layer has no data grows nothing` (tanks in view, no tank series);
  `reduce motion applies targets at once`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): fade pinned strip layers with the cards in view`.

### Task 5: Layer painters

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_band_painter.dart`
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_line_painter.dart`
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_marker_painter.dart`
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_painters_test.dart`, `test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter_test.dart`

**Interfaces:**
- Modifies `PinnedStripPainter`: new params `double curveHeight = kPinnedStripHeight` (replaces `_curveAreaHeight`) and `double extraMaxDepthMeters = 0` (own mapping's depth axis runs to `max(profileMax, extraMaxDepthMeters)`); both in `shouldRepaint`.
- Produces: `StripBandPainter({required PinnedStripPainter strip, required StripLayerState layers})`, `StripLinePainter({...same})`, `StripMarkerPainter({...same})`. Each projects through `strip.mappingFor(size)` and clips with `strip.clipFor(size)`. A line maps value v to `rect.bottom - (v - min) / (max - min) * rect.height` (flat series: mid-height); stroke 1.5, estimated lines dashed `[4, 3]`; alpha multiplied by the layer's strength; strength 0 skips the layer. Ghosts: 1 px at 0.45 alpha on the depth mapping. Bands full curve-area height. Ticks 6 px from their edge, 1.5 px wide (hollow: outlined 2.5 px radius circle at the top). Dots radius 3, ringed in `strip.surfaceColor` like the max-depth dot; clustering with `clusterPhotoMarkers` using the mapping's rect. `shouldRepaint` compares mapping inputs, data identity and strengths.

- [ ] **Step 1: Failing tests**: painter tests record canvas calls with a `Canvas` over `PictureRecorder` plus a mock-free check through public helpers: add `@visibleForTesting Offset linePointFor(Size size, StripLine line, StripPoint p)` on `StripLinePainter` and assert: `value at max sits at the curve top`, `value at min at the bottom`, `grown curve area places max at the same top and min 28 px lower`. `PinnedStripPainter: curveHeight 72 maps the deepest point to y 68`; `extraMaxDepthMeters deeper than the profile shrinks the profile's deepest point above the bottom`. `a layer at strength 0 paints nothing` (record picture, compare `Picture` approximate bytes via `toImage` pixel at a line point being transparent).
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** these tests plus the existing `pinned_strip_painter_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): paint the pinned strip's card layers`.

### Task 6: Tooltip rows for active layers

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_tooltip_rows.dart`
- Modify: every `lib/l10n/arb/app_*.arb` (one new key, see below), regenerate.
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_tooltip_rows_test.dart`

**Interfaces:**
- Produces: `List<TooltipRow> stripLayerTooltipRows({required StripLayerState layers, required int cursorSeconds, required UnitFormatter units, required AppLocalizations l10n})`. Rows in `StripLayer` declaration order for layers in `layers.active`: temperature (`diveLog_tooltip_temp`, `units.formatTemperature`), CNS (`diveLog_tooltip_cns`, `%`), surface GF (`diveLog_tooltip_srfGf`, `%`), each tank (its `label`, `units.formatPressure`, with `diveLog_pressure_estimatedSuffix` when estimated), GTR (`diveLog_tooltip_gtr`, minutes as `diveLog_deco_minutesValue`), SAC (`diveLog_legend_label_sacRate`, the full chart's SAC formatting), phase (new key `diveLog_pinnedStrip_phase` = "Phase", value the phase name from the consumption card's strings), TTS (`diveLog_tooltip_tts`, minutes), heart rate (`diveLog_tooltip_hr`, bpm), finding under the cursor (`safetyReview_sectionTitle`, `safetyRuleLabel`), ghosts (`'${diveLog_tooltip_depth} · ${ghost.label}'`, `units.formatDepth`). A line with no value at the cursor is skipped; media, annotations, bookmarks and gas switches add none. Bullet colour = layer colour.

- [ ] **Step 1: Failing tests**: `rows follow active layers only`; `temperature formats in the diver's units` (imperial formatter gives F); `estimated tank row carries the suffix`; `phase row names the phase under the cursor`; `finding row only inside its window`; `ghost rows read depth at the cursor`; `inactive or fading-out layers add no row`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement**; add the ARB key to every locale (English text in untranslated locales follows the repo's l10n convention; check `INDEX_L10N` rules), `flutter gen-l10n`.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): read the active card layers in the pinned strip tooltip`.

### Task 7: The strip draws its layers

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip_test.dart`

**Interfaces:**
- Consumes: Tasks 4 to 6.
- Changes `PinnedProfileStrip` with `StripLayerState layers = StripLayerState.none`. Height when settled: `kPinnedStripHeight + layers.grow * (kPinnedStripGrownHeight - kPinnedStripHeight)`; passes `curveHeight` (same value) and `extraMaxDepthMeters: layers.data.ghostMaxDepth(...)` weighted by ghost strengths (lerp from profile max) to `PinnedStripPainter`; stacks `StripBandPainter` below and `StripLinePainter` + `StripMarkerPainter` above the depth painter (the cursor painter stays on top); appends `stripLayerTooltipRows` to the tooltip rows and semantics value; tooltip room grows from 240 to fit (rows x row height, at least 240).

- [ ] **Step 1: Failing tests**: `settled strip with grow 1 is 72 px tall`; `grow 0.5 is 58 px`; `tooltip shows the temperature row when temperature is active` (cursor set via `profileTrackingIndexProvider`); `semantics value includes the active layer rows`; existing strip tests still pass.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `pinned_profile_strip_test.dart` and `pinned_strip_tooltip_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): draw card layers on the pinned strip`.

### Task 8: Overlay measures marked cards; section list marks them

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/layers/strip_card_marker.dart`
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_overlay.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_overlay_test.dart`, `test/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list_test.dart` (create if missing)

**Interfaces:**
- Produces:
  - `class PinnedStripCardRegistry` with `void register(DiveDetailSectionId id, BuildContext context)`, `void unregister(DiveDetailSectionId id, BuildContext context)` (only if that context is the registered one), `Map<DiveDetailSectionId, Rect> measure(RenderBox overlay, double pixels)` (rects in content coordinates, skipping unattached or sizeless boxes), and a `VoidCallback? onChanged`.
  - `class PinnedStripCardScope extends InheritedWidget { PinnedStripCardRegistry registry; static PinnedStripCardRegistry? maybeOf(BuildContext) }` (no rebuild dependency: `getInheritedWidgetOfExactType`).
  - `class PinnedStripCardMarker extends StatefulWidget { DiveDetailSectionId id; Widget child; }` registering in `didChangeDependencies`, unregistering in `dispose`; registration calls `onChanged`.
- Overlay changes: owns a registry, wraps `widget.child` in `PinnedStripCardScope`, records `_cardsInContent` in `_measure()` (and on `onChanged` via `_scheduleMeasure`), recomputes `cardsInView(...)` (viewport height from `_lastConstraints.maxHeight`) in `_onScroll`/`_onMetrics`/`_measure` and `setState` only when the set changes. Its stack is built inside `PinnedStripLayerHost(dive, cardsInView, settled: handOver >= 1 && morph >= 1, builder: ...)`; `_pinned` takes the `StripLayerState` and uses `stripHeight = kPinnedStripHeight + grow * 28` for `toward`'s bottom; the strip gets `layers`. `condenseProgress`/`condenseFadeEnd` keep `kPinnedStripHeight` (grow is 0 whenever condense < 1, since layers need settled). `ensureVisibleBelowPinnedStrip` uses `kPinnedStripGrownHeight` for `room`.
- Section list: wrap the content in `PinnedStripCardMarker(id: id, ...)` when `kStripLayersByCard.containsKey(id)` at the three places a section is wrapped: the `KeyedSubtree` (line ~197), `_foldSection`'s expanded body only, and each side of `_PairCards`/`ResponsiveSectionPair`.

- [ ] **Step 1: Failing tests**:
  section list: `mapped cards are wrapped in a marker` (environment and tanks), `unmapped cards are not` (buddies), `paired cards are each marked`, `a folded card's header is not marked`.
  overlay: `cards below the pinned strip reach the host` (pump a page with a profile card and two marked 300 px cards, scroll to settle, read `tester.widget<PinnedStripLayerHost>(...).cardsInView`); `scrolling a card above the 72 px edge removes it`; `settled is false while condensing`; `ensureVisibleBelowPinnedStrip leaves 72 px` (update the existing 44 px expectation).
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/dive_log/presentation/widgets/pinned_profile/`, the section list test, `test/features/dive_log/presentation/pages/dive_detail_page*` and `test/architecture/`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): pinned strip follows the cards in view`.

### Task 9: Finish

- [ ] `dart format .`, `flutter analyze` (whole repo), affected tests above, `test/architecture/` and `test/shared/`.
- [ ] After screenshots of the same four screens (environment dark, cylinders dark, consumption light, tissue loading phone), plus one with the cursor showing the extra tooltip rows.
