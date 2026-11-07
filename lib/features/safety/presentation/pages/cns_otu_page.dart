import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_tissue_loading_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_hero_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/otu_limit_progress_row.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/features/safety/domain/entities/cns_otu_snapshot.dart';
import 'package:submersion/features/safety/domain/entities/tissue_load_state.dart';
import 'package:submersion/features/safety/domain/services/cns_otu_live_service.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/domain/services/tissue_live_service.dart';
import 'package:submersion/features/safety/presentation/formatters/cns_otu_format.dart';
import 'package:submersion/features/safety/presentation/providers/cns_otu_providers.dart';
import 'package:submersion/features/safety/presentation/widgets/tissue_load_notes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Current CNS%/OTU load, live-decaying since the diver's most recent dive.
/// Lives in the Planning section, next to "Flying after diving".
class CnsOtuPage extends ConsumerStatefulWidget {
  /// Renders without its own Scaffold and AppBar, for the Planning detail
  /// pane. See [PlanningToolPane].
  final bool embedded;

  const CnsOtuPage({super.key, this.embedded = false});

  @override
  ConsumerState<CnsOtuPage> createState() => _CnsOtuPageState();
}

class _CnsOtuPageState extends ConsumerState<CnsOtuPage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh the live CNS% decay once a minute while the page is open.
    // The snapshot itself (cnsOtuSnapshotProvider) stays cached between dive
    // writes; only the decay math re-runs on each tick, in CnsOtuStatusCard.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshotAsync = ref.watch(cnsOtuSnapshotProvider);
    final units = ref.watch(unitFormatterProvider);
    // The diver's CURRENT conservatism, not whatever the last dive itself
    // was analyzed with: the live tissue readout shows what today's GF
    // settings mean for the residual loading right now.
    final gfLow = ref.watch(gfLowDecimalProvider);
    final gfHigh = ref.watch(gfHighDecimalProvider);

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Only render the clear/active card once we actually have a result.
        // During the very first load or an error with no prior value, show
        // an explicit placeholder instead of silently implying "no load" --
        // misleading for a safety readout. A refresh after data exists keeps
        // the retained value (no flicker). Mirrors NoFlyPage.
        if (snapshotAsync.hasValue)
          CnsOtuStatusCard(
            snapshot: snapshotAsync.value,
            units: units,
            gfLow: gfLow,
            gfHigh: gfHigh,
          )
        else if (snapshotAsync.hasError)
          _CnsOtuStatusPlaceholder(
            icon: Icons.error_outline,
            text: l10n.common_label_error,
          )
        else
          _CnsOtuStatusPlaceholder(
            icon: Icons.hourglass_empty,
            text: l10n.common_label_loading,
          ),
      ],
    );

    if (widget.embedded) {
      return PlanningToolPane(
        title: l10n.safetySettings_cnsOtuHeader,
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetySettings_cnsOtuHeader)),
      body: content,
    );
  }
}

/// The CNS/OTU readout card. Re-derives the live CNS% from [snapshot] on
/// every build, so a parent that rebuilds on a timer (see [CnsOtuPage]) keeps
/// the decay current without re-fetching anything.
class CnsOtuStatusCard extends StatelessWidget {
  final CnsOtuSnapshot? snapshot;
  final UnitFormatter units;

  /// The diver's current gradient factors, for projecting live tissue
  /// loading -- the setting the diver has now, not whatever the last dive
  /// itself was analyzed with.
  final double gfLow;
  final double gfHigh;

  const CnsOtuStatusCard({
    required this.snapshot,
    required this.units,
    required this.gfLow,
    required this.gfHigh,
    super.key,
  });

  /// Below this, CNS% and OTU are shown as "all clear" rather than as a
  /// residual fraction too small to act on.
  static const double _loadEpsilon = 1.0;

  /// How long a profile-less last dive keeps the readout in its warning
  /// state: as long as the dive can still be inside the rolling 7-day OTU
  /// window. Its CNS% has long decayed by then, so after it the unknown
  /// exposure can no longer matter.
  static const Duration _unknownExposureSpan = Duration(days: 7);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final snap = snapshot;

    if (snap == null) {
      return _clearCard(l10n, theme);
    }

    // True instants: CNS%, tissues and the "ended ... ago" line all measure
    // elapsed time. Only daily OTU stays on clock digits, because it belongs
    // to a calendar day rather than a span.
    final now = clock.now().toUtc();
    final elapsed = now.isAfter(snap.lastDiveEnd)
        ? now.difference(snap.lastDiveEnd)
        : Duration.zero;
    final dailyOtu = CnsOtuLiveService.currentOtuDaily(
      dailyOtu: snap.dailyOtu,
      computedAt: snap.computedAt,
      now: NoFlyService.wallClockNowUtc(),
    );

    // Independent of exposure: a gauge-mode or gas-segment-less rebreather
    // dive can have a known exposure but withheld tissue data (see
    // CnsOtuSnapshot.endOfDiveCompartments) -- hence the separate null check
    // rather than reusing `exposure`.
    //
    // Shown in every state, not only while a load remains (issue #4228): a
    // diver checking whether they have desaturated must see the bars back at
    // their surface level markers, not the tissue view simply vanishing. The
    // timeline off-gasses the surface interval in sampled steps (a deco
    // evaluation per sample, re-run on every tick) so CompactTissueLoadingCard
    // can draw its heat map / area chart over that off-gassing the same way
    // it draws one over a dive.
    //
    // The timeline's last entry is the state now (see
    // TissueLiveService.surfaceIntervalTimeline), so the off-gassing runs
    // once, and _TissueTimelineCache keeps it for the rest of the minute:
    // rebuilds in between (the minute tick, theme or provider changes) reuse
    // it instead of re-running every sampled deco evaluation.
    final endOfDiveCompartments = snap.endOfDiveCompartments;
    final tissueTimeline = endOfDiveCompartments != null
        ? _TissueTimelineCache.timeline(
            endOfDiveCompartments: endOfDiveCompartments,
            lastDiveEnd: snap.lastDiveEnd,
            now: now,
            gfLow: gfLow,
            gfHigh: gfHigh,
            environment: snap.surfaceEnvironment,
          )
        : null;
    final lastTissue = tissueTimeline?.last;
    // An empty status has nothing to draw or explain: same as no data.
    final currentTissue =
        lastTissue != null && lastTissue.compartments.isNotEmpty
        ? lastTissue
        : null;
    // One classification for both the "active load" gate below and the
    // "no residual tissue load" note (issue #4228). Gated on magnitude, not a
    // fixed time span: a trivial, shallow dive settles quickly, a deep one
    // reads as still moving for as long as its slow compartments do.
    final tissueState = currentTissue != null
        ? TissueLiveService.classify(currentTissue)
        : null;
    final tissueSection = _TissueSection(
      status: currentTissue,
      timeline: tissueTimeline,
      atSurfaceEquilibrium: tissueState == TissueLoadState.settled,
    );
    final tissueAbout = [
      if (currentTissue != null) ...[
        const SizedBox(height: 8),
        _AboutCard(
          title: l10n.safetyHub_tissueLoading_about_title,
          body: l10n.safetyHub_tissueLoading_about_body,
        ),
      ],
    ];

    final exposure = snap.exposure;
    if (exposure == null) {
      if (elapsed >= _unknownExposureSpan) {
        return _withLastDiveHeader(snap, elapsed, l10n, theme, [
          _clearCard(l10n, theme),
          const SizedBox(height: 8),
          tissueSection,
          ...tissueAbout,
        ]);
      }
      return _withLastDiveHeader(snap, elapsed, l10n, theme, [
        const _NoProfileWarningCard(),
        const SizedBox(height: 8),
        _OtuTotalsCard(dailyOtu: dailyOtu, weeklyOtu: snap.weeklyOtu),
        // Without a profile there is no tissue data either; the warning
        // above already says why, so no second "not available" note.
        if (currentTissue != null) ...[
          const SizedBox(height: 8),
          tissueSection,
          ...tissueAbout,
        ],
      ]);
    }

    final liveCns = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: exposure.cnsEnd,
      lastDiveEnd: snap.lastDiveEnd,
      now: now,
    );

    // A CNS that is only a minimum stays on screen for as long as the unknown
    // dive behind it can matter: a low figure then says nothing about the
    // load, so reading it as "no active load" would claim a recovery nobody
    // knows about.
    final unknownDiveAge = exposure.cnsUnknownDiveAge;
    final cnsMayBeHigher =
        unknownDiveAge != null &&
        unknownDiveAge + elapsed < CnsTable.cnsRecoveryWindow;

    // Tissues that have not settled count as active too -- without this,
    // CNS/OTU decaying below their own epsilons (CNS within ~15h, daily OTU
    // at midnight) would read as "no active load" while the tissues are
    // still loaded, or still visibly moving (refilling with nitrogen after
    // oxygen deco). "No active load" and the "no residual tissue load" note
    // read the same classification, so they appear together.
    final hasActiveLoad =
        liveCns >= _loadEpsilon ||
        cnsMayBeHigher ||
        dailyOtu >= _loadEpsilon ||
        snap.weeklyOtu >= _loadEpsilon ||
        (tissueState != null && tissueState != TissueLoadState.settled);
    if (!hasActiveLoad) {
      return _withLastDiveHeader(snap, elapsed, l10n, theme, [
        _clearCard(l10n, theme),
        const SizedBox(height: 8),
        tissueSection,
        ...tissueAbout,
      ]);
    }

    return _withLastDiveHeader(snap, elapsed, l10n, theme, [
      O2ToxicityCard(
        exposure: exposure,
        units: units,
        // Max ppO2, its depth, and time above threshold are facts about the
        // last dive itself, not the live readout this page is for.
        showDetails: false,
        liveCns: liveCns,
        dailyOtu: dailyOtu,
        weeklyOtu: snap.weeklyOtu,
        showCnsMinimumNote: cnsMayBeHigher,
      ),
      const SizedBox(height: 8),
      tissueSection,
      // Explanations last, below every readout they describe, so they never
      // push the numbers themselves further down the page.
      const SizedBox(height: 8),
      _AboutCard(
        title: l10n.safetyHub_cnsOtu_about_title,
        body: l10n.safetyHub_cnsOtu_about_body,
      ),
      ...tissueAbout,
    ]);
  }

  /// The last dive's hero header and "ended ... ago" line above [children].
  Widget _withLastDiveHeader(
    CnsOtuSnapshot snap,
    Duration elapsed,
    AppLocalizations l10n,
    ThemeData theme,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LastDiveHeader(diveId: snap.lastDiveId, units: units),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            l10n.safetyHub_cnsOtu_sinceLastDive(
              formatTimeSinceLastDive(elapsed, l10n),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _clearCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.air, color: theme.colorScheme.primary),
        title: Text(l10n.safetyHub_cnsOtu_clear_title),
        subtitle: Text(l10n.safetyHub_cnsOtu_clear_subtitle),
      ),
    );
  }
}

/// Keeps the last surface interval timeline for the rest of its minute.
///
/// The page rebuilds every minute (and on theme or provider changes); each
/// timeline is 60 sampled deco evaluations, so a rebuild within the same
/// minute for the same dive and settings reuses the previous one. Keyed on
/// the end-of-dive compartment list by identity, so a new snapshot (a dive
/// written, a test building its own list) never sees a stale entry.
class _TissueTimelineCache {
  _TissueTimelineCache._();

  static List<TissueCompartment>? _compartments;
  static Object? _key;
  static List<DecoStatus>? _timeline;

  static List<DecoStatus> timeline({
    required List<TissueCompartment> endOfDiveCompartments,
    required DateTime lastDiveEnd,
    required DateTime now,
    required double gfLow,
    required double gfHigh,
    required DiveEnvironment environment,
  }) {
    // Whole minutes: the readout updates once a minute anyway, and the
    // truncated instant makes every rebuild in that minute compute the same.
    final minute = DateTime.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch ~/
          Duration.millisecondsPerMinute *
          Duration.millisecondsPerMinute,
      isUtc: true,
    );
    final key = (lastDiveEnd, minute, gfLow, gfHigh, environment);
    final cached = _timeline;
    if (cached != null &&
        identical(_compartments, endOfDiveCompartments) &&
        _key == key) {
      return cached;
    }
    final fresh = TissueLiveService.surfaceIntervalTimeline(
      endOfDiveCompartments: endOfDiveCompartments,
      lastDiveEnd: lastDiveEnd,
      now: minute,
      gfLow: gfLow,
      gfHigh: gfHigh,
      environment: environment,
    );
    _compartments = endOfDiveCompartments;
    _key = key;
    _timeline = fresh;
    return fresh;
  }
}

/// The tissue part of the readout, in every state (issue #4228): the live
/// tissue card, preceded by a "no residual load" note once every compartment
/// is back at surface equilibrium, or a note saying why there is no tissue
/// data at all.
class _TissueSection extends StatelessWidget {
  /// Tissue state now, or null when the last dive carries no tissue data.
  final DecoStatus? status;
  final List<DecoStatus>? timeline;

  /// See [TissueLiveService.isAtSurfaceEquilibrium].
  final bool atSurfaceEquilibrium;

  const _TissueSection({
    required this.status,
    required this.timeline,
    required this.atSurfaceEquilibrium,
  });

  @override
  Widget build(BuildContext context) {
    final current = status;
    if (current == null) return const TissueUnavailableNote();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (atSurfaceEquilibrium) ...[
          const TissueClearNote(),
          const SizedBox(height: 8),
        ],
        CompactTissueLoadingCard(status: current, decoStatuses: timeline),
      ],
    );
  }
}

/// Shown in place of the CNS/OTU card when the last dive has no profile, so
/// its exposure is unknown: the readout must not imply "no load".
class _NoProfileWarningCard extends StatelessWidget {
  const _NoProfileWarningCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.warning_amber_rounded,
          color: colorScheme.onErrorContainer,
        ),
        title: Text(
          l10n.safetyHub_cnsOtu_noProfile_title,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
        subtitle: Text(
          l10n.safetyHub_cnsOtu_noProfile_body,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

/// The OTU totals that are still known when the last dive has no profile:
/// today's and the rolling week's, from the dives that do have one.
class _OtuTotalsCard extends StatelessWidget {
  final double dailyOtu;
  final double weeklyOtu;

  const _OtuTotalsCard({required this.dailyOtu, required this.weeklyOtu});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.diveLog_o2tox_oxygenToleranceUnits,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            OtuLimitProgressRow(
              label: l10n.o2Toxicity_daily,
              value: dailyOtu,
              limit: O2Exposure.dailyOtuLimit,
            ),
            const SizedBox(height: 6),
            OtuLimitProgressRow(
              label: l10n.o2Toxicity_weekly,
              value: weeklyOtu,
              limit: O2Exposure.weeklyOtuLimit,
            ),
          ],
        ),
      ),
    );
  }
}

/// A short plain-language explanation card, same shape as the "About Tissue
/// Loading" card on the Surface Interval Tool page: an info icon, a title,
/// and a body paragraph. Used here so a diver can understand what the
/// numbers above mean (CNS/OTU decay and reset, or tissue off-gassing and
/// counter-diffusion) without leaving the page.
class _AboutCard extends StatelessWidget {
  final String title;
  final String body;

  const _AboutCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.info_outline,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads the dive this readout is projected from and hands it to
/// [DiveHeroHeader]. Renders nothing while loading or on a miss rather
/// than a placeholder -- the CNS/OTU content above it already identifies
/// this as a safety readout; a loading flicker here isn't worth it.
class _LastDiveHeader extends ConsumerWidget {
  final String diveId;
  final UnitFormatter units;

  const _LastDiveHeader({required this.diveId, required this.units});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dive = ref.watch(diveProvider(diveId)).valueOrNull;
    if (dive == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DiveHeroHeader(dive: dive, units: units),
    );
  }
}

/// Neutral placeholder shown while the snapshot is still loading or has
/// failed to load, so the page never implies "no load" before it knows.
class _CnsOtuStatusPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CnsOtuStatusPlaceholder({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(text),
      ),
    );
  }
}
