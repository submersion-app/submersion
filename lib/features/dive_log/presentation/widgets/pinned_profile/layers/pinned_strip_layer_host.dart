import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/helpers/source_name_labels.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_annotations_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_normalization.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show ChartSourceOverlay, DiveProfileChart;
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_animator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_input_memo.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_sources.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Reads the dive data behind the pinned strip's card layers and hands the
/// layers, eased in and out with the cards in view, to [builder]
/// (issue #4562).
///
/// While the strip is not [shown] it reads nothing and every layer is
/// hidden: the data is only worth loading for a strip on screen. It builds
/// the same widgets either way, so the page below it, the [builder]'s
/// child, is never moved to a new parent, which would reset its scroll.
class PinnedStripLayerHost extends ConsumerStatefulWidget {
  const PinnedStripLayerHost({
    super.key,
    required this.dive,
    required this.shown,
    required this.settled,
    required this.cardsInView,
    required this.builder,
  });

  final Dive dive;
  final bool shown;
  final bool settled;
  final Set<DiveDetailSectionId> cardsInView;
  final Widget Function(BuildContext context, StripLayerState layers) builder;

  @override
  ConsumerState<PinnedStripLayerHost> createState() =>
      _PinnedStripLayerHostState();
}

class _PinnedStripLayerHostState extends ConsumerState<PinnedStripLayerHost> {
  /// The inputs the data was last built from, and that data: the host
  /// rebuilds on every frame of a fade, and nothing it reads changes then.
  StripLayerInputs? _builtFrom;
  StripLayerStyle? _builtWith;
  PinnedStripLayerData _data = PinnedStripLayerData.empty;

  /// The locale the style's tank names were made in.
  Locale? _styleLocale;

  /// What the inputs derive from the providers, kept while those values
  /// are, so unchanged inputs are the same objects and the data is reused.
  final StripInputMemo _memo = StripInputMemo();

  @override
  Widget build(BuildContext context) {
    if (!widget.shown) {
      return PinnedStripLayerAnimator(
        data: PinnedStripLayerData.empty,
        cardsInView: const {},
        settled: false,
        builder: widget.builder,
      );
    }
    final inputs = _watchInputs();
    final style = _style(context);
    final from = _builtFrom;
    // Rebuilt whenever what it is made of changes, while the strip condenses
    // too: no layer shows until it settles, but the data decides how tall
    // it condenses to, and data from an earlier pass would leave it to grow
    // or shrink again on settling (#4579).
    final stale = from == null || !from.sameAs(inputs) || _builtWith != style;
    if (stale) {
      _builtFrom = inputs;
      _builtWith = style;
      _data = buildStripLayerData(inputs, style);
    }
    return PinnedStripLayerAnimator(
      data: _data,
      cardsInView: widget.cardsInView,
      settled: widget.settled,
      builder: widget.builder,
    );
  }

  /// The style, kept while nothing it is made of changes, so the data is
  /// not rebuilt for an equal one.
  StripLayerStyle _style(BuildContext context) {
    final theme = Theme.of(context);
    final overrides = ref.watch(
      settingsProvider.select((s) => s.profileMetricColors),
    );
    final locale = Localizations.localeOf(context);
    final previous = _builtWith;
    if (previous != null &&
        _styleLocale == locale &&
        previous.palette.overrides == overrides &&
        previous.palette.temperatureAuto == theme.colorScheme.tertiary &&
        previous.brightness == theme.brightness &&
        previous.colorScheme == theme.colorScheme) {
      return previous;
    }
    final l10n = context.l10n;
    _styleLocale = locale;
    return StripLayerStyle(
      palette: ProfileMetricPalette(
        overrides: overrides,
        temperatureAuto: theme.colorScheme.tertiary,
      ),
      brightness: theme.brightness,
      colorScheme: theme.colorScheme,
      // Named as the full chart's tooltip names a tank.
      tankLabel: (tank, index) => DiveProfileChart.tankTooltipLabel(
        tank,
        DiveProfileChart.tankDefaultLabel(l10n, tank, index),
      ),
    );
  }

  StripLayerInputs _watchInputs() {
    final dive = widget.dive;
    final id = dive.id;
    final profile = watchChartProfile(ref, dive);
    final sourceId = ref.watch(activeDiveSourceProvider(id));
    final key = (diveId: id, sourceId: sourceId);
    final media =
        ref.watch(mediaForDiveProvider(id).select((a) => a.value)) ?? const [];
    final review = ref.watch(safetyReviewProvider(id).select((a) => a.value));
    final safety = ref.watch(
      settingsProvider.select(
        (s) => (
          enabled: s.safetyReviewEnabled,
          disabled: s.safetyReviewDisabledRules,
        ),
      ),
    );
    final plan = ref.watch(
      plannedProfileOverlayProvider(id).select((a) => a.value),
    );
    final analysis = ref.watch(
      sourceProfileAnalysisProvider(key).select((a) => a.value),
    );
    return StripLayerInputs(
      profile: profile,
      analysis: analysis,
      sacScale: calculateSacNormalizationFactor(dive, analysis),
      // The chart's tank series, kept while its sources are: without the
      // estimates it is built afresh from the measured series every call.
      tanks: _tankSeries(id),
      diveTanks: dive.tanks,
      gasSwitches:
          ref.watch(gasSwitchesProvider(id).select((a) => a.value)) ?? const [],
      phases: ref.watch(phaseSegmentsProvider(key).select((a) => a.value)),
      media: _mediaMoments(media, profile),
      annotations:
          ref.watch(diveAnnotationsProvider(id).select((a) => a.value)) ??
          const [],
      computerEvents:
          ref.watch(diveComputerEventsProvider(id).select((a) => a.value)) ??
          const [],
      findings: _memo.remember(
        'findings',
        [review, safety.disabled, safety.enabled],
        () => safety.enabled
            ? chartSafetyFindings(review, safety.disabled)
            : const <SafetyFinding>[],
      ),
      plan: _memo.remember('plan', [
        plan,
        context.l10n.diveLog_legend_label_plan,
      ], () => plan?.copyWith(name: context.l10n.diveLog_legend_label_plan)),
      otherSources: _otherSources(id, sourceId),
    );
  }

  /// [watchChartTankSeries], as one object while its sources are.
  EstimatedTankPressures? _tankSeries(String id) {
    final estimated = ref.watch(
      estimatedTankPressuresProvider(id).select((a) => a.value),
    );
    final measured = ref.watch(
      activeSourceTankPressuresProvider(id).select((a) => a.value),
    );
    return _memo.remember('tanks', [
      estimated,
      measured,
    ], () => chartTankSeries(estimated, measured));
  }

  /// The moment and depth of each photo or video placed on the profile,
  /// kept while the media and profile lists are the same objects.
  List<({int seconds, double depthMeters})> _mediaMoments(
    List<MediaItem> media,
    List<DiveProfilePoint> profile,
  ) => _memo.remember('media', [media, profile], () {
    if (profile.isEmpty || media.isEmpty) return const [];
    return List.unmodifiable([
      for (final m in photoMarkersFromMedia(
        media,
        maxProfileSeconds: profile.last.timestamp,
      ))
        (seconds: m.elapsedSeconds, depthMeters: m.depthMeters),
    ]);
  });

  /// The dive's other computers' records of it, as the full chart's source
  /// overlays draw them. Only on a dive two computers recorded together;
  /// the halves of a combined dive are not other records of it.
  List<ChartSourceOverlay> _otherSources(String id, String? activeSourceId) {
    final profiles =
        ref.watch(sourceProfilesProvider(id).select((a) => a.value)) ??
        const <String, SourceProfile>{};
    final sources =
        ref.watch(diveDataSourcesProvider(id).select((a) => a.value)) ??
        const <DiveDataSource>[];
    final labels = sourceNameLabelsFor(context);
    return _memo.remember('otherSources', [
      profiles,
      sources,
      activeSourceId,
      // The locale as text: the memo compares objects by identity.
      Localizations.localeOf(context).toLanguageTag(),
    ], () => _overlaysOf(profiles, sources, activeSourceId, labels));
  }

  List<ChartSourceOverlay> _overlaysOf(
    Map<String, SourceProfile> profiles,
    List<DiveDataSource> sources,
    String? activeSourceId,
    SourceNameLabels labels,
  ) {
    if (!usesPerSourceRendering(sources, profiles.values)) return const [];
    final primary =
        sources.where((s) => s.isPrimary).firstOrNull ?? sources.firstOrNull;
    final active = activeSourceId == null
        ? primary
        : sources.where((s) => s.id == activeSourceId).firstOrNull ?? primary;
    return [
      for (final (index, source) in sources.indexed)
        if (source.id != active?.id && profiles[source.id] != null)
          ChartSourceOverlay(
            sourceId: source.id,
            name: resolveSourceName(
              source,
              labels,
              edited: profiles[source.id]!.isEdited,
            ),
            color: sourceColorAt(index),
            computerId: profiles[source.id]!.computerId,
            points: profiles[source.id]!.points,
          ),
    ];
  }
}
