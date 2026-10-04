import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_toxicity_card.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/features/safety/domain/entities/cns_otu_snapshot.dart';
import 'package:submersion/features/safety/domain/services/cns_otu_live_service.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/formatters/no_fly_format.dart';
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
class CnsOtuStatusCard extends ConsumerWidget {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final snap = snapshot;

    if (snap == null) {
      return _clearCard(l10n, theme);
    }

    final now = NoFlyService.wallClockNowUtc();
    final liveCns = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: snap.cnsAtDiveEnd,
      lastDiveEnd: snap.lastDiveEnd,
      now: now,
    );
    final otuDaily = snap.exposure.otuDaily;

    final hasActiveLoad =
        liveCns >= _loadEpsilon ||
        otuDaily >= _loadEpsilon ||
        snap.weeklyOtu >= _loadEpsilon;
    if (!hasActiveLoad) {
      return _clearCard(l10n, theme);
    }

    final elapsed = now.isAfter(snap.lastDiveEnd)
        ? now.difference(snap.lastDiveEnd)
        : Duration.zero;
    final liveExposure = snap.exposure.copyWith(cnsEnd: liveCns);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LastDiveSummaryRow(diveId: snap.lastDiveId),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            l10n.safetyHub_cnsOtu_sinceLastDive(formatNoFlyRemaining(elapsed)),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        O2ToxicityCard(
          exposure: liveExposure,
          units: units,
          weeklyOtu: snap.weeklyOtu,
          // Max ppO2, its depth, and time above threshold are facts about
          // the last dive itself, not the live readout this page is for.
          showDetails: false,
          // "This dive" implied one was in progress; "last dive" is what
          // these two rows actually are.
          isLiveSinceLastDive: true,
        ),
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

/// Compact identification of which dive this readout is projected from:
/// number badge, name/site, and when it happened. Deliberately a small,
/// purpose-built row rather than reusing DiveDetailPage's embedded header --
/// that one also carries dive-to-dive navigation, a favorite toggle and a
/// "log for buddy" action, none of which belong on a safety readout that
/// is not browsing the dive itself.
class _LastDiveSummaryRow extends ConsumerWidget {
  final String diveId;

  const _LastDiveSummaryRow({required this.diveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dive = ref.watch(diveProvider(diveId)).valueOrNull;
    if (dive == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '#${dive.diveNumber ?? '-'}',
                  maxLines: 1,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dive.effectiveName ??
                      dive.site?.name ??
                      l10n.diveLog_listPage_unknownSite,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  units.formatDateTimeBullet(dive.effectiveEntryTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
