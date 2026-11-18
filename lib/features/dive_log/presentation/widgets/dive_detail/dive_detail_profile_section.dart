import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_3d/presentation/pages/spatial_site_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/helpers/source_name_labels.dart';
import 'package:submersion/features/dive_log/presentation/info/dive_profile_info.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/outlier_suggestion_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipPresentation;
import 'package:submersion/features/dive_log/presentation/providers/annotation_placement_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_placement_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_annotation_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_stats_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/annotation_edits.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_safety_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

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
    // Equatable stops at the first difference, so the samples, by far the
    // costliest to compare, go last.
    dive.id,
    // The entry places Apple Health heart rate on the timeline (issue #637).
    dive.entryTime,
    dive.dateTime,
    dive.effectiveRuntime,
    dive.maxDepth,
    dive.sac,
    dive.sacReferenceVolume,
    dive.isRebreather,
    dive.diluentGas,
    dive.environment,
    dive.tanks,
    dive.profile,
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
    this.onOpenInNotes,
    this.fillHeight = false,
    this.onPlotFrame,
    this.viewport,
    this.onViewportChanged,
    this.editing,
    this.onEditProfile,
    this.onEditOutliers,
  });

  /// This section with the same inputs, the page's zoom among them, drawn
  /// as the open Profile card's editor over [session]. [exportKey] is the
  /// editor's own, kept across its rebuilds: the page's stays with the
  /// read card it marks.
  DiveDetailProfileSection editingIn(
    EditSession<Dive> session, {
    required GlobalKey exportKey,
  }) => DiveDetailProfileSection(
    diveId: diveId,
    exportKey: exportKey,
    onSafetyFindingDetails: onSafetyFindingDetails,
    onSetPrimarySource: onSetPrimarySource,
    onOpenInNotes: onOpenInNotes,
    fillHeight: fillHeight,
    viewport: viewport,
    onViewportChanged: onViewportChanged,
    editing: session,
    onEditProfile: onEditProfile,
    onEditOutliers: onEditOutliers,
  );

  final String diveId;

  /// The open Profile card's sitting (issue #4527): annotations placed,
  /// moved and removed go there, held until Save, and the card draws bare,
  /// inside the open card's frame. Null everywhere else: on a page that
  /// offers editing the chart then writes nothing, locked or in a sitting,
  /// and draws the sitting's annotations and gas switches during one.
  final EditSession<Dive>? editing;

  /// Fill the height the card is given, the chart taking up the slack: the
  /// pinned copy is laid out shorter and shorter as the card scrolls away,
  /// squashing its chart (#4423).
  final bool fillHeight;

  /// Told where the chart's plot is, for the pinned copy's hand-over to the
  /// strip.
  final ValueChanged<ProfilePlotFrame>? onPlotFrame;

  /// The zoom window the chart shows, set from outside: the pinned copy's,
  /// easing out from the full card's (#4423).
  final ChartViewport? viewport;

  /// Told the chart's zoom window whenever the reader zooms or pans it, so
  /// the pinned copy can start from it.
  final ValueChanged<ChartViewport>? onViewportChanged;

  /// "Open in Notes" on an annotation's popup (#4109): scrolls to the Notes
  /// card and highlights the passage.
  final ValueChanged<String>? onOpenInNotes;

  /// Repaint boundary key for "export profile as image".
  final GlobalKey exportKey;

  /// "Show me the details" on a safety finding's callout.
  final VoidCallback onSafetyFindingDetails;

  final void Function(String readingId) onSetPrimarySource;

  /// Opens the profile editor, which saves on its own page: a whole-record
  /// operation on a page that offers editing (issue #4527). Null leaves the
  /// toolbar without it (no editing offered, or the pinned copy).
  final VoidCallback? onEditProfile;

  /// Opens the profile editor in Outlier mode: the same operation as
  /// [onEditProfile], offered beside it when the profile has outliers
  /// (issue #4527, plan 11). Null leaves the toolbar without it.
  final VoidCallback? onEditOutliers;

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
    final editing = this.editing;
    if (editing == null) return _build(context, ref, dive, editing: null);
    // The open card follows its sitting as annotations are placed.
    return ListenableBuilder(
      listenable: editing,
      builder: (context, _) => _build(context, ref, dive, editing: editing),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    Dive dive, {
    required EditSession<Dive>? editing,
  }) {
    final scope = RecordEditScope.maybeOf<Dive>(context);
    final session = editing ?? scope?.session;
    // The profile is changed in the open card only (issue #4527), and its
    // annotations only once the sitting holds them: until then (or after a
    // failed read) a pin, a move or a removal would go nowhere.
    final annotationsReadOnly =
        editing == null || sittingAnnotations(editing) == null;
    final annotationActions = DiveDetailAnnotationActions(
      ref: ref,
      context: context,
      dive: dive,
      onOpenInNotes: onOpenInNotes,
      edits: editing == null ? null : SittingAnnotationEdits(editing),
      readOnly: annotationsReadOnly,
    );
    final placement = ref.watch(annotationPlacementProvider(dive.id));
    final annotationsInSitting =
        session != null && sittingAnnotations(session) != null
        ? sittingAnnotationEvents(session)
        : null;
    final gasSwitchesInSitting = session == null
        ? null
        : sittingGasSwitchesWithTanks(session);
    void openScene(_ProfileScene scene) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => switch (scene) {
          _ProfileScene.dive => Dive3dPage(diveId: dive.id),
          _ProfileScene.site => SpatialSitePage(diveId: dive.id),
        },
      ),
    );
    // On a card too narrow for every button (a 360 or 375 px phone), the
    // two 3D scenes share one More menu, so the title and the pencil keep
    // their place.
    Widget toolbar({required bool narrow}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RangeToggle(diveId: dive.id),
        if (!annotationsReadOnly)
          AnnotationPinButton(
            active: placement != null,
            onPressed: annotationActions.onPinPressed,
          ),
        if (narrow)
          _ProfileScenesMenu(onSelected: openScene)
        else ...[
          IconButton(
            icon: const Icon(Icons.view_in_ar),
            tooltip: context.l10n.dive3d_previewTitle,
            visualDensity: VisualDensity.compact,
            onPressed: () => openScene(_ProfileScene.dive),
          ),
          IconButton(
            icon: const Icon(Icons.terrain),
            tooltip: context.l10n.dive3d_spatial_title,
            visualDensity: VisualDensity.compact,
            onPressed: () => openScene(_ProfileScene.site),
          ),
        ],
        if (onEditProfile case final onEditProfile?)
          _EditProfileButton(scope: scope, onPressed: onEditProfile),
        if (onEditOutliers case final onEditOutliers?)
          _OutliersButton(
            diveId: diveId,
            scope: scope,
            onPressed: onEditOutliers,
          ),
        IconButton(
          icon: const Icon(Icons.fullscreen),
          tooltip: context.l10n.diveLog_detail_tooltip_viewFullscreen,
          visualDensity: VisualDensity.compact,
          onPressed: () => _showFullscreenProfile(context),
        ),
        HeaderInfoButton(
          title: context.l10n.diveLog_detail_section_diveProfile,
          height: 40,
          width: 40,
          content: diveProfileInfoFor,
        ),
      ],
    );

    // What follows a provider around the chart watches it in a widget of its
    // own. A watch here would hand the chart a new host each time it fired,
    // whatever the host's own narrowed reads decided.
    Widget card(Widget child) => editing != null
        ? child
        : Card(
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          );
    return ProfileLegendSnapshotScope(
      child: card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Header row: the open card's frame draws the title above an
            // editor, so the toolbar alone; otherwise the title, which
            // gains its pencil while the dive is unlocked.
            LayoutBuilder(
              builder: (context, constraints) {
                final bar = toolbar(
                  narrow: constraints.maxWidth < _fullToolbarMinWidth,
                );
                return editing != null
                    ? Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: bar,
                      )
                    : RecordCardHeader(
                        title: context.l10n.diveLog_detail_section_diveProfile,
                        trailing: bar,
                      );
              },
            ),
            const SizedBox(height: 8),
            if (placement != null) ...[
              AnnotationPlacementBanner(
                moving: placement.isMove,
                onCancel: ref
                    .read(annotationPlacementProvider(dive.id).notifier)
                    .cancel,
              ),
              const SizedBox(height: 8),
            ],
            // Chart with optional range selection overlay
            _fill(
              DiveProfileChartHost(
                dive: dive,
                exportKey: exportKey,
                onPlotFrame: onPlotFrame,
                viewport: viewport,
                onViewportChanged: onViewportChanged,
                annotationActions: annotationActions,
                // Findings are dismissed in the open Safety review card.
                findingsDismissable: false,
                annotationsInSitting: annotationsInSitting,
                gasSwitchesInSitting: gasSwitchesInSitting,
                safetyReviewInSitting: session == null
                    ? null
                    : (stored) => reviewInSitting(session, stored),
                onSafetyFindingDetails: (_) => onSafetyFindingDetails(),
                // fl_chart's own tooltip bubble (issue #2228 follow-up): this
                // is the exact pre-#2228 presentation for the embedded chart,
                // positioned above the chart box by fl_chart itself rather
                // than by the custom ProfileCursorTooltip used elsewhere.
                // Restored after the custom in-chart tooltip's own upward-
                // growth approximation still did not land in the same place.
                tooltipPresentation: TooltipPresentation.nativeBubble,
              ),
            ),
            _ProfilePointCount(dive: dive),
            _ProfileSourceBar(
              diveId: dive.id,
              onSetPrimarySource: onSetPrimarySource,
            ),
            _ProfileRangeStats(dive: dive),
          ],
        ),
      ),
    );
  }

  /// In [fillHeight] mode the chart takes whatever height the rest of the
  /// card leaves; the chart fills a bounded height, so it squashes.
  Widget _fill(Widget chart) => fillHeight ? Expanded(child: chart) : chart;

  void _showFullscreenProfile(BuildContext context) {
    // Root navigator, not the ShellRoute's: pushing on the shell navigator
    // renders the page inside MainScaffold, leaving the bottom navigation
    // bar painted under a supposedly fullscreen chart (#811).
    // The fullscreen page edits only the open Profile card's sitting, and
    // otherwise reads (issue #4527).
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => FullscreenProfilePage(
          diveId: diveId,
          onOpenInNotes: onOpenInNotes,
          session: editing,
        ),
      ),
    );
  }
}

/// The toolbar's range analysis toggle.
class _RangeToggle extends ConsumerWidget {
  const _RangeToggle({required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeState = ref.watch(rangeSelectionProvider(diveId));
    // A toggle, so it reads as one of the row's icons with an on state rather
    // than a pill that shoulders them aside. The label it used to carry is the
    // tooltip.
    return IconButton(
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
        final notifier = ref.read(rangeSelectionProvider(diveId).notifier);
        rangeState.isEnabled
            ? notifier.disableRangeMode()
            : notifier.enableRangeMode();
      },
    );
  }
}

/// Profile point count (bottom-right, inline with x-axis)
class _ProfilePointCount extends ConsumerWidget {
  const _ProfilePointCount({required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartProfile = watchChartProfile(ref, dive);
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        context.l10n.diveLog_detail_profilePoints(chartProfile.length),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Sources bar: tap a chip to make that source drive the whole page; the eye
/// overlays a source on the chart for comparison. Both of those are per-source
/// RENDERING, which is why the bar follows usesPerSourceRendering rather than
/// the source count: on a dive whose sources are consecutive halves there is
/// no "other source" to switch to or overlay, only the rest of the same dive.
/// Set primary does not disappear with it: the Data Sources section carries
/// its own copy, gated on the source count alone. Split lives only there
/// (data_sources_section.dart).
class _ProfileSourceBar extends ConsumerWidget {
  const _ProfileSourceBar({
    required this.diveId,
    required this.onSetPrimarySource,
  });

  final String diveId;
  final void Function(String readingId) onSetPrimarySource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read through the built-in AsyncValue.value, which keeps the previous
    // value while a provider reloads. The valueOrNull polyfill returns null
    // during a reload, and these providers reload behind any detail change
    // tick (the first-view safety review write included): the bar would drop
    // out for a frame, then come back (#1468).
    final sourceProfiles =
        ref.watch(sourceProfilesProvider(diveId).select((a) => a.value)) ??
        const <String, SourceProfile>{};
    final dataSources =
        ref.watch(diveDataSourcesProvider(diveId).select((a) => a.value)) ??
        const [];
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
    if (!isMultiSource) return const SizedBox.shrink();

    final activeSourceId = ref.watch(activeDiveSourceProvider(diveId));
    final overlayIds = ref.watch(overlaySourcesProvider(diveId));

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

    return SourceBar(
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
            hasProfile: sourceProfiles[s.id]?.points.isNotEmpty ?? false,
          ),
      ],
      onActivate: (id) {
        ref.read(activeDiveSourceProvider(diveId).notifier).state = id;
        final current = ref.read(overlaySourcesProvider(diveId));
        if (current.contains(id)) {
          ref.read(overlaySourcesProvider(diveId).notifier).state = {...current}
            ..remove(id);
        }
      },
      onToggleOverlay: (id, overlaid) {
        final current = ref.read(overlaySourcesProvider(diveId));
        ref.read(overlaySourcesProvider(diveId).notifier).state = overlaid
            ? {...current, id}
            : ({...current}..remove(id));
      },
      onSetPrimary: onSetPrimarySource,
      // Set as primary acts on the whole dive at once (issue #4527).
      operationReason: recordOperationReason(
        context.l10n,
        recordOperationBlockOf(RecordEditScope.maybeOf<Dive>(context)),
      ),
    );
  }
}

/// Range stats panel (when range mode is active)
class _ProfileRangeStats extends ConsumerWidget {
  const _ProfileRangeStats({required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeState = ref.watch(rangeSelectionProvider(dive.id));
    if (!rangeState.isEnabled || !rangeState.hasSelection) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        RangeStatsPanel(
          diveId: dive.id,
          profile: watchChartProfile(ref, dive),
          units: ref.watch(unitFormatterProvider),
          tanks: dive.tanks,
          isRebreather: dive.isRebreather,
          environment: dive.environment,
        ),
      ],
    );
  }
}

/// Edit profile on the Profile card's toolbar (issue #4527): a whole-record
/// operation, so while it is unavailable its one tooltip says why, rather
/// than a second tooltip competing with the button's own label.
class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({required this.scope, required this.onPressed});

  final RecordEditController<Dive>? scope;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reason = recordOperationReason(
      context.l10n,
      recordOperationBlockOf(scope),
    );
    return IconButton(
      icon: const Icon(Icons.edit_note),
      tooltip: reason ?? context.l10n.diveLog_profile_editProfile,
      visualDensity: VisualDensity.compact,
      onPressed: reason == null ? onPressed : null,
    );
  }
}

/// The profile's outliers, when it has any: a warning with their count,
/// opening the profile editor in Outlier mode. A whole-record operation,
/// so it follows the page's lock as Edit profile does. Watches the
/// detection on its own, so the card does not rebuild with it.
class _OutliersButton extends ConsumerWidget {
  const _OutliersButton({
    required this.diveId,
    required this.scope,
    required this.onPressed,
  });

  final String diveId;
  final RecordEditController<Dive>? scope;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outliers =
        ref.watch(outlierSuggestionProvider(diveId)).value ?? const [];
    if (outliers.isEmpty) return const SizedBox.shrink();
    final reason = recordOperationReason(
      context.l10n,
      recordOperationBlockOf(scope),
    );
    return IconButton(
      icon: Badge(
        label: Text('${outliers.length}'),
        child: const Icon(Icons.warning_amber),
      ),
      tooltip:
          reason ?? context.l10n.diveLog_edit_profile_outliers(outliers.length),
      visualDensity: VisualDensity.compact,
      onPressed: reason == null ? onPressed : null,
    );
  }
}

/// The narrowest header row that holds the Profile card's full toolbar
/// beside its title and, while unlocked, the pencil. Measured: a 375 px
/// phone's 311 px row overflowed with the outliers button showing, a 393 px
/// phone's 329 px row did not.
const double _fullToolbarMinWidth = 328;

/// The Profile card's two 3D scenes.
enum _ProfileScene { dive, site }

/// The 3D scenes as one More menu, for a card too narrow for their buttons.
class _ProfileScenesMenu extends StatelessWidget {
  const _ProfileScenesMenu({required this.onSelected});

  final ValueChanged<_ProfileScene> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    PopupMenuItem<_ProfileScene> item(
      _ProfileScene scene,
      IconData icon,
      String label,
    ) => PopupMenuItem(
      value: scene,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        contentPadding: EdgeInsets.zero,
      ),
    );
    return PopupMenuButton<_ProfileScene>(
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.common_action_more,
      style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
      onSelected: onSelected,
      itemBuilder: (context) => [
        item(_ProfileScene.dive, Icons.view_in_ar, l10n.dive3d_previewTitle),
        item(_ProfileScene.site, Icons.terrain, l10n.dive3d_spatial_title),
      ],
    );
  }
}
