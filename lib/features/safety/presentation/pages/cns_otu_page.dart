import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_hero_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/otu_limit_progress_row.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/features/safety/domain/entities/cns_otu_snapshot.dart';
import 'package:submersion/features/safety/domain/services/cns_otu_live_service.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/formatters/cns_otu_format.dart';
import 'package:submersion/features/safety/presentation/providers/cns_otu_providers.dart';
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
    final units = UnitFormatter(ref.watch(settingsProvider));

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Only render the clear/active card once we actually have a result.
        // During the very first load or an error with no prior value, show
        // an explicit placeholder instead of silently implying "no load" --
        // misleading for a safety readout. A refresh after data exists keeps
        // the retained value (no flicker). Mirrors NoFlyPage.
        if (snapshotAsync.hasValue)
          CnsOtuStatusCard(snapshot: snapshotAsync.value, units: units)
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

  const CnsOtuStatusCard({
    required this.snapshot,
    required this.units,
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

    final now = NoFlyService.wallClockNowUtc();
    final elapsed = now.isAfter(snap.lastDiveEnd)
        ? now.difference(snap.lastDiveEnd)
        : Duration.zero;
    final dailyOtu = CnsOtuLiveService.currentOtuDaily(
      dailyOtu: snap.dailyOtu,
      computedAt: snap.computedAt,
      now: now,
    );

    final exposure = snap.exposure;
    if (exposure == null) {
      if (elapsed >= _unknownExposureSpan) return _clearCard(l10n, theme);
      return _withLastDiveHeader(snap, elapsed, l10n, theme, [
        const _NoProfileWarningCard(),
        const SizedBox(height: 8),
        _OtuTotalsCard(dailyOtu: dailyOtu, weeklyOtu: snap.weeklyOtu),
      ]);
    }

    final liveCns = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: exposure.cnsEnd,
      lastDiveEnd: snap.lastDiveEnd,
      now: now,
    );

    final hasActiveLoad =
        liveCns >= _loadEpsilon ||
        dailyOtu >= _loadEpsilon ||
        snap.weeklyOtu >= _loadEpsilon;
    if (!hasActiveLoad) {
      return _clearCard(l10n, theme);
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
      ),
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
