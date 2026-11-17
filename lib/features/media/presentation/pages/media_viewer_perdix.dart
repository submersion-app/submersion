part of 'media_viewer_page.dart';

/// The dive computer face's data for the item on screen.
extension _ViewerPerdix on _MediaViewerPageState {
  /// Same source-aware profile/analysis pairing as the fullscreen
  /// profile page: analysis curves are read by index, so the profile
  /// passed to the resolver must be the one the analysis was computed
  /// over (multi-computer dives).
  ///
  /// Built ONLY when the face can actually render: a dive-linked,
  /// profile-synced item with the overlay turned on. The watches
  /// below start the per-source profile analysis, and through it the
  /// full Buhlmann pipeline with its recursive residual-CNS/tissue
  /// lookback across the surrounding dives. Watching that
  /// unconditionally ran the whole cascade on the UI isolate for
  /// every dive-linked item the viewer showed, with the result
  /// discarded whenever the overlay was off -- the first ingredient
  /// of the app-wide freeze after viewing media (2026-08 hang
  /// reports). Toggling the overlay on simply rebuilds and starts the
  /// watches then.
  PerdixFaceResolver _perdixResolverFor(String currentDiveId, Dive? dive) {
    final activeSourceId = ref.watch(activeDiveSourceProvider(currentDiveId));
    final analysis = ref
        .watch(
          sourceProfileAnalysisProvider((
            diveId: currentDiveId,
            sourceId: activeSourceId,
          )),
        )
        .value;
    final sourceProfiles =
        ref.watch(sourceProfilesProvider(currentDiveId)).value ?? const {};
    final dataSources =
        ref.watch(diveDataSourcesProvider(currentDiveId)).value ?? const [];
    final gasSwitches =
        ref.watch(gasSwitchesProvider(currentDiveId)).value ?? const [];
    final tankPressures = ref
        .watch(activeSourceTankPressuresProvider(currentDiveId))
        .value;
    final primarySource =
        dataSources.where((s) => s.isPrimary).firstOrNull ??
        dataSources.firstOrNull;
    final activeSource = activeSourceId == null
        ? primarySource
        : dataSources.where((s) => s.id == activeSourceId).firstOrNull ??
              primarySource;
    final activeProfile = activeSource == null
        ? null
        : sourceProfiles[activeSource.id];
    // Sources that never overlap in time are consecutive halves of
    // one dive a Combine stitched together, not alternative
    // recordings of it: the face reads the whole dive, not the
    // active half (#1451). Mirrors the detail and fullscreen pages.
    final isMultiSource = usesPerSourceRendering(
      dataSources,
      sourceProfiles.values,
    );
    final drawsActiveSource = isMultiSource && activeProfile != null;
    final perdixProfile = drawsActiveSource
        ? activeProfile.points
        : dive?.profile ?? const [];
    // Rebuilt only on page-level setState (page swipes, toggles),
    // not per video frame; prefix-max and gas segments precompute
    // here. The gas and cylinder come from the drawn source's own
    // switches, as on the chart's gas strip: another computer's
    // record of a switch must not move this one's gas (#4300).
    return dive == null
        ? PerdixFaceResolver(
            profile: perdixProfile,
            analysis: analysis,
            tankPressures: tankPressures,
          )
        : PerdixFaceResolver.forSource(
            dive,
            profile: perdixProfile,
            analysis: analysis,
            gasSwitches: gasSwitches,
            tankPressures: tankPressures,
            computerId: drawsActiveSource ? activeProfile.computerId : null,
          );
  }
}
