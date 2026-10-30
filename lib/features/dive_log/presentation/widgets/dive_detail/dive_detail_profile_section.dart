import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_3d/presentation/pages/spatial_site_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/helpers/source_name_labels.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipPresentation;
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_stats_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The parts of a dive the chart subtree draws from.
///
/// Two of these compare equal when every value the chart reads is equal, which
/// is what spares the chart a rebuild when something else about the dive
/// changes: a note, the favorite flag, a tag. Anything [DiveProfileChartHost]
/// or [DiveDetailProfileSection] starts reading from a dive belongs here too,
/// or the chart keeps showing the old value until something else changes.
class DiveChartInputs extends Equatable {
  const DiveChartInputs(this.dive);

  final Dive dive;

  @override
  List<Object?> get props => [
    dive.id,
    dive.profile,
    dive.tanks,
    dive.effectiveRuntime,
    dive.maxDepth,
    dive.sac,
    dive.sacReferenceVolume,
    dive.isRebreather,
  ];
}

/// The Dive Profile card: the chart with its toolbar, sources bar and range
/// statistics.
///
/// Takes the dive's id rather than the dive and reads [DiveChartInputs] itself,
/// so the page can hand it the same widget instance on every rebuild and
/// Flutter skips the subtree. This is the most expensive part of the page, and
/// little that changes on it concerns the chart.
class DiveDetailProfileSection extends ConsumerWidget {
  const DiveDetailProfileSection({
    super.key,
    required this.diveId,
    required this.exportKey,
    required this.onSafetyFindingDetails,
    required this.onSetPrimarySource,
  });

  final String diveId;

  /// Repaint boundary key for "export profile as image".
  final GlobalKey exportKey;

  /// "Show me the details" on a safety finding's callout.
  final VoidCallback onSafetyFindingDetails;

  final void Function(String readingId) onSetPrimarySource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dive = ref
        .watch(
          diveProvider(diveId).select((a) {
            final dive = a.value;
            return dive == null ? null : DiveChartInputs(dive);
          }),
        )
        ?.dive;
    if (dive == null) return const SizedBox.shrink();

    // Every async chart input below is read through the built-in
    // AsyncValue.value, which keeps the previous value while a provider
    // reloads. The valueOrNull polyfill returns null during a reload, and
    // these providers reload behind any detail change tick (the first-view
    // safety review write included): the chart would drop its overlays and
    // estimated pressure series for a frame, then draw them again.

    // Get range selection state
    final rangeState = ref.watch(rangeSelectionProvider(dive.id));

    // Profiles grouped by owning data source, plus the active-source and
    // overlay view state driving the whole page.
    final sourceProfiles =
        ref.watch(sourceProfilesProvider(dive.id)).value ??
        const <String, SourceProfile>{};
    final dataSources =
        ref.watch(diveDataSourcesProvider(dive.id)).value ?? const [];
    final labels = sourceNameLabelsFor(context);
    // Per-source rendering exists because two computers recording one dive
    // disagree sample by sample (#543); the halves of a split dive a Combine
    // stitched together are not that, and drawing one of those would hide the
    // rest of the dive (#1451). Profiles that have not loaded yet carry no
    // spans, so this stays true on the first build, exactly as it does today.
    final isMultiSource = usesPerSourceRendering(
      dataSources,
      sourceProfiles.values,
    );

    final activeSourceId = ref.watch(activeDiveSourceProvider(dive.id));
    final overlayIds = ref.watch(overlaySourcesProvider(dive.id));

    final primarySource =
        dataSources.where((s) => s.isPrimary).firstOrNull ??
        dataSources.firstOrNull;
    final activeSource = activeSourceId == null
        ? primarySource
        : dataSources.where((s) => s.id == activeSourceId).firstOrNull ??
              primarySource;

    // Stable color per source, assigned by data-source order (never changes
    // as overlays toggle).
    final sourceColorById = <String, Color>{
      for (final (index, s) in dataSources.indexed) s.id: sourceColorAt(index),
    };

    // The series the chart draws, resolved by the same one rule the chart
    // itself uses (#543): the active source's own points on a multi-source
    // dive, dive.profile otherwise. The point count, the playback stats and
    // the range panel below all index it, so they must read the same series
    // the curve was drawn from.
    final chartProfile =
        ref.watch(activeSourceProfileProvider(dive.id))?.points ?? dive.profile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.diveLog_detail_section_diveProfile,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    // A toggle, so it reads as one of the row's icons with
                    // an on state rather than a pill that shoulders them
                    // aside. The label it used to carry is the tooltip.
                    IconButton(
                      icon: const Icon(Icons.straighten),
                      tooltip: context.l10n.diveLog_detail_button_rangeAnalysis,
                      visualDensity: VisualDensity.compact,
                      isSelected: rangeState.isEnabled,
                      style: IconButton.styleFrom(
                        backgroundColor: rangeState.isEnabled
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                        foregroundColor: rangeState.isEnabled
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : null,
                      ),
                      onPressed: () {
                        final notifier = ref.read(
                          rangeSelectionProvider(dive.id).notifier,
                        );
                        rangeState.isEnabled
                            ? notifier.disableRangeMode()
                            : notifier.enableRangeMode();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.view_in_ar),
                      tooltip: context.l10n.dive3d_previewTitle,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Dive3dPage(diveId: dive.id),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.terrain),
                      tooltip: context.l10n.dive3d_spatial_title,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SpatialSitePage(diveId: dive.id),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      tooltip:
                          context.l10n.diveLog_detail_tooltip_viewFullscreen,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showFullscreenProfile(context, dive),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Chart with optional range selection overlay
            DiveProfileChartHost(
              dive: dive,
              exportKey: exportKey,
              onSafetyFindingDetails: (_) => onSafetyFindingDetails(),
              // fl_chart's own tooltip bubble (issue #2228 follow-up): this
              // is the exact pre-#2228 presentation for the embedded chart,
              // positioned above the chart box by fl_chart itself rather
              // than by the custom ProfileCursorTooltip used elsewhere.
              // Restored after the custom in-chart tooltip's own upward-
              // growth approximation still did not land in the same place.
              tooltipPresentation: TooltipPresentation.nativeBubble,
            ),
            // Profile point count (bottom-right, inline with x-axis)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.l10n.diveLog_detail_profilePoints(chartProfile.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Sources bar: tap a chip to make that source drive the whole
            // page; the eye overlays a source on the chart for comparison.
            // Both of those are per-source RENDERING, which is why the bar
            // follows usesPerSourceRendering rather than the source count:
            // on a dive whose sources are consecutive halves there is no
            // "other source" to switch to or overlay, only the rest of the
            // same dive. Set primary does not disappear with it: the Data
            // Sources section carries its own copy, gated on the source
            // count alone. Split lives only there (data_sources_section.dart).
            if (isMultiSource)
              SourceBar(
                sources: [
                  for (final s in dataSources)
                    SourceBarItem(
                      sourceId: s.id,
                      label: resolveSourceName(
                        s,
                        labels,
                        edited: sourceProfiles[s.id]?.isEdited ?? false,
                      ),
                      color: sourceColorById[s.id] ?? sourceColorAt(0),
                      isActive: s.id == activeSource?.id,
                      isPrimary: s.isPrimary,
                      isOverlaid: overlayIds.contains(s.id),
                      hasProfile:
                          sourceProfiles[s.id]?.points.isNotEmpty ?? false,
                    ),
                ],
                onActivate: (id) {
                  ref.read(activeDiveSourceProvider(dive.id).notifier).state =
                      id;
                  final current = ref.read(overlaySourcesProvider(dive.id));
                  if (current.contains(id)) {
                    ref.read(overlaySourcesProvider(dive.id).notifier).state = {
                      ...current,
                    }..remove(id);
                  }
                },
                onToggleOverlay: (id, overlaid) {
                  final current = ref.read(overlaySourcesProvider(dive.id));
                  ref.read(overlaySourcesProvider(dive.id).notifier).state =
                      overlaid ? {...current, id} : ({...current}..remove(id));
                },
                onSetPrimary: onSetPrimarySource,
              ),
            // Range stats panel (when range mode is active)
            if (rangeState.isEnabled && rangeState.hasSelection) ...[
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) => RangeStatsPanel(
                  diveId: dive.id,
                  profile: chartProfile,
                  units: UnitFormatter(ref.watch(settingsProvider)),
                  tanks: dive.tanks,
                  isRebreather: dive.isRebreather,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullscreenProfile(BuildContext context, Dive dive) {
    // Root navigator, not the ShellRoute's: pushing on the shell navigator
    // renders the page inside MainScaffold, leaving the bottom navigation
    // bar painted under a supposedly fullscreen chart (#811).
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => FullscreenProfilePage(diveId: dive.id),
      ),
    );
  }
}
