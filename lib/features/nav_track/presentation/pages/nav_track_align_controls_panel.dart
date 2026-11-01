part of 'nav_track_align_page.dart';

class _ControlsPanel extends ConsumerWidget {
  const _ControlsPanel({
    required this.state,
    required this.route,
    required this.correction,
    required this.hasPostDiveFix,
    required this.activeStart,
    required this.cumulative,
    required this.totalDistance,
    required this.trustedDistance,
  });

  final _NavTrackAlignPageState state;
  final NavTrack route;
  final NavTrackCorrection correction;
  final bool hasPostDiveFix;
  final int activeStart;

  /// The trust slider's distance axis over the active range, as the page
  /// body already computed it for the map's trust marker.
  final List<double> cumulative;
  final double totalDistance;
  final double trustedDistance;

  /// The linked dive's entry fix, watched through the existing
  /// `diveProvider` family rather than re-`read` inside a fresh `Future`
  /// handed to a `FutureBuilder` on every build: `_updateCorrection` calls
  /// `setState` on every drag, slider move and rotation tap, so a
  /// per-build `Future` would be recreated (and re-awaited) constantly.
  /// `ref.watch` instead reads the provider's already-cached value and only
  /// rebuilds this widget when the dive itself actually changes.
  GeoPoint? _diveEntryLocation(WidgetRef ref) {
    final diveId = route.diveId;
    if (diveId == null) return null;
    return ref.watch(diveProvider(diveId)).value?.entryLocation;
  }

  GeoPoint? _siteLocation(WidgetRef ref) {
    final siteId = route.siteId;
    if (siteId == null) return null;
    return ref.watch(siteProvider(siteId)).value?.location;
  }

  /// A start suggestion built from the route's own pre-dive GPS fix, when it
  /// has one (item 3: the segmenter detects a fix event anywhere in the
  /// recording, so a jump before the diver ever descends -- not seen in any
  /// fixture so far, but not hardcoded away either -- is classified exactly
  /// like the far more common post-dive one).
  ///
  /// The ENC CSV never carries an absolute coordinate (see the design spec's
  /// "Ground truth" section), so the pre-dive fix's own position -- even
  /// [NavTrackSegmenter.stabilizedFixPosition]'s better estimate of it -- is
  /// still only a local offset from the recording's origin, not a place on
  /// the map. This suggestion is only available at all because a known
  /// absolute location already exists to anchor that offset against (the
  /// linked dive's entry fix, or the site pin): it back-solves the origin's
  /// map position so that, once placed there, the stabilized fix position
  /// itself lands on that known location -- the same reasoning as "the diver
  /// surfaced roughly where the site pin already says", just applied to the
  /// start instead of the end. Ignores the route's own rotation setting
  /// (rarely non-zero this early in alignment); the diver reviews the result
  /// on the map like any other suggestion.
  GeoPoint? _preDiveFixStartSuggestion(WidgetRef ref) {
    final points = route.points;
    if (points.length < 2) return null;
    // The corrector's own rule, so this never offers a start derived from
    // a fix the correction treats as the end of the route.
    final preDiveFix = NavTrackCorrector.preDiveFixEvent(
      NavTrackSegmenter.classify(points),
    );
    if (preDiveFix == null) return null;

    final reference = _diveEntryLocation(ref) ?? _siteLocation(ref);
    if (reference == null) return null;

    final stabilized = NavTrackSegmenter.stabilizedFixPosition(
      points,
      preDiveFix,
    );
    return offsetToGeoPoint(
      reference,
      east: -stabilized.east,
      north: -stabilized.north,
    );
  }

  /// The Start row's suggestion chips, plus whether the anchor was placed
  /// by hand (crosshair or drag) rather than picked from one of them.
  ///
  /// There is no persisted "which source set this" field --
  /// [NavTrackCorrection.anchor] is just a [GeoPoint] -- so both are
  /// inferred by comparing the live anchor against each known coordinate
  /// source, computed once here (each source is its own classification or
  /// provider read) rather than twice over for the chip list and the
  /// manual-placement check separately.
  ({List<NavTrackPositionOption> options, bool isManual}) _startRow(
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final anchor = correction.anchor;
    final diveEntry = _diveEntryLocation(ref);
    final site = _siteLocation(ref);
    final preDiveFix = _preDiveFixStartSuggestion(ref);
    final options = [
      if (diveEntry != null)
        NavTrackPositionOption(
          key: 'nav-track-align-from-dive-entry',
          label: l10n.navTrack_align_fromDiveEntry,
          selected: _geoPointsMatch(anchor, diveEntry),
          onSelected: () =>
              state._selectChip((c) => c.copyWith(anchor: diveEntry), route),
        ),
      if (site != null)
        NavTrackPositionOption(
          key: 'nav-track-align-from-site',
          label: l10n.navTrack_align_fromSite,
          selected: _geoPointsMatch(anchor, site),
          onSelected: () =>
              state._selectChip((c) => c.copyWith(anchor: site), route),
        ),
      if (preDiveFix != null)
        NavTrackPositionOption(
          key: 'nav-track-align-from-gps',
          label: l10n.navTrack_align_fromGps,
          // _preDiveFixStartSuggestion re-derives this GeoPoint from scratch
          // on every build (offsetToGeoPoint over the same inputs); a
          // tolerance, not ==, keeps the chip selected even if that re-
          // derivation ever lands a floating-point ULP off the value stored
          // on a prior selection, instead of silently un-selecting a choice
          // the diver did not actually change (code review).
          selected: _geoPointsMatch(anchor, preDiveFix),
          onSelected: () =>
              state._selectChip((c) => c.copyWith(anchor: preDiveFix), route),
        ),
    ];
    final isManual = anchor != null && options.every((o) => !o.selected);
    return (options: options, isManual: isManual);
  }

  /// The End row's mode chips: unlike Start, [NavTrackCorrection.endMode]
  /// is an explicit enum, so each chip's selected state reads it directly
  /// instead of comparing coordinates.
  List<NavTrackPositionOption> _endOptions(AppLocalizations l10n) => [
    NavTrackPositionOption(
      key: 'nav-track-align-end-none',
      label: l10n.navTrack_align_endMode_none,
      selected: correction.endMode == NavTrackEndMode.none,
      onSelected: () => state._selectChip(
        (c) => c.copyWith(endMode: NavTrackEndMode.none),
        route,
      ),
    ),
    NavTrackPositionOption(
      key: 'nav-track-align-end-same-as-start',
      label: l10n.navTrack_align_endMode_sameAsStart,
      selected: correction.endMode == NavTrackEndMode.sameAsStart,
      onSelected: () => state._selectChip(
        (c) => c.copyWith(endMode: NavTrackEndMode.sameAsStart),
        route,
      ),
    ),
    if (hasPostDiveFix)
      NavTrackPositionOption(
        key: 'nav-track-align-end-gps-fix',
        label: l10n.navTrack_align_endMode_gpsFix,
        selected: correction.endMode == NavTrackEndMode.gpsFix,
        onSelected: () => state._selectChip(
          (c) => c.copyWith(endMode: NavTrackEndMode.gpsFix),
          route,
        ),
      ),
  ];

  int _trustedDurationSeconds() {
    if (route.points.isEmpty || totalDistance <= 0) return 0;
    final relativeIndex = trustCutoffIndex(cumulative, trustedDistance);
    final index = activeStart + relativeIndex;
    return route.points[index].timestamp - route.points[activeStart].timestamp;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustedMinutes = (_trustedDurationSeconds() / 60).round();
    final l10n = context.l10n;
    final startRow = _startRow(ref, l10n);
    return SafeArea(
      top: false,
      // A visible thumb whenever the cap makes this panel scroll (#3994
      // review): the capped height alone gives no hint that Save/Cancel,
      // below the fold on a short screen, are still reachable by scrolling.
      child: Scrollbar(
        controller: state._panelScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: state._panelScrollController,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NavTrackPositionRowControls(
                  label: l10n.navTrack_align_startLabel,
                  placeKey: 'nav-track-align-place-start',
                  placeLabel: l10n.navTrack_align_setStartOnMap,
                  placeSelected: startRow.isManual,
                  onPlace: () => state._startPlacing(_Placing.start),
                  options: startRow.options,
                ),
                const SizedBox(height: 8),
                NavTrackPositionRowControls(
                  label: l10n.navTrack_align_endLabel,
                  placeKey: 'nav-track-align-place-end',
                  placeLabel: l10n.navTrack_align_endMode_point,
                  placeSelected: correction.endMode == NavTrackEndMode.point,
                  onPlace: () => state._startPlacingEndPoint(route),
                  options: _endOptions(l10n),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.navTrack_align_trustSummary(
                    ref
                        .watch(unitFormatterProvider)
                        .formatDistance(trustedDistance),
                    trustedMinutes,
                  ),
                ),
                Slider(
                  key: const ValueKey('nav-track-align-trust-slider'),
                  value: correction.trustFraction.clamp(0.0, 1.0),
                  onChanged: totalDistance <= 0
                      ? null
                      : (value) => state._updateCorrection(
                          (c) => c.copyWith(trustFraction: value),
                          route,
                        ),
                ),
                NavTrackRotationControl(
                  headingOffsetDeg: correction.headingOffsetDeg,
                  onChanged: (value) => state._updateCorrection(
                    (c) => c.copyWith(headingOffsetDeg: value),
                    route,
                  ),
                ),
                if (state._terrainResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      key: const ValueKey('nav-track-align-terrain-summary'),
                      state._terrainResult!.summaryLine(
                        l10n,
                        formatDepth: ref
                            .watch(unitFormatterProvider)
                            .formatDepth,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      key: const ValueKey('nav-track-align-cancel'),
                      onPressed: () => context.pop(),
                      child: Text(l10n.navTrack_common_cancel),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('nav-track-align-save'),
                      onPressed: () => state._save(route),
                      child: Text(l10n.navTrack_common_save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
